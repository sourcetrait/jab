# virtio_pci.S

virtio over PCI, the modern transport, for the devices on the PCI Express
root (pci.S): the same bring-up, queue setup, notify, and status as virtio.S
drives over mmio, through the common configuration region a device's
capabilities named, a byte, a half, or a word at a time, the queue
addresses as halves. Every routine takes the device's record in a0 and
clobbers t registers, plus a0 for what it returns.
