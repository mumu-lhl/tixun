#!/usr/bin/env bash
set -euo pipefail
if [[ "$(id -u)" != 0 ]]; then
  echo '需要 root 安装系统包；请使用 sudo，或在开发容器中执行。' >&2
  exit 1
fi
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
# A hosted runner's Azure mirror can fail DNS while other mirrors work.
# APT's index fallback does not reliably redirect package downloads too.
if [[ "${1:-}" == --github-runner ]]; then
  for mirror_list in /etc/apt/apt-mirrors.txt /etc/apt/apt-security-mirrors.txt; do
    if [[ -f "$mirror_list" ]]; then
      sed -i 's|https\?://azure.archive.ubuntu.com/ubuntu|https://archive.ubuntu.com/ubuntu|g' "$mirror_list"
    fi
  done
fi
apt_options=(-o Acquire::Retries=2 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 -o DPkg::Lock::Timeout=60)
apt-get "${apt_options[@]}" update
apt-get "${apt_options[@]}" install -y --no-install-recommends \
  python3-pip ca-certificates curl git unzip xz-utils clang cmake ninja-build pkg-config \
  libgtk-3-dev g++ libsecret-1-dev libjsoncpp-dev \
  libgl1-mesa-dri mesa-utils xvfb xauth xdotool imagemagick ripgrep dbus-x11
