# pci.inc

PCI configuration space as the kernel reads it through ECAM, and virtio over
PCI, the modern transport (virtio 1.3, section 4.1): a device's capability
list names where its common configuration, notification, ISR, and device
configuration regions sit inside its BARs, and the common configuration is
the mmio register set in another layout, accessed a byte, a half, or a word
at a time.

## .set PCI_VIRTIO_DEVICE_MODERN

A modern device's PCI device id is PCI_VIRTIO_DEVICE_MODERN plus the virtio
device id; a transitional one's is PCI_VIRTIO_DEVICE_TRANSITIONAL on, with
the virtio id in the subsystem device id.
