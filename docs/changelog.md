# Changelog

Infrastructure and configuration changes, newest first.

---

## 2026-04-27

### Vultr switches session to full route exchange

Vultr changed the import policy on our BGP session(s) from default-only
(a single `0.0.0.0/0`) to full route exchange. Each announcer now
receives the global BGP table from Vultr's route server.

**Impact:**

- East/west traffic between our own Vultr instances may now resolve
  via BGP rather than requiring the static "via host public IP" workaround,
  depending on whether Vultr's RS reflects our own prefix back to us.
- `import all` remains in the rendered config; BIRD will install the
  full table in its routing database. On instances with <1 GB RAM,
  monitor memory usage.
- The static `ip route ... via <host_public_ip>` fallback on
  `bgp.nimble-hi.com` remains in place until the BGP path is confirmed.

**Verification commands** (run on each announcer):

```bash
sudo birdc show route 204.14.240.0/22 all
sudo birdc show route for 204.14.240.1 all
ip route get 204.14.240.1
```

See `docs/troubleshooting.md` "East / west traffic" for the full
decision matrix.

---

### Initial repo setup

Created `anakaoka/Vultr-bird-BGP` with:

- `scripts/render-bird-conf.sh` — env file → BIRD 2 config renderer
  supporting VPS (AS 64515) and Bare Metal (AS 20473).
- `scripts/install-bird2-ubuntu.sh` — BIRD 2 installer for Ubuntu/Debian.
- `scripts/deploy.sh` — render → validate → install → reload in one step.
- `scripts/verify-session.sh` — session health check with pass/fail exit code.
- `examples/` — static reference configs for VPS and Bare Metal.
- `etc/systemd/network/` — templates for prefix binding and east/west routes.
- `envs/` — per-host placeholder env files for the three Nimble demo hosts.
- `docs/` — architecture, inventory, setup runbook, host bootstrap,
  monitoring (web UIs at `bird.nimble-hi.com` / `bird2.nimble-hi.com`),
  server prep, and troubleshooting.
- GitHub Actions CI: shellcheck on all scripts + `bird -p -c` syntax
  validation on rendered and static configs.

**Hosts in scope:**

| Host                  | Role                        |
|-----------------------|-----------------------------|
| `bird.nimble-hi.com`  | Primary BGP announcer       |
| `bird2.nimble-hi.com` | Secondary BGP announcer     |
| `bgp.nimble-hi.com`   | Client / verification host  |

**Announced prefix:** `204.14.240.0/22`
