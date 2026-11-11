#!/usr/bin/env python3
"""Reject build artifacts missing the embedded Python app or calculation libraries."""
import argparse
import io
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
        with zipfile.ZipFile(io.BytesIO(bundle.read('assets/sitepackages.zip'))) as packages:
            for name in ('sympy/__init__.py', 'mpmath/__init__.py'):
                if name not in packages.namelist():
                    raise ValueError(f'{apk.name}: missing {name}')
        if not any(n.startswith('lib/') and '/libpython3' in n for n in names):
            raise ValueError(f'{apk.name}: missing native Python runtime')


def check_linux(bundle):
    for name in ('app/main.py', 'site-packages/sympy/__init__.py', 'site-packages/mpmath/__init__.py'):
        if not (bundle / name).is_file():
            raise ValueError(f'{bundle}: missing {name}')
    if not list((bundle / 'lib').glob('libpython3*.so*')):
        raise ValueError(f'{bundle}: missing native Python runtime')
    if not list(bundle.glob('python3.*/encodings/__init__.*')):
        raise ValueError(f'{bundle}: missing Python standard library')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=['android', 'linux'])
    parser.add_argument('paths', nargs='+', type=Path)
    args = parser.parse_args()
    for path in args.paths:
        (check_android if args.platform == 'android' else check_linux)(path)
        print(f'Embedded Python bundle verified: {path.name}')
