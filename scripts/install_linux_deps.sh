#!/usr/bin/env bash
set -euo pipefail
if [[ "$(id -u)" != 0 ]]; then
  echo '需要 root 安装系统包；请使用 sudo，或在开发容器中执行。' >&2
  exit 1
fi
apt-get update
apt-get install -y --no-install-recommends \
  python3-pip ca-certificates curl git unzip xz-utils clang cmake ninja-build pkg-config \
  libgtk-3-dev g++ libsecret-1-dev libjsoncpp-dev \
  libgl1-mesa-dri mesa-utils xvfb xauth xdotool imagemagick ripgrep dbus-x11
