# pci.S

PCI: the machine's PCI Express root, walked once for virtio devices, which
are the only ones Jab puts there. Under -bios none no firmware has run, so
the kernel does what firmware would: each device's BARs are sized by the
write-ones probe and given a base out of the 1 GiB MMIO window in order,
memory decoding and bus mastering are turned on, and the device's INTx pin
is followed by the host bridge's swizzle to its PLIC line. Then the virtio
capabilities in its configuration space are read for where its regions sit,
and the device is kept in a record for whoever drives it (block.S). A
device's interrupt is a level held until its ISR register is read, which
plic_service does for every device on a PCI line it takes.

## pci_bring_up

The line is QEMU_VIRT_PCIE_IRQ0 plus the slot and the pin, less one, modulo
four; a device with no pin gets line 0. The virtio device id is the PCI
device id past the modern base, or the subsystem id of a transitional
device. The INTx pin is left enabled.

## pci_assign_bar

The BAR is sized by writing ones and reading the mask back. The size is the
low word's address bits and the high word together, inverted and one more;
a 32-bit BAR's size stays within a word.

## pci_devices

The PCI_DEV_* records, PCI_DEV_MAX of them.

## pci_count

`u64`: the records filled.

## pci_scanned

`u64`: 1 once the scan has run.

## pci_next_base

`addr`: the next free byte of the PCI MMIO window.
