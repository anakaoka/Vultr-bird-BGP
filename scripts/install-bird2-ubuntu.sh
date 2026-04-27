#!/usr/bin/env bash
# Install BIRD 2 on Ubuntu / Debian and enable the service.
#
# Run as root. Does not lay down /etc/bird/bird.conf - render that with
# scripts/render-bird-conf.sh and copy it in separately.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "must run as root" >&2
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get not found - this script targets Ubuntu/Debian." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y bird2

systemctl enable --now bird

echo
echo "BIRD 2 installed. Drop your rendered bird.conf at /etc/bird/bird.conf, then:"
echo "  sudo systemctl restart bird"
echo "  sudo birdc show proto"
