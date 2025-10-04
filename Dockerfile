FROM ubuntu:24.04 AS builder

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
        qemu-system-arm \
        tar \
        curl \
    && rm -rf /var/lib/apt/lists/*

# u-boot
WORKDIR /opt
RUN git clone --depth=1 -b v2024.04 https://source.denx.de/u-boot/u-boot.git
WORKDIR /opt/u-boot
RUN make CROSS_COMPILE=aarch64-linux-gnu- qemu_arm64_defconfig
RUN make CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

# buildroot
ENV BUILDROOT_VERSION=2025.05
WORKDIR /opt
RUN curl https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.xz | tar xvJf -
WORKDIR /opt/buildroot-${BUILDROOT_VERSION}
RUN make qemu_aarch64_virt_defconfig
RUN sed -i -e 's/BR2_PACKAGE_HOST_QEMU=y/BR2_PACKAGE_HOST_QEMU=n/' .config
RUN make -j$(nproc)
RUN cp output/images/Image /opt/Image
RUN cp output/images/rootfs.ext2 /opt/DISK0
WORKDIR /opt
RUN rm -rf /opt/buildroot-${BUILDROOT_VERSION}

#####################################################

FROM ubuntu:24.04 AS runtime

COPY --from=builder /opt/Image /opt/Image
COPY --from=builder /opt/DISK0 /opt/DISK0
COPY --from=builder /opt/u-boot /opt/u-boot

ENV UBOOT=/opt/u-boot
WORKDIR /work
