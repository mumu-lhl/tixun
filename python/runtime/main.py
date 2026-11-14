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
    code_file = None
    result = {'ok': True}
    try:
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

        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            os.chdir(workspace)
            sys.settrace(trace)
            exec(compile(request['code'], str(code_file), 'exec'), {
                '__name__': '__main__', '__file__': str(code_file),
                'WORKSPACE': str(workspace),
            })
    except BaseException as exc:
        result = {'ok': False, 'error': type(exc).__name__,
                  'traceback': ''.join(traceback.format_exception(exc))[-LIMIT:]}
    finally:
        sys.settrace(None)
        os.chdir(cwd)
        # The actual code is already retained in the app's execution history;
        # don't leave an extra generated script in the user's workspace.
        if code_file is not None:
            try:
                code_file.unlink(missing_ok=True)
            except OSError:
                pass
    result.update(stdout=out.value(), stderr=err.value(),
                  output_truncated=out.truncated or err.truncated,
                  elapsed_ms=round((time.monotonic() - started) * 1000))
    return result


def publish_result(target, result):
    temp = target.with_name(target.name + '.tmp')
    temp.write_text(json.dumps(result, ensure_ascii=True), encoding='utf-8')
    temp.replace(target)


def process_request(path, root):
    request_id = path.name.removesuffix('.request.json')
    target = root / (request_id + '.result.json')
    try:
        request = json.loads(path.read_text(encoding='utf-8'))
        if request.get('id') != request_id:
            raise ValueError('Request id does not match its filename')
        result = execute(request, root / (request_id + '.cancel'))
    except BaseException as exc:
        result = {'ok': False, 'error': type(exc).__name__,
                  'traceback': ''.join(traceback.format_exception(exc))[-LIMIT:],
                  'stdout': '', 'stderr': '', 'output_truncated': False}
    finally:
        path.unlink(missing_ok=True)
    publish_result(target, result)


def worker():
    root = Path(os.environ['TIXUN_PYTHON_ROOT'])
    root.mkdir(parents=True, exist_ok=True)
    (root / 'ready').write_text(sys.version, encoding='utf-8')
    while not (root / 'shutdown').exists():
        for path in root.glob('*.request.json'):
            process_request(path, root)
        time.sleep(.05)


if __name__ == '__main__':
    worker()
