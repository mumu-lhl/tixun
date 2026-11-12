#!/usr/bin/env bash
# Stage wheels for the embedded interpreter, never the build host's Python ABI.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export SERIOUS_PYTHON_VERSION="${SERIOUS_PYTHON_VERSION:-3.13}"
export SERIOUS_PYTHON_APP="$PWD/python/runtime"
export SERIOUS_PYTHON_SITE_PACKAGES="$PWD/build/python-packages"
rm -rf "$SERIOUS_PYTHON_SITE_PACKAGES"
pip_args=(--disable-pip-version-check --only-binary=:all: --no-compile
  --python-version "$SERIOUS_PYTHON_VERSION" --implementation cp
  --abi "cp${SERIOUS_PYTHON_VERSION//./}" -r python/requirements.txt)
# Android's plugin consumes per-ABI trees and relocates native extensions to
# jniLibs. Flet publishes Android NumPy wheels; PyPI supplies Linux wheels.
if [[ "${1:-Linux}" == Android ]]; then
  for abi in arm64-v8a armeabi-v7a x86_64; do
    python3 -m pip install "${pip_args[@]}" --platform "android_24_${abi//-/_}" \
      --extra-index-url https://pypi.flet.dev \
      --target "$SERIOUS_PYTHON_SITE_PACKAGES/$abi"
  done
else
  python3 -m pip install "${pip_args[@]}" --target "$SERIOUS_PYTHON_SITE_PACKAGES"
fi

chmod -R a+rX "$SERIOUS_PYTHON_SITE_PACKAGES"
