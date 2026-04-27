# Vultr BIRD BGP

BIRD 2 configuration templates and helper scripts for running BGP on Vultr
Cloud Compute or Bare Metal instances.

This repo is intentionally small: it gives you a repeatable way to render
`/etc/bird/bird.conf`, install BIRD 2 on Ubuntu/Debian, and verify the
Vultr BGP session.

## Vultr BGP Reference

Vultr currently documents these peer settings:

| Platform               | Vultr ASN | IPv4 neighbor       | IPv6 neighbor        | Multihop |
|------------------------|-----------|---------------------|----------------------|----------|
| Cloud Compute / VPS    | 64515     | 169.254.169.254     | 2001:19f0:ffff::1    | 2        |
| Bare Metal             | 20473     | 169.254.1.1         | 2001:19f0:ffff::1    | 2        |

You still need BGP enabled on your Vultr account, an assigned local/private
ASN (or your own ASN), and the BGP password from Vultr.

## Quick Start

1. Copy the environment example.

   ```bash
   cp vultr-bgp.env.example vultr-bgp.env
   ```

2. Edit `vultr-bgp.env` with your real instance IP, ASN, BGP password,
   and prefixes.

3. Render a BIRD 2 configuration.

   ```bash
   ./scripts/render-bird-conf.sh vultr-bgp.env > bird.conf
   ```

4. Install BIRD 2 and apply the generated config on the Vultr instance.

   ```bash
   sudo ./scripts/install-bird2-ubuntu.sh
   sudo cp bird.conf /etc/bird/bird.conf
   sudo systemctl restart bird
   ```

5. Verify the session.

   ```bash
   sudo birdc show proto all vultr_ipv4
   sudo birdc show proto all vultr_ipv6
   sudo birdc show route
   ```

## Configuration

The renderer supports IPv4, IPv6, or dual-stack sessions.

Required values:

| Variable                 | Example              | Notes                                              |
|--------------------------|----------------------|----------------------------------------------------|
| `VULTR_PLATFORM`         | `vps`                | Use `vps` or `bare-metal`.                         |
| `LOCAL_ASN`              | `64512`              | Your ASN or the private ASN assigned by Vultr.     |
| `BGP_PASSWORD`           | `change-me`          | BGP password from Vultr.                           |
| `ROUTER_ID`              | `203.0.113.10`       | Usually the instance IPv4 address.                 |
| `SOURCE_IPV4`            | `203.0.113.10`       | Required for IPv4 BGP.                             |
| `SOURCE_IPV6`            | `2001:db8::10`       | Required for IPv6 BGP.                             |
| `ANNOUNCE_IPV4_PREFIXES` | `198.51.100.0/24`    | Space-separated IPv4 prefixes.                     |
| `ANNOUNCE_IPV6_PREFIXES` | `2001:db8:100::/48`  | Space-separated IPv6 prefixes.                     |

For internet-routable announcements, Vultr notes that IPv4 generally needs
at least a /24, and IPv6 generally needs at least a /48.

## East / West Traffic on Vultr

**East/west traffic between your Vultr instances over the BGP-announced
prefix requires explicit routes to the Vultr-assigned host public IP of
the announcing instance.** Vultr does not freely route between your VMs
over the announced address space — peer-to-peer reachability must go via
the announcing instance's primary Vultr-assigned public IPv4/IPv6.

```bash
# On the *client* VM, send the announced prefix to the announcing VM's
# Vultr-assigned public IP (replace with your real values):
sudo ip route add 198.51.100.0/24 via 203.0.113.10
sudo ip -6 route add 2001:db8:100::/48 via 2001:19f0:1000::abcd
```

Persist these via `/etc/systemd/network/`, `/etc/network/interfaces.d/`,
or your config-management tool of choice. Without them, traffic between
your own Vultr instances over the announced space will be silently
dropped by Vultr's edge. See `docs/troubleshooting.md` for more.

## Files

| Path                                  | Purpose                                                         |
|---------------------------------------|-----------------------------------------------------------------|
| `vultr-bgp.env.example`               | Example values for rendering a config.                          |
| `scripts/render-bird-conf.sh`         | Generates a BIRD 2 config from an env file.                     |
| `scripts/install-bird2-ubuntu.sh`     | Installs BIRD 2 and enables the service on Ubuntu/Debian.       |
| `examples/bird2-vultr-vps.conf`       | Static Cloud Compute / VPS example.                             |
| `examples/bird2-vultr-bare-metal.conf`| Static Bare Metal example.                                      |
| `docs/troubleshooting.md`             | Common failure modes (incl. east/west routing).                 |

## Notes

- Do not commit real BGP passwords.
- If the Vultr instance existed before BGP was enabled on the account,
  Vultr documents that it must be **rebooted from the control panel**.
- TCP MD5 is used for BGP authentication, so a simple `telnet` test to
  port 179 is **not** a reliable connectivity check.
- Bare Metal does not receive the full internet BGP table from Vultr.

## Sources

- [Configuring BGP on Vultr](https://docs.vultr.com/configuring-bgp-on-vultr)
- [How to Set Up High Availability Using Vultr Reserved IP and BGP](https://docs.vultr.com/how-to-set-up-high-availability-using-vultr-reserved-ip-and-bgp)
