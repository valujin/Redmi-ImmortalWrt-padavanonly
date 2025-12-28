#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/padavanonly/immortalwrt-mt798x-6.6/}"
REPO_BRANCH="${REPO_BRANCH:-openwrt-24.10-6.6}"
FEEDS_CONF="${FEEDS_CONF:-feeds.conf.default}"
CONFIG_FILE="${CONFIG_FILE:-immortalwrtARM/ax6000/ax6000-stock-24.10-6.6.config}"
DIY_P1_SH="${DIY_P1_SH:-immortalwrtARM/ax6000/diy1.sh}"
DIY_P2_SH="${DIY_P2_SH:-immortalwrtARM/ax6000/diy2.sh}"
TZ="${TZ:-Asia/Shanghai}"
WORKSPACE="${WORKSPACE:-/workspace}"
WORKDIR="${WORKDIR:-/workdir}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"

echo ">> Using timezone ${TZ}"
ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
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

if [ -e "${WORKSPACE}/${DIY_P1_SH}" ]; then
  echo ">> Running pre-feed customization ${DIY_P1_SH}"
  chmod +x "${WORKSPACE}/${DIY_P1_SH}"
  "${WORKSPACE}/${DIY_P1_SH}"
fi

echo ">> Updating and installing feeds"
./scripts/feeds update -a
./scripts/feeds install -a

if [ -e "${WORKSPACE}/${CONFIG_FILE}" ]; then
  echo ">> Applying base config from ${WORKSPACE}/${CONFIG_FILE}"
  cp "${WORKSPACE}/${CONFIG_FILE}" .config
fi

if [ -e "${WORKSPACE}/${DIY_P2_SH}" ]; then
  echo ">> Running post-feed customization ${DIY_P2_SH}"
  chmod +x "${WORKSPACE}/${DIY_P2_SH}"
  "${WORKSPACE}/${DIY_P2_SH}"
fi

if [ -f defconfig/mt7986-ax6000.config ]; then
  echo ">> Refreshing config with defconfig/mt7986-ax6000.config"
  cp -f defconfig/mt7986-ax6000.config .config
fi

echo ">> Generating defconfig and downloading sources"
make defconfig
make download -j"$(nproc)"
find dl -size -1024c -exec rm -f {} \;

echo ">> Building firmware"
make -j"$(nproc)" || make -j1 || make -j1 V=s

DEVICE_NAME="$(grep '^CONFIG_TARGET.*DEVICE.*=y' .config | sed -r 's/.*DEVICE_(.*)=y/\1/' || true)"
DEVICE_NAME="${DEVICE_NAME//$'\n'/}"
FILE_DATE="$(date +"%Y%m%d%H%M")"

mkdir -p "${OUTPUT_DIR}/bin"
if [ -d bin ]; then
  echo ">> Copying bin/ to ${OUTPUT_DIR}/bin"
  cp -r bin "${OUTPUT_DIR}/"
fi

target_dir="$(find bin/targets -mindepth 2 -maxdepth 2 -type d | head -n 1 || true)"
if [ -n "${target_dir}" ]; then
  firmware_name="ImmortalWrt_padavanonly${DEVICE_NAME:+_${DEVICE_NAME}}_${FILE_DATE}"
  dest="${OUTPUT_DIR}/firmware/${firmware_name}"
  echo ">> Copying firmware from ${target_dir} to ${dest}"
  mkdir -p "${dest}"
  rsync -a --delete --exclude packages "${target_dir}/" "${dest}/"
fi

echo ">> Build completed. Artifacts are available under ${OUTPUT_DIR}"
