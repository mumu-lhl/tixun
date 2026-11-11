#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export SERIOUS_PYTHON_VERSION=3.13
export SERIOUS_PYTHON_APP="$PWD/python/runtime"
export SERIOUS_PYTHON_SITE_PACKAGES="$PWD/build/python-packages"
exec flutter "$@"
