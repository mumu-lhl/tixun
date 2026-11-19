"""Run the Linux dependency installer without changing the host's APT setup."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest


INSTALLER = Path(__file__).resolve().parents[1] / "install_linux_deps.sh"


class LinuxDependencyTests(unittest.TestCase):
    def test_runner_retries_package_downloads_on_another_mirror(self):
        with tempfile.TemporaryDirectory() as directory:
            bin_dir = Path(directory)
            calls = bin_dir / "calls"
            commands = {
                "id": "#!/bin/sh\nprintf '0\\n'\n",
                "apt-get": """#!/usr/bin/env bash
operation=unknown
sources=
ipv4=
for arg in "$@"; do
  case "$arg" in
    update|install) operation=$arg ;;
    Dir::Etc::sourcelist=*) sources=${arg#*=} ;;
    Acquire::ForceIPv4=true) ipv4=ipv4 ;;
  esac
done
mirror=first
if [[ -n "$sources" ]] && grep -q 'archive.ubuntu.com' "$sources"; then
  mirror=fallback
fi
printf '%s %s %s\\n' "$operation" "$mirror" "$ipv4" >> "$APT_TEST_CALLS"
if [[ "$operation $mirror" == 'install first' ]]; then
  echo 'E: Failed to fetch package: Network is unreachable' >&2
  exit 100
fi
""",
            }
            for name, content in commands.items():
                path = bin_dir / name
                path.write_text(content)
                path.chmod(0o755)
            result = subprocess.run(
                ["bash", str(INSTALLER), "--github-runner"],
                env=dict(
                    os.environ,
                    PATH=f"{directory}:{os.environ['PATH']}",
                    APT_TEST_CALLS=str(calls),
                ),
                capture_output=True,
                text=True,
                timeout=5,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                calls.read_text().splitlines(),
                [
                    "update first ipv4",
                    "install first ipv4",
                    "update fallback ipv4",
                    "install fallback ipv4",
                ],
            )
