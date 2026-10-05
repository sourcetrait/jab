# virtio_pci.S

virtio over PCI, the modern transport, for the devices on the PCI Express
root (pci.S): the same bring-up, queue setup, notify, and status as virtio.S
drives over mmio, through the common configuration region a device's
capabilities named, a byte, a half, or a word at a time, the queue
addresses as halves. Every routine takes the device's record in a0 and
clobbers t registers, plus a0 for what it returns. The queue enable, the
DRIVER_OK status, and the notify each follow `fence ow, o`, virtio.S's
ordering rule; the notify's fence is vpci_notify's own, so a caller
publishing to a PCI queue needs none before the call.

## vpci_init_with

A device with no common configuration region is refused, never written
through a null address. Its reset is read back as virtio_reset's is,
bounded by VIRTIO_RESET_TICKS from the write's end, and a device that does
not read 0 by then refuses the kernel at bring-up, where nothing has been
given to it yet.

## vpci_reset

block_fault's reset of each disk on a failed line, the PCI counterpart of
virtio_reset under the fault-routine contract: a0 the record, t registers
alone. A device with no common configuration region was never driven and
needs none. A virtio-blk reset in QEMU drains every disk's requests on the
machine inside the write, its own and every other line's, so the write can
take as long as the slowest request in flight (block_fault reads every
disk's queue before the first reset for that reason).
