# Raspberry Pi WiFi to Ethernet Gateway

A Raspberry Pi image that turns the Pi into a small **WiFi -> Ethernet gateway**:
plug a wired-only device (in my case an ESXi server) into the Pi's Ethernet
port and it joins your home network over the Pi's WiFi. No Ethernet cable to
the router needed.

```
[Your laptop] <-wifi-> [Home router] <-wifi-> [Pi: WiFi side]
                        192.168.0.0/24         [Pi: Ethernet side] <-cable-> [Your wired device]
                            |                   192.168.2.0/24                192.168.2.x
                            +-- static route: 192.168.2.0/24 -> the Pi's WiFi IP
```

How it works, in one paragraph: the Pi's Ethernet side is its own little
network (192.168.2.0/24 by default). The Pi hands out addresses on it (DHCP),
answers DNS, and forwards packets between the two sides. Your home router is
told, with one static route, that 192.168.2.x lives behind the Pi. So your
laptop can talk to the wired device by its real address, for example
`ssh root@192.168.2.5`, with no port forwarding. The only traffic the Pi
rewrites (NAT) is internet-bound traffic from the wired device, because home
routers refuse to forward addresses outside their own network.

The Pi is a *gateway*, not a bridge: WiFi client interfaces cannot be bridged
to Ethernet on Linux, which is why the Ethernet side gets its own subnet.

## What is in the image

