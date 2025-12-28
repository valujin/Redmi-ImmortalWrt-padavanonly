#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/padavanonly/immortalwrt-mt798x-6.6/}"
REPO_BRANCH="${REPO_BRANCH:-openwrt-24.10-6.6}"
FEEDS_CONF="${FEEDS_CONF:-feeds.conf.default}"
CONFIG_FILE="${CONFIG_FILE:-immortalwrtARM/ax6000/ax6000-stock-24.10-6.6.config}"
DIY_P1_SH="${DIY_P1_SH:-immortalwrtARM/ax6000/diy1.sh}"
DIY_P2_SH="${DIY_P2_SH:-immortalwrtARM/ax6000/diy2.sh}"
DEFCONFIG_PATH="${DEFCONFIG_PATH:-defconfig/mt7986-ax6000.config}"
TZ="${TZ:-Asia/Shanghai}"
WORKSPACE="${WORKSPACE:-/workspace}"
WORKDIR="${WORKDIR:-/workdir}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
FIRMWARE_PREFIX="${FIRMWARE_PREFIX:-ImmortalWrt_padavanonly}"

validate_timezone() {
  local tz_value="$1"
  local resolved
  resolved="$(realpath -m "/usr/share/zoneinfo/${tz_value}" 2>/dev/null || true)"

  if [ -z "${resolved}" ] || [[ "${resolved}" != /usr/share/zoneinfo/* ]] || [ ! -e "${resolved}" ]; then
    echo ">> Invalid TZ value: ${tz_value}" >&2
    exit 1
  fi

  echo "${resolved}"
}

resolve_workspace_path() {
  local relative_path="$1"
  local candidate="${WORKSPACE}/${relative_path}"

  if [ ! -e "${candidate}" ]; then
    return 1
  fi

  local resolved
  resolved="$(readlink -f "${candidate}")"
  case "${resolved}" in
    "${WORKSPACE}/"*)
      echo "${resolved}"
      ;;
    *)
      echo ">> Refusing to use path outside workspace: ${relative_path}" >&2
      return 1
      ;;
  esac
}

ZONEINFO_PATH="$(validate_timezone "${TZ}")"
echo ">> Using timezone ${TZ}"
ln -snf "${ZONEINFO_PATH}" /etc/localtime
echo "${TZ}" >/etc/timezone

mkdir -p "${WORKDIR}" "${OUTPUT_DIR}"
cd "${WORKDIR}"

if [ -d openwrt/.git ]; then
  echo ">> Reusing existing openwrt checkout in ${WORKDIR}/openwrt"
  git -C openwrt fetch --all
  git -C openwrt checkout "${REPO_BRANCH}"
  git -C openwrt reset --hard "origin/${REPO_BRANCH}"
else
  echo ">> Cloning ${REPO_URL} (${REPO_BRANCH})"
  git clone "${REPO_URL}" -b "${REPO_BRANCH}" openwrt
fi

cd openwrt

if [ -e "${WORKSPACE}/${FEEDS_CONF}" ]; then
  echo ">> Applying feeds config from ${WORKSPACE}/${FEEDS_CONF}"
  cp "${WORKSPACE}/${FEEDS_CONF}" feeds.conf.default
fi

p1_path="$(resolve_workspace_path "${DIY_P1_SH}" || true)"
if [ -n "${p1_path}" ]; then
  echo ">> Running pre-feed customization ${DIY_P1_SH}"
  chmod +x "${p1_path}"
  "${p1_path}"
fi

echo ">> Updating and installing feeds"
./scripts/feeds update -a
./scripts/feeds install -a

if [ -e "${WORKSPACE}/${CONFIG_FILE}" ]; then
  echo ">> Applying base config from ${WORKSPACE}/${CONFIG_FILE}"
  cp "${WORKSPACE}/${CONFIG_FILE}" .config
fi

p2_path="$(resolve_workspace_path "${DIY_P2_SH}" || true)"
if [ -n "${p2_path}" ]; then
  echo ">> Running post-feed customization ${DIY_P2_SH}"
  chmod +x "${p2_path}"
  "${p2_path}"
fi

if [ -f "${DEFCONFIG_PATH}" ]; then
  echo ">> Refreshing config with ${DEFCONFIG_PATH}"
  cp -f "${DEFCONFIG_PATH}" .config
fi

echo ">> Generating defconfig and downloading sources"
make defconfig
make download -j"$(nproc)"
find dl -size -1024c -delete

echo ">> Building firmware"
# Follow the same fallback pattern used in the GitHub Actions workflow
if ! make -j"$(nproc)"; then
  echo ">> Parallel build failed, retrying single-thread"
  if ! make -j1; then
    echo ">> Single-thread build failed, retrying verbose"
    make -j1 V=s || {
      echo ">> Verbose single-thread build failed"
      exit 1
    }
  fi
fi

DEVICE_LINE="$(grep '^CONFIG_TARGET.*DEVICE.*=y' .config | head -n1 || true)"
DEVICE_NAME=""
if [ -n "${DEVICE_LINE}" ]; then
  # .config lines look like: CONFIG_TARGET_mediatek_filogic_DEVICE_redmi_ax6000=y
  DEVICE_NAME="$(echo "${DEVICE_LINE}" | sed -r 's/.*DEVICE_(.*)=y/\1/' | tr -d '\n')"
fi
FILE_DATE="$(date +"%Y%m%d%H%M")"

mkdir -p "${OUTPUT_DIR}/bin"
if [ -d bin ]; then
  echo ">> Copying bin/ to ${OUTPUT_DIR}/bin"
  cp -r bin "${OUTPUT_DIR}/"
fi

target_dir="$(find bin/targets -mindepth 2 -maxdepth 2 -type d -print -quit 2>/dev/null || true)"
if [ -n "${target_dir}" ]; then
  firmware_name="${FIRMWARE_PREFIX}"
  if [ -n "${DEVICE_NAME}" ]; then
    firmware_name="${firmware_name}_${DEVICE_NAME}"
  fi
  firmware_name="${firmware_name}_${FILE_DATE}"
  dest="${OUTPUT_DIR}/firmware/${firmware_name}"
  echo ">> Copying firmware from ${target_dir} to ${dest}"
  mkdir -p "${dest}"
  rsync -a --exclude packages "${target_dir}/" "${dest}/"
fi

echo ">> Build completed. Artifacts are available under ${OUTPUT_DIR}"
