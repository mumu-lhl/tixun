"""Reusable paired prompt benchmark. Standard library only; planning is offline."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import re
import subprocess
import time
import urllib.request
import urllib.parse


def read(path):
    return json.loads(Path(path).read_text())


def save(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    # Never replace results, including failed/incomplete calls.
    with path.open('x') as f:
        json.dump(value, f, ensure_ascii=False, indent=2)
        f.write('\n')


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def prepare(suite, model, provider, repeats=1, seed=42, effort='high'):
    requests = suite['requests']
    if not requests or repeats < 1 or repeats > 100:
        raise ValueError('Empty suite or invalid repeat count')
    seen = set()
    variants = set()
    pairs = {}
    for r in requests:
        for key in ('case', 'variant'):
            if not re.fullmatch(r'[A-Za-z0-9_-]+', r[key]):
                raise ValueError('Case/variant identifiers must be filename-safe')
        if not isinstance(r['instructions'], str) or not isinstance(r['input'], str):
            raise ValueError('Instructions and input must be strings')
        identity = (r['case'], r['variant'])
        if identity in seen:
            raise ValueError('Duplicate case/variant')
        seen.add(identity)
        variants.add(r['variant'])
        pairs.setdefault(r['case'], []).append(r)
    if len(variants) < 2:
        raise ValueError('At least two variants required')
    for rows in pairs.values():
        if {r['variant'] for r in rows} != variants:
            raise ValueError('Every case must have every variant')
        if len({(r['input'], r.get('expectJson', False)) for r in rows}) != 1:
            raise ValueError('Paired variants must use identical input and checks')
    config = dict(provider=provider, model=model, effort=effort, seed=seed, repeats=repeats)
    jobs = [dict(r, repeat=i, id=f"{r['case']}-{r['variant']}-{i}")
            for i in range(repeats) for r in requests]
    random.Random(seed).shuffle(jobs)
    plan = dict(schemaVersion=1, config=config, jobs=jobs)
    plan['fingerprint'] = digest(plan)
    return plan


def validate_plan(plan):
    copy = dict(plan)
    fingerprint = copy.pop('fingerprint')
    if digest(copy) != fingerprint:
        raise ValueError('Plan fingerprint mismatch; prepare a new directory')


def summary(directory):
    plan = read(directory / 'plan.json')
    validate_plan(plan)
    groups = {}
    blind, mapping = [], {}
    for job in plan['jobs']:
        path = directory / (job['id'] + '.json')
        if not path.exists():
            continue
        r = read(path)
        if r['fingerprint'] != plan['fingerprint']:
            raise ValueError('Result belongs to another plan')
        group = groups.setdefault(job['variant'], dict(attempted=0, completed=0, jsonPassed=0, jsonChecked=0, elapsedSeconds=0, inputTokens=0, outputTokens=0, usageAvailable=0))
        group['attempted'] += 1
        group['completed'] += r.get('completed', False)
        group['elapsedSeconds'] += r.get('elapsedSeconds', 0)
        if job.get('expectJson'):
            group['jsonChecked'] += 1
            group['jsonPassed'] += r.get('completed', False) and r.get('jsonParsed', False)
        usage = r.get('usage') or {}
        if usage.get('inputTokens') is not None:
            group['usageAvailable'] += 1
            for k in ('inputTokens', 'outputTokens'):
                group[k] += usage.get(k) or 0
        code = digest(job['id'])[:12]
        blind.append(dict(id=code, case=job['case'], input=job['input'], text=r.get('text', ''), completed=r.get('completed', False)))
        mapping[code] = job['id']
    random.Random(plan['config']['seed']).shuffle(blind)
    # These are derived views, not immutable observations.
    for name, value in [('summary.json', groups), ('blind.json', blind), ('blind-key.json', mapping)]:
        (directory / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    return groups


def run_api(directory, endpoint, key_env, max_calls):
    plan = read(directory / 'plan.json')
    validate_plan(plan)
    if plan['config']['provider'] != 'api':
        raise ValueError('Wrong provider')
    if not endpoint.startswith('https://') or urllib.parse.urlsplit(endpoint).username or urllib.parse.urlsplit(endpoint).query:
        raise ValueError('Explicit HTTPS endpoint without credentials/query required')
    transport = dict(endpoint=endpoint, keyEnvironment=key_env)
    transport_path = directory / 'transport.json'
    if transport_path.exists():
        if read(transport_path) != transport:
            raise ValueError('Transport mismatch; prepare a new run directory')
    else:
        save(transport_path, transport)
    key = os.environ.get(key_env)
    if not key:
        raise ValueError('Explicit key environment variable required')
    summary(directory)  # Reject mixed-run results before making any calls.
    pending = [j for j in plan['jobs'] if not (directory / (j['id'] + '.json')).exists()]
    if len(pending) > max_calls:
        raise ValueError('Pending calls exceed explicit --max-calls budget')
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None
    opener = urllib.request.build_opener(NoRedirect())
    for job in pending:
        result = dict(fingerprint=plan['fingerprint'], completed=False)
        target = directory / (job['id'] + '.json')
        save(target, result)  # Reserve before sending; crashes never trigger replay.
        start = time.monotonic()
        try:
            payload = dict(model=plan['config']['model'], messages=[dict(role='system', content=job['instructions']), dict(role='user', content=job['input'])])
            req = urllib.request.Request(endpoint, data=json.dumps(payload).encode(), headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'})
            with opener.open(req, timeout=180) as response:
                data = json.load(response)
            choice = data['choices'][0]
            text = choice['message']['content']
            if not isinstance(text, str) or key in text:
                raise ValueError('Unsafe response')
            usage = data.get('usage', {})
            # Whitelist fields: never save headers, raw bodies, errors or reasoning.
            result.update(text=text, completed=choice.get('finish_reason') == 'stop', usage={
                'inputTokens': usage.get('prompt_tokens'), 'outputTokens': usage.get('completion_tokens')})
            try:
                json.loads(text)
                result['jsonParsed'] = True
            except ValueError:
                result['jsonParsed'] = False
        except Exception:
            result['error'] = 'Request failed; details suppressed to protect credentials'
        result['elapsedSeconds'] = time.monotonic() - start
        target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        print(job['id'], 'complete' if result['completed'] else 'stopped')
        if not result['completed']:
            break
    summary(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    p = sub.add_parser('import-snapshots')
    p.add_argument('source', type=Path)
    p.add_argument('suite', type=Path)
    p = sub.add_parser('prepare')
    p.add_argument('suite', type=Path)
    p.add_argument('directory', type=Path)
    p.add_argument('--model', required=True)
    p.add_argument('--provider', choices=['chatgpt', 'api'], required=True)
    p.add_argument('--repeats', type=int, default=1)
    p.add_argument('--seed', type=int, default=42)
    p.add_argument('--effort', choices=['low', 'medium', 'high'], default='high')
    p = sub.add_parser('run')
    p.add_argument('directory', type=Path)
    p.add_argument('--allow-live', action='store_true', required=True)
    p.add_argument('--max-calls', type=int, required=True)
    p.add_argument('--endpoint')
    p.add_argument('--key-env')
    p = sub.add_parser('report')
    p.add_argument('directory', type=Path)
    args = parser.parse_args()
    if args.action == 'import-snapshots':
        rows = []
        for path in sorted(args.source.glob('*.json')):
            r = read(path)
            if 'request' not in r or 'case' not in r:
                continue
            messages = r['request']['messages']
            if len(messages) != 2:
                raise ValueError('Snapshot must have two messages')
            rows.append(dict(case=r['case'], variant=r['variant'], instructions=messages[0]['content'], input=messages[1]['content'], expectJson=r['case'] != 'explain'))
        save(args.suite, dict(requests=rows))
    elif args.action == 'prepare':
        save(args.directory / 'plan.json', prepare(read(args.suite), args.model, args.provider, args.repeats, args.seed, args.effort))
    elif args.action == 'report':
        print(json.dumps(summary(args.directory), indent=2))
    else:
        plan = read(args.directory / 'plan.json')
        validate_plan(plan)
        if plan['config']['provider'] == 'api':
            if not args.endpoint or not args.key_env:
                parser.error('API route requires --endpoint and --key-env')
            run_api(args.directory, args.endpoint, args.key_env, args.max_calls)
        else:
            if args.endpoint or args.key_env:
                parser.error('ChatGPT route does not accept API credentials')
            env = dict(os.environ, TIXUN_LIVE_EVAL='1', EVAL_PLAN_DIR=str(args.directory.resolve()), EVAL_MAX_CALLS=str(args.max_calls))
            subprocess.run(['flutter', 'test', '--no-pub', '-j', '4', 'scripts/eval_chatgpt_prompts_test.dart', '--reporter', 'expanded'], env=env, check=True)
            summary(args.directory)


if __name__ == '__main__':
    try:
        main()
    except Exception:
        raise SystemExit('Benchmark stopped. Check configuration; no retries or credential fallback. Error details suppressed.')