Raspberry Pi OS Lite (trixie, 32-bit) built with [pi-gen](https://github.com/RPi-Distro/pi-gen), plus:

| piece | file on the Pi | what it does |
|---|---|---|
| NetworkManager profile `gateway-ethernet` | `/etc/NetworkManager/system-connections/` | fixed address on the Ethernet side, never a default route |
| NetworkManager WiFi profile | same directory | joins your WiFi at first boot (from `network-config`) |
| dnsmasq | `/etc/dnsmasq.d/gateway-ethernet.conf`, `gateway-reservations.conf` | DHCP + DNS for wired devices, fixed addresses for chosen devices |
| IP forwarding | `/etc/sysctl.d/99-ip-forward.conf` | lets packets cross between WiFi and Ethernet |
| nftables | `/etc/nftables.conf` | NAT for internet-bound traffic from wired devices only |
| login status page | `/etc/update-motd.d/20-gateway-status` | shows addresses, wired devices, and how the Pi is set up, every time you SSH in |
| tools | | `tcpdump`, `ethtool` |

SSH is on, the login user is kept as you configured it (no first-boot wizard),
and your SSH key is installed if you gave one.

## Repository layout

| path | what |
|---|---|
| `pi-gen/` | upstream pi-gen, as a git submodule pinned to one commit |
| `patches/` | small fixes to pi-gen, applied by you once (see below) |
| `stage-gateway/` | our extra pi-gen build stage: packages, network templates, login page |
| `pi-gen-config.example` | pi-gen settings: image name, locale, user, password, WiFi country |
| `network-config.example` | WiFi name and password; addresses: home network, Ethernet-side subnet, DHCP range |
| `pi-gen-mounts/` | files mounted into the build container so `pi-gen/` is never modified |
| `build.sh`, `clean.sh` | build the image; wipe a previous build |

`build.sh` copies the two `.example` files to `pi-gen-config` and
`network-config` on first run. Those copies are gitignored because they contain
your login and WiFi passwords, so edit them freely.

## Getting it running

### 1. Build the image

Prerequisites: Linux or macOS with [Docker](https://www.docker.com/get-started/)
installed, plus `qemu-user-static` on Linux (`sudo apt install qemu-user-static`),
about 20 GB of free disk, and 30 to 60 minutes.

```bash
git clone --recurse-submodules git@github.com:poornack/pi-wifi-to-eth-modem.git
cd pi-wifi-to-eth-modem
git -C pi-gen apply ../patches/*.patch      # one-time pi-gen fixes, see patches/README.md
./build.sh                                  # first run creates the config files and stops
```

Now edit the two files it created:

- `pi-gen-config`: set `FIRST_USER_NAME`, `FIRST_USER_PASS` and `WPA_COUNTRY` (your two-letter country code). Optionally your SSH public key.
- `network-config`: set `WIFI_SSID` and `WIFI_PSK` to your WiFi network. The address defaults work for a home network on 192.168.0.0/24. If your router uses something else (for example 192.168.1.0/24), set `GATEWAY_HOME_LAN` to match, and make sure `GATEWAY_ETH_NET` does not overlap it.
- Optional: `stage-gateway/01-network/files/dhcp-reservations.conf` to give a wired device a fixed address.

Then:

```bash
./build.sh
```

The image lands in `deploy/<date>-pi-wifi-to-eth-gateway.img`. If the build is
interrupted, running `./build.sh` again resumes it. `./clean.sh` throws the
previous build away. Both scripts take `--help`; `./build.sh --dry-run` checks
the config files without building.

### 2. Flash the micro SD card

The easy way: [Raspberry Pi Imager](https://www.raspberrypi.com/software/),
choose "Use custom" and pick the `.img`. Skip its OS customisation step, the
image is already configured.

By hand:

1. List disks **before** inserting the card: `diskutil list` (macOS) or `lsblk` (Linux)
2. Insert the micro SD card (an SD or USB adapter is fine)
3. Run the same command again. The new entry is your card, for example `/dev/disk4` (macOS) or `/dev/sdb` (Linux). Double-check: getting this wrong overwrites the wrong disk.
4. Unmount it: `diskutil unmountDisk /dev/diskX` (macOS) or `sudo umount /dev/sdX?*` (Linux)
5. Write the image:
   - macOS: `sudo dd if=deploy/<image>.img of=/dev/rdiskX bs=4m status=progress` (the `r` in `rdiskX` uses the raw device and is several times faster)
   - Linux: `sudo dd if=deploy/<image>.img of=/dev/sdX bs=4M status=progress conv=fsync`
6. Eject: `diskutil eject /dev/diskX` (macOS) or `sudo eject /dev/sdX` (Linux)

### 3. First boot and router setup

1. Insert the card and power the Pi on. It boots, joins your WiFi, and gets an
   address from your router. If you left `WIFI_SSID` empty, connect a keyboard
   and screen, log in, and run `nmtui` to pick a network.
2. **Give the Pi a fixed WiFi address** on your router. Log in to the router,
   find the Pi in the client list, note its MAC address and current IP, and add
   a DHCP reservation for that MAC. Easiest is to reserve the IP it already has.
3. **Add a static route** on your router. Find the static/advanced routing
   page and enter:
   - Destination network: the value of `GATEWAY_ETH_NET` in your `network-config` (default `192.168.2.0`, mask `255.255.255.0`)
   - Gateway / next hop: the Pi's WiFi IP from step 2
   - Interface: LAN

   This tells your router to send all traffic bound for the Pi's Ethernet subnet to the Pi's WiFi IP.
4. Plug your wired device into the Pi's Ethernet port. Several devices work too,
   through a switch. Set the device to get its address automatically (DHCP), or
   give it a fixed address in `GATEWAY_ETH_NET` with the Pi (`GATEWAY_ETH_IP`,
   default `192.168.2.1`) as gateway and DNS.
5. SSH into the Pi: `ssh <FIRST_USER_NAME>@<pi-wifi-ip>`. The login page lists
   the wired devices the Pi has seen. To list DHCP clients directly:

   ```bash
   cat /var/lib/misc/dnsmasq.leases
   ```

6. From your laptop, `ping <wired-device-ip>` and then `ssh` to it directly.

## Changing things later

- **Different subnet or DHCP range**: edit `network-config`, rebuild, update the
  router's static route. Nothing is hard-coded anywhere else.
- **Fixed address for a wired device**: add a line to
  `stage-gateway/01-network/files/dhcp-reservations.conf` and rebuild, or edit
  `/etc/dnsmasq.d/gateway-reservations.conf` on the Pi and
  `sudo systemctl restart dnsmasq`.
- **Newer pi-gen**: `cd pi-gen && git checkout <commit>`, re-apply the patches,
  commit the submodule change.

## Notes

- Your WiFi password is stored in the image as a root-only file. Treat the
  `.img` like you would treat the password.
- Wired devices reach the internet through the Pi. Your laptop reaches wired
  devices directly by their `192.168.2.x` address; the Pi does not NAT that.
- Only IPv4 is routed. The wired device will not have IPv6 connectivity.
