#!/usr/bin/env python3
"""Prepare isolated signing material and verify the actual APK certificate."""
import argparse
import base64
import binascii
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from build_artifacts import find_aapt, release_apks


def prepare(env):
    required = ('ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_PASSWORD')
    missing = [name for name in required if not env.get(name)]
    if missing:
        raise ValueError('Missing signing secrets: ' + ', '.join(missing))
    encoded = ''.join(env['ANDROID_KEYSTORE_BASE64'].split())
    if len(encoded) > 2 * 1024 * 1024:
        raise ValueError('Keystore is too large')
    try:
        data = base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error):
        raise ValueError('ANDROID_KEYSTORE_BASE64 is not valid Base64') from None
    if not data:
        raise ValueError('Keystore is empty')
    alias = env.get('ANDROID_KEY_ALIAS') or 'tixun'
    if not alias.strip():
        alias = 'tixun'
    directory = Path(tempfile.mkdtemp(prefix='tixun-signing-', dir=env['RUNNER_TEMP']))
    try:
        path = directory / 'release.jks'
        with path.open('xb') as file:
            path.chmod(0o600)
            file.write(data)
        # Passwords are read from the environment, never process arguments.
        result = subprocess.run([
            'keytool', '-exportcert', '-keystore', str(path), '-alias', alias,
            '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD',
        ], env=env, capture_output=True, timeout=30)
        if result.returncode or not result.stdout:
            raise ValueError('Cannot read signing certificate; check keystore, store password and key alias (default: tixun)')
        return dict(directory=str(directory), keystore_path=str(path),
                    certificate_sha256=hashlib.sha256(result.stdout).hexdigest())
    except BaseException:
        shutil.rmtree(directory)
        raise


def verify_certificate(output, expected):
    if not re.fullmatch(r'[0-9a-fA-F]{64}', expected):
        raise ValueError('Expected signing certificate SHA-256 is missing or invalid')
    signers = re.findall(r'^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]+)\s*$',
                         output, re.MULTILINE)
    if len(signers) != 1 or signers[0].lower() != expected.lower():
        raise ValueError('APK signing certificate does not match the configured release key')


def cleanup(directory, runner_temp):
    if not directory:
        return
    path = Path(directory).absolute()
    root = Path(runner_temp).resolve()
    if path.is_symlink() or path.parent.resolve() != root or not path.name.startswith('tixun-signing-'):
        raise ValueError('Refusing to remove a path outside the signing temporary directory')
    if path.exists():
        shutil.rmtree(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('prepare')
    sub.add_parser('cleanup')
    verify = sub.add_parser('verify')
    verify.add_argument('apk', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'prepare':
            for key, value in prepare(os.environ).items():
                print(f'{key}={value}')
        elif args.command == 'cleanup':
            cleanup(os.environ.get('SIGNING_DIRECTORY'), os.environ['RUNNER_TEMP'])
        else:
            paths = [args.apk / name for _, name in release_apks()] if args.apk.is_dir() else [args.apk]
            for path in paths:
                result = subprocess.run([
                    str(find_aapt().with_name('apksigner')), 'verify', '--verbose', '--print-certs', str(path),
                ], capture_output=True, text=True, timeout=60)
                if result.returncode:
                    raise ValueError(f'APK signature verification failed: {path.name}')
                verify_certificate(result.stdout, os.environ.get('EXPECTED_CERT_SHA256', ''))
                print(f'APK release signature verified: {path.name}')
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        # Never echo tool output, secret values or command arguments on failure.
        message = str(error) if isinstance(error, ValueError) else 'Signing tool failed; check the runner configuration'
        parser.exit(1, message + '\n')


if __name__ == '__main__':
    main()
