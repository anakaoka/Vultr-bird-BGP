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

### Historical behaviour (Vultr default-route mode)

When Vultr was sending us only a default route (or limited partials),
traffic between our own instances destined for an IP inside our
BGP-announced prefix would black-hole unless we added an explicit
route to the **Vultr-assigned host public IP** of the announcing
instance:

```bash
# On the *client* VM (the one trying to reach the announced prefix):
sudo ip route add 204.14.240.0/22 via <ANNOUNCING_VM_HOST_PUBLIC_IPV4>
sudo ip -6 route add 2001:db8:100::/48 via <ANNOUNCING_VM_HOST_PUBLIC_IPV6>
```

Symptoms when this is missing:

- External traceroutes to the announced IP work fine.
- Pings/connections from another *Vultr* VM to the announced IP time
  out, even though the announcing VM has the address bound.
- `tcpdump` on the announcing VM shows no packets arriving from the
  client VM at all.

### Current behaviour (Vultr full-routes mode, as of 2026-04-27)

Vultr has switched our session(s) to full route exchange. We now
expect (and need to verify) that:

- Each announcer receives a BGP route for `204.14.240.0/22` (and any
  more-specifics) back from Vultr's RS, originating from the *other*
  announcer.
- Traffic between announcers to IPs in the prefix follows that BGP
  route via Vultr — no static workaround needed.
- `bgp.nimble-hi.com` (a non-announcer that does not run BGP with
  Vultr) still needs the static workaround unless it joins the BGP
  mesh.

How to verify on each announcer:

```bash
# Did we receive 204.14.240.0/22 (and/or /32s) from Vultr's RS?
sudo birdc show route 204.14.240.0/22 all
sudo birdc show route for 204.14.240.1 all

# Where is BIRD pointing for that prefix? Look at the BGP next-hop.
sudo birdc show route 204.14.240.0/22 protocol vultr_ipv4 all

# Does the kernel agree?
ip route get 204.14.240.1
```

What we expect to see:

- A route for `204.14.240.0/22` (or each /32 if we announce them
  individually) in the `vultr_ipv4` protocol with `BGP.next_hop`
  set to the *other* announcer's source address.
- Kernel `ip route get` resolves to that BGP next-hop, not via the
  default route.

If we *don't* see those routes, either:

- Vultr's RS is not reflecting customer prefixes back to the same
  customer (a common RS policy — open a ticket to confirm).
- Our import filter is dropping them (we currently use `import all`,
  so this would be unexpected).
- The local static `reject` route for `204.14.240.0/22` is winning
  the BIRD route selection over the BGP route. In that case set the
  static origin route's preference lower, e.g.

  ```
  protocol static static_ipv4 {
      ipv4;
      route 204.14.240.0/22 reject {
          preference 50;
      };
  }
  ```

  so BGP-learned more-specifics or equally-specific routes from peers
  are preferred for forwarding.

### Decision matrix

| Source                          | Vultr full routes? | Workaround needed?                  |
|---------------------------------|--------------------|-------------------------------------|
| Other announcer (BGP speaker)   | yes                | No, BGP path should resolve.        |
| Other announcer (BGP speaker)   | no / partial       | Yes — static via host public IP.    |
| Non-BGP Vultr VM in same acct   | n/a                | Yes — static via host public IP.    |
| External internet               | n/a                | No — normal global BGP forwarding.  |

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
