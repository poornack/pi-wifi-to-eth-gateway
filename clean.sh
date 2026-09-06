#!/usr/bin/env bash
# Remove everything a previous build left behind so the next ./build.sh starts
# from scratch. Keeps your pi-gen-config and network-config.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
	cat <<- USAGE
	Usage: ./clean.sh [-h|--help]

	Remove everything a previous build left behind (the pi-gen Docker build
	container and its work volume, pi-gen/deploy, pi-gen/work, deploy/) so the
	next ./build.sh starts from scratch. Keeps pi-gen-config and network-config.

	Options:
	  -h, --help       show this help
	USAGE
}

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) usage; exit 0 ;;
		*) echo "!! unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

CONTAINER="${CONTAINER_NAME:-pigen_work}"
if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
	echo ">> removing build container ${CONTAINER} (and its work volume)"
	docker rm -v "${CONTAINER}"
fi
for d in "${ROOT}/pi-gen/deploy" "${ROOT}/pi-gen/work" "${ROOT}/deploy"; do
	if [ -d "$d" ]; then echo ">> removing $d"; rm -rf "$d"; fi
done
echo ">> clean. Run ./build.sh for a fresh build."
