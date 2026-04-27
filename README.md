# Vultr BIRD BGP

[![CI](https://github.com/anakaoka/Vultr-bird-BGP/actions/workflows/ci.yml/badge.svg)](https://github.com/anakaoka/Vultr-bird-BGP/actions/workflows/ci.yml)

BIRD 2 configuration templates and helper scripts for running BGP on Vultr
Cloud Compute or Bare Metal instances.

Announced prefix: **`204.14.240.0/22`**
Management UIs: [bird.nimble-hi.com](https://bird.nimble-hi.com/) · [bird2.nimble-hi.com](https://bird2.nimble-hi.com/)

## Vultr BGP Reference

| Platform               | Vultr ASN | IPv4 neighbor       | IPv6 neighbor        | Multihop |
|------------------------|-----------|---------------------|----------------------|----------|
| Cloud Compute / VPS    | 64515     | 169.254.169.254     | 2001:19f0:ffff::1    | 2        |
| Bare Metal             | 20473     | 169.254.1.1         | 2001:19f0:ffff::1    | 2        |

You still need BGP enabled on your Vultr account, an assigned local/private
ASN (or your own ASN), and the BGP password from Vultr.

## Quick Start

1. Copy or edit the per-host env file.

   ```bash
   # For the Nimble demo hosts:
   vi envs/bird.nimble-hi.com.env   # fill in ASN, password, IPs

   # Or for a new host:
   cp vultr-bgp.env.example vultr-bgp.env
   vi vultr-bgp.env
   ```

2. Bind your announced prefix to the loopback (or `dummy0`) so the
   kernel has somewhere to deliver traffic — **required before bird
   will forward anything**.

   ```bash
   sudo ip addr add 204.14.240.1/32 dev lo

   # Persistent: copy etc/systemd/network/ templates to /etc/systemd/network/
   # and run: sudo systemctl restart systemd-networkd
   ```

   See `docs/host-bootstrap.md` and `etc/systemd/network/` for details.

3. Deploy (render → validate → install → reload in one step).

   ```bash
   sudo ./scripts/deploy.sh
   # Or for a specific env file:
   sudo ./scripts/deploy.sh --env envs/bird.nimble-hi.com.env

   # Dry-run (no changes, shows diff):
   ./scripts/deploy.sh --dry-run --env envs/bird.nimble-hi.com.env
   ```

4. Verify.

   ```bash
   sudo ./scripts/verify-session.sh
   ```

## Configuration

The renderer supports IPv4-only, IPv6-only, or dual-stack sessions.

| Variable                 | Example              | Notes                                              |
|--------------------------|----------------------|----------------------------------------------------|
| `VULTR_PLATFORM`         | `vps`                | Use `vps` or `bare-metal`.                         |
| `LOCAL_ASN`              | `64512`              | Your ASN or the private ASN assigned by Vultr.     |
| `BGP_PASSWORD`           | `change-me`          | BGP password from Vultr.                           |
| `ROUTER_ID`              | `203.0.113.10`       | Usually the instance IPv4 address.                 |
| `SOURCE_IPV4`            | `203.0.113.10`       | Required for IPv4 BGP.                             |
| `SOURCE_IPV6`            | `2001:db8::10`       | Required for IPv6 BGP.                             |
| `ANNOUNCE_IPV4_PREFIXES` | `204.14.240.0/22`    | Space-separated IPv4 prefixes.                     |
| `ANNOUNCE_IPV6_PREFIXES` | `2001:db8:100::/48`  | Space-separated IPv6 prefixes.                     |

## East / West Traffic on Vultr

Traffic between your own Vultr instances over the BGP-announced prefix
may require explicit static routes to the Vultr-assigned host public IP
of the announcing instance (see `docs/troubleshooting.md` for the full
decision matrix — this changed when Vultr switched us to full route
exchange in April 2026).

Persistent east/west routes live in `etc/systemd/network/20-east-west.network`.

## Files

**Scripts**

| Path                              | Purpose                                                      |
|-----------------------------------|--------------------------------------------------------------|
| `scripts/deploy.sh`               | Render → validate → install → reload in one command.         |
| `scripts/verify-session.sh`       | Pass/fail session health check (cron-friendly).              |
| `scripts/render-bird-conf.sh`     | Render a BIRD 2 config from an env file.                     |
| `scripts/install-bird2-ubuntu.sh` | Install BIRD 2 on Ubuntu/Debian.                             |

**Config**

| Path                                   | Purpose                                              |
|----------------------------------------|------------------------------------------------------|
| `vultr-bgp.env.example`                | Template for a new host env file.                    |
| `envs/bird.nimble-hi.com.env`          | Placeholder env for the primary announcer.           |
| `envs/bird2.nimble-hi.com.env`         | Placeholder env for the secondary announcer.         |
| `envs/bgp.nimble-hi.com.env`           | Notes for the client/verification host.              |
| `examples/bird2-vultr-vps.conf`        | Static VPS reference config.                         |
| `examples/bird2-vultr-bare-metal.conf` | Static Bare Metal reference config.                  |
| `etc/systemd/network/`                 | Templates for prefix binding and east/west routes.   |

**Docs**

| Path                       | Purpose                                                         |
|----------------------------|-----------------------------------------------------------------|
| `docs/architecture.md`     | Topology, roles, ASN / prefix layout.                           |
| `docs/inventory.md`        | Per-host specs / IPs / role table (fill from server-prep.md).   |
| `docs/setup-runbook.md`    | End-to-end recreation runbook.                                  |
| `docs/host-bootstrap.md`   | OS-level setup (sysctl, prefix binding, firewall).              |
| `docs/monitoring.md`       | Web management UIs and hardening checklist.                     |
| `docs/troubleshooting.md`  | Common failure modes including east/west routing.               |
| `docs/server-prep.md`      | Diagnostic commands to collect before configuring.              |
| `docs/changelog.md`        | Dated log of infrastructure changes.                            |

## Notes

- Do not commit real BGP passwords. Use `envs/*.env.local` for local
  overrides (gitignored).
- If the Vultr instance existed before BGP was enabled on the account,
  it must be **rebooted from the Vultr control panel**.
- TCP MD5 auth means a wrong password produces silent TCP resets — not
  a helpful error. `telnet` to port 179 is not a useful test.
- Bare Metal does not receive the full internet BGP table from Vultr.

## Sources

- [Configuring BGP on Vultr](https://docs.vultr.com/configuring-bgp-on-vultr)
- [How to Set Up High Availability Using Vultr Reserved IP and BGP](https://docs.vultr.com/how-to-set-up-high-availability-using-vultr-reserved-ip-and-bgp)
