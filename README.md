# pi-wifi-to-eth

A Raspberry Pi image that turns the Pi into a small **WiFi -> Ethernet router**
so a wired-only machine (an ESXi host, in my case) can sit behind the Pi and be
reached from anything on the home WiFi LAN.

```
Mac ──wifi──> Home router <──wifi── Pi wlan0 (DHCP, 192.168.0.x)
                  │                 Pi eth0  192.168.2.1 ── ethernet ── ESXi 192.168.2.5
                  └─ static route 192.168.2.0/24 -> Pi's wlan0 IP
```

Routed subnet: devices behind the Pi keep real addresses and are reachable
directly from the LAN (`ssh root@192.168.2.5`). The only thing the home router
needs is one static route. LAN <-> 192.168.2.x traffic is **not** NATed; only
internet-bound traffic from 192.168.2.x is masqueraded on the Pi, because
consumer routers refuse to NAT sources outside their own LAN subnet.

## What the image contains

Built with [pi-gen](https://github.com/RPi-Distro/pi-gen) (submodule) as a
Raspberry Pi OS Lite (trixie, armhf) plus the custom `stage-bridge/`:

| piece | where | what |
|---|---|---|
| NetworkManager profile `eth0-lan` | `/etc/NetworkManager/system-connections/` | static `BRIDGE_ETH_IP`, never a default route |
| NetworkManager WiFi profile | same dir | joins `WIFI_SSID` at first boot (from `config.local`) |
| dnsmasq | `/etc/dnsmasq.d/eth0-lan.conf` | DHCP + DNS on eth0 only, static reservations from `BRIDGE_DHCP_HOSTS` |
| IPv4 forwarding | `/etc/sysctl.d/99-ip-forward.conf` | |
| nftables | `/etc/nftables.conf` | masquerade internet-bound traffic from eth0 subnet only |
| SSH banner | `/etc/update-motd.d/20-lan-router` | live addresses, leases, neighbours, and a summary of the setup |
| tools | | `tcpdump`, `ethtool` |

SSH is enabled, the first user is kept (no first-boot rename wizard), and the
authorized key in `config` is installed.

## Build

Requirements: Docker, `qemu-user-static` / binfmt (pi-gen's `build-docker.sh`
checks these), ~20 GB free disk, an hour.

```bash
git clone --recurse-submodules git@github.com:poornack/pi-wifi-to-eth.git
cd pi-wifi-to-eth
cp config.local.example config.local   # fill in FIRST_USER_PASS, WPA_COUNTRY, WIFI_SSID, WIFI_PSK
./build.sh
```

Output: `deploy/<date>-pi-wifi-to-eth-bridge.img`. Flash with Raspberry Pi
Imager or `dd`.

Rebuild only the custom stage after editing `stage-bridge/`:

```bash
touch pi-gen/stage0/SKIP pi-gen/stage1/SKIP pi-gen/stage2/SKIP
PRESERVE_CONTAINER=1 CONTINUE=1 CLEAN=1 ./build.sh
```

### Files

- `config` - pi-gen settings, committed, no secrets. Network layout lives in
  the `BRIDGE_*` variables at the bottom.
- `config.local` - secrets (gitignored). `build.sh` merges it with `config`
  into `.config.generated` because pi-gen only accepts one config file.
- `stage-bridge/` - the custom pi-gen stage. It is bind-mounted into the
  build container, so it stays outside the submodule.
- `patches/` - small fixes applied to pi-gen at build time.
- `pi-gen/` - upstream submodule, tracked unmodified. `.gitmodules` sets
  `ignore = dirty` because the build touches `stage2/SKIP_IMAGES` and applies
  patches there.

## After flashing

1. Boot the Pi; it joins the WiFi and gets an address from the home router.
   Reserve that address on the router (the banner shows the wlan0 MAC).
2. Add a static route on the home router: `192.168.2.0/24` -> the Pi's wlan0 IP.
3. Cable the PC/host to the Pi's Ethernet port. It gets an address from dnsmasq,
   or use one of the reservations from `BRIDGE_DHCP_HOSTS` (gateway and DNS =
   `192.168.2.1`).
4. `ssh poorna@<pi-ip>` shows the banner with everything currently on the cable.

## Notes

- The WiFi PSK is stored in the image in plain text (root-only keyfile). Treat
  the `.img` accordingly.
- Changing the subnet: edit the `BRIDGE_*` variables in `config`, rebuild, and
  update the router's static route. Nothing is hard-coded elsewhere.
