#!/bin/bash

set -p

TOP=`realpath .`
CROSS_COMPILE="riscv64-linux-gnu-"

fetch_all() {
    cd "${TOP}"
    if [[ ! -d "${TOP}/crosvm/.git" ]]; then
        git clone git@github.com:tjeznach/crosvm.git
        cd crosvm
        git checkout tjeznach/topic/riscv-iommu 
        git submodule update --init
        cd ..
    fi
    if [[ ! -d "${TOP}/linux/.git" ]]; then
        git clone https://github.com/tjeznach/linux.git
        cd linux
        git checkout tjeznach/riscv-iommu-aia
        cd ..
    fi
    if [[ ! -d "${TOP}/qemu/.git" ]]; then
        git clone https://github.com/tjeznach/qemu.git
        cd qemu
        git checkout tjeznach/riscv-iommu
        git submodule update --init
        cd ..
    fi
}


# Get CrosVM and build riscv64 target
build_qemu() {
    cd "${TOP}/qemu"
    mkdir build && cd build
    ../configure --target-list="riscv64-softmmu"
    make -j$(nproc)
    cd "${TOP}/qemu"
    make -C roms/opensbi CROSS_COMPILE=${CROSS_COMPILE} O=../../build PLATFORM_RISCV_XLEN=64 PLATFORM=generic -j $(nproc)
}

build_kernel() {
    cd "${TOP}/linux"
    if [[ ! -d build ]]; then
        mkdir build
        make ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} O=build -j$(nproc) defconfig
        cd build
        ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} ../scripts/kconfig/merge_config.sh .config ../../vfio.config
        cd ..
    fi
    make ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} O=build -j$(nproc) Image
}

build_crosvm() {
    cd "${TOP}/crosvm"
    export PKG_CONFIG_ALLOW_CROSS="true"
    export CROS_RUST=1
    cargo build --no-default-features --target=riscv64gc-unknown-linux-gnu --release
}

build_rootfs() {
    REL="kinetic"
    cd "${TOP}"
    if [[ ! -f "${REL}.img" ]]; then
        truncate -s 1G $REL.img
        mkfs.ext4 $REL.img
        mkdir -p $REL
        sudo mount -oloop $REL.img $REL
        sudo debootstrap --arch=riscv64 $REL $REL
        sudo sed 's/root:.:/root::/' -i $REL/etc/shadow
        sudo echo 'riscv-guest' > $REL/etc/hostname
        sudo umount $REL
        cp $REL.img nvme1.img
        sudo mount -oloop $REL.img $REL
        sudo cp crosvm/target/riscv64gc-unknown-linux-gnu/release/crosvm $REL/usr/bin
        sudo cp linux/build/arch/riscv/boot/Image $REL/usr/share/Image
        sudo echo 'riscv-host' > $REL/etc/hostname
        sudo cp crosvm.cli $REL/usr/bin
        sudo umount $REL
        cp $REL.img nvme0.img
    fi
}

fetch_all

build_qemu
build_kernel
build_crosvm
build_rootfs

# run QEMU

cd "${TOP}"

QEMU="qemu/build/qemu-system-riscv64"
KERNEL="linux/build/arch/riscv/boot/Image"
OPEN_SBI="qemu/build/platform/generic/firmware/fw_jump.elf"

NVME0="nvme0.img,format=raw"
NVME1="nvme1.img,format=raw"
# release/Fedora-Developer-37-20221130.n.0-nvme.raw.img,format=raw"

die() {
    echo $*
    exit 1
}

test -x "${QEMU}" || die "Can't find QEMU: ${QEMU}"
test -f "${KERNEL}" || die "Can't find KERNEL: ${KERNEL}"
test -f "${OPEN_SBI}" || die "Can't find OPEN_SBI: ${OPEN_SBI}"

QARGS=""
# machine definition
QARGS="${QARGS} -no-reboot -no-user-config -nographic -machine virt,aia=aplic-imsic,aia-guests=4 -cpu rv64 -smp 2"
QARGS="${QARGS} -m 4G -object memory-backend-file,id=sysmem,mem-path=/dev/shm/4g,size=4G,share=on"

# emulation backends
QARGS="${QARGS} -drive file=${NVME0},read-only=off,id=nvme0"
QARGS="${QARGS} -drive file=${NVME1},read-only=off,id=nvme1" 
QARGS="${QARGS} -netdev user,id=host-net,hostfwd=tcp::2223-:23"
# emulated devices, use virtio-blk for host OS
QARGS="${QARGS} -device x-riscv-iommu-pci,addr=1.0"
QARGS="${QARGS} -device virtio-blk-pci,disable-legacy=on,disable-modern=off,iommu_platform=on,ats=on,drive=nvme0,addr=3.0"
QARGS="${QARGS} -device virtio-net-pci,romfile=,netdev=host-net,disable-legacy=on,disable-modern=off,iommu_platform=on,ats=on,addr=7.0"
QARGS="${QARGS} -device nvme,serial=87654321,drive=nvme1,addr=4.0"

# kernel arguments
KARGS="nokaslr earlycon=sbi console=ttyS0 root=/dev/vda"

# Optional - enable IOMMU DMA translation trace
# QARGS="${QARGS} -trace riscv_iommu_dma"

# run qemu
${QEMU} -bios ${OPEN_SBI} -append "${KARGS}" -kernel ${KERNEL} ${QARGS}

