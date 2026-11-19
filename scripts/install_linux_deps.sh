#!/usr/bin/env bash
set -euo pipefail
if [[ "$(id -u)" != 0 ]]; then
  echo '需要 root 安装系统包；请使用 sudo，或在开发容器中执行。' >&2
  exit 1
fi
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
apt_options=(-o Acquire::Retries=2 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 -o DPkg::Lock::Timeout=60)

install_dependencies() {
  apt-get "${apt_options[@]}" "$@" update &&
    apt-get "${apt_options[@]}" "$@" install -y --no-install-recommends \
      python3-pip bubblewrap ca-certificates curl git unzip xz-utils clang cmake ninja-build pkg-config \
      libgtk-3-dev g++ libsecret-1-dev libjsoncpp-dev \
      libgl1-mesa-dri mesa-utils xvfb xauth xdotool imagemagick ripgrep dbus-x11
}

if [[ "${1:-}" != --github-runner ]]; then
  install_dependencies
  exit
fi

# A mirror can serve its indexes and still fail to serve packages. Re-run both
# steps with a fresh signed source list when either step fails on a runner.
source /etc/os-release
suite=${UBUNTU_CODENAME:-${VERSION_CODENAME:?Missing Ubuntu suite in os-release}}
runner_sources=$(mktemp --suffix=.list)
trap 'unlink "$runner_sources"' EXIT
runner_options=(
  -o "Dir::Etc::sourcelist=$runner_sources" -o Dir::Etc::sourceparts=-
  -o APT::Update::Error-Mode=any -o Acquire::ForceIPv4=true
  -o Acquire::Retries=0 -o Acquire::https::Timeout=10
)
kernel_mirror=https://mirrors.edge.kernel.org/ubuntu
archive_mirror=https://archive.ubuntu.com/ubuntu
keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg
for mirror in "$kernel_mirror" "$archive_mirror"; do
  security_mirror=$mirror
  if [[ "$mirror" == "$archive_mirror" ]]; then
    security_mirror=https://security.ubuntu.com/ubuntu
  fi
  printf 'deb [signed-by=%s] %s %s main universe\n' \
    "$keyring" "$mirror" "$suite" \
    "$keyring" "$mirror" "$suite-updates" \
    "$keyring" "$security_mirror" "$suite-security" > "$runner_sources"
  if install_dependencies "${runner_options[@]}"; then
    exit 0
  else
    status=$?
  fi
  printf 'Ubuntu dependency setup failed using %s (exit %s).\n' "$mirror" "$status" >&2
done
exit "$status"
