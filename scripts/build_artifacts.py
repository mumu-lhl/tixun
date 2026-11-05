#!/usr/bin/env python3
"""The shared artifact contract used by CI and release packaging."""
import argparse
import os
from pathlib import Path
import re
import subprocess
from zipfile import BadZipFile, ZipFile


def metadata(platform, mode='release'):
    if platform == 'linux':
        return dict(artifact_name='tixun-linux-release', release_suffix='linux-x64.tar.gz',
                    bundle_path='artifacts/linux-production')
    if platform != 'android' or mode not in ('debug', 'release'):
        raise ValueError('Unsupported build platform or mode')
    apk_name = f'app-{mode}.apk'
    return dict(mode=mode, artifact_name=f'tixun-android-{mode}', apk_name=apk_name,
                apk_path=f'build/app/outputs/flutter-apk/{apk_name}',
                release_suffix=f'android-{mode}.apk')


def verify_apk(path, mode, badging):
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
    args = parser.parse_args()
    if args.command == 'metadata':
        for key, value in metadata(args.platform, args.mode).items():
            print(f'{key}={value}')
    else:
        result = subprocess.run([str(find_aapt()), 'dump', 'badging', str(args.path)],
                                check=True, capture_output=True, text=True)
        verify_apk(args.path, args.mode, result.stdout)
        print(f'APK verified: {args.mode}')


if __name__ == '__main__':
    main()
