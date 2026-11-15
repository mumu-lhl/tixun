#!/usr/bin/env bash
set -Eeuo pipefail
probe() {
  bwrap --unshare-user --unshare-pid --unshare-ipc --unshare-uts \
    --ro-bind / / --proc /proc -- /bin/true
}
if ! probe; then
  # Ubuntu 24.04 AppArmor may restrict user namespaces for bwrap. Grant only
  # /usr/bin/bwrap access on this ephemeral runner, not system-wide access.
  sudo tee /etc/apparmor.d/tixun-ci-bwrap >/dev/null <<'EOF'
abi <abi/4.0>,
include <tunables/global>
profile tixun-ci-bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
}
EOF
  sudo apparmor_parser -r /etc/apparmor.d/tixun-ci-bwrap
  probe
fi
