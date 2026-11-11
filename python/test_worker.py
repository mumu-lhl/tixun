import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('worker', Path(__file__).parent / 'runtime' / 'main.py')
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)

class PythonWorkerTests(unittest.TestCase):
    def run_code(self, code, timeout=2, cancel=False):
        with tempfile.TemporaryDirectory() as tmp:
            stop = Path(tmp) / 'cancel'
            if cancel:
                stop.touch()
            return worker.execute({'id': 'test', 'code': code,
                'workspace': tmp, 'timeout_seconds': timeout}, stop)

    def test_arbitrary_python_and_imports(self):
        r = self.run_code('from fractions import Fraction\nprint(sum(Fraction(1, n) for n in range(1, 5)))')
        self.assertTrue(r['ok'])
        self.assertEqual(r['stdout'], '25/12\n')

    def test_files_and_stderr_are_allowed(self):
        r = self.run_code("from pathlib import Path\nimport sys\nPath('result.txt').write_text('42')\nprint(Path('result.txt').read_text())\nprint('note', file=sys.stderr)")
        self.assertEqual(r['stdout'], '42\n')
        self.assertEqual(r['stderr'], 'note\n')

    def test_exception_and_system_exit_are_reported(self):
        for code in ['1/0', 'raise SystemExit(2)']:
            r = self.run_code(code)
            self.assertFalse(r['ok'])
            self.assertTrue(r['traceback'])

    def test_timeout_and_cancellation(self):
        self.assertEqual(self.run_code('while True: pass', timeout=.05)['error'], 'TimeoutError')
        self.assertEqual(self.run_code('while True: pass', cancel=True)['error'], 'InterruptedError')

    def test_output_is_bounded_without_restricting_code(self):
        r = self.run_code("print('a' * 100000)")
        self.assertTrue(r['ok'])
        self.assertTrue(r['output_truncated'])
        self.assertEqual(len(r['stdout']), worker.LIMIT)

if __name__ == '__main__':
    unittest.main()
