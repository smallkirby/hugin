FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    build-essential \
    make \
    bison \
    bc \
    flex \
    gcc-aarch64-linux-gnu \
    libssl-dev \
    device-tree-compiler \
    wget \
    cpio \
    unzip \
    rsync \
    sudo \
    fdisk \
    dosfstools \
    file \
    git \
    socat \
    qemu-system-arm

# u-boot
WORKDIR /opt
RUN git clone --depth=1 -b v2024.04 https://source.denx.de/u-boot/u-boot.git
WORKDIR /opt/u-boot
RUN make CROSS_COMPILE=aarch64-linux-gnu- qemu_arm64_defconfig
RUN make CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

WORKDIR /work

ENV UBOOT=/opt/u-boot
