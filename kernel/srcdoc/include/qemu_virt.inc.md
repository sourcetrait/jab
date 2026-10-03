# qemu_virt.inc

QEMU's virt machine, the only machine Jab runs on. The map is fixed, so it
is written down here rather than read from a device tree.

## .set QEMU_VIRT_VIRTIO0

Eight transports one page apart, modern with
-global virtio-mmio.force-legacy=false; a device is found by its id, since
-device order is free.

## .set QEMU_VIRT_PCIE_ECAM

PCI Express is a GPEX host bridge the machine always has. A device's 4 KiB
of configuration space sits at the base plus its bus, device, and function
shifted into place.

## .set QEMU_VIRT_PCIE_MMIO

A 1 GiB window from which the kernel gives each device its BARs, since with
-bios none nothing else has.

## .set QEMU_VIRT_DRAM

The machine has 4 GiB of RAM (-m 4G on every line): the kernel's 2 MiB at
the bottom, the framebuffer next, and the program's window the rest.
