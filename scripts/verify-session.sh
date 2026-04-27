#!/usr/bin/env bash
# Verify the Vultr BGP session health on this host.
#
# Usage:
#   sudo ./scripts/verify-session.sh [--quiet]
#
# Exit codes:
#   0  all checks passed
#   1  one or more checks failed
#
# --quiet suppresses per-check output; summary line is always printed.
# Suitable for cron / monitoring (pipe to your alerting tool).

set -euo pipefail

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

PASS=0
FAIL=0
WARNS=()

log()  { [[ $QUIET -eq 0 ]] && printf '%s\n' "$*" || true; }
ok()   { PASS=$((PASS+1)); log "  [OK]   $*"; }
fail() { FAIL=$((FAIL+1)); WARNS+=("FAIL: $*"); log "  [FAIL] $*"; }
warn() { WARNS+=("WARN: $*"); log "  [WARN] $*"; }
hdr()  { log ""; log "==> $*"; }

# ---- Basic: bird is running -------------------------------------------------

hdr "BIRD process"
if systemctl is-active --quiet bird 2>/dev/null; then
    ok "bird.service is active"
else
    fail "bird.service is not active"
fi

BIRDC="birdc"
if ! command -v birdc >/dev/null 2>&1; then
    fail "birdc not found in PATH"
    printf '\nResult: %d passed, %d failed\n' "$PASS" "$FAIL"
    exit 1
fi

# ---- Session state ----------------------------------------------------------

hdr "BGP session state"
check_proto() {
    local proto="$1"
    local state
    state=$(birdc show protocols "$proto" 2>/dev/null | awk '/ BGP / {print $6}')
    if [[ "$state" == "Established" ]]; then
        ok "$proto: Established"
    elif [[ -z "$state" ]]; then
        warn "$proto: protocol not found (not configured for this AF?)"
    else
        fail "$proto: state=$state (expected Established)"
    fi
}

check_proto vultr_ipv4
check_proto vultr_ipv6

# ---- Route export (what we announce to Vultr) --------------------------------

hdr "Route export"
check_export() {
    local proto="$1"
    local count
    count=$(birdc show route export "$proto" 2>/dev/null | grep -c '^[0-9a-f]' || true)
    if [[ "$count" -gt 0 ]]; then
        ok "$proto: exporting $count prefix(es)"
        [[ $QUIET -eq 0 ]] && birdc show route export "$proto" 2>/dev/null | \
            grep '^[0-9a-f]' | awk '{print "         " $1}' || true
    else
        fail "$proto: no prefixes being exported — check export filter and static routes"
    fi
}

if birdc show protocols vultr_ipv4 2>/dev/null | grep -q Established; then
    check_export vultr_ipv4
fi
if birdc show protocols vultr_ipv6 2>/dev/null | grep -q Established; then
    check_export vultr_ipv6
fi

# ---- Route import (what Vultr sends us) -------------------------------------

hdr "Route import"
check_import() {
    local proto="$1"
    local count
    count=$(birdc show route protocol "$proto" 2>/dev/null | grep -c '^[0-9a-f]' || true)
    if [[ "$count" -gt 0 ]]; then
        ok "$proto: received $count route(s) from Vultr"
    else
        warn "$proto: no routes received (bare metal / filtered? expected on VPS with full table)"
    fi
}

if birdc show protocols vultr_ipv4 2>/dev/null | grep -q Established; then
    check_import vultr_ipv4
fi
if birdc show protocols vultr_ipv6 2>/dev/null | grep -q Established; then
    check_import vultr_ipv6
fi

# ---- Announced prefix in kernel FIB (sanity) --------------------------------

hdr "Kernel FIB"
for prefix in $(birdc show route export vultr_ipv4 2>/dev/null | grep '^[0-9]' | awk '{print $1}'); do
    ip_in_prefix="${prefix%%/*}.1"  # pick first address in the prefix
    result=$(ip route get "$ip_in_prefix" 2>/dev/null | head -n1)
    if echo "$result" | grep -qE 'unreachable|blackhole|prohibit'; then
        fail "kernel FIB for $prefix is unreachable/blackhole — bind the prefix to lo or dummy0"
    elif [[ -z "$result" ]]; then
        warn "no kernel route for $prefix"
    else
        ok "kernel resolves $prefix: $result"
    fi
done

# ---- Peer reachability (multihop neighbor) ----------------------------------

hdr "Peer reachability"
for neighbor in 169.254.169.254 169.254.1.1; do
    if ip route get "$neighbor" >/dev/null 2>&1; then
        ok "route to $neighbor exists"
        break
    fi
done
if ip -6 route get 2001:19f0:ffff::1 >/dev/null 2>&1; then
    ok "route to 2001:19f0:ffff::1 exists"
else
    warn "no route to 2001:19f0:ffff::1 (IPv6 peer)"
fi

# ---- Summary ----------------------------------------------------------------

log ""
log "========================================"
if [[ $FAIL -eq 0 ]]; then
    printf 'Result: OK — %d checks passed\n' "$PASS"
else
    printf 'Result: FAIL — %d passed, %d failed\n' "$PASS" "$FAIL"
    for w in "${WARNS[@]}"; do printf '  %s\n' "$w"; done
fi
log "========================================"

[[ $FAIL -eq 0 ]]
