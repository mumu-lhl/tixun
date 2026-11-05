#!/usr/bin/env python3
"""Choose the last published, reachable release, ignoring unpublished tags."""
import argparse
import json
import re
import subprocess
import sys

from check_release_tag import parse_tag


def choose_base(releases, current, repository='.'):
    parse_tag(current)
    candidates = []
    for release in releases:
        tag = release['tag_name']
        if release.get('draft') or not release.get('published_at') or tag == current:
            continue
        try:
            parse_tag(tag)
        except ValueError:
            continue  # Only the app's version tags participate in its history.
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
    return max(candidates, key=lambda r: r['published_at'])['tag_name'] if candidates else None


def tag_pattern(current, base):
    # Restrict git-cliff's release boundaries to actual public releases. Failed
    # and draft tags inside the commit range remain ordinary commits.
    return '^(' + '|'.join(re.escape(t) for t in [base, current] if t) + ')$'


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
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', args.repo):
        parser.error('Invalid GitHub repository')
    result = subprocess.run(['gh', 'api', '--paginate',
                             f'repos/{args.repo}/releases?per_page=100'],
                            check=True, capture_output=True, text=True)
    releases = decode_pages(result.stdout)
    base = choose_base(releases, args.tag)
    print(f'base_tag={base or ""}')
    print(f'tag_pattern={tag_pattern(args.tag, base)}')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(f'GitHub release lookup failed: {error.stderr.strip()}')
    except ValueError as error:
        sys.exit(str(error))
