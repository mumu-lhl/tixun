from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from zipfile import ZipFile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_artifacts import ABIS, build_release, package_android, release_apks, verify_apk, verify_release_set


class ApkVariantTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def apk(self, path, abis):
        with ZipFile(path, 'w') as file:
            for abi in abis:
                for name in ['libapp.so', 'libflutter.so']:
                    file.writestr(f'lib/{abi}/{name}', b'fixture')

    def test_each_split_has_exactly_one_abi_and_universal_has_all(self):
        path = self.root / 'app.apk'
        for abi, _ in release_apks():
            abis = ABIS if abi == 'universal' else [abi]
            self.apk(path, abis)
            verify_apk(path, 'release', '', abi)
            wrong = 'arm64-v8a' if abi == 'universal' else 'universal'
            with self.assertRaisesRegex(ValueError, 'architecture'):
                verify_apk(path, 'release', '', wrong)

    def test_missing_engine_library_is_rejected(self):
        path = self.root / 'app.apk'
        with ZipFile(path, 'w') as file:
            file.writestr('lib/arm64-v8a/libapp.so', b'fixture')
        with self.assertRaisesRegex(ValueError, 'architecture'):
            verify_apk(path, 'release', '', 'arm64-v8a')

    def test_variants_must_share_id_and_version_to_allow_switching(self):
        for abi, name in release_apks():
            self.apk(self.root / name, ABIS if abi == 'universal' else [abi])
        good = "package: name='org.tixun.tixun' versionCode='7' versionName='0.5.2'"
        verify_release_set(self.root, lambda _: good)
        for replacement in ["versionCode='2007'", "versionName='0.5.3'", "name='org.other'"]:
            field = replacement.split('=')[0]
            wrong = re.sub(field + r"='[^']+'", replacement, good)
            with self.subTest(replacement=replacement), self.assertRaisesRegex(ValueError, 'share'):
                verify_release_set(self.root, lambda p: wrong if 'arm64' in p.name else good)

    def test_build_preserves_universal_when_split_build_replaces_flutter_outputs(self):
        source, destination = self.root / 'flutter', self.root / 'release'
        source.mkdir()
        def run(command, check):
            self.assertTrue(check)
            if '--split-per-abi' not in command:
                (source / 'app-release.apk').write_bytes(b'universal before split')
            else:
                (source / 'app-release.apk').unlink()
                for abi in ABIS:
                    (source / f'app-{abi}-release.apk').write_text(abi)
        build_release(destination, run=run, source=source)
        self.assertEqual((destination / 'app-release.apk').read_bytes(), b'universal before split')
        self.assertEqual({p.name for p in destination.iterdir()}, {name for _, name in release_apks()})
        with self.assertRaisesRegex(ValueError, 'stale'):
            build_release(destination, run=run, source=source)

    def test_failed_build_never_exposes_partial_artifact(self):
        source, destination = self.root / 'flutter', self.root / 'release'
        source.mkdir()
        def run(command, check):
            if '--split-per-abi' in command:
                raise subprocess.CalledProcessError(1, command)
            (source / 'app-release.apk').write_bytes(b'universal')
        with self.assertRaises(subprocess.CalledProcessError):
            build_release(destination, run=run, source=source)
        self.assertFalse(destination.exists())
        self.assertEqual({p.name for p in self.root.iterdir()}, {'flutter'})

    def test_packaging_includes_four_labeled_apks_and_rejects_extras(self):
        source, destination = self.root / 'input', self.root / 'dist'
        source.mkdir()
        for _, name in release_apks():
            (source / name).write_text(name)
        package_android(source, destination, 'v0.6.0')
        self.assertEqual({p.name for p in destination.iterdir()}, {
            f'tixun-v0.6.0-android-{abi}-release.apk' for abi, _ in release_apks()})
        (source / 'app-debug.apk').write_text('debug')
        with self.assertRaisesRegex(ValueError, 'exactly'):
            package_android(source, destination, 'nightly-20261108-203000')
        with self.assertRaisesRegex(ValueError, 'Invalid release tag'):
            package_android(source, destination, '../escape')


if __name__ == '__main__':
    unittest.main()
