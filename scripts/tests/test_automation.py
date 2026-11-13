import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from zipfile import ZipFile

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
from build_artifacts import verify_apk
from check_release_tag import check
from release_notes import choose_base, tag_pattern, decode_pages, has_changes


class ApkTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'renamed-app-release.apk'

    def apk(self, *names):
        with ZipFile(self.path, 'w') as apk:
            for name in names:
                apk.writestr(name, b'fixture')

    def test_release_accepts_aot_without_debuggable(self):
        self.apk('lib/arm64-v8a/libapp.so')
        verify_apk(self.path, 'release', 'package: name=org.tixun.tixun')

    def test_renaming_debug_file_does_not_pass_release_verification(self):
        self.apk('assets/flutter_assets/kernel_blob.bin')
        with self.assertRaises(ValueError):
            verify_apk(self.path, 'release', 'application-debuggable')

    def test_each_release_requirement_is_enforced(self):
        for names, badging in [
            (['lib/x86_64/libapp.so'], 'application-debuggable'),
            (['lib/x86_64/libapp.so', 'assets/flutter_assets/kernel_blob.bin'], ''),
            (['lib/x86_64/libflutter.so'], ''),
        ]:
            with self.subTest(names=names, badging=badging):
                self.apk(*names)
                with self.assertRaises(ValueError):
                    verify_apk(self.path, 'release', badging)

    def test_debug_verification_and_invalid_archives(self):
        self.apk('assets/flutter_assets/kernel_blob.bin')
        verify_apk(self.path, 'debug', 'application-debuggable')
        with self.assertRaises(ValueError):
            verify_apk(self.path, 'debug', '')
        self.path.write_text('not an APK')
        with self.assertRaises(ValueError):
            verify_apk(self.path, 'release', '')


class TagTests(unittest.TestCase):
    def test_version_and_build_number(self):
        self.assertEqual(check('v0.5.2', 'version: 0.5.2+7'), ('0.5.2', False))
        self.assertEqual(check('v0.6.0-rc.1', 'version: "0.6.0-rc.1+8"'), ('0.6.0-rc.1', True))

    def test_invalid_and_mismatched_versions(self):
        for tag in ['v0.5.3', 'v0.05.2', 'v0.5.2+7', 'v0.5.2-01', 'v0.5.2\nother=true']:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                check(tag, 'version: 0.5.2+7')


class ApiPagesTests(unittest.TestCase):
    def test_all_paginated_release_arrays_are_read(self):
        self.assertEqual(decode_pages('[{"tag_name":"v1.0.0"}]\n [{"tag_name":"v0.9.0"}]\n'),
                         [{'tag_name': 'v1.0.0'}, {'tag_name': 'v0.9.0'}])
        self.assertEqual(decode_pages('[]'), [])

    def test_api_errors_cannot_be_mistaken_for_first_release(self):
        with self.assertRaises(ValueError):
            decode_pages('{"message":"Bad credentials"}')
        with self.assertRaises(ValueError):
            decode_pages('not json')
        with self.assertRaises(ValueError):
            decode_pages('')


