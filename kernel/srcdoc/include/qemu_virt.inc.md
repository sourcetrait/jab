# qemu_virt.inc

QEMU's virt machine, the only machine Jab runs on. The map is fixed, so it
is written down here; the device tree QEMU hands the kernel is read for the
harts alone and held to these where it says the same (harts.S).

## .set QEMU_VIRT_UART0

`addr`: the 16550 UART, byte registers, transmit at 0 and line status at 5.

## .set QEMU_VIRT_VIRTIO0

`addr`: the first of the virtio-mmio transports.

Eight transports one page apart, modern with
-global virtio-mmio.force-legacy=false; a device is found by its id, since
-device order is free.

## .set QEMU_VIRT_VIRTIO_STRIDE

`u64`: bytes between transports.

## .set QEMU_VIRT_VIRTIO_COUNT

`u64`: the transports the machine has.

## .set QEMU_VIRT_VIRTIO_IRQ0

`u64`: transport 0's interrupt source at the APLIC, transport n's this
plus n.

## .set QEMU_VIRT_PCIE_ECAM

`addr`: the host bridge's configuration space by ECAM.

PCI Express is a GPEX host bridge the machine always has. A device's 4 KiB
of configuration space sits at the base plus its bus, device, and function
shifted into place.

## .set QEMU_VIRT_PCIE_ECAM_SIZE

`u64`.

## .set QEMU_VIRT_PCIE_MMIO

`addr`: the window the kernel gives each device its BARs from.

A 1 GiB window from which the kernel gives each device its BARs, since with
-bios none nothing else has.

## .set QEMU_VIRT_PCIE_MMIO_SIZE

`u64`.

## .set QEMU_VIRT_PCIE_IRQ0

`u64`: the first INTx line, an APLIC source, a device's this plus its slot
and pin modulo four.

## .set QEMU_VIRT_PCIE_IRQ_COUNT

`u64`: the INTx lines.

## .set QEMU_VIRT_APLIC_M
## .set QEMU_VIRT_APLIC_S

`addr`: the APLIC's machine and supervisor domains, the machine's the
root.

The tree's APLIC nodes are held to these (aia.S's aia_topology), since
the page tables map the supervisor domain's page at assembly; the root
domain is never mapped in supervisor mode.

## .set QEMU_VIRT_IMSIC_M
## .set QEMU_VIRT_IMSIC_S

`addr`: the IMSIC's machine interrupt files and supervisor ones, a page a
hart with no guest files.

## .set QEMU_VIRT_TEST

`addr`: the test device, a 32-bit write ending QEMU with an exit code.

## .set QEMU_TEST_PASS

`u32`: the test device's word for a pass.

## .set QEMU_TEST_FAIL

`u32`: the test device's word for a failure, the exit code above it from bit 16.

## .set QEMU_VIRT_DRAM

`addr`: the start of RAM, where -kernel loads the kernel.

The machine has 4 GiB of RAM (-m 4G on every line): the kernel's 2 MiB at
the bottom, the framebuffer next, and the program's window the rest.

## .set QEMU_VIRT_DRAM_SIZE

`u64`: the RAM every run line gives the machine.

## .set QEMU_VIRT_TIMEBASE

`u64`: how many times the time counter ticks a second.

Every usable cpu's timebase-frequency in the tree, its own else /cpus's,
is held to it at boot, and another ends the run before the program
starts, since the frame clock and every program's time count in it.
