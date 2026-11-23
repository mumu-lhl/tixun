"""Guard reusable CI check, publication, and native GUI policies."""
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

WORKFLOW = Path(__file__).resolve().parents[2] / ".github/workflows/ci.yml"


class WorkflowPolicyTests(unittest.TestCase):
    def test_manual_and_reusable_workflows_default_to_full_gui(self):
        source = WORKFLOW.read_text()
        defaults = re.findall(
            r"      full_gui:\n(?:        [^\n]*\n)*?        default: (true|false)",
            source,
        )
        self.assertEqual(defaults, ["true", "true"])

    def test_gui_condition_covers_push_pr_and_explicit_opt_out(self):
        source = WORKFLOW.read_text()
        condition = re.search(
            r"  gui:\n(?:.*\n)*?    if: ([^\n]+)", source,
        ).group(1)
        expression = condition.replace("&&", " and ").replace("||", " or ")
        # Evaluate only the checked-in Actions expression, with no Python builtins.
        def enabled(event, full_gui=None, run_tests=None, run_gui=None):
            return bool(eval(expression, {"__builtins__": {}}, {
                "github": SimpleNamespace(event_name=event),
                "inputs": SimpleNamespace(full_gui=full_gui, run_tests=run_tests, run_gui=run_gui),
                "format": lambda _, value: str(value).lower() if value is not None else "",
            }))

        for event in ("push", "pull_request"):
            with self.subTest(event=event):
                self.assertTrue(enabled(event))
        self.assertTrue(enabled("workflow_dispatch", True, True))
        self.assertFalse(enabled("workflow_dispatch", False, True))
        self.assertFalse(enabled("workflow_dispatch", True, False))
        self.assertFalse(enabled("schedule", True, False))
        self.assertFalse(enabled("push", True, False))
        self.assertFalse(enabled("push", True, True, False))
        self.assertFalse(enabled("workflow_dispatch", True, True, False))

    def test_checks_default_on_and_only_skip_when_explicitly_disabled(self):
        source = WORKFLOW.read_text()
        defaults = re.findall(
            r"      run_checks:\n(?:        [^\n]*\n)*?        default: (true|false)", source,
        )
        self.assertEqual(defaults, ['true', 'true'])
        condition = re.search(r"  checks:\n(?:.*\n)*?    if: ([^\n]+)", source).group(1)
        for value, expected in [(None, True), (True, True), (False, False)]:
            with self.subTest(run_checks=value):
                actual = eval(condition, {'__builtins__': {}}, {
                    'inputs': SimpleNamespace(run_checks=value),
                    'format': lambda _, item: str(item).lower() if item is not None else '',
                })
                self.assertEqual(actual, expected)

    def test_native_jobs_start_without_waiting_for_checks(self):
        source = WORKFLOW.read_text()
        for job in ('android', 'linux', 'gui'):
            with self.subTest(job=job):
                body = re.search(rf'^  {job}:\n(.*?)(?=^  [\w-]+:\n|\Z)', source, re.M | re.S).group(1)
                self.assertNotRegex(body, r'(?m)^    needs:')

    def test_gui_display_is_one_based_without_changing_shard_indices(self):
        source = WORKFLOW.read_text()
        self.assertIn('name: Native GUI regressions (${{ matrix.display }}/3)', source)
        shards = re.findall(r'- shard: (\d+)\n\s+display: (\d+)', source)
        self.assertEqual(shards, [('0', '1'), ('1', '2'), ('2', '3')])
        self.assertIn('TIXUN_GUI_SHARD_INDEX: ${{ matrix.shard }}', source)
        self.assertIn('name: tixun-linux-gui-regressions-${{ matrix.shard }}', source)

    def test_publications_skip_repeated_checks_and_tests(self):
        for filename in ('release.yml', 'nightly.yml'):
            with self.subTest(workflow=filename):
                publication = (WORKFLOW.parent / filename).read_text()
                inputs = re.search(r'    with:\n(.*?)    secrets:', publication, re.S).group(1)
                for option in ('run_checks', 'run_tests', 'run_gui'):
                    self.assertIn(f'{option}: false', inputs)
        source = WORKFLOW.read_text()
        self.assertRegex(source, r"- name: Verify bubblewrap user namespaces\n\s+if: format\('\{0\}', inputs.run_gui\) != 'false'")
        self.assertIn("TIXUN_GUI_SHARD_COUNT: '3'", source)
        self.assertIn('TIXUN_GUI_SHARD_INDEX: ${{ matrix.shard }}', source)
        for command in ('flutter build linux --release --dart-define=TIXUN_DEMO=true',
                        'scripts/gui_smoke.sh'):
            self.assertIn(f"- run: {command}\n        if: format('{{0}}', inputs.run_gui) != 'false'", source)


if __name__ == "__main__":
    unittest.main()
