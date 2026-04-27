# systemd-networkd templates

These files configure persistent network state needed for Vultr BGP.
Copy them to `/etc/systemd/network/` and run:

```bash
sudo systemctl restart systemd-networkd
```

| File                    | Install on        | Purpose                                              |
|-------------------------|-------------------|------------------------------------------------------|
| `10-dummy0.netdev`      | Announcers        | Creates the `dummy0` interface.                      |
| `10-dummy0.network`     | Announcers        | Binds announced prefix(es) to `dummy0`.              |
| `20-east-west.network`  | Non-announcing VMs| Static routes for east/west traffic to the announcer.|

## Check networkd is running

```bash
systemctl is-active systemd-networkd
# If inactive:
sudo systemctl enable --now systemd-networkd
```

## Verify after apply

```bash
ip addr show dummy0          # should show your announced IPs
ip route show | grep 204     # should show the east/west static routes
networkctl status dummy0
```

## Not using systemd-networkd?

- **netplan** (Ubuntu default): create `/etc/netplan/99-bgp.yaml` with
  equivalent `dummy-devices:` and `routes:` stanzas, then `netplan apply`.
- **ifupdown** (Debian): add to `/etc/network/interfaces.d/bgp` and
  `ifup dummy0`.
- **NetworkManager**: use `nmcli` to add a dummy device and static routes.
