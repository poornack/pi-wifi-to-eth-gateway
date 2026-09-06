#!/bin/bash -e
# Configure the Pi as a WiFi -> Ethernet gateway.
#   WiFi side    : joins the home network, gets its address from the home router
#   Ethernet side: fixed address; dnsmasq hands out addresses to wired devices
#   Forwarding on; NAT only for internet-bound traffic (see files/nftables.conf)
# All settings come from ./network-config (mounted into this stage by build.sh).
# Templates live in ./files; ${VAR} placeholders are filled in by render() below.

# Load the network layout. Fail clearly if the file or any value is missing.
source "${STAGE_DIR}/network-config"
for v in GATEWAY_WIFI_IF GATEWAY_ETH_IF GATEWAY_HOME_LAN GATEWAY_ETH_NET \
         GATEWAY_ETH_IP GATEWAY_ETH_PREFIX GATEWAY_DHCP_START GATEWAY_DHCP_END GATEWAY_DHCP_LEASE; do
	: "${!v:?$v is not set in network-config}"
	export "$v"
done

# render <template> <destination> <mode>: copy a file from ./files, replacing
# every ${NAME} with the environment variable of that name.
render() {
	perl -pe 's/\$\{(\w+)\}/defined $ENV{$1} ? $ENV{$1} : die("template $ARGV: \$$1 is not set\n")/ge' "files/$1" > "$2"
	chmod "$3" "$2"
}

# Where NetworkManager keeps connection profiles inside the image
NM_DIR="${ROOTFS_DIR}/etc/NetworkManager/system-connections"
install -d -m 755 "${NM_DIR}"

# Ethernet side: fixed address, never a default route
render ethernet.nmconnection "${NM_DIR}/gateway-ethernet.nmconnection" 600

# WiFi side: join the home network (skipped if WIFI_SSID is empty)
if [ -n "${WIFI_SSID:-}" ]; then
	: "${WIFI_PSK:?WIFI_PSK is not set in network-config}"
	export WIFI_SSID WIFI_PSK
	render wifi.nmconnection "${NM_DIR}/${WIFI_SSID}.nmconnection" 600
	echo "WiFi profile installed for '${WIFI_SSID}'"
else
	echo "WIFI_SSID is empty: no WiFi profile installed, configure with nmtui after first boot"
fi

# DHCP + DNS for wired devices, plus any fixed reservations
install -d -m 755 "${ROOTFS_DIR}/etc/dnsmasq.d"
render dnsmasq-gateway.conf "${ROOTFS_DIR}/etc/dnsmasq.d/gateway-ethernet.conf" 644
install -m 644 files/dhcp-reservations.conf "${ROOTFS_DIR}/etc/dnsmasq.d/gateway-reservations.conf"

# Kernel forwarding between the two interfaces
install -d -m 755 "${ROOTFS_DIR}/etc/sysctl.d"
install -m 644 files/99-ip-forward.conf "${ROOTFS_DIR}/etc/sysctl.d/99-ip-forward.conf"

# NAT rule for internet-bound traffic only
render nftables.conf "${ROOTFS_DIR}/etc/nftables.conf" 755

# Start these services at boot (on_chroot runs a command inside the image)
on_chroot <<- CHEOF
	systemctl enable dnsmasq
	systemctl enable nftables
	systemctl enable NetworkManager
CHEOF
