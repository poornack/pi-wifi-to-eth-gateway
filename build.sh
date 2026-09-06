#!/usr/bin/env bash
# Build the WiFi -> Ethernet gateway image with pi-gen, inside Docker.
#
# Run ./build.sh --help for usage.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIGEN="${ROOT}/pi-gen"

usage() {
	cat <<- USAGE
	Usage: ./build.sh [-n|--dry-run] [-h|--help]

	Build the WiFi -> Ethernet gateway image with pi-gen, inside Docker.
	Re-running after an interrupted build resumes where it stopped;
	use ./clean.sh to start from scratch.

	On the first run the two config files are created from their .example
	files and the script stops so you can edit them:
	  pi-gen-config    image name, locale, login user and password, WiFi country
	  network-config   addresses, DHCP range, WiFi network name and password

	Options:
	  -n, --dry-run    check the config files and show what would run, do not build
	  -h, --help       show this help
	USAGE
}

DRY_RUN=0
while [ $# -gt 0 ]; do
	case "$1" in
		-n|--dry-run) DRY_RUN=1 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "!! unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

# Both hold secrets (login password, WiFi password)
chmod 600 "${ROOT}/pi-gen-config" "${ROOT}/network-config"

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
	for v in GATEWAY_WIFI_IF GATEWAY_ETH_IF GATEWAY_HOME_LAN GATEWAY_ETH_NET GATEWAY_ETH_IP \
	         GATEWAY_ETH_PREFIX GATEWAY_DHCP_START GATEWAY_DHCP_END GATEWAY_DHCP_LEASE; do
		: "${!v:?$v must be set in network-config}"
	done
	if [ -n "${WIFI_SSID}" ] && { [ "${#WIFI_PSK}" -lt 8 ] || [ "${#WIFI_PSK}" -gt 63 ]; }; then
		echo "!! WIFI_PSK in network-config must be 8-63 characters"; exit 1
	fi
	if [ "${FIRST_USER_PASS}" = "change-me" ]; then
		echo "!! FIRST_USER_PASS in pi-gen-config is still the example value"; exit 1
	fi
)

# 4. Mount our files into the container without touching the submodule:
#    - pi-gen-mounts/stage-gateway: our build stage, at the path STAGE_LIST expects
#    - network-config: read by stage-gateway/01-network/00-run.sh (addresses + WiFi)
#    - stage2/SKIP_IMAGES: stop pi-gen exporting the intermediate "Lite" image
export PIGEN_DOCKER_OPTS="${PIGEN_DOCKER_OPTS:-} \
	--volume ${ROOT}/pi-gen-mounts/stage-gateway:/pi-gen/stage-gateway \
	--volume ${ROOT}/network-config:/pi-gen/stage-gateway/network-config:ro \
	--volume ${ROOT}/pi-gen-mounts/stage2/SKIP_IMAGES:/pi-gen/stage2/SKIP_IMAGES:ro"

# 5. Resume by default: keep the build container and pick up where it stopped.
#    ./clean.sh removes it for a fresh start.
export CONTINUE="${CONTINUE:-1}"
export PRESERVE_CONTAINER="${PRESERVE_CONTAINER:-1}"

if [ "${DRY_RUN}" = 1 ]; then
	echo ">> dry run: config OK. Would run: pi-gen/build-docker.sh -c pi-gen-config"
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
echo ">> Built image:"
ls -lh "${ROOT}/deploy"/*.img* 2>/dev/null || ls -lh "${ROOT}/deploy"
echo ">> Build Succeeded"
