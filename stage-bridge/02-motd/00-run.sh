#!/bin/bash -e
# Replace the stock Debian MOTD with a live status banner for the router.
install -d -m 755 "${ROOTFS_DIR}/etc/update-motd.d"
install -m 755 files/20-lan-router "${ROOTFS_DIR}/etc/update-motd.d/20-lan-router"
: > "${ROOTFS_DIR}/etc/motd"
