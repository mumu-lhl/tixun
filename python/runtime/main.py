"""TiXun's unrestricted, single-interpreter Python worker.

The protocol bounds transport, not Python capabilities. This is NOT a sandbox.
Cancellation uses tracing and cannot interrupt blocking native code immediately.
"""
import contextlib
import io
import json
import os
from pathlib import Path
import sys
import time
import traceback

LIMIT = 32000


class Capture(io.TextIOBase):
    def __init__(self):
        self.parts = []
        self.count = 0
        self.truncated = False

    def write(self, value):
        value = str(value)
        remaining = LIMIT - self.count
        if remaining > 0:
            self.parts.append(value[:remaining])
            self.count += min(len(value), remaining)
        if len(value) > remaining:
            self.truncated = True
        return len(value)

    def flush(self):
        pass

    def value(self):
        return ''.join(self.parts)


def execute(request, cancel_path):
    started = time.monotonic()
    deadline = started + request['timeout_seconds']
    out, err = Capture(), Capture()
    cwd = os.getcwd()
    workspace = Path(request['workspace'])
    workspace.mkdir(parents=True, exist_ok=True)
    code_file = workspace / ('run-' + request['id'] + '.py')
    code_file.write_text(request['code'], encoding='utf-8')
    last_check = 0.0

    def trace(frame, event, arg):
        nonlocal last_check
        now = time.monotonic()
        if now - last_check > .02:
            last_check = now
            if cancel_path.exists():
                raise InterruptedError('Python execution cancellation requested')
            if now >= deadline:
                raise TimeoutError('Python execution exceeded its time limit')
        return trace

    result = {'ok': True}
    try:
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            os.chdir(workspace)
            sys.settrace(trace)
            exec(compile(request['code'], str(code_file), 'exec'), {
                '__name__': '__main__', '__file__': str(code_file),
                'WORKSPACE': str(workspace),
            })
    except BaseException as exc:
        sys.settrace(None)
        result = {'ok': False, 'error': type(exc).__name__,
                  'traceback': ''.join(traceback.format_exception(exc))[-LIMIT:]}
    finally:
        sys.settrace(None)
        os.chdir(cwd)
    result.update(stdout=out.value(), stderr=err.value(),
                  output_truncated=out.truncated or err.truncated,
                  elapsed_ms=round((time.monotonic() - started) * 1000))
    return result


def worker():
    root = Path(os.environ['TIXUN_PYTHON_ROOT'])
    root.mkdir(parents=True, exist_ok=True)
    (root / 'ready').write_text(sys.version, encoding='utf-8')
    while not (root / 'shutdown').exists():
        for path in root.glob('*.request.json'):
            request = json.loads(path.read_text(encoding='utf-8'))
            path.unlink()
            result = execute(request, root / (request['id'] + '.cancel'))
            target = root / (request['id'] + '.result.json')
            temp = target.with_suffix('.tmp')
            temp.write_text(json.dumps(result, ensure_ascii=True), encoding='utf-8')
            temp.replace(target)
        time.sleep(.05)


if __name__ == '__main__':
    worker()
