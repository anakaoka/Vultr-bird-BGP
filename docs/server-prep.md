# Server Prep / Diagnostics

Run these on the Vultr instance before rendering and applying the BGP
config. The output tells you what to put in `vultr-bgp.env` and confirms
the host can reach Vultr's BGP peer.

## What to collect

```bash
# OS / kernel - so we know the install path is correct
hostnamectl
uname -r

# Addresses - source these into ROUTER_ID, SOURCE_IPV4, SOURCE_IPV6
ip -4 addr show scope global
ip -6 addr show scope global

# Default gateways must exist for multihop BGP to work
ip -4 route
ip -6 route

# The instance must be able to route toward the Vultr BGP peer.
# Cloud Compute / VPS:
ip route get 169.254.169.254
# Bare Metal:
ip route get 169.254.1.1
# IPv6 (both platforms):
ip route get 2001:19f0:ffff::1

# Confirm nothing is blocking outbound TCP/179
iptables -S 2>/dev/null | grep -E '179|REJECT|DROP' || true
nft list ruleset 2>/dev/null | grep -E '179|reject|drop' || true
```

Also confirm with the operator:

- VPS or Bare Metal? (decides ASN + IPv4 neighbor)
- Vultr-assigned local ASN, or own ASN.
- BGP password from the Vultr customer portal.
- Prefixes Vultr has on file for the account (LOA), so we know what to
  put in `ANNOUNCE_IPV4_PREFIXES` / `ANNOUNCE_IPV6_PREFIXES`.

## After `bird` is running

```bash
sudo birdc show status
sudo birdc show proto
sudo birdc show proto all vultr_ipv4
sudo birdc show proto all vultr_ipv6

# If a session is stuck in Active / Connect:
sudo journalctl -u bird --since "5 min ago"
```

## Reminders

- If BGP was enabled on the account *after* the instance was deployed,
  the instance must be **rebooted from the Vultr control panel** — an
  in-OS reboot is not enough.
- TCP MD5 means a wrong password produces silent resets, not errors.
- Bare Metal does not receive the full internet table from Vultr.
- East/west traffic between your own Vultr instances over the announced
  prefix needs explicit static routes via the Vultr-assigned host
  public IP of the announcing instance — see `troubleshooting.md`.
