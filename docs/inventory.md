# Host Inventory

One row per Vultr instance in the demo. All `<TBD>` values must be
filled in from the live host (codex can collect them with
`docs/server-prep.md`).

> ⚠️ Do **not** commit the BGP password or any other secret to this
> file. Secrets live in a host-local `vultr-bgp.env` (gitignored).

## bird.nimble-hi.com

| Attribute                   | Value      |
|-----------------------------|------------|
| Vultr plan                  | `<TBD>`    |
| Region / DC                 | `<TBD>`    |
| Instance type               | `<vps \| bare-metal>` |
| OS image                    | `<TBD>`    |
| Kernel                      | `<TBD>`    |
| vCPUs / RAM / disk          | `<TBD>`    |
| Primary IPv4 (Vultr-assigned) | `<TBD>`  |
| Primary IPv6 (Vultr-assigned) | `<TBD>`  |
| Reverse DNS                 | `<TBD>`    |
| Default IPv4 gateway        | `<TBD>`    |
| Default IPv6 gateway        | `<TBD>`    |
| Local ASN                   | `<TBD>`    |
| Announced IPv4 prefix       | `204.14.240.0/22` |
| Announced IPv6 prefix       | `<TBD>/48` |
| Bound prefix iface          | `lo` / `dummy0` (`<TBD>`) |
| BIRD version                | `<TBD>`    |
| BIRD config path            | `/etc/bird/bird.conf` |
| Management UI               | `https://bird.nimble-hi.com/` |
| Role                        | Primary BGP announcer |

## bird2.nimble-hi.com

| Attribute                   | Value      |
|-----------------------------|------------|
| Vultr plan                  | `<TBD>`    |
| Region / DC                 | `<TBD>`    |
| Instance type               | `<vps \| bare-metal>` |
| OS image                    | `<TBD>`    |
| Kernel                      | `<TBD>`    |
| vCPUs / RAM / disk          | `<TBD>`    |
| Primary IPv4 (Vultr-assigned) | `<TBD>`  |
| Primary IPv6 (Vultr-assigned) | `<TBD>`  |
| Reverse DNS                 | `<TBD>`    |
| Default IPv4 gateway        | `<TBD>`    |
| Default IPv6 gateway        | `<TBD>`    |
| Local ASN                   | `<TBD>`    |
| Announced IPv4 prefix       | `204.14.240.0/22` |
| Announced IPv6 prefix       | `<TBD>/48` |
| Bound prefix iface          | `lo` / `dummy0` (`<TBD>`) |
| BIRD version                | `<TBD>`    |
| BIRD config path            | `/etc/bird/bird.conf` |
| Management UI               | `https://bird2.nimble-hi.com/` |
| Role                        | Secondary BGP announcer |

## bgp.nimble-hi.com

| Attribute                   | Value      |
|-----------------------------|------------|
| Vultr plan                  | `<TBD>`    |
| Region / DC                 | `<TBD>`    |
| Instance type               | `<vps \| bare-metal>` |
| OS image                    | `<TBD>`    |
| Kernel                      | `<TBD>`    |
| vCPUs / RAM / disk          | `<TBD>`    |
| Primary IPv4 (Vultr-assigned) | `<TBD>`  |
| Primary IPv6 (Vultr-assigned) | `<TBD>`  |
| Reverse DNS                 | `<TBD>`    |
| Default IPv4 gateway        | `<TBD>`    |
| Default IPv6 gateway        | `<TBD>`    |
| Static east/west routes     | `<TBD>`    |
| Role                        | Client / verification host |

## How to populate

Run on each host (codex can do this):

```bash
hostnamectl
uname -r
cat /etc/os-release | grep -E '^(NAME|VERSION)='
nproc
free -h | awk '/Mem/ {print $2}'
lsblk -d -o NAME,SIZE | tail -n +2
ip -4 addr show scope global
ip -6 addr show scope global
ip -4 route show default
ip -6 route show default
bird --version 2>&1 | head -n1
```

Paste the output back and I'll fold it into this file (and into the
matching `vultr-bgp.env` for each box).
