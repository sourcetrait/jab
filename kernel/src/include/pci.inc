# pci.inc: PCI configuration space as the kernel reads it through ECAM,
# and virtio over PCI, the modern transport (virtio 1.3, section 4.1):
# a device's capability list names where its common configuration,
# notification, ISR, and device configuration regions sit inside its
# BARs, and the common configuration is the mmio register set in
# another layout, accessed a byte, a half, or a word at a time.

# The configuration header, type 0
.set PCI_CFG_VENDOR, 0x00
.set PCI_CFG_DEVICE, 0x02
.set PCI_CFG_COMMAND, 0x04
.set PCI_CFG_STATUS, 0x06
.set PCI_CFG_HEADER_TYPE, 0x0e
.set PCI_CFG_BAR0, 0x10
.set PCI_CFG_SUBSYSTEM_DEVICE, 0x2e
.set PCI_CFG_CAPABILITIES, 0x34
.set PCI_CFG_INTERRUPT_PIN, 0x3d
.set PCI_CFG_SIZE, 0x1000
.set PCI_BAR_COUNT, 6
.set PCI_COMMAND_MEMORY, 0x2
.set PCI_COMMAND_MASTER, 0x4
.set PCI_COMMAND_INTX_DISABLE, 0x400
.set PCI_STATUS_CAPABILITIES, 0x10
.set PCI_HEADER_TYPE_MASK, 0x7f
.set PCI_BAR_IO, 0x1
.set PCI_BAR_TYPE_MASK, 0x6
.set PCI_BAR_TYPE_64, 0x4
.set PCI_BAR_ADDRESS_MASK, 0xfffffff0
.set PCI_VENDOR_NONE, 0xffff
.set PCI_CAP_VENDOR, 0x09

# virtio's vendor, and its device ids: a modern device is
# PCI_VIRTIO_DEVICE_MODERN plus the virtio device id, a transitional
# one PCI_VIRTIO_DEVICE_TRANSITIONAL on with the virtio id in the
# subsystem device id
.set PCI_VIRTIO_VENDOR, 0x1af4
.set PCI_VIRTIO_DEVICE_MODERN, 0x1040
.set PCI_VIRTIO_DEVICE_TRANSITIONAL, 0x1000
.set PCI_VIRTIO_DEVICE_TRANSITIONAL_LAST, 0x103f

# A virtio capability in configuration space
.set VIRTIO_PCI_CAP_NEXT, 1
.set VIRTIO_PCI_CAP_TYPE, 3
.set VIRTIO_PCI_CAP_BAR, 4
.set VIRTIO_PCI_CAP_OFFSET, 8
.set VIRTIO_PCI_CAP_LENGTH, 12
.set VIRTIO_PCI_CAP_NOTIFY_MULTIPLIER, 16
.set VIRTIO_PCI_CAP_COMMON_CFG, 1
.set VIRTIO_PCI_CAP_NOTIFY_CFG, 2
.set VIRTIO_PCI_CAP_ISR_CFG, 3
.set VIRTIO_PCI_CAP_DEVICE_CFG, 4

# The common configuration, the transport's registers
.set VIRTIO_PCI_COMMON_DEVICE_FEATURE_SELECT, 0
.set VIRTIO_PCI_COMMON_DEVICE_FEATURE, 4
.set VIRTIO_PCI_COMMON_DRIVER_FEATURE_SELECT, 8
.set VIRTIO_PCI_COMMON_DRIVER_FEATURE, 12
.set VIRTIO_PCI_COMMON_MSIX_CONFIG, 16
.set VIRTIO_PCI_COMMON_NUM_QUEUES, 18
.set VIRTIO_PCI_COMMON_STATUS, 20
.set VIRTIO_PCI_COMMON_GENERATION, 21
.set VIRTIO_PCI_COMMON_QUEUE_SELECT, 22
.set VIRTIO_PCI_COMMON_QUEUE_SIZE, 24
.set VIRTIO_PCI_COMMON_QUEUE_MSIX_VECTOR, 26
.set VIRTIO_PCI_COMMON_QUEUE_ENABLE, 28
.set VIRTIO_PCI_COMMON_QUEUE_NOTIFY_OFF, 30
.set VIRTIO_PCI_COMMON_QUEUE_DESC_LOW, 32
.set VIRTIO_PCI_COMMON_QUEUE_DESC_HIGH, 36
.set VIRTIO_PCI_COMMON_QUEUE_DRIVER_LOW, 40
.set VIRTIO_PCI_COMMON_QUEUE_DRIVER_HIGH, 44
.set VIRTIO_PCI_COMMON_QUEUE_DEVICE_LOW, 48
.set VIRTIO_PCI_COMMON_QUEUE_DEVICE_HIGH, 52
.set VIRTIO_PCI_ISR_QUEUE, 0x1

# The kernel's record of a PCI device it has brought up: its ids, its
# slot, pin, and PLIC line, its virtio device id, where its virtio
# regions sit, the address a notify for the queue last set up goes to,
# and each BAR's base
.set PCI_DEV_VENDOR, 0
.set PCI_DEV_DEVICE, 2
.set PCI_DEV_SLOT, 4
.set PCI_DEV_PIN, 5
.set PCI_DEV_LINE, 6
.set PCI_DEV_VIRTIO_ID, 8
.set PCI_DEV_COMMON, 16
.set PCI_DEV_NOTIFY, 24
.set PCI_DEV_NOTIFY_MULTIPLIER, 32
.set PCI_DEV_ISR, 40
.set PCI_DEV_DEVICE_CFG, 48
.set PCI_DEV_QUEUE_NOTIFY, 56
.set PCI_DEV_BARS, 64
.set PCI_DEV_SIZE, (PCI_DEV_BARS + PCI_BAR_COUNT * 8)
.set PCI_DEV_MAX, 16
