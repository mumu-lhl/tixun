#!/usr/bin/env bash
# Pure-Python dependencies are identical on all supported CPUs. Never install at runtime.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export SERIOUS_PYTHON_VERSION="${SERIOUS_PYTHON_VERSION:-3.13}"
export SERIOUS_PYTHON_APP="$PWD/python/runtime"
export SERIOUS_PYTHON_SITE_PACKAGES="$PWD/build/python-packages"
python3 -m pip install --disable-pip-version-check --only-binary=:all: --no-compile \
  --target "$SERIOUS_PYTHON_SITE_PACKAGES" -r python/requirements.txt
# Android's plugin consumes per-ABI trees, Linux the root tree. These packages
# have no native extensions; include their distribution metadata too.
if [[ "${1:-Linux}" == Android ]]; then
  for abi in arm64-v8a armeabi-v7a x86_64; do
    mkdir -p "$SERIOUS_PYTHON_SITE_PACKAGES/$abi"
    cp -R "$SERIOUS_PYTHON_SITE_PACKAGES/sympy" "$SERIOUS_PYTHON_SITE_PACKAGES/mpmath" \
      "$SERIOUS_PYTHON_SITE_PACKAGES"/sympy-*.dist-info \
      "$SERIOUS_PYTHON_SITE_PACKAGES"/mpmath-*.dist-info "$SERIOUS_PYTHON_SITE_PACKAGES/$abi/"
  done
fi

chmod -R a+rX "$SERIOUS_PYTHON_SITE_PACKAGES"
