#!/bin/bash -e
# pi-gen runs prerun.sh before the numbered steps of a stage. Each stage works
# on its own copy of the root filesystem; copy_previous (a pi-gen helper)
# seeds ours from the previous stage's result (stage2 = Raspberry Pi OS Lite)
# unless a copy already exists from an earlier, resumed build.
if [ ! -d "${ROOTFS_DIR}" ]; then
	copy_previous
fi
