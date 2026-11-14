#!/usr/bin/env python3
"""Reject build artifacts missing the embedded Python app or calculation libraries."""
import argparse
import io
import struct
from pathlib import Path
import zipfile


def check_android(apk):
    with zipfile.ZipFile(apk) as bundle:
        names = set(bundle.namelist())
        for name in ('assets/stdlib.zip', 'assets/sitepackages.zip', 'assets/app.zip'):
            if name not in names:
                raise ValueError(f'{apk.name}: missing {name}')
        with zipfile.ZipFile(io.BytesIO(bundle.read('assets/app.zip'))) as app:
            if 'main.py' not in app.namelist():
                raise ValueError(f'{apk.name}: missing Python worker')
        package_names = set()
        for archive in ('assets/sitepackages.zip', 'assets/extract.zip'):
            if archive in names:
                with zipfile.ZipFile(io.BytesIO(bundle.read(archive))) as packages:
                    package_names.update(packages.namelist())
        for name in ('sympy/__init__.py', 'mpmath/__init__.py', 'numpy/__init__.py',
                     'numpy/_core/_multiarray_umath.soref', 'numpy/linalg/_umath_linalg.soref'):
            if name not in package_names:
                raise ValueError(f'{apk.name}: missing {name}')
        if not any(n.startswith('lib/') and '/libpython3' in n for n in names):
            raise ValueError(f'{apk.name}: missing native Python runtime')
        architectures = {'arm64-v8a': 183, 'armeabi-v7a': 40, 'x86_64': 62}
        abis = {n.split('/')[1] for n in names
                if n.startswith('lib/') and '/libpython3' in n}
        for abi in abis:
            for module in ('libnumpy-_core-_multiarray_umath.so',
                           'libnumpy-linalg-_umath_linalg.so'):
                name = f'lib/{abi}/{module}'
                if name not in names:
                    raise ValueError(f'{apk.name}: missing {name}')
                with bundle.open(name) as native:
                    header = native.read(20)
                if (len(header) != 20 or header[:4] != b'\x7fELF' or header[5] != 1
                        or struct.unpack_from('<H', header, 18)[0] != architectures.get(abi)):
                    raise ValueError(f'{apk.name}: incorrect native architecture: {name}')


def check_linux(bundle):
    for name in ('app/main.py', 'site-packages/sympy/__init__.py',
                 'site-packages/mpmath/__init__.py', 'site-packages/numpy/__init__.py',
                 'libexec/tixun-python-sandbox'):
        if not (bundle / name).is_file():
            raise ValueError(f'{bundle}: missing {name}')
    if not (bundle / 'libexec/tixun-python-sandbox').stat().st_mode & 0o111:
        raise ValueError(f'{bundle}: Python sandbox launcher is not executable')
    if not list((bundle / 'lib').glob('libpython3*.so*')):
        raise ValueError(f'{bundle}: missing native Python runtime')
    if not list(bundle.glob('python3.*/encodings/__init__.*')):
        raise ValueError(f'{bundle}: missing Python standard library')
    for module in ('_core/_multiarray_umath', 'linalg/_umath_linalg'):
        if not list((bundle / 'site-packages/numpy').glob(module + '.cpython-313-*.so')):
            raise ValueError(f'{bundle}: missing CPython 3.13 NumPy module: {module}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=['android', 'linux'])
    parser.add_argument('paths', nargs='+', type=Path)
    args = parser.parse_args()
    for path in args.paths:
        (check_android if args.platform == 'android' else check_linux)(path)
        print(f'Embedded Python bundle verified: {path.name}')
