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

Login as `root`, no password.

```
$ echo "$(</sys/firmware/devicetree/base/model)"
riscv-virtio,qemu

$ cat /proc/cpuinfo
processor	: 0
hart		: 0
isa		: rv64imafdch_zicbom_zicboz_zihintpause_zbb_smaia_ssaia_sstc
mmu		: sv57
mvendorid	: 0x0
marchid		: 0x80032
mimpid		: 0x80032

processor	: 1
hart		: 1
isa		: rv64imafdch_zicbom_zicboz_zihintpause_zbb_smaia_ssaia_sstc
mmu		: sv57
mvendorid	: 0x0
marchid		: 0x80032
mimpid		: 0x80032

~# ls /sys/bus/pci/devices/0000\:00\:0?.0/iommu_group -l
lrwxrwxrwx 1 root root 0 Jun  8 22:41 /sys/bus/pci/devices/0000:00:03.0/iommu_group -> ../../../../../../kernel/iommu_groups/1
lrwxrwxrwx 1 root root 0 Jun  8 22:41 /sys/bus/pci/devices/0000:00:04.0/iommu_group -> ../../../../../../kernel/iommu_groups/0
lrwxrwxrwx 1 root root 0 Jun  8 22:41 /sys/bus/pci/devices/0000:00:07.0/iommu_group -> ../../../../../../kernel/iommu_groups/2
~# ls /sys/bus/pci/devices/0000\:00\:0?.0/iommu -l
lrwxrwxrwx 1 root root 0 Jun  8 22:42 /sys/bus/pci/devices/0000:00:03.0/iommu -> ../../../../../virtual/iommu/riscv-iommu@40000c000
lrwxrwxrwx 1 root root 0 Jun  8 22:42 /sys/bus/pci/devices/0000:00:04.0/iommu -> ../../../../../virtual/iommu/riscv-iommu@40000c000
lrwxrwxrwx 1 root root 0 Jun  8 22:42 /sys/bus/pci/devices/0000:00:07.0/iommu -> ../../../../../virtual/iommu/riscv-iommu@40000c000
```

Run CrosVM using PCIe device 0000:00:04.0 as direct attached storage and 0000:00:09.0 as network devices.

```
$ crosvm.cli
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
