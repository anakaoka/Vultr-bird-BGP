# Architecture

The Nimble BGP demo uses three Vultr instances, each running BIRD 2 and
peering with Vultr's BGP route servers. The goal is to prove that:

1. A customer-controlled prefix can be advertised from a Vultr instance
   to the global table via Vultr's BGP service.
2. East/west traffic between Nimble-owned Vultr instances over the
   announced prefix works once the explicit-route workaround is in place.
3. Failover / multi-homing across multiple announcing instances behaves
   the way the BGP best-path / MED / local-pref logic implies.

## Hosts

| Host                    | Role (placeholder)                | Notes                                                  |
|-------------------------|-----------------------------------|--------------------------------------------------------|
| `bird.nimble-hi.com`    | Primary BGP speaker + LG UI       | Announces the demo prefix; web UI at `https://bird.nimble-hi.com/`. |
| `bird2.nimble-hi.com`   | Secondary BGP speaker + LG UI     | Announces the same prefix; web UI at `https://bird2.nimble-hi.com/`. |
| `bgp.nimble-hi.com`     | Client / verification host        | Originates east/west traffic toward the announced IPs. |

See `monitoring.md` for what each web UI exposes.

> The role mapping above is the working assumption — please correct it
> from codex output and re-commit. See `inventory.md` for the per-host
> values that need filling in.

## ASN / prefix layout

| Item                       | Value (TBD) | Source                          |
|----------------------------|-------------|---------------------------------|
| Local ASN                  | `<TBD>`     | Vultr customer portal           |
| Vultr ASN (Cloud Compute)  | `64515`     | Vultr docs                      |
| Vultr ASN (Bare Metal)     | `20473`     | Vultr docs                      |
| Announced IPv4 prefix      | `204.14.240.0/22` | LOA on file with Vultr     |
| Announced IPv6 prefix      | `<TBD>/48`  | LOA on file with Vultr          |
| BGP password               | secret      | Vultr customer portal (per acct)|

### Vultr import policy (as of 2026-04-27)

Vultr recently switched our session(s) from default-only to **full
route exchange**. Implications:

- Each announcer now receives the global table (or a substantial
  subset) from Vultr's RS, including — likely — its own announced
  prefix re-advertised back to it via Vultr.
- East/west between our own announcers may now resolve via BGP
  rather than requiring the static "via host public IP" workaround.
  The static route is still safe to keep as a fallback while we
  confirm.
- See `troubleshooting.md` "East / west traffic" and
  `setup-runbook.md` §8 for the verification commands we now expect
  to use to confirm this.

## Topology (logical)

```
                 +---------------------+
                 |  Internet / global  |
                 |    BGP table        |
                 +----------+----------+
                            |
                  +---------+----------+
                  |  Vultr route       |
                  |  servers           |
                  |  (AS 64515 / 20473)|
                  +----+----------+----+
                       |          |
        eBGP multihop  |          | eBGP multihop
        (TCP MD5)      |          | (TCP MD5)
                       |          |
            +----------v--+   +---v----------+
            |  bird.       |   |  bird2.      |
            |  nimble-hi   |   |  nimble-hi   |
            |  (Vultr VM)  |   |  (Vultr VM)  |
            +------+-------+   +-------+------+
                   |                   |
                   |   announced /24   |
                   +---------+---------+
                             |
                  East/west via explicit
                  route to host public IP
                             |
                    +--------v--------+
                    |   bgp.          |
                    |   nimble-hi     |
                    |   (client VM)   |
                    +-----------------+
```

Each announcer runs an identical BIRD 2 config (modulo `ROUTER_ID` /
`SOURCE_IPV4` / `SOURCE_IPV6`) rendered from `vultr-bgp.env`. The client
host has static routes for the announced prefix(es) pointing at the
Vultr-assigned host public IP of the announcer it should reach (see
`host-bootstrap.md` and `troubleshooting.md`).

## What a successful demo looks like

1. From a third-party looking glass (e.g. `bgp.tools`,
   `lg.he.net`) the announced prefix is visible with origin AS = our
   local ASN, transit AS = `64515` (or `20473` for bare metal).
2. From outside Vultr: `mtr` / `traceroute` to an IP inside the
   announced prefix terminates on whichever announcer BGP best-path
   selects.
3. Stopping `bird` on the primary announcer causes the global table
   to converge onto the secondary within ~30s. Restarting brings it
   back.
4. From `bgp.nimble-hi.com` (with the explicit east/west route in
   place): `curl` / `ping` to an IP inside the announced prefix
   reaches the announcer over the public network.

## Out of scope (for now)

- iBGP between the two announcers.
- Route reflection.
- Anycast / equal-cost multi-path between the announcers.
- RPKI ROA publication (Vultr validates against published ROAs but
  we are not currently signing our own).
