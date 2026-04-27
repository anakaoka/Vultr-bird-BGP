# Route Policy Notes

## Current `bgp` Import Policy

The aggregate server currently uses `import none` on the Vultr BGP session.
That means inbound routes from Vultr are intentionally rejected and are not
installed into BIRD's routing table or the Linux kernel table.

Observed on 2026-04-27 after an inbound route refresh:

```text
Input filter: REJECT
Routes: 0 imported, 1 exported, 0 preferred
Import updates: 2 received, 2 filtered, 0 accepted
```

The only route present in BIRD on `bgp` is the local static aggregate:

```text
204.14.240.0/22 unreachable
```

So even if Vultr has enabled full-route delivery for the account, this host is
not currently accepting those routes. The existing session also did not show a
full table after a route refresh; it only reported two filtered inbound updates.

## Testing Whether Vultr Sends Explicit Routes

Do not immediately change the aggregate host to `import all` and export those
routes to the kernel. A full IPv4 table can be large, and importing everything
without a deliberate policy can consume memory or change host routing in ways
that are hard to reason about.

A safer test is to temporarily accept only routes we care about, such as the
aggregate and host routes inside the aggregate:

```bird
filter vultr_interesting_import {
    if net ~ [ 204.14.240.0/22{22,32}, 0.0.0.0/0 ] then accept;
    reject;
}

protocol bgp vultr {
    local as 18612;
    source address 208.83.236.223;

    ipv4 {
        import filter vultr_interesting_import;
        export all;
    };

    graceful restart on;
    multihop 2;
    neighbor 169.254.169.254 as 64515;
    password "<VULTR_BGP_PASSWORD>";
}
```

Then reload inbound routes and inspect what was accepted:

```bash
sudo birdc configure
sudo birdc reload in vultr
sudo birdc show route protocol vultr
sudo birdc show route where net ~ [ 204.14.240.0/22{22,32} ]
```

If Vultr is sending explicit `/32` routes for `bird` and `bird2`, they should
appear in the protocol route output after this limited import policy is applied.

## Full Routes vs East-West Routing

Full routes from Vultr may help a host make better outbound decisions, but they
do not automatically prove that east-west traffic between Vultr instances will
work over the announced address space.

For the demo, keep treating east-west reachability as something that needs an
explicit test:

1. Confirm the announcing host has the `/32` bound locally.
2. Confirm BIRD exports the `/32`.
3. Confirm the aggregate host or peer host learns the `/32`, if import testing
   is enabled.
4. Confirm the Linux kernel has a usable route for that destination.
5. Test traffic both from outside Vultr and from another Vultr instance in the
   same data center.

If the kernel still routes traffic for `204.14.240.0/22` toward Vultr's default
gateway instead of toward the announcing host, keep explicit host or prefix
routes on the client/demo machines.