class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git('init', '-b', 'main')
        self.git('config', 'user.name', 'Release Test')
        self.git('config', 'user.email', 'release-test@example.invalid')
        self.commit('Initial public release', 'v0.1.0')
        self.commit('Failed build must remain in history', 'v0.2.0')
        self.commit('Draft release', 'v0.3.0-rc.1')
        self.commit('Current release', 'v0.3.0')

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], stderr=subprocess.DEVNULL, text=True)

    def commit(self, message, tag):
        self.git('commit', '--allow-empty', '-m', message)
        self.git('tag', tag)

    def public(self, tag, date='2026-01-01T00:00:00Z', draft=False):
        return dict(tag_name=tag, published_at=date, draft=draft)

    def test_failed_and_draft_tags_do_not_truncate_history(self):
        releases = [self.public('v0.1.0'), self.public('v0.3.0-rc.1', draft=True)]
        self.assertEqual(choose_base(releases, 'v0.3.0', self.repo), 'v0.1.0')
        self.assertEqual(tag_pattern('v0.3.0', 'v0.1.0'), r'^(v0\.1\.0|v0\.3\.0)$')

    def test_first_public_release_ignores_all_unpublished_tags(self):
        self.assertIsNone(choose_base([], 'v0.3.0', self.repo))
        self.assertEqual(tag_pattern('v0.3.0', None), r'^(v0\.3\.0)$')

    def test_resume_current_draft_and_ignore_current_public_release(self):
        releases = [self.public('v0.1.0'), self.public('v0.3.0', '2026-02-01T00:00:00Z')]
        self.assertEqual(choose_base(releases, 'v0.3.0', self.repo), 'v0.1.0')

    def test_published_prereleases_participate(self):
        releases = [self.public('v0.1.0'), self.public('v0.3.0-rc.1', '2026-02-01T00:00:00Z')]
        self.assertEqual(choose_base(releases, 'v0.3.0', self.repo), 'v0.3.0-rc.1')

    def test_other_branch_is_not_a_comparison_base(self):
        self.git('checkout', '-b', 'other', 'v0.1.0')
        self.commit('Different branch', 'v9.0.0')
        self.git('checkout', '--detach', 'v0.3.0')
        releases = [self.public('v0.1.0'), self.public('v9.0.0', '2026-03-01T00:00:00Z')]
        self.assertEqual(choose_base(releases, 'v0.3.0', self.repo), 'v0.1.0')

    def test_missing_published_tag_fails_instead_of_silently_changing_range(self):
        with self.assertRaises(ValueError):
            choose_base([self.public('v1.0.0')], 'v0.3.0', self.repo)

    def test_nightly_prefers_published_nightly_and_falls_back_to_stable(self):
        old, current = 'nightly-20261107-203000', 'nightly-20261108-203000'
        self.git('tag', old, 'v0.2.0')
        self.git('tag', current, 'v0.3.0')
        releases = [self.public('v0.1.0'), self.public(old, '2026-01-02T00:00:00Z'),
                    self.public('v0.3.0', '2026-01-03T00:00:00Z')]
        self.assertEqual(choose_base(releases, current, self.repo, nightly=True), old)
        releases[1]['draft'] = True
        self.assertEqual(choose_base(releases, current, self.repo, nightly=True), 'v0.3.0')

    def test_stable_changelog_ignores_nightly_and_invalid_nightly_fails(self):
        old = 'nightly-20261107-203000'
        self.git('tag', old, 'v0.2.0')
        releases = [self.public('v0.1.0'), self.public(old, '2026-01-02T00:00:00Z')]
        self.assertEqual(choose_base(releases, 'v0.3.0', self.repo), 'v0.1.0')
        with self.assertRaises(ValueError):
            choose_base(releases, 'nightly-invalid', self.repo, nightly=True)

    def test_unreachable_nightly_and_missing_published_tags_are_not_silent(self):
        old, current = 'nightly-20261107-203000', 'nightly-20261108-203000'
        self.git('tag', current, 'v0.3.0')
        with self.assertRaises(ValueError):
            choose_base([self.public(old)], current, self.repo, nightly=True)
        self.git('checkout', '-b', 'other-nightly', 'v0.1.0')
        self.commit('Unrelated nightly', old)
        self.git('checkout', '--detach', current)
        self.assertIsNone(choose_base([self.public(old)], current, self.repo, nightly=True))

    def test_nightly_without_code_changes_does_not_replay_entire_history(self):
        current = 'nightly-20261108-203000'
        self.git('tag', current, 'v0.3.0')
        self.assertFalse(has_changes('v0.3.0', current, self.repo))
        self.assertTrue(has_changes('v0.1.0', current, self.repo))
        self.assertTrue(has_changes(None, current, self.repo))

    def test_cli_emits_an_explicit_range_even_with_stable_tag_on_same_commit(self):
        old, current = 'nightly-20261107-203000', 'nightly-20261108-203000'
        self.git('tag', old, 'v0.1.0')
        self.git('tag', '-a', 'v0.3.1', '-m', 'Stable release on current commit')
        self.git('tag', current)
        gh = self.repo / 'gh'
        gh.write_text('#!/bin/sh\ncat "$RELEASE_FIXTURE"\n')
        gh.chmod(0o755)
        fixture = self.repo / 'releases.json'
        env = {**os.environ, 'PATH': str(self.repo) + os.pathsep + os.environ['PATH'],
               'RELEASE_FIXTURE': str(fixture)}
        for published in ([self.public(old), self.public('v0.3.1')], []):
            fixture.write_text(json.dumps(published))
            result = subprocess.check_output(
                [sys.executable, str(SCRIPTS / 'release_notes.py'), '--nightly',
                 '--tag', current, '--repo', 'owner/repo'],
                cwd=self.repo, env=env, text=True)
            values = dict(line.split('=', 1) for line in result.splitlines())
            commit = self.git('rev-parse', f'{current}^{{commit}}').strip()
            self.assertEqual(values['current_commit'], commit)
            self.assertIsNotNone(re.fullmatch(values['tag_pattern'], commit))
            self.assertIsNone(re.fullmatch(values['tag_pattern'], current))
            if not published:
                # git-cliff accepts a single OID, but not a single tag name.
                self.assertRegex(values['commit_range'], r'^[0-9a-f]{40,64}$')
            commits = self.git('log', '--format=%s', values['commit_range']).splitlines()
            self.assertIn('Current release', commits)
            self.assertIn('Failed build must remain in history', commits)
            self.assertEqual('Initial public release' in commits, not published)


