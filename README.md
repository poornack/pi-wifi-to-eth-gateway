# Raspberry Pi Wi-Fi to Ethernet Gateway

A Raspberry Pi image that turns the Pi into a small **WiFi -> Ethernet gateway**
so a wired-only machine (an ESXi host, in my case) can connect to my home network without running an ethernet cable to the physical machine.

```
[My Laptop] <── wifi ──> [Home router] (192.168.0.0/24) <── wifi ──> [Pi WLAN0] [Pi SW Router (dnsmaqp)] (192.168.2.0/24) <── eth ──> [ESXi machine]
                              │                 
                              └─ static route 192.168.2.0/24 -> Pi's WLAN0 IP
```

Routed subnet: devices behind the Pi keep real addresses and are reachable
directly from the LAN (`ssh root@192.168.2.x`). The only thing the home router
needs is one static route. LAN <-> 192.168.2.x traffic is **not** NATed; only
internet-bound traffic from 192.168.2.x is masqueraded on the Pi, because
consumer routers refuse to NAT sources outside their own LAN subnet.

## What the image contains

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

## Getting it Running

### Build
1. Checkout repo
```bash
clone --recurse-submodules git@github.com:poornack/pi-wifi-to-eth.git
cd pi-wifi-to-eth
git checkout master
```
2. Prerequisites:
  a. Docker:  [Getting Started with Docker](https://www.docker.com/get-started/)
  b. `qemu-user-static`
3. Build `./build.sh`

### Flash
1. Run `diskutil list`(mac) or ` `(linux)
2. Plug in your Pi's micro SD card into your PC/Laptop (Through SD card adapter, USD adapter is fine)
3. Run command from step 1 again and find the new disk that enumerated
4. Unmount that disk `diskutil unmountDisk /dev/diskX`(mac) or ` `(linux)
5. Flash: `sudo -v | pv <path_to_.img> | dd of=/dev/rdiskX bs=4m`(mac) or ` `(linux) Note the 'r' in /dev/rdiskX. It makes the transfer go faster by referencing the raw disk and not a partition.
6. Eject: `diskutil eject /dev/diskX`(mac) or ` `(linux)

I've never used [Raspberry Pi Imager[(https://www.raspberrypi.com/software/), but you can use that too

### Run
1. Insert the micro SD card into your Pi and power it on
2. If you entered you Wi-Fi credentials, it should boot up and connect to your network via Wi-Fi. If not, run `nmutil` to connect to your Wi-Fi network.
3. Add DHCP entry for the Pi: Easiest way is to
  a. log into your router
  b. find the Pi in the list of clients
  c. copy the MAC address and currently assigned IP address
  d. find DHCP settings
  e. add an entry for the MAC address. It's easiest if you just assign it the IP it already had
4. Add static route for the Pi subnet traffic:
  a. log into your router
  b. find the static route/routing settings
  c. enter the subnet you chose when building the image (TBD var)
  d. enter the IP address you assigned the Pi from step 3 for default gateway
     This tells your router to route all traffic bound for the Pi subnet to the Pi's IP
6. Connect your ethernet device to the Pi. You can connect multiple through a switch also
7. ssh into the Pi `ssh username@pi-ip-address` and run `TBD`. Ensure your ethernet device shows up in the list of DHCP clients
8. From your PC/Laptop, run `ping ip-address-of-ethernet-device-plugged-into-pi` to verify that your PC/Laptop can reach your ethernet device.

## Notes

- The WiFi PSK is stored in the image in plain text (root-only keyfile). Treat
  the `.img` accordingly.
- Changing the subnet: edit the `BRIDGE_*` variables in `config`, rebuild, and
  update the router's static route. Nothing is hard-coded elsewhere.
