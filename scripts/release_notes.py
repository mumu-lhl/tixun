#!/usr/bin/env python3
"""Choose published, reachable release boundaries and write stable compare links."""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

from check_release_tag import parse_tag


def is_nightly(tag):
    return tag == 'nightly' or re.fullmatch(r'nightly-[0-9]{8}-[0-9]{6}', tag) is not None


def git(repository, *args):
    return subprocess.run(['git', '-C', str(repository), *args],
                          check=True, capture_output=True, text=True).stdout.strip()


def commit_for(repository, ref):
    try:
        return git(repository, 'rev-parse', '--verify', f'{ref}^{{commit}}')
    except subprocess.CalledProcessError as error:
        raise ValueError(f'Published release reference {ref} is missing; fetch complete tag history first') from error


def is_ancestor(repository, base, current):
    result = subprocess.run(['git', '-C', str(repository), 'merge-base', '--is-ancestor', base, current])
    if result.returncode not in (0, 1):
        raise ValueError('Cannot determine release ancestry')
    return result.returncode == 0


def choose_base(releases, current, repository='.', nightly=False, current_ref=None):
    if nightly:
        if not is_nightly(current):
            raise ValueError('Invalid nightly tag')
    else:
        _, current_prerelease = parse_tag(current)
    current_commit = commit_for(repository, current_ref or f'refs/tags/{current}')
    candidates = []
    for release in releases:
        tag = release['tag_name']
        if release.get('draft') or not release.get('published_at'):
            continue
        is_old_nightly = nightly and is_nightly(tag)
        if not is_old_nightly:
            try:
                _, prerelease = parse_tag(tag)
            except ValueError:
                continue
            # Stable releases and nightlies compare against stable releases;
            # version prereleases retain their existing version-tag history.
            if (prerelease or release.get('prerelease')) and (nightly or not current_prerelease):
                continue
            if tag == current:
                continue
        elif tag == current and not current_ref:
            continue
        commit = commit_for(repository, f'refs/tags/{tag}')
        if is_ancestor(repository, commit, current_commit):
            distance = int(git(repository, 'rev-list', '--count', f'{commit}..{current_commit}'))
            candidates.append((distance, release['published_at'], is_old_nightly, tag, commit))
    if not candidates:
        return None
    # The closest ancestor is the newest code boundary, independent of when a
    # GitHub release was published. Prefer a formal release on the same commit.
    distance = min(candidate[0] for candidate in candidates)
    nearest = [candidate for candidate in candidates if candidate[0] == distance]
    _, _, old_nightly, tag, commit = max(nearest, key=lambda c: (not c[2], c[1]))
    return commit if old_nightly else tag


def tag_pattern(current, base):
    return '^(' + '|'.join(re.escape(t) for t in [base, current] if t) + ')$'


def has_changes(base, current, repository='.'):
    if base is None:
        return True
    return int(git(repository, 'rev-list', '--count', f'{base}..{current}')) > 0


def decode_pages(text):
    releases = []
    decoder = json.JSONDecoder()
    remaining = text.strip()
    if not remaining:
        raise ValueError('GitHub returned an empty release response')
    while remaining:
        page, end = decoder.raw_decode(remaining)
        if not isinstance(page, list):
            raise ValueError('Expected a GitHub releases array')
        releases.extend(page)
        remaining = remaining[end:].lstrip()
    return releases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--repo', required=True)
    parser.add_argument('--nightly', action='store_true')
    parser.add_argument('--ref', help='Current commit; use HEAD before moving the nightly tag')
    parser.add_argument('--notes', type=Path, help='Append an explicit comparison link to these notes')
    parser.add_argument('--base', default='')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', args.repo):
        parser.error('Invalid GitHub repository')
    current_commit = commit_for('.', args.ref or f'refs/tags/{args.tag}')
    if args.notes:
        target = current_commit if args.nightly else args.tag
        link = (f'compare/{args.base}...{target}' if args.base
                else f'commits/{target}')
        with args.notes.open('a', encoding='utf-8') as notes:
            notes.write(f'\n\n**Full Changelog**: https://github.com/{args.repo}/{link}\n')
        return
    result = subprocess.run(['gh', 'api', '--paginate',
                             f'repos/{args.repo}/releases?per_page=100'],
                            check=True, capture_output=True, text=True)
    base = choose_base(decode_pages(result.stdout), args.tag, nightly=args.nightly, current_ref=args.ref)
    print(f'base_tag={base or ""}')
    print(f'current_commit={current_commit}')
    print(f'commit_range={base}..{current_commit}' if base else f'commit_range={current_commit}')
    print(f'tag_pattern={tag_pattern(current_commit if args.nightly else args.tag, base)}')
    print(f'has_changes={str(has_changes(base, current_commit)).lower()}')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(f'Release lookup failed: {(error.stderr or "").strip()}')
    except ValueError as error:
        sys.exit(str(error))
