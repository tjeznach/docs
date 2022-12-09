# RISC-V IOMMU Experiment

## Dependencies

Install tools and dependencies required for each project:

- QEMU: https://github.com/tjeznach/qemu/tree/tjeznach/riscv-iommu
- LINUX: https://github.com/tjeznach/linux/tree/tjeznach/riscv-iommu-aia
- CROSVM: https://github.com/tjeznach/crosvm/tree/tjeznach/topic/riscv-iommu

## Installation

Run simple script to fetch, build and run experiment.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/tjeznach/docs/master/riscv-iommu/run-qemu.sh | bash
```

## RISC-V Host

```
$ echo "$(</sys/firmware/devicetree/base/model)"
riscv-virtio,qemu

$ cat /proc/cpuinfo
processor	: 0
hart		: 0
isa		: rv64imafdch_smaia_ssaia_sstc_zihintpause
mmu		: sv57
mvendorid	: 0x0
marchid		: 0x7015e
mimpid		: 0x7015e

processor	: 1
hart		: 1
isa		: rv64imafdch_smaia_ssaia_sstc_zihintpause
mmu		: sv57
mvendorid	: 0x0
marchid		: 0x7015e
mimpid		: 0x7015e


$ ls /sys/bus/pci/devices/0000\:00\:0?.0/iommu -l
lrwxrwxrwx 1 root root 0 Dec  9 06:45 /sys/bus/pci/devices/0000:00:03.0/iommu -> ../../../../../virtual/iommu/riscv-iommu@40000c000
lrwxrwxrwx 1 root root 0 Dec  9 06:45 /sys/bus/pci/devices/0000:00:04.0/iommu -> ../../../../../virtual/iommu/riscv-iommu@40000c000
lrwxrwxrwx 1 root root 0 Dec  9 06:45 /sys/bus/pci/devices/0000:00:07.0/iommu -> ../../../../../virtual/iommu/riscv-iommu@40000c000
lrwxrwxrwx 1 root root 0 Dec  9 06:45 /sys/bus/pci/devices/0000:00:09.0/iommu -> ../../../../../virtual/iommu/riscv-iommu@40000c000

$ ls /sys/bus/pci/devices/0000\:00\:0?.0/iommu_group -l
lrwxrwxrwx 1 root root 0 Dec  9 06:45 /sys/bus/pci/devices/0000:00:03.0/iommu_group -> ../../../../../../kernel/iommu_groups/0
lrwxrwxrwx 1 root root 0 Dec  9 06:45 /sys/bus/pci/devices/0000:00:04.0/iommu_group -> ../../../../../../kernel/iommu_groups/1
lrwxrwxrwx 1 root root 0 Dec  9 06:45 /sys/bus/pci/devices/0000:00:07.0/iommu_group -> ../../../../../../kernel/iommu_groups/3
lrwxrwxrwx 1 root root 0 Dec  9 06:45 /sys/bus/pci/devices/0000:00:09.0/iommu_group -> ../../../../../../kernel/iommu_groups/2

```

Attach NVMe1n1 to VFIO-PCI

```
$ export BDF="0000:00:04.0"
$ export DID="1b36 0010"
$ echo "$BDF" > /sys/bus/pci/devices/$BDF/driver/unbind
$ echo "$DID" > /sys/bus/pci/drivers/vfio-pci/new_id

$ ls /dev/vfio -l
crw------- 1 root root 246,   0 Dec  9 06:44 1
crw-rw-rw- 1 root root  10, 196 Dec  9 06:43 vfio
```

Run CrosVM using NVMe1n1 as direct attached root drive.

```
$ crosvm --no-syslog run --disable-sandbox -p 'nokaslr console=ttyS0 root=/dev/nvme0n1' --vfio "/sys/bus/pci/devices/$BDF" /usr/share/Image
```

## RISC-V Guest

```
# cat /proc/cpuinfo
processor	: 0
hart		: 0
isa		: rv64iafdc_smaia_ssaia
mmu		: sv57
mvendorid	: 0x0
marchid		: 0x7015e
mimpid		: 0x7015e
```

```
# cat /sys/firmware/devicetree/base/compatible
linux,dummy-virt
```
