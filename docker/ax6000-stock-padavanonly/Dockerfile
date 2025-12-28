FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -qq update && \
    apt-get -qq install -y --no-install-recommends \
      ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
      bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk \
      gettext gcc-multilib g++-multilib git gnutls-dev gperf haveged help2man intltool \
      lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev \
      libmpc-dev libmpfr-dev libncurses-dev libpython3-dev libreadline-dev libssl-dev \
      libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano ninja-build p7zip \
      p7zip-full patch pkgconf python3 python3-docutils python3-pip python3-ply \
      python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig \
      texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd && \
    apt-get -qq autoremove --purge -y && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/*

ENV REPO_URL=https://github.com/padavanonly/immortalwrt-mt798x-6.6/ \
    REPO_BRANCH=openwrt-24.10-6.6 \
    FEEDS_CONF=feeds.conf.default \
    CONFIG_FILE=immortalwrtARM/ax6000/ax6000-stock-24.10-6.6.config \
    DIY_P1_SH=immortalwrtARM/ax6000/diy1.sh \
    DIY_P2_SH=immortalwrtARM/ax6000/diy2.sh \
    TZ=Asia/Shanghai \
    WORKSPACE=/workspace \
    WORKDIR=/workdir \
    OUTPUT_DIR=/output

WORKDIR /workspace
COPY . /workspace

RUN chmod +x /workspace/docker/ax6000-stock-padavanonly/entrypoint.sh \
    /workspace/immortalwrtARM/ax6000/diy1.sh \
    /workspace/immortalwrtARM/ax6000/diy2.sh

VOLUME ["/output", "/workdir"]

ENTRYPOINT ["/workspace/docker/ax6000-stock-padavanonly/entrypoint.sh"]
