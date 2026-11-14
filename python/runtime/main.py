"""The old in-process worker is intentionally disabled.

Linux execution uses the bubblewrap launcher; Android uses an isolated-UID
service with its own launcher and bounded workspace snapshot transfer. Keeping this
entry point fail-closed prevents accidental restoration of unrestricted exec().
"""
import sys

print(
    'In-process Python execution is disabled; use the isolated sandbox runner.',
    file=sys.stderr,
)
raise SystemExit(78)
