import subprocess
import sys
import unittest
from pathlib import Path


class DisabledInProcessWorkerTests(unittest.TestCase):
    def test_legacy_worker_fails_closed(self):
        worker = Path(__file__).parent / 'runtime' / 'main.py'
        result = subprocess.run(
            [sys.executable, str(worker)], capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 78)
        self.assertIn('In-process Python execution is disabled', result.stderr)


if __name__ == '__main__':
    unittest.main()
