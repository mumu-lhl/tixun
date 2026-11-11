import io
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_python_bundle import check_android, check_linux


def zipped(files):
    data = io.BytesIO()
    with zipfile.ZipFile(data, 'w') as out:
        for name in files:
            out.writestr(name, b'fixture')
    return data.getvalue()


class PythonBundleTests(unittest.TestCase):
    def apk(self, root, *, worker=True, sympy=True, runtime=True):
        apk = root / 'app.apk'
        with zipfile.ZipFile(apk, 'w') as out:
            out.writestr('assets/app.zip', zipped(['main.py'] if worker else []))
            out.writestr('assets/stdlib.zip', zipped(['encodings/__init__.pyc']))
            out.writestr('assets/sitepackages.zip', zipped(
                ['mpmath/__init__.py'] + (['sympy/__init__.py'] if sympy else [])))
            if runtime:
                out.writestr('lib/arm64-v8a/libpython3.13.so', b'fixture')
        return apk

    def test_complete_android_bundle(self):
        with tempfile.TemporaryDirectory() as tmp:
            check_android(self.apk(Path(tmp)))

    def test_incomplete_android_bundles_fail(self):
        for missing in ('worker', 'sympy', 'runtime'):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory() as tmp:
                with self.assertRaises(ValueError):
                    check_android(self.apk(Path(tmp), **{missing: False}))

    def test_linux_requires_worker_dependencies_stdlib_and_runtime(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            files = ['app/main.py', 'site-packages/sympy/__init__.py',
                     'site-packages/mpmath/__init__.py', 'lib/libpython3.13.so.1.0',
                     'python3.13/encodings/__init__.pyc']
            for name in files:
                p = root / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.touch()
            check_linux(root)
            for name in files:
                p = root / name
                p.unlink()
                with self.assertRaises(ValueError):
                    check_linux(root)
                p.touch()
