import base64
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile


class ZipRuntimeTest(unittest.TestCase):
    def test_workspace_from_zipimport_runtime(self):
        import pyfakefs
        package = Path(pyfakefs.__file__).parent
        worker = Path(__file__).parent / "runtime"
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "runtime.zip"
            with zipfile.ZipFile(archive, "w") as target:
                for path in package.rglob("*.py"):
                    target.write(path, "pyfakefs/" + path.relative_to(package).as_posix())
                for path in worker.glob("*.py"):
                    target.write(path, path.name)
            script = (
                "import sys; sys.path.insert(0, sys.argv[1]); "
                "from android_workspace import execute; "
                "result, error = execute(\"open('result', 'w').write('ok')\", "
                "{'files': {}, 'directories': []}); "
                "assert error is None; assert result['files'] == {'result': 'b2s='}"
            )
            result = subprocess.run(
                [sys.executable, "-I", "-c", script, str(archive)],
                capture_output=True, text=True, timeout=30,
            )
            self.assertEqual(result.returncode, 0, result.stderr[-3000:])


class AndroidOutputTest(unittest.TestCase):
    def test_output_is_bounded_by_utf8_bytes_and_still_decodable(self):
        from runtime.android_worker import LimitedOutput
        output = LimitedOutput()
        self.assertEqual(output.write("😀" * 10000), 10000)
        self.assertEqual(len(output.value), 8000)
        self.assertTrue(output.truncated)
        output.write("more")
        self.assertEqual(len(output.data), 32000)


class AndroidWorkspaceTest(unittest.TestCase):
    def execute(self, code, files=None):
        from runtime.android_workspace import execute
        with contextlib.redirect_stderr(io.StringIO()):
            return execute(code, {"files": files or {}, "directories": []})

    def test_files_and_directories_round_trip(self):
        snapshot, error = self.execute(
            "from pathlib import Path\n"
            "Path('nested').mkdir()\n"
            "Path('nested/output.txt').write_text(Path('input.txt').read_text() + '!')\n"
            "Path('input.txt').unlink()",
            {"input.txt": base64.b64encode(b"hello").decode()},
        )
        self.assertIsNone(error)
        self.assertEqual(snapshot["directories"], ["nested"])
        self.assertEqual(snapshot["files"], {"nested/output.txt": "aGVsbG8h"})

    def test_executions_do_not_share_in_memory_files(self):
        self.execute("open('previous', 'w').write('old')")
        snapshot, error = self.execute("pass")
        self.assertIsNone(error)
        self.assertEqual(snapshot["files"], {})

    def test_rejects_link_exports(self):
        with self.assertRaisesRegex(ValueError, "links"):
            self.execute("import os\nos.symlink('/etc/passwd', 'escape')")

    def test_rejects_oversized_output(self):
        with self.assertRaisesRegex(ValueError, "8 MiB"):
            self.execute("open('huge', 'wb').write(b'x' * (8 * 1024 * 1024 + 1))")

    def test_error_keeps_regular_file_changes(self):
        snapshot, error = self.execute("open('ok', 'w').write('saved')\nraise ValueError('bad')")
        self.assertEqual(error, "ValueError")
        self.assertIn("ok", snapshot["files"])
