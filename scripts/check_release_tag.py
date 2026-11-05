#!/usr/bin/env python3
"""Validate a release tag before starting builds. No third-party dependencies."""
import re
import sys
from pathlib import Path


def parse_tag(tag: str) -> tuple[str, bool]:
    core = r'(?:0|[1-9][0-9]*)'
    pattern = rf'v({core}\.{core}\.{core}(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)'
    match = re.fullmatch(pattern, tag)
    if not match:
        raise ValueError('标签应为 v主版本.次版本.修订号，可带预发布后缀，例如 v0.5.1 或 v0.6.0-rc.1。')
    version = match[1]
    prerelease = '-' in version
    if prerelease:
        for part in version.split('-', 1)[1].split('.'):
            if part.isdigit() and len(part) > 1 and part.startswith('0'):
                raise ValueError('预发布版本中的数字不能包含前导零。')
    return version, prerelease


def check(tag: str, pubspec: str) -> tuple[str, bool]:
    version, prerelease = parse_tag(tag)
    found = re.search(r'^version:\s*[\'"]?([^\s\'"#]+)', pubspec, re.MULTILINE)
    if not found or found[1].split('+', 1)[0] != version:
        raise ValueError(f'{tag} 与 pubspec.yaml 的 version 不一致，请先更新应用版本。')
    return version, prerelease


if __name__ == '__main__':
    try:
        version, prerelease = check(sys.argv[1], Path('pubspec.yaml').read_text())
    except (ValueError, IndexError, OSError) as error:
        sys.exit(str(error))
    print(f'version={version}')
    print(f'prerelease={str(prerelease).lower()}')
