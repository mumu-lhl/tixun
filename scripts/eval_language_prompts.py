"""Offline exporter for historical 83b73ba prompt pairs. Reads Git, never credentials.
Live execution and reporting: scripts/prompt_benchmark.py.
"""
import ast
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*' ''', re.X)

def strings(s):
    return ''.join(ast.literal_eval(m.group()) for m in TOKEN.finditer(s))

def prompts(rev):
    s = subprocess.check_output(['git', 'show', f'{rev}:lib/core/ai/language_prompt_definitions.dart'], cwd=ROOT, text=True)
    preferences = s.split('const _englishLanguagePrompts = {')[1].split('};')[0]
    prefs = {m[1]: strings(m[2]) for m in re.finditer(r'"(language_[^"]+)":\s*((?:"(?:\\.|[^"\\])*"\s*)+)', preferences)}
    boundary = s.split('String languagePromptContract(PromptDefinition definition) =>')[1].split(';')[0]
    # The interpolation is the already extracted requestContract.
    boundary = strings(boundary).replace('${definition.requestContract!}', '')
    result = {}
    for block in s.split('  PromptDefinition(')[1:]:
        name = TOKEN.search(block).group()[1:-1]
        contract = strings(block.split('requestContract:')[1].split('\n  ),')[0])
        result[name] = contract + boundary + '\n' + prefs[name]
    assert len(result) == 8
    def source(path):
        return subprocess.check_output(['git', 'show', f'{rev}:{path}'], cwd=ROOT, text=True)
    prefix = 'lib/features/language_learning/'
    quick = source(prefix+'quick_lookup/quick_ai.dart').split("const _instructions = '''")[1].split("''';")[0]
    builtins = source(prefix+'quick_lookup/quick_models.dart').split('const quickBuiltIns = {')[1].split('\n};')[0]
    for block in re.split(r'  "language_', builtins)[1:]:
        name = block.split('"')[0]
        template = strings(block.split('prompt:')[1].split('\n  ),')[0])
        task = re.sub(r'\{(\w+)\}', lambda m: 'the '+m[1]+' field in the user data', template)
        heading = 'Task instructions:' if rev.endswith('^') else 'Task preferences (only within the rules above):'
        result['quick_'+name] = quick+'\n\n'+heading+'\n'+task
    return result

skills = ['detail', 'meaningInContext', 'inference']
base = dict(glossLanguage='en', level='intermediate', skills=skills)
CASES = [
 ('vocabulary', 'language_vocabulary', dict(base, topic='everyday workplace communication', count=3, type='mixed', focus='', exclude=[], generateGroupTitle=False)),
 ('sentence_en', 'language_sentence_batch', dict(base, count=4, style='sentence', level='mixed', focus=None, exclude=[])),
 ('dialogue_zh', 'language_sentence_batch', dict(base, count=4, style='dialogue', glossLanguage='zh', focus='inference', exclude=[])),
 ('context', 'language_context_understanding', dict(base, count=2, vocabulary=[{'form':'run into','meaning':'meet unexpectedly'}], focus='meaningInContext', exclude=['I ran into an old friend at the station.'])),
 ('check', 'language_sentence_check', dict(base, text='The museum is free on Fridays, except during special exhibitions.')),
 ('explain', 'language_explanation', dict(base, text='I was going to call, but it slipped my mind.', simpler=True)),
 ('reading', 'language_exam_generation', dict(base, kind='reading', count=3, genre='informational article', focus='inference', excludeTitles=[])),
 ('cloze', 'language_exam_generation', dict(base, kind='cloze', count=3, genre='short narrative', focus=None, excludeTitles=[])),
 ('writing_task', 'language_writing_task', dict(base, kind='continuation', topic='a missed bus', profile='general English learner')),
 ('writing_feedback', 'language_writing', dict(base, feedbackLanguage='en', task='Write an email to a colleague asking to move a meeting to Friday. Give a reason and ask for confirmation.', draft='Hi Sam, Could we move our meeting to Friday? I have a dentist appointment on Thursday. Please let me know if Friday works for you. Cheers, Alex')),
]

def main():
    """Export historical prompt pairs offline; live execution lives in benchmark."""
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('suite', type=Path, help='New output JSON suite (never overwritten)')
    args = parser.parse_args()
    variants = {'old': prompts('83b73ba^'), 'new': prompts('83b73ba')}
    rows = [(name, variant, variants[variant][task], data)
            for name, task, data in CASES for variant in variants]
    for action, text in [('express', '请帮我告诉同事：我今天晚点才能回复邮件。'), ('meaning', 'saw'), ('usage', 'used to')]:
        data = dict(input=text, sourceLanguage='auto', targetLanguage='en', glossLanguage='zh', level='intermediate', detail='brief')
        rows.extend((f'quick_{action}', variant, variants[variant]['quick_'+action], data) for variant in variants)
    requests = []
    for name, variant, instructions, data in rows:
        if name != 'explain':
            instructions += '\nReturn a single compact JSON object without Markdown fences.'
        requests.append(dict(case=name, variant=variant, instructions=instructions,
                             input=json.dumps(data, ensure_ascii=False), expectJson=name != 'explain'))
    with args.suite.open('x') as f:
        json.dump(dict(requests=requests), f, ensure_ascii=False, indent=2)
        f.write('\n')


if __name__ == '__main__':
    main()
