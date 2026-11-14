"""Isolated Android entry point. Called only by the isolated-service launcher."""
import json
import os
import sys
import io
import traceback


class LimitedOutput(io.TextIOBase):
    def __init__(self):
        self.data = bytearray()
        self.truncated = False

    def write(self, value):
        encoded = value.encode("utf-8", errors="replace")
        remaining = 32000 - len(self.data)
        self.data.extend(encoded[:remaining])
        self.truncated |= len(encoded) > remaining
        return len(value)

    @property
    def value(self):
        return self.data.decode("utf-8", errors="replace")

    def flush(self):
        pass


def run(input_fd, output_fd):
    with os.fdopen(input_fd, "r", closefd=False) as source:
        request = json.load(source)
    stdout, stderr = LimitedOutput(), LimitedOutput()
    sys.stdout, sys.stderr = stdout, stderr
    ok = True
    snapshot = None
    try:
        from android_workspace import execute
        snapshot, error = execute(request["code"], request["workspace"])
        ok = error is None
    except BaseException:
        ok = False
        traceback.print_exc()
    response = {
        "ok": ok,
        "stdout": stdout.value,
        "stderr": stderr.value,
        "output_truncated": stdout.truncated or stderr.truncated,
        "workspace": snapshot,
    }
    with os.fdopen(output_fd, "w", closefd=False) as target:
        json.dump(response, target)
