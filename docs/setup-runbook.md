# Setup Runbook

End-to-end recreation of the Nimble Vultr BGP demo, from a Vultr account
with BGP enabled to a host announcing prefixes to the global table.

Use this alongside:

- `architecture.md` for topology and roles.
- `inventory.md` for the per-host values.
- `host-bootstrap.md` for the OS-level network setup.
- `server-prep.md` for the diagnostic commands.
- `troubleshooting.md` when a step doesn't go to plan.

## 1. Vultr account prerequisites

1. Open a Vultr support ticket and request:
   - **BGP enabled** on the account.
   - A **private ASN** assignment, or attach your own ASN with an LOA.
   - LOA upload for each prefix (IPv4 ≥ /24, IPv6 ≥ /48) you want to
     advertise.
2. Once enabled, the customer portal exposes a **BGP** page with:
   - Your ASN.
   - The BGP password (TCP MD5).
   - Vultr's peer ASN and neighbor IPs (which we also keep hard-coded
     in `scripts/render-bird-conf.sh` for safety).
3. **If the instance existed before BGP was enabled, reboot it from
   the Vultr control panel** — an in-OS reboot is not enough.

## 2. Provision the instance

For each announcer + the client host:

1. Create the instance.
   - **Cloud Compute / VPS**: any plan with ≥ 1 GB RAM is fine for a
     demo. Full BGP table imports use ~300 MB of RAM in BIRD; if you
     do `import all` you want ≥ 1 GB.
   - **Bare Metal**: only if you specifically want the BM peering path
     (peer AS 20473, neighbor 169.254.1.1). BM does not receive the
     full table from Vultr.
2. OS: Ubuntu 22.04 LTS or 24.04 LTS (the install script targets these
   plus current Debian; if you pick something else update
   `scripts/install-bird2-ubuntu.sh`).
3. Region: pick something close to your customers; for failover
   testing, place the two announcers in **different** regions.
4. Networking: leave IPv6 enabled. Don't attach the Vultr managed
   firewall yet (it can mask BGP problems while you're bringing up
   the session).
5. Capture the assigned values into `inventory.md`:
   - Primary IPv4 / IPv6.
   - Default gateways.
   - Region / plan / OS image / kernel.

## 3. DNS

Set the public hostname (e.g. `bird.nimble-hi.com`) to point at the
Vultr-assigned primary IPv4. **Do not** point the hostname at an
announced IP — those are anycast / failover-eligible and will resolve
to the wrong box during a failover test.

If you want a name for the announced service, use a separate
`service.nimble-hi.com` that resolves to the announced IP(s).

## 4. Host bootstrap

See `host-bootstrap.md`. Summary:

1. Set hostname, install base packages, configure NTP.
2. Apply `etc/sysctl.d/99-bgp.conf` equivalents (forwarding, rp_filter).
3. Bind the announced IP(s) to `lo` (or a `dummy0` interface). Without
   this, BIRD will export the prefix to Vultr but the kernel will
   blackhole the traffic via the static `reject` route.
4. (Client host only) Add the static east/west routes that send the
   announced prefix to each announcer's Vultr-assigned host public IP.

## 5. Render the BIRD config

On each announcer:

```bash
git clone https://github.com/anakaoka/Vultr-bird-BGP.git
cd Vultr-bird-BGP
cp vultr-bgp.env.example vultr-bgp.env
# Fill in vultr-bgp.env with values from inventory.md + the BGP password
./scripts/render-bird-conf.sh vultr-bgp.env > bird.conf
```

Sanity-check the rendered file:

- `router id` matches the Vultr-assigned primary IPv4.
- `local <ip> as <asn>` uses an address actually present on the host
  (`ip -4 addr` / `ip -6 addr`).
- `neighbor 169.254.169.254 as 64515` (VPS) or
  `neighbor 169.254.1.1 as 20473` (Bare Metal).
- `password "..."` contains your real BGP password (no `$` / backtick /
  `"` in the password — see `troubleshooting.md`).

## 6. Install BIRD and apply

```bash
sudo ./scripts/install-bird2-ubuntu.sh
sudo install -m 0640 -o root -g bird bird.conf /etc/bird/bird.conf
sudo systemctl restart bird
```

## 7. Verify the session

```bash
sudo birdc show status
sudo birdc show proto
sudo birdc show proto all vultr_ipv4
sudo birdc show proto all vultr_ipv6
sudo birdc show route export vultr_ipv4
sudo birdc show route export vultr_ipv6
```

You want:

- `vultr_ipv4` / `vultr_ipv6` in state **Established**.
- `Routes: ... received` non-zero (full table on VPS, partial on BM).
- `show route export` lists exactly the prefixes you intend to
  advertise — nothing more.

## 8. Verify externally

From outside Vultr:

- `bgp.tools` / `lg.he.net` / `bgpview.io` should show the prefix
  with origin AS = your local ASN, transit AS = Vultr.
- `mtr <ip-inside-prefix>` should terminate on the announcer.

From `bgp.nimble-hi.com` (with east/west routes in place):

- `ping <announced-ip>` and `curl http://<announced-ip>` should
  succeed and land on the announcer with the BGP best-path.

## 9. Failover test

1. On the primary announcer: `sudo systemctl stop bird`.
2. Watch global tables (e.g. `bgp.tools`) — the route should
   converge onto the secondary in ~30s.
3. Restart: `sudo systemctl start bird`. Primary should reclaim
   best-path (assuming identical attributes; if not, set
   `bgp_local_pref` on the secondary to 90 vs. 100 on primary).

## 10. Recreating a host from scratch

If a host is rebuilt:

1. Re-provision per §2, capture new IPs in `inventory.md`.
2. Update DNS.
3. Re-bind announced prefixes per `host-bootstrap.md`.
4. Re-render `vultr-bgp.env` → `bird.conf` (router id and source
   addresses change with the new instance; ASN, password, and
   announced prefixes do not).
5. **If BGP was enabled on the account before the rebuild, reboot
   the new instance from the Vultr control panel** before expecting
   the session to come up.

## Open questions / TODO for codex

- [ ] Capture exact OS image + kernel for each host.
- [ ] Confirm whether each host runs full-table `import all` or a
      filtered import.
- [ ] Confirm `dummy0` vs `lo` for announced-prefix binding on each
      announcer.
- [ ] Document the existing east/west routes on `bgp.nimble-hi.com`.
- [ ] Snapshot `/etc/bird/bird.conf` (with password redacted) from each
      announcer and diff against the renderer output.