class GuiRunnerTests(unittest.TestCase):
    def run_gui(self, fail=''):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name, body in {
                'xvfb-run': 'shift 3\nexec "$@"',
                'dbus-run-session': 'shift\nexec "$@"',
                'flutter': '''echo "$2" >> "$GUI_CALLS"
echo "captured $2"
test "$LIBGL_ALWAYS_SOFTWARE" = 1 || exit 7
case "$2" in *"$FAIL_GUI"*) if [ -n "$FAIL_GUI" ]; then exit 23; fi;; esac''',
            }.items():
                file = root / name
                file.write_text('#!/bin/sh\n' + body + '\n')
                file.chmod(0o755)
            env = {**os.environ, 'PATH': f'{root}:{os.environ["PATH"]}',
                   'GUI_CALLS': str(root / 'calls'), 'FAIL_GUI': fail,
                   'TIXUN_GUI_LOG_DIR': str(root / 'logs')}
            result = subprocess.run(['bash', str(SCRIPTS / 'gui_tests.sh')], env=env, capture_output=True, text=True)
            calls = (root / 'calls').read_text().splitlines()
            logs = {p.name: p.read_text() for p in (root / 'logs').iterdir()}
            return result.returncode, calls, logs

    def test_each_native_flow_runs_once_with_its_own_log(self):
        code, calls, logs = self.run_gui()
        self.assertEqual(code, 0)
        self.assertEqual(sorted(Path(p).name for p in calls),
                         sorted(p.name for p in (SCRIPTS.parent / 'integration_test').glob('*_test.dart')))
        self.assertEqual(len(set(calls)), len(calls))
        self.assertEqual(len(logs), len(calls))
        self.assertIn('practice_management_test', logs['integration-management.log'])

    def test_first_failure_stops_later_builds_and_preserves_exit_code_and_log(self):
        code, calls, logs = self.run_gui('learning_materials')
        self.assertEqual(code, 23)
        self.assertEqual(Path(calls[-1]).stem, 'learning_materials_test')
        self.assertLess(len(calls), len(list((SCRIPTS.parent / 'integration_test').glob('*_test.dart'))))
        self.assertEqual(len(logs), len(calls))
        self.assertIn('learning_materials_test', logs['integration-materials.log'])


if __name__ == '__main__':
    unittest.main()
