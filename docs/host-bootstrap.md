# Host Bootstrap

OS-level setup that has to happen on each host *before* `bird` will do
anything useful. Performed once per instance (or codified into your
provisioning tool).

## Base packages

```bash
sudo apt-get update
sudo apt-get install -y \
    bird2 \
    iproute2 \
    tcpdump \
    mtr-tiny \
    bgpq4 \
    chrony
```

## Hostname / DNS

```bash
sudo hostnamectl set-hostname bird.nimble-hi.com   # adjust per host
```

Make sure forward + reverse DNS resolve correctly — the Vultr portal
controls reverse DNS for the primary IP, but you need to set forward
DNS at your registrar.

## sysctl

Install `etc/sysctl.d/99-bgp.conf` from this repo (or equivalent):

```bash
sudo tee /etc/sysctl.d/99-bgp.conf >/dev/null <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Loose RPF: traffic to anycast / announced prefixes can arrive on any iface.
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2

# Don't accept ICMP redirects from upstream.
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF

sudo sysctl --system
```

## Bind announced prefixes (announcers only)

This is the step most often missed. BIRD originates the prefix via a
static `reject` route, so the kernel will black-hole traffic to any IP
inside the prefix unless a more-specific bound interface exists.

Two patterns:

### Pattern A — bind specific service IPs to `lo`

Use this when you only need a handful of addresses live on the host.

```bash
# /etc/systemd/network/10-anycast.network (systemd-networkd)
[Match]
Name=lo

[Network]
Address=204.14.240.1/32
Address=204.14.240.2/32
```

Or one-shot for testing:

```bash
sudo ip addr add 204.14.240.1/32 dev lo
sudo ip -6 addr add 2001:db8:100::1/128 dev lo
```

### Pattern B — bind the whole prefix to a `dummy0` interface

Use this when you want every IP in the prefix to terminate locally
(e.g. if this host is the only announcer and accepts traffic for the
entire range).

```bash
# /etc/systemd/network/10-dummy0.netdev
[NetDev]
Name=dummy0
Kind=dummy

# /etc/systemd/network/10-dummy0.network
[Match]
Name=dummy0

[Network]
Address=204.14.240.1/24
Address=2001:db8:100::1/48
```

Or one-shot:

```bash
sudo ip link add dummy0 type dummy
sudo ip link set dummy0 up
sudo ip addr add 204.14.240.1/24 dev dummy0
sudo ip -6 addr add 2001:db8:100::1/48 dev dummy0
```

> Adjust `204.14.240.0/22` and the actual /32s in use to match what
> Vultr has on file for the account.

## Static east/west routes (client hosts only)

On any Vultr instance that is NOT the announcer but needs to talk to
an IP inside the announced prefix:

```bash
# /etc/systemd/network/20-east-west.network (systemd-networkd) or via
# ip route directly:
sudo ip route add 204.14.240.0/22 via <ANNOUNCER_HOST_PUBLIC_IPV4>
sudo ip -6 route add 2001:db8:100::/48 via <ANNOUNCER_HOST_PUBLIC_IPV6>
```

This may not be required anymore now that Vultr is sending full
routes — see `troubleshooting.md` "East / west traffic" for the
current state. Keep the manual route as a fallback.

## Firewall

If you use `ufw` / `nftables` / Vultr's managed firewall, allow:

| Direction | Protocol | Port | Source                                | Purpose         |
|-----------|----------|------|---------------------------------------|-----------------|
| inbound   | TCP      | 179  | `169.254.169.254` (or `169.254.1.1`)  | BGP from Vultr  |
| inbound   | TCP      | 179  | `2001:19f0:ffff::1`                   | BGP from Vultr  |
| outbound  | TCP      | 179  | (any to those)                        | BGP to Vultr    |

If you are bringing the session up for the first time, leave Vultr's
managed firewall *off* until you can see the session establish — it
can silently drop the multihop SYNs.

## Sanity checks

```bash
# Forwarding is on
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding

# Announced address is bound
ip -4 addr show | grep 204.14.240
ip -6 addr show | grep 2001:db8:100

# Route to Vultr's BGP peer exists
ip route get 169.254.169.254
ip -6 route get 2001:19f0:ffff::1
```

Once those all return sensible output, proceed to `setup-runbook.md`
step 5.
