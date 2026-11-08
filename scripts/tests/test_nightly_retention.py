import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from prune_nightlies import deletion_candidates, prune


OLD = 'nightly-20261107-203000'
KEEP = 'nightly-20261108-203000'


def release(tag, **overrides):
    return dict({'id': 12, 'tag_name': tag, 'prerelease': True, 'draft': False,
                 'published_at': tag, 'body': ''}, **overrides)


class RetentionTests(unittest.TestCase):
    def test_only_public_nightly_prereleases_are_deleted(self):
        old = release(OLD)
        protected = [release('v1.0.0', prerelease=False), release('v1.1.0-rc.1'),
                     release('nightly-other'), release('nightly-20261106-203000', draft=True),
                     release('nightly-20261105-203000', prerelease=False)]
        self.assertEqual(deletion_candidates([old, release(KEEP), *protected], KEEP), [old])

    def test_missing_draft_stable_and_superseded_keep_are_rejected(self):
        for releases, keep in [([], KEEP), ([release(KEEP, draft=True)], KEEP),
                               ([release(KEEP, prerelease=False)], KEEP),
                               ([release(OLD), release(KEEP)], OLD),
                               ([release('v1.0.0')], 'v1.0.0')]:
            with self.subTest(keep=keep), self.assertRaises(ValueError):
                deletion_candidates(releases, keep)

    def test_patch_changelog_before_deleting_release_and_tag(self):
        sha = 'a' * 40
        body = f'**Full Changelog**: https://github.com/owner/repo/compare/{OLD}...{KEEP}'
        run = Mock(side_effect=[
            subprocess.CompletedProcess([], 0, json.dumps([release(OLD), release(KEEP, body=body)])),
            subprocess.CompletedProcess([], 0, sha + '\n'),
            subprocess.CompletedProcess([], 0), subprocess.CompletedProcess([], 0)])
        prune('owner/repo', KEEP, apply=True, run=run)
        patch = run.call_args_list[2]
        self.assertIn('--method', patch.args[0])
        self.assertIn(f'/compare/{sha}...{KEEP}', json.loads(patch.kwargs['input'])['body'])
        self.assertEqual(run.call_args_list[3].args[0], [
            'gh', 'release', 'delete', OLD, '--repo', 'owner/repo', '--yes', '--cleanup-tag'])

    def test_failed_changelog_update_prevents_any_deletion(self):
        body = f'https://github.com/owner/repo/compare/{OLD}...{KEEP}'
        run = Mock(side_effect=[
            subprocess.CompletedProcess([], 0, json.dumps([release(OLD), release(KEEP, body=body)])),
            subprocess.CompletedProcess([], 0, 'a' * 40),
            subprocess.CalledProcessError(1, 'gh')])
        with self.assertRaises(subprocess.CalledProcessError):
            prune('owner/repo', KEEP, apply=True, run=run)
        self.assertEqual(run.call_count, 3)

    def test_dry_run_and_repeated_cleanup_do_not_delete_anything(self):
        for releases, apply in [([release(OLD), release(KEEP)], False), ([release(KEEP)], True)]:
            run = Mock(return_value=subprocess.CompletedProcess([], 0, json.dumps(releases)))
            prune('owner/repo', KEEP, apply=apply, run=run)
            self.assertEqual(run.call_count, 1)


if __name__ == '__main__':
    unittest.main()
