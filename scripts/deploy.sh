#!/usr/bin/env bash
# Deploy the Vultr BIRD BGP config to the local host.
#
# Usage:
#   sudo ./scripts/deploy.sh [--env <env-file>] [--dry-run] [--no-restart]
#
# Defaults:
#   --env   envs/<hostname>.env   (falls back to vultr-bgp.env)
#   Renders bird.conf, validates it, installs it, and restarts bird.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=0
RESTART=1
ENV_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --env)       ENV_FILE="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=1; shift ;;
        --no-restart) RESTART=0; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

# ---- Locate env file --------------------------------------------------------

if [[ -z "$ENV_FILE" ]]; then
    HOST_ENV="$REPO_DIR/envs/$(hostname -f).env"
    SHORT_ENV="$REPO_DIR/envs/$(hostname -s).env"
    FALLBACK="$REPO_DIR/vultr-bgp.env"

    if [[ -f "$HOST_ENV" ]]; then
        ENV_FILE="$HOST_ENV"
    elif [[ -f "$SHORT_ENV" ]]; then
        ENV_FILE="$SHORT_ENV"
    elif [[ -f "$FALLBACK" ]]; then
        ENV_FILE="$FALLBACK"
    else
        echo "No env file found. Create one of:" >&2
        echo "  $HOST_ENV" >&2
        echo "  $FALLBACK" >&2
        exit 2
    fi
fi

echo "==> Using env: $ENV_FILE"

# ---- Render -----------------------------------------------------------------

RENDERED="$(mktemp /tmp/bird.conf.XXXXXX)"
trap 'rm -f "$RENDERED"' EXIT

echo "==> Rendering config..."
"$REPO_DIR/scripts/render-bird-conf.sh" "$ENV_FILE" > "$RENDERED"

# ---- Validate ---------------------------------------------------------------

echo "==> Validating config (bird -p -c)..."
bird -p -c "$RENDERED"
echo "    Config OK"

# ---- Diff (always shown, even in dry-run) -----------------------------------

if [[ -f /etc/bird/bird.conf ]]; then
    echo "==> Diff vs installed config:"
    diff --color=never -u /etc/bird/bird.conf "$RENDERED" || true
else
    echo "==> /etc/bird/bird.conf does not exist yet (first deploy)"
fi

if [[ $DRY_RUN -eq 1 ]]; then
    echo "==> --dry-run: stopping here. Rendered config is at $RENDERED (will be deleted on exit)."
    exit 0
fi

# ---- Root check -------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "deploy.sh must be run as root (or re-run without --dry-run as root)" >&2
    exit 1
fi

# ---- Install ----------------------------------------------------------------

echo "==> Installing config to /etc/bird/bird.conf..."
install -m 0640 -o root -g bird "$RENDERED" /etc/bird/bird.conf

# ---- Apply ------------------------------------------------------------------

if [[ $RESTART -eq 1 ]]; then
    if systemctl is-active --quiet bird; then
        echo "==> Reloading bird (birdc configure)..."
        birdc configure
    else
        echo "==> Starting bird..."
        systemctl start bird
    fi
    sleep 2
    echo ""
    echo "==> Session state:"
    birdc show protocols
    echo ""
    echo "==> Run 'sudo ./scripts/verify-session.sh' for a full health check."
fi
