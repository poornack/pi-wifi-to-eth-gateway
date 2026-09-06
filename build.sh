#!/usr/bin/env bash
# Build the WiFi -> Ethernet gateway image with pi-gen, inside Docker.
#
#   ./build.sh              build (or resume a previous, interrupted build)
#   ./clean.sh              throw away the previous build and start from scratch
#   DRY_RUN=1 ./build.sh    check config only, do not build
#

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIGEN="${ROOT}/pi-gen"

# 1. pi-gen submodule present?
if [ ! -f "${PIGEN}/build-docker.sh" ]; then
	echo ">> fetching the pi-gen submodule"
	git -C "${ROOT}" submodule update --init
fi

# 2. Config files. Created from the examples on first run so you can edit them.
missing=0
for f in pi-gen-config network-config; do
	if [ ! -f "${ROOT}/${f}" ]; then
		cp "${ROOT}/${f}.example" "${ROOT}/${f}"
		echo "!! created ${f} from ${f}.example"
		missing=1
	fi
done
if [ "${missing}" = 1 ]; then
	echo "   Edit pi-gen-config (password, WiFi) and network-config (addresses), then run ./build.sh again."
	exit 1
fi
chmod 600 "${ROOT}/pi-gen-config"

# 3. Check the values before spending half an hour in Docker.
(
	set +u
	# shellcheck disable=SC1091
	source "${ROOT}/pi-gen-config"
	# shellcheck disable=SC1091
	source "${ROOT}/network-config"
	: "${IMG_NAME:?IMG_NAME must be set in pi-gen-config}"
	: "${FIRST_USER_PASS:?FIRST_USER_PASS must be set in pi-gen-config}"
	: "${WPA_COUNTRY:?WPA_COUNTRY must be set in pi-gen-config (without it WiFi stays disabled)}"
	if [ -n "${WIFI_SSID}" ] && { [ "${#WIFI_PSK}" -lt 8 ] || [ "${#WIFI_PSK}" -gt 63 ]; }; then
		echo "WIFI_PSK must be 8-63 characters"; exit 1
	fi
	for v in GATEWAY_WIFI_IF GATEWAY_ETH_IF GATEWAY_HOME_LAN GATEWAY_ETH_NET GATEWAY_ETH_IP \
	         GATEWAY_ETH_PREFIX GATEWAY_DHCP_START GATEWAY_DHCP_END GATEWAY_DHCP_LEASE; do
		: "${!v:?$v must be set in network-config}"
	done
	if [ "${FIRST_USER_PASS}" = "change-me" ]; then
		echo "!! FIRST_USER_PASS in pi-gen-config is still the example value"; exit 1
	fi
)

# 4. Mount our files into the container without touching the submodule:
#    - stage-gateway: our build stage, at the path STAGE_LIST expects
#    - network-config: read by stage-gateway/01-network/00-run.sh
#    - stage2/SKIP_IMAGES: stop pi-gen exporting the intermediate "Lite" image
export PIGEN_DOCKER_OPTS="${PIGEN_DOCKER_OPTS:-} \
	--volume ${ROOT}/stage-gateway:/pi-gen/stage-gateway \
	--volume ${ROOT}/network-config:/pi-gen/stage-gateway/network-config:ro \
	--volume ${ROOT}/pi-gen-mounts/stage2/SKIP_IMAGES:/pi-gen/stage2/SKIP_IMAGES:ro"

# 5. Resume by default: keep the build container and pick up where it stopped.
#    ./clean.sh removes it for a fresh start.
export CONTINUE="${CONTINUE:-1}"
export PRESERVE_CONTAINER="${PRESERVE_CONTAINER:-1}"

if [ "${DRY_RUN:-0}" = "1" ]; then
	echo ">> DRY_RUN: config OK. Would run: pi-gen/build-docker.sh -c pi-gen-config"
	exit 0
fi

echo ">> building with pi-gen $(git -C "${PIGEN}" rev-parse --short HEAD)"
cd "${PIGEN}"
./build-docker.sh -c "${ROOT}/pi-gen-config"

# 6. Collect the result.
# shellcheck disable=SC1091
IMG_NAME="$(source "${ROOT}/pi-gen-config" >/dev/null 2>&1; echo "${IMG_NAME}")"
mkdir -p "${ROOT}/deploy"
cp -v "${PIGEN}"/deploy/*"${IMG_NAME}"* "${ROOT}/deploy/"
echo ">> done. Your image:"
ls -lh "${ROOT}/deploy"/*.img* 2>/dev/null || ls -lh "${ROOT}/deploy"
