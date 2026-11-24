import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('benchmark', Path(__file__).parents[1] / 'prompt_benchmark.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class BenchmarkTest(unittest.TestCase):
    def suite(self):
        return {'requests': [dict(case='case', variant=v, instructions=v, input='same', expectJson=True) for v in ('A', 'B')]}

    def test_pairing_and_fingerprint(self):
        suite = self.suite()
        a = b.prepare(suite, 'model', 'api', 3)
        self.assertEqual(len(a['jobs']), 6)
        self.assertEqual(a, b.prepare(suite, 'model', 'api', 3))
        b.validate_plan(a)
        a['jobs'][0]['input'] = 'different'
        with self.assertRaises(ValueError):
            b.validate_plan(a)
        suite['requests'][1]['input'] = 'unpaired'
        with self.assertRaises(ValueError):
            b.prepare(suite, 'model', 'api')

    def test_duplicates_and_traversal_rejected(self):
        suite = self.suite()
        suite['requests'].append(suite['requests'][0])
        with self.assertRaises(ValueError):
            b.prepare(suite, 'm', 'api')
        suite = self.suite()
        suite['requests'][0]['case'] = '../escape'
        with self.assertRaises(ValueError):
            b.prepare(suite, 'm', 'api')

    def test_failure_redaction_resume_budget(self):
        with tempfile.TemporaryDirectory() as d:
            directory = Path(d)
            plan = b.prepare(self.suite(), 'model', 'api')
            b.save(directory / 'plan.json', plan)
            with patch.dict(b.os.environ, {'BENCH_KEY': 'sensitive-test-key'}), patch.object(b.urllib.request, 'build_opener') as opener:
                with self.assertRaises(ValueError):
                    b.run_api(directory, 'https://example.com/chat', 'BENCH_KEY', 1)
                opener.return_value.open.side_effect = RuntimeError('sensitive-test-key')
                for count in (1, 2, 2):
                    b.run_api(directory, 'https://example.com/chat', 'BENCH_KEY', 2)
                    self.assertEqual(opener.return_value.open.call_count, count)
            self.assertNotIn('sensitive-test-key', ''.join(p.read_text() for p in directory.glob('*')))
            self.assertEqual(sum(r['attempted'] for r in b.summary(directory).values()), 2)
            with self.assertRaises(ValueError):
                b.run_api(directory, 'https://different.com/chat', 'BENCH_KEY', 2)

    def test_success_whitelists_output_and_preserves_requests(self):
        with tempfile.TemporaryDirectory() as d:
            directory = Path(d)
            plan = b.prepare(self.suite(), 'model', 'api')
            b.save(directory / 'plan.json', plan)
            data = dict(choices=[dict(finish_reason='stop', message={'content': '{}', 'reasoning_content': 'private'})],
                        usage=dict(prompt_tokens=9, completion_tokens=2), secret_metadata='not saved')
            with patch.dict(b.os.environ, {'BENCH_KEY': 'test-secret'}), patch.object(b.urllib.request, 'build_opener') as opener:
                opener.return_value.open.side_effect = lambda *a, **k: io.BytesIO(json.dumps(data).encode())
                b.run_api(directory, 'https://example.com/chat', 'BENCH_KEY', 2)
                sent = json.loads(opener.return_value.open.call_args.args[0].data)
                self.assertEqual(sent['model'], 'model')
                self.assertEqual(sent['messages'][1]['content'], 'same')
            report = b.summary(directory)
            self.assertEqual(report['A']['completed'], 1)
            self.assertEqual(report['B']['inputTokens'], 9)
            output = ''.join(p.read_text() for p in directory.glob('*'))
            for secret in ('test-secret', 'private', 'not saved'):
                self.assertNotIn(secret, output)

    def test_report_and_blind_view(self):
        with tempfile.TemporaryDirectory() as d:
            directory = Path(d)
            plan = b.prepare(self.suite(), 'm', 'api')
            b.save(directory / 'plan.json', plan)
            for job in plan['jobs']:
                b.save(directory / (job['id'] + '.json'), dict(fingerprint=plan['fingerprint'], text='{}', completed=True, jsonParsed=True, usage={'inputTokens': 7, 'outputTokens': 2}))
            report = b.summary(directory)
            self.assertEqual(report['A']['jsonPassed'], 1)
            self.assertEqual(report['B']['inputTokens'], 7)
            blind = b.read(directory / 'blind.json')
            self.assertNotIn('variant', blind[0])
            self.assertNotIn('instructions', blind[0])
            self.assertEqual(len(b.read(directory / 'blind-key.json')), 2)
