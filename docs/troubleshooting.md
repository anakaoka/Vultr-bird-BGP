# Troubleshooting Vultr BIRD BGP

## Session never reaches `Established`

Ordered cheapest-to-most-expensive checks:

1. **Was BGP enabled before the instance existed?**
   If BGP was turned on for the account *after* the instance was deployed,
   Vultr requires a reboot from the control panel before the multihop
   peer is reachable. A reboot from inside the OS is not enough.

2. **Are you using the right neighbor for the platform?**
   - Cloud Compute / VPS: peer ASN `64515`, IPv4 `169.254.169.254`,
     IPv6 `2001:19f0:ffff::1`.
   - Bare Metal: peer ASN `20473`, IPv4 `169.254.1.1`,
     IPv6 `2001:19f0:ffff::1`.
   Both require `multihop 2`.

3. **Is the BGP password right?**
   TCP MD5 means a wrong password produces silent TCP resets, not a
   helpful error. `birdc show proto all vultr_ipv4` will sit in `Active`
   or `Connect`. Don't bother `telnet`-ing port 179 - MD5 will reject
   that too.

4. **Is the source address correct?**
   `local <ip> as <asn>` must use an address actually configured on the
   instance. Verify with `ip -4 addr` / `ip -6 addr`. For IPv6, prefer
   a global address rather than link-local.

5. **Firewall.**
   `iptables -L -n -v` / `nft list ruleset` - inbound TCP 179 from the
   neighbor address must be allowed. Vultr's cloud firewall (if you
   enabled one) also has to permit it.

6. **Routes to the neighbor exist.**
   `ip route get 169.254.169.254` (or the bare-metal address) should
   succeed and resolve via your default gateway.

## Session is `Established` but no routes import

- `birdc show route protocol vultr_ipv4` shows what arrived.
- Check your import filter: `import all` is the simplest baseline.
- Bare Metal does **not** receive the full internet table from Vultr.

## Session is `Established` but Vultr is not announcing my prefix

- Confirm the prefix is on Vultr's LOA / portal allow-list for your
  account. Without that, exports are dropped at Vultr's edge.
- Check `birdc show route export vultr_ipv4` - the route must be in
  there. If not, your export filter is blocking it, or the static
  origin route is missing.
- Vultr typically requires IPv4 announcements to be at least a /24
  and IPv6 at least a /48 to enter the global table.

## East / West traffic between my Vultr VMs over the announced prefix

This is **expected behaviour** on Vultr: traffic between your own
instances destined for an IP inside your BGP-announced prefix will
black-hole unless you add an explicit route to the **Vultr-assigned
host public IP** of the announcing instance.

```bash
# On the *client* VM (the one trying to reach the announced prefix):
sudo ip route add 198.51.100.0/24 via <ANNOUNCING_VM_HOST_PUBLIC_IPV4>
sudo ip -6 route add 2001:db8:100::/48 via <ANNOUNCING_VM_HOST_PUBLIC_IPV6>
```

Persist these in `/etc/systemd/network/`, `/etc/network/interfaces.d/`,
or your config-management tool of choice.

Symptoms when this is missing:

- External traceroutes to the announced IP work fine.
- Pings/connections from another *Vultr* VM to the announced IP time
  out, even though the announcing VM has the address bound.
- `tcpdump` on the announcing VM shows no packets arriving from the
  client VM at all.

## Useful commands

```bash
sudo birdc show status
sudo birdc show proto
sudo birdc show proto all vultr_ipv4
sudo birdc show route protocol vultr_ipv4
sudo birdc show route export   vultr_ipv4
sudo birdc configure           # reload bird.conf without dropping sessions
sudo journalctl -u bird -f
```
