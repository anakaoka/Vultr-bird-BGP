# Management & Monitoring

Each announcer exposes a web management/monitoring interface in addition
to the local `birdc` socket.

## Endpoints

| URL                               | Host                  | Purpose (TBD)                            |
|-----------------------------------|-----------------------|------------------------------------------|
| `https://bird.nimble-hi.com/`     | `bird.nimble-hi.com`  | BGP status / route inspection / control. |
| `https://bird2.nimble-hi.com/`    | `bird2.nimble-hi.com` | BGP status / route inspection / control. |

> The UI implementation (e.g. [bird-lg-go], [birdwatcher] +
> [bird-lg], a custom dashboard, or a plain `birdc` REST shim) needs
> to be confirmed and recorded here. Codex can fetch the exact
> binary, version, listening port, and reverse-proxy config from each
> host.

[bird-lg-go]: https://github.com/xddxdd/bird-lg-go
[birdwatcher]: https://github.com/alice-lg/birdwatcher
[bird-lg]: https://github.com/sileht/bird-lg

## Per-host detail (to be populated)

| Attribute                       | `bird.nimble-hi.com`         | `bird2.nimble-hi.com`        |
|---------------------------------|------------------------------|------------------------------|
| UI software / version           | `<TBD>`                      | `<TBD>`                      |
| Process / systemd unit          | `<TBD>`                      | `<TBD>`                      |
| Listen address / port           | `<TBD>`                      | `<TBD>`                      |
| Reverse proxy (nginx/caddy/...) | `<TBD>`                      | `<TBD>`                      |
| TLS certificate (issuer / path) | `<TBD>` (Let's Encrypt?)     | `<TBD>` (Let's Encrypt?)     |
| Auth (basic / OIDC / IP-allow)  | `<TBD>`                      | `<TBD>`                      |
| `birdc` socket path             | `/run/bird/bird.ctl`         | `/run/bird/bird.ctl`         |
| Read-only or read-write?        | `<TBD>`                      | `<TBD>`                      |

## What the UI exposes (expected)

Most BIRD looking-glass tools surface:

- `show status` — uptime, router id.
- `show protocols` — session state per peer.
- `show route` (filtered by net / protocol / table).
- `show route export <protocol>` — what we're advertising.
- `show route protocol <protocol>` — what the peer sent us.
- Optional traceroute / ping shims.

If the deployed UI does not expose `show route export`, that's the
single most useful command for verifying our advertisement, so we
should add it.

## Discovery commands (run on each host)

Codex can populate the table above with:

```bash
# What's listening?
sudo ss -tlnp

# Reverse proxy?
sudo systemctl list-units --type=service --state=running | \
    grep -E 'nginx|caddy|apache|traefik'

# BIRD looking-glass binary on disk?
which bird-lg-go birdwatcher 2>/dev/null
dpkg -l | grep -iE 'bird-lg|birdwatcher' || true
ls /etc/systemd/system/ /lib/systemd/system/ 2>/dev/null | \
    grep -iE 'bird-lg|birdwatcher|bird-monitor'

# TLS cert details
sudo find /etc/letsencrypt/live -maxdepth 2 -name '*.nimble-hi.com*' 2>/dev/null

# Reverse-proxy server block
sudo find /etc/nginx /etc/caddy /etc/apache2 -type f 2>/dev/null | \
    xargs grep -l 'nimble-hi' 2>/dev/null
```

## Hardening checklist

- [ ] Confirm the UI is reachable only over HTTPS (HSTS preferred).
- [ ] Confirm authentication is enforced (no anonymous read-write).
- [ ] If the UI can issue `birdc configure` / `disable` / `restart`,
      restrict that to an authenticated admin role or remove the
      capability.
- [ ] Rate-limit / IP-allow the UI if it has a `traceroute` shim, to
      avoid using the host as a probe source.
- [ ] Make sure the UI's process does not run as root — it only needs
      group access to `/run/bird/bird.ctl` (typically the `bird`
      group).

## Internal vs. public exposure

Decide explicitly whether each UI is:

- **Public** — useful for sharing a looking glass with peers.
  Then enforce TLS + read-only + rate limits.
- **Internal only** — restricted to Nimble IP space or a VPN.
  Then enforce TLS + IP allow-list + auth.

Document the choice for each host in the table above.
