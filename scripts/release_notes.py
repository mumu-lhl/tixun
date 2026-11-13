#!/usr/bin/env python3
"""Choose the last published, reachable release, ignoring unpublished tags."""
import argparse
import json
import re
import subprocess
import sys

from check_release_tag import parse_tag


def is_nightly(tag):
    return re.fullmatch(r'nightly-[0-9]{8}-[0-9]{6}', tag) is not None


def choose_base(releases, current, repository='.', nightly=False):
    if nightly:
        if not is_nightly(current):
            raise ValueError('Invalid nightly tag')
    else:
        parse_tag(current)
    candidates = []
    for release in releases:
        tag = release['tag_name']
        if release.get('draft') or not release.get('published_at') or tag == current:
            continue
        if not (nightly and is_nightly(tag)):
            try:
                parse_tag(tag)
            except ValueError:
                continue  # Stable release history must not be split by nightlies.
        exists = subprocess.run(['git', '-C', str(repository), 'rev-parse', '--verify',
                                 f'refs/tags/{tag}^{{commit}}'], capture_output=True)
        if exists.returncode:
            raise ValueError(f'Published release tag {tag} is missing; fetch complete tag history first')
        ancestor = subprocess.run(['git', '-C', str(repository), 'merge-base', '--is-ancestor',
                                   f'refs/tags/{tag}', f'refs/tags/{current}'])
        if ancestor.returncode == 0:
            candidates.append(release)
        elif ancestor.returncode != 1:
            raise ValueError('Cannot determine release ancestry')
    return max(candidates, key=lambda r: (nightly and is_nightly(r['tag_name']),
                                          r['published_at']))['tag_name'] if candidates else None


def tag_pattern(current, base):
    # Restrict git-cliff's release boundaries to actual public releases. Failed
    # and draft tags inside the commit range remain ordinary commits.
    return '^(' + '|'.join(re.escape(t) for t in [base, current] if t) + ')$'


def has_changes(base, current, repository='.'):
    if base is None:
        return True
    result = subprocess.run(['git', '-C', str(repository), 'rev-list', '--count',
                             f'refs/tags/{base}..refs/tags/{current}'],
                            check=True, capture_output=True, text=True)
    return int(result.stdout.strip()) > 0


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
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', args.repo):
        parser.error('Invalid GitHub repository')
    result = subprocess.run(['gh', 'api', '--paginate',
                             f'repos/{args.repo}/releases?per_page=100'],
                            check=True, capture_output=True, text=True)
    releases = decode_pages(result.stdout)
    base = choose_base(releases, args.tag, nightly=args.nightly)
    print(f'base_tag={base or ""}')
    print(f'commit_range={base + ".." if base else ""}{args.tag}')
    print(f'tag_pattern={tag_pattern(args.tag, base)}')
    print(f'has_changes={str(has_changes(base, args.tag)).lower()}')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(f'GitHub release lookup failed: {error.stderr.strip()}')
    except ValueError as error:
        sys.exit(str(error))
