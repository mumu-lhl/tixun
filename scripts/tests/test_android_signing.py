import base64
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from android_signing import cleanup, prepare, verify_certificate


class SigningPolicyTests(unittest.TestCase):
    def test_missing_and_malformed_secrets_do_not_create_files(self):
        with tempfile.TemporaryDirectory() as root:
            env = {**os.environ, 'RUNNER_TEMP': root}
            for key in ['ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_PASSWORD']:
                env.pop(key, None)
            with self.assertRaisesRegex(ValueError, 'Missing signing secrets'):
                prepare(env)
            env.update(ANDROID_KEYSTORE_BASE64='invalid!', ANDROID_KEYSTORE_PASSWORD='private',
                       ANDROID_KEY_PASSWORD='private')
            with self.assertRaisesRegex(ValueError, 'not valid Base64'):
                prepare(env)
            env['ANDROID_KEYSTORE_BASE64'] = '  \n'
            with self.assertRaisesRegex(ValueError, 'empty'):
                prepare(env)
            self.assertEqual(list(Path(root).iterdir()), [])

    def test_signature_must_have_exactly_one_matching_certificate(self):
        expected = hashlib.sha256(b'certificate-fixture').hexdigest()
        valid = '-----BEGIN CERTIFICATE-----\n' + base64.b64encode(b'certificate-fixture').decode() + '\n-----END CERTIFICATE-----\n'
        verify_certificate(valid, expected)
        for output, fingerprint in [('', expected), (valid, ''), (valid, 'cd' * 32),
                                    (valid + valid, expected)]:
            with self.subTest(output=output, fingerprint=fingerprint), self.assertRaises(ValueError):
                verify_certificate(output, fingerprint)

    def test_cleanup_refuses_other_paths_and_symlinks(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'tixun-signing-fixture'
            path.mkdir()
            (path / 'release.jks').write_bytes(b'private fixture')
            link = Path(root) / 'tixun-signing-link'
            link.symlink_to(path, target_is_directory=True)
            for unsafe in [root, str(Path(root) / 'other'), str(link)]:
                with self.subTest(path=unsafe), self.assertRaises(ValueError):
                    cleanup(unsafe, root)
            self.assertTrue(path.exists())
            cleanup(str(path), root)
            self.assertFalse(path.exists())
            cleanup('', root)


@unittest.skipUnless(shutil.which('keytool'), 'JDK keytool is required')
class KeyStoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temp.cleanup)
        path = Path(cls.temp.name) / 'fixture.jks'
        env = {**os.environ, 'FIXTURE_PASSWORD': 'fixture-password-only'}
        subprocess.run([
            'keytool', '-genkeypair', '-keystore', str(path), '-storetype', 'JKS',
            '-alias', 'tixun', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '2',
            '-dname', 'CN=Signing Test', '-storepass:env', 'FIXTURE_PASSWORD',
            '-keypass:env', 'FIXTURE_PASSWORD',
        ], env=env, check=True, capture_output=True, timeout=30)
        cls.encoded = base64.b64encode(path.read_bytes()).decode()

    def setUp(self):
        self.root = tempfile.TemporaryDirectory()
        self.addCleanup(self.root.cleanup)
        self.env = {**os.environ, 'RUNNER_TEMP': self.root.name,
                    'ANDROID_KEYSTORE_BASE64': self.encoded,
                    'ANDROID_KEYSTORE_PASSWORD': 'fixture-password-only',
                    'ANDROID_KEY_PASSWORD': 'fixture-password-only'}
        self.env.pop('ANDROID_KEY_ALIAS', None)

    def test_default_alias_private_permissions_and_certificate(self):
        result = prepare(self.env)
        self.assertEqual(Path(result['directory']).stat().st_mode & 0o777, 0o700)
        self.assertEqual(Path(result['keystore_path']).stat().st_mode & 0o777, 0o600)
        self.assertRegex(result['certificate_sha256'], r'^[a-f0-9]{64}$')
        cleanup(result['directory'], self.root.name)
        self.assertEqual(list(Path(self.root.name).iterdir()), [])

    def test_empty_alias_uses_same_default_and_wrapped_base64_works(self):
        first = prepare(self.env)
        self.env.update(ANDROID_KEY_ALIAS='', ANDROID_KEYSTORE_BASE64='\n' + self.encoded + '\n')
        second = prepare(self.env)
        self.assertEqual(first['certificate_sha256'], second['certificate_sha256'])

    def test_wrong_password_or_alias_cleans_files_without_leaking_values(self):
        for override in [{'ANDROID_KEYSTORE_PASSWORD': 'do-not-print-this-password'},
                         {'ANDROID_KEY_ALIAS': 'nonexistent-alias'}]:
            with self.subTest(override=tuple(override)):
                with self.assertRaises(ValueError) as caught:
                    prepare({**self.env, **override})
                for value in override.values():
                    self.assertNotIn(value, str(caught.exception))
                self.assertEqual(list(Path(self.root.name).iterdir()), [])


if __name__ == '__main__':
    unittest.main()
