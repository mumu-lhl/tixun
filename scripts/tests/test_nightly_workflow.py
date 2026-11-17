"""Exercise the actual fixed-nightly publish step with a local Git remote."""
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest

WORKFLOW = Path(__file__).resolve().parents[2] / '.github/workflows/nightly.yml'


class NightlyPublishTests(unittest.TestCase):
    def test_build_only_when_published_nightly_needs_updating(self):
        text = WORKFLOW.read_text()
        step = text.split('      - name: Check for changes since the published nightly\n', 1)[1]
        step = textwrap.dedent(step.split('        run: |\n', 1)[1].split('      - id: tag', 1)[0])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.run(['git', *args], cwd=root, check=True,
                                      capture_output=True, text=True).stdout.strip()
            git('init', '-b', 'main')
            git('config', 'user.name', 'Nightly Test')
            git('config', 'user.email', 'nightly@example.invalid')
            git('commit', '--allow-empty', '-m', 'published')
            git('tag', 'nightly')
            published = git('rev-parse', 'HEAD')
            git('commit', '--allow-empty', '-m', 'new commit')
            current = git('rev-parse', 'HEAD')
            curl = root / 'curl'
            curl.write_text('''#!/bin/sh
printf '%s' "$RELEASE_JSON" > nightly-release.json
printf '%s' "$RELEASE_STATUS"
''')
            curl.chmod(0o755)
            output = root / 'output'
            env = {**os.environ, 'PATH': f'{root}{os.pathsep}{os.environ["PATH"]}',
                   'GH_TOKEN': 'test', 'GH_API_URL': 'https://example.invalid',
                   'GH_REPO': 'test/test', 'GITHUB_OUTPUT': str(output)}
            for status, release, sha, expected in (
                ('404', '{}', current, 'true'),
                ('200', '{"draft": false}', published, 'false'),
                ('200', '{"draft": false}', current, 'true'),
                ('200', '{"draft": true}', published, 'true'),
            ):
                with self.subTest(status=status, release=release, sha=sha):
                    output.write_text('')
                    env.update(RELEASE_STATUS=status, RELEASE_JSON=release, GITHUB_SHA=sha)
                    subprocess.run(['bash', '-c', step], cwd=root, env=env,
                                   check=True, capture_output=True, text=True)
                    self.assertEqual(output.read_text().strip(), f'should_build={expected}')
            env.update(RELEASE_STATUS='500', RELEASE_JSON='{}', GITHUB_SHA=current)
            self.assertNotEqual(subprocess.run(['bash', '-c', step], cwd=root, env=env,
                                               capture_output=True).returncode, 0)

    def test_first_publish_and_replacement_move_the_fixed_tag(self):
        text = WORKFLOW.read_text()
        step = text.split('      - name: Publish fixed nightly release\n        run: |\n', 1)[1]
        step = textwrap.dedent(step.split('      - name:', 1)[0])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            remote, repo = root / 'remote.git', root / 'repo'
            subprocess.run(['git', 'init', '--bare', str(remote)], check=True, capture_output=True)
            subprocess.run(['git', 'init', '-b', 'main', str(repo)], check=True, capture_output=True)
            def git(*args):
                return subprocess.run(['git', '-C', str(repo), *args], check=True,
                                      capture_output=True, text=True).stdout.strip()
            git('config', 'user.name', 'Nightly Test')
            git('config', 'user.email', 'nightly@example.invalid')
            git('remote', 'add', 'origin', str(remote))
            git('commit', '--allow-empty', '-m', 'first build')
            (repo / 'dist').mkdir()
            (repo / 'dist' / 'package.apk').write_text('fixture')
            (repo / 'release-notes.md').write_text('fixture')
            gh = root / 'gh'
            gh.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$GH_CALLS"
if [ "$1 $2" = 'release view' ]; then
  if [ "$RELEASE_EXISTS" = false ]; then exit 1; fi
  if [ "$RELEASE_EXISTS" = draft ]; then
    printf '{"isDraft":true,"name":"题训 %s","body":"original notes"}\n' "$BUILD_ID"
  else
    echo '{"isDraft":false,"body":"original notes"}'
  fi
fi
''')
            gh.chmod(0o755)
            calls = root / 'calls'
            env = {**os.environ, 'PATH': f'{root}{os.pathsep}{os.environ["PATH"]}',
                   'RELEASE_TAG': 'nightly', 'BUILD_ID': 'nightly-20261109-203000',
                   'GH_CALLS': str(calls)}
            for exists in (False, True):
                if exists:
                    git('commit', '--allow-empty', '-m', 'second build')
                sha = git('rev-parse', 'HEAD')
                env.update(GITHUB_SHA=sha, RELEASE_EXISTS=str(exists).lower())
                subprocess.run(['bash', '-c', step], cwd=repo, env=env,
                               check=True, capture_output=True, text=True)
                remote_sha = subprocess.check_output(
                    ['git', '--git-dir', str(remote), 'rev-parse', 'refs/tags/nightly'], text=True).strip()
                self.assertEqual(remote_sha, sha)
                commands = calls.read_text()
                if exists:
                    self.assertIn('release edit nightly --draft=true', commands)
                else:
                    self.assertIn('release create nightly', commands)
                self.assertIn('release upload nightly', commands)
                calls.unlink()
            (repo / 'release-notes.md').write_text('recomputed notes')
            env['RELEASE_EXISTS'] = 'draft'
            subprocess.run(['bash', '-c', step], cwd=repo, env=env,
                           check=True, capture_output=True, text=True)
            self.assertEqual((repo / 'release-notes.md').read_text(), 'original notes')


if __name__ == '__main__':
    unittest.main()
