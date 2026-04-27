# Recreate the Nimble Vultr BGP Demo

This document records the live demo topology and enough host detail to rebuild it.
Secrets such as root passwords and the Vultr BGP password are intentionally omitted.

## Topology

| Hostname | DNS A record | Role | Status |
|----------|--------------|------|--------|
| `bgp.nimble-hi.com` | `208.83.236.223` | Aggregate BGP announcer for the Vultr data center. | Inventoried. |
| `bird.nimble-hi.com` | `204.14.240.1` | Demo host reached by a more specific per-machine route. | SSH inventory pending. |
| `bird2.nimble-hi.com` | `204.14.240.2` | Demo host reached by a more specific per-machine route. | SSH inventory pending. |

The aggregate server must advertise the covering route into the Vultr data
center. Individual machines can then advertise or receive more specific host
routes, such as `/32` routes, to steer traffic to the correct host.

## Aggregate Server: `bgp`

Observed on 2026-04-27.

| Item | Value |
|------|-------|
| Provider | Vultr |
| Hardware model | `VHP` |
| Virtualization | Microsoft hypervisor, full virtualization |
| OS | Ubuntu 24.04.4 LTS (`noble`) |
| Kernel | `6.8.0-110-generic` |
| Architecture | `x86_64` |
| CPU | 1 vCPU, Intel Xeon Processor (Cascadelake) |
| Memory | 955 MiB RAM, 2.3 GiB swap |
| Disk | 25 GiB virtual disk, ext4 root filesystem |
| Primary interface | `enp1s0` |
| Primary IPv4 | `208.83.236.223/23` |
| Default gateway | `208.83.236.1` |
| BIRD package | `bird2 2.14-1build2` |
| Git package | `git 1:2.43.0-1ubuntu7.3` |
| OpenSSH package | `openssh-server 1:9.6p1-3ubuntu13.15` |
| BIRD service | enabled and active |

Current BIRD state:

| Protocol | State | Notes |
|----------|-------|-------|
| `static1` | up | Installs the aggregate route into BIRD. |
| `vultr` | established | BGP session to Vultr. |

Current exported aggregate:

```text
204.14.240.0/22 unreachable
```

Current BGP parameters:

| Item | Value |
|------|-------|
| Local ASN | `18612` |
| Router ID | `208.83.236.223` |
| Source address | `208.83.236.223` |
| Vultr neighbor | `169.254.169.254` |
| Vultr ASN | `64515` |
| Multihop | `2` |
| Address family | IPv4 |
| Import policy | `import none` |
| Export policy | `export all` |

Redacted live BIRD configuration:

```bird
router id 208.83.236.223;

protocol static {
    ipv4;
    route 204.14.240.0/22 unreachable;
}

protocol bgp vultr {
    local as 18612;
    source address 208.83.236.223;
    ipv4 {
        import none;
        export all;
    };
    graceful restart on;
    multihop 2;
    neighbor 169.254.169.254 as 64515;
    password "<VULTR_BGP_PASSWORD>";
}
```

## Rebuild Checklist

1. Create a Vultr Cloud Compute instance in the target data center.
2. Enable BGP for the Vultr account before deploying the instance, or reboot
   the instance from the Vultr control panel after BGP is enabled.
3. Install the baseline packages.

   ```bash
   apt-get update
   apt-get install -y bird2 git openssh-server
   systemctl enable bird
   ```

4. Create `/etc/bird/bird.conf` using the aggregate server values above.
5. Parse-check the config before restart.

   ```bash
   bird -p -c /etc/bird/bird.conf
   ```

6. Restart BIRD.

   ```bash
   systemctl restart bird
   ```

7. Verify the BGP session and exported route.

   ```bash
   birdc show status
   birdc show proto all vultr
   birdc show route
   birdc show route export vultr
   ```

8. Add explicit east-west routes on client/demo hosts as needed. Vultr does
   not automatically make one VM's BGP-announced address space reachable from
   another VM in the same data center.

## Known Open Items

- Inventory `bird.nimble-hi.com` and `bird2.nimble-hi.com` once their SSH host
  key changes are confirmed as expected.
- Record the Vultr plan names, region slug, firewall group, and any reserved IP
  settings from the Vultr control panel.
- Add persistent route examples for the exact network manager used on `bird`
  and `bird2`.
