#!/bin/bash -e
# Replace the stock Debian login text with a live status page for the gateway.
# Debian builds the "message of the day" (the text printed after you SSH in)
# by running every script in /etc/update-motd.d at login.
install -d -m 755 "${ROOTFS_DIR}/etc/update-motd.d"
install -m 755 files/20-gateway-status "${ROOTFS_DIR}/etc/update-motd.d/20-gateway-status"
# Empty the static part (the Debian licence notice)
: > "${ROOTFS_DIR}/etc/motd"
