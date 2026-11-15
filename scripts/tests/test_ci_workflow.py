"""Guard when the reusable CI actually runs native GUI regressions."""
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

WORKFLOW = Path(__file__).resolve().parents[2] / ".github/workflows/ci.yml"


class NativeGuiPolicyTests(unittest.TestCase):
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

    def test_release_skips_all_gui_steps_but_keeps_unit_tests(self):
        release = (WORKFLOW.parent / 'release.yml').read_text()
        inputs = re.search(r'    with:\n(.*?)    secrets:', release, re.S).group(1)
        self.assertIn('run_gui: false', inputs)
        self.assertNotIn('run_tests:', inputs)
        nightly = (WORKFLOW.parent / 'nightly.yml').read_text()
        nightly_inputs = re.search(r'    with:\n(.*?)    secrets:', nightly, re.S).group(1)
        self.assertIn('run_gui: false', nightly_inputs)
        self.assertIn('run_tests: false', nightly_inputs)
        source = WORKFLOW.read_text()
        self.assertRegex(source, r"- name: Verify bubblewrap user namespaces\n\s+if: format\('\{0\}', inputs.run_gui\) != 'false'")
        self.assertIn("shard: [0, 1, 2]", source)
        self.assertIn("TIXUN_GUI_SHARD_COUNT: '3'", source)
        self.assertIn('TIXUN_GUI_SHARD_INDEX: ${{ matrix.shard }}', source)
        for command in ('flutter build linux --release --dart-define=TIXUN_DEMO=true',
                        'scripts/gui_smoke.sh'):
            self.assertIn(f"- run: {command}\n        if: format('{{0}}', inputs.run_gui) != 'false'", source)


if __name__ == "__main__":
    unittest.main()
