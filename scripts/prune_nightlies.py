#!/usr/bin/env python3
"""Keep one published nightly, preserving stable releases and changelog links."""
import argparse
import json
import re
import subprocess
import sys

from release_notes import decode_pages, is_nightly


def deletion_candidates(releases, keep):
    if not is_nightly(keep):
        raise ValueError('Expected a timestamped nightly tag')
    published = [r for r in releases if is_nightly(r['tag_name'])
                 and r.get('prerelease') is True and not r.get('draft')
                 and r.get('published_at')]
    if not published or max(published, key=lambda r: (
            r['published_at'], r['tag_name']))['tag_name'] != keep:
        raise ValueError('Keep tag must be the latest published nightly prerelease')
    return [r for r in published if r['tag_name'] != keep]


def prune(repo, keep, apply=False, run=subprocess.run):
    result = run(['gh', 'api', '--paginate', f'repos/{repo}/releases?per_page=100'],
                 check=True, capture_output=True, text=True)
    releases = decode_pages(result.stdout)
    old = deletion_candidates(releases, keep)
    current = next(r for r in releases if r['tag_name'] == keep)
    body = current.get('body') or ''
    # git-cliff references the previous tag, which is about to be deleted.
    # Commit IDs keep the public Full Changelog link usable after retention.
    for release in old:
        tag = release['tag_name']
        prefix = f'https://github.com/{repo}/compare/{tag}...'
        if prefix in body:
            commit = run(['git', 'rev-parse', '--verify', f'refs/tags/{tag}^{{commit}}'],
                         check=True, capture_output=True, text=True).stdout.strip()
            if not re.fullmatch(r'[0-9a-f]{40,64}', commit):
                raise ValueError('Invalid previous nightly commit')
            body = body.replace(prefix, f'https://github.com/{repo}/compare/{commit}...')
    if apply and body != (current.get('body') or ''):
        run(['gh', 'api', '--method', 'PATCH', f'repos/{repo}/releases/{current["id"]}',
             '--input', '-'], input=json.dumps({'body': body}),
            check=True, capture_output=True, text=True)
    for release in old:
        tag = release['tag_name']
        print(f'{"Deleting" if apply else "Would delete"} nightly release and tag: {tag}')
        if apply:
            run(['gh', 'release', 'delete', tag, '--repo', repo, '--yes', '--cleanup-tag'],
                check=True, capture_output=True, text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', required=True)
    parser.add_argument('--keep', required=True)
    parser.add_argument('--apply', action='store_true', help='Actually delete old nightlies')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', args.repo):
        parser.error('Invalid GitHub repository')
    prune(args.repo, args.keep, args.apply)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        # Commands may contain release text; avoid dumping command arguments.
        sys.exit(str(error) if isinstance(error, ValueError) else
                 'Nightly retention failed; inspect GitHub releases before retrying.')
