#!/usr/bin/env python3
"""The shared artifact contract used by CI and release packaging."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from zipfile import BadZipFile, ZipFile

ABIS = ('armeabi-v7a', 'arm64-v8a', 'x86_64')


def release_apks():
    return [('universal', 'app-release.apk')] + [(abi, f'app-{abi}-release.apk') for abi in ABIS]


def metadata(platform, mode='release'):
    if platform == 'linux':
        return dict(artifact_name='tixun-linux-release', release_suffix='linux-x64.tar.gz',
                    bundle_path='artifacts/linux-production')
    if platform != 'android' or mode not in ('debug', 'release'):
        raise ValueError('Unsupported build platform or mode')
    apk_name = f'app-{mode}.apk'
    return dict(mode=mode, artifact_name=f'tixun-android-{mode}',
                artifact_path='artifacts/android-release' if mode == 'release'
                else f'build/app/outputs/flutter-apk/{apk_name}')


def verify_apk(path, mode, badging, abi=None):
    if mode not in ('debug', 'release'):
        raise ValueError('Unsupported APK mode')
    try:
        with ZipFile(path) as apk:
            names = set(apk.namelist())
    except BadZipFile as error:
        raise ValueError('Invalid APK archive') from error
    debuggable = 'application-debuggable' in badging
    kernel = 'assets/flutter_assets/kernel_blob.bin' in names
    aot = any(re.fullmatch(r'lib/[^/]+/libapp\.so', name) for name in names)
    if mode == 'release' and (debuggable or kernel or not aot):
        raise ValueError('Release APK required: must contain AOT code, without debuggable or Debug kernel')
    if mode == 'debug' and (not debuggable or not kernel):
        raise ValueError('Debug APK does not match the requested build mode')
    if abi is not None:
        expected = set(ABIS) if abi == 'universal' else {abi}
        actual = {m.group(1) for name in names if (m := re.fullmatch(r'lib/([^/]+)/libapp\.so', name))}
        engine = {m.group(1) for name in names if (m := re.fullmatch(r'lib/([^/]+)/libflutter\.so', name))}
        if abi not in (*ABIS, 'universal') or actual != expected or engine != expected:
            raise ValueError(f'APK native libraries do not match the requested architecture: {abi}')


def build_release(directory, run=subprocess.run, source=Path('build/app/outputs/flutter-apk')):
    directory = Path(directory)
    directory.parent.mkdir(parents=True, exist_ok=True)
    if directory.exists():
        raise ValueError('Release staging directory already exists; refusing stale APKs')
    with tempfile.TemporaryDirectory(prefix='android-build-', dir=directory.parent) as temp:
        staging = Path(temp)
        run(['flutter', 'build', 'apk', '--release'], check=True)
        shutil.copyfile(source / 'app-release.apk', staging / 'app-release.apk')
        run(['flutter', 'build', 'apk', '--release', '--split-per-abi'], check=True)
        for abi in ABIS:
            name = f'app-{abi}-release.apk'
            shutil.copyfile(source / name, staging / name)
        staging.rename(directory)


def package_android(source, destination, tag):
    if not re.fullmatch(r'(v[0-9A-Za-z.-]+|nightly-[0-9]{8}-[0-9]{6})', tag):
        raise ValueError('Invalid release tag')
    expected = {name for _, name in release_apks()}
    if {p.name for p in Path(source).iterdir()} != expected:
        raise ValueError('Expected exactly the Universal APK and three ABI APKs')
    Path(destination).mkdir(parents=True, exist_ok=True)
    for abi, name in release_apks():
        shutil.copyfile(Path(source) / name, Path(destination) / f'tixun-{tag}-android-{abi}-release.apk')


def verify_release_set(directory, inspect):
    versions = set()
    for abi, name in release_apks():
        path = Path(directory) / name
        badging = inspect(path)
        verify_apk(path, 'release', badging, abi)
        version = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging)
        if not version:
            raise ValueError('Cannot read APK application identity and version')
        versions.add(version.groups())
    if len(versions) != 1:
        raise ValueError('All APK variants must share the application ID and version codes')


def find_aapt():
    root = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    if not root:
        raise ValueError('ANDROID_HOME or ANDROID_SDK_ROOT is required')
    tools = list((Path(root) / 'build-tools').glob('*/aapt'))
    if not tools:
        raise ValueError('Android SDK aapt was not found')
    return max(tools, key=lambda p: tuple(map(int, re.findall(r'\d+', p.parent.name))))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    meta = sub.add_parser('metadata')
    meta.add_argument('platform', choices=['android', 'linux'])
    meta.add_argument('--mode', choices=['debug', 'release'], default='release')
    verify = sub.add_parser('verify-apk')
    verify.add_argument('path', type=Path)
    verify.add_argument('--mode', choices=['debug', 'release'], required=True)
    verify.add_argument('--abi', choices=[*ABIS, 'universal'])
    build = sub.add_parser('build-android-release')
    build.add_argument('directory', type=Path)
    package = sub.add_parser('package-android')
    package.add_argument('--source', type=Path, required=True)
    package.add_argument('--destination', type=Path, required=True)
    package.add_argument('--tag', required=True)
    suite = sub.add_parser('verify-android-release')
    suite.add_argument('directory', type=Path)
    args = parser.parse_args()
    if args.command == 'metadata':
        for key, value in metadata(args.platform, args.mode).items():
            print(f'{key}={value}')
    elif args.command == 'build-android-release':
        build_release(args.directory)
    elif args.command == 'package-android':
        package_android(args.source, args.destination, args.tag)
    elif args.command == 'verify-android-release':
        def inspect(path):
            return subprocess.run([str(find_aapt()), 'dump', 'badging', str(path)],
                                  check=True, capture_output=True, text=True).stdout
        verify_release_set(args.directory, inspect)
        print('All four Release APKs verified: build mode, architectures and matching versions')
    else:
        result = subprocess.run([str(find_aapt()), 'dump', 'badging', str(args.path)],
                                check=True, capture_output=True, text=True)
        verify_apk(args.path, args.mode, result.stdout, args.abi)
        print(f'APK verified: {args.mode}')


if __name__ == '__main__':
    main()
