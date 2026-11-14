"""The old in-process worker is intentionally disabled.

Linux Python execution uses the separate bubblewrap launcher. Android execution
remains disabled until an isolated Android service is implemented. Keeping this
entry point fail-closed prevents accidental restoration of unrestricted exec().
"""
import sys

print(
    'In-process Python execution is disabled; use the isolated sandbox runner.',
    file=sys.stderr,
)
raise SystemExit(78)
