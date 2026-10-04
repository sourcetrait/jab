# pci.inc

PCI configuration space as the kernel reads it through ECAM, and virtio over
PCI, the modern transport (virtio 1.3, section 4.1): a device's capability
list names where its common configuration, notification, ISR, and device
configuration regions sit inside its BARs, and the common configuration is
the mmio register set in another layout, accessed a byte, a half, or a word
at a time.

## .set PCI_CFG_VENDOR

`u16`: the configuration header's vendor id, type 0.

## .set PCI_CFG_DEVICE

`u16`.

## .set PCI_CFG_COMMAND

`u16`.

## .set PCI_CFG_STATUS

`u16`.

## .set PCI_CFG_HEADER_TYPE

`u8`.

## .set PCI_CFG_BAR0

`u32`: the first of the BARs.

## .set PCI_CFG_SUBSYSTEM_DEVICE

`u16`.

## .set PCI_CFG_CAPABILITIES

`u8`: the offset of the first capability.

## .set PCI_CFG_INTERRUPT_PIN

`u8`.

## .set PCI_CFG_SIZE

`u64`: a function's configuration space in bytes.

## .set PCI_BAR_COUNT

`u64`: the BARs of a type 0 header.

## .set PCI_COMMAND_MEMORY

`u16`: command's memory space enable.

## .set PCI_COMMAND_MASTER

`u16`: command's bus master enable.

## .set PCI_COMMAND_INTX_DISABLE

`u16`.

## .set PCI_STATUS_CAPABILITIES

`u16`: status's capability list present.

## .set PCI_HEADER_TYPE_MASK

`u8`: the header type without the multi-function bit.

## .set PCI_BAR_IO

`u32`: a BAR in I/O space.

## .set PCI_BAR_TYPE_MASK

`u32`: a memory BAR's type field.

## .set PCI_BAR_TYPE_64

`u32`: a memory BAR spanning two slots.

## .set PCI_BAR_ADDRESS_MASK

`u32`: a memory BAR's address bits.

## .set PCI_VENDOR_NONE

`u16`: the vendor id read where no function answers.

## .set PCI_CAP_VENDOR

`u8`: a vendor-specific capability, as virtio's are.

## .set PCI_VIRTIO_VENDOR

`u16`: virtio's vendor id.

## .set PCI_VIRTIO_DEVICE_MODERN

`u16`: a modern device's id less its virtio device id.

A modern device's PCI device id is PCI_VIRTIO_DEVICE_MODERN plus the virtio
device id; a transitional one's is PCI_VIRTIO_DEVICE_TRANSITIONAL on, with
the virtio id in the subsystem device id.

## .set PCI_VIRTIO_DEVICE_TRANSITIONAL

`u16`: the first transitional device id.

## .set PCI_VIRTIO_DEVICE_TRANSITIONAL_LAST

`u16`: the last transitional device id.

## .set VIRTIO_PCI_CAP_NEXT

`u8`: a virtio capability's next pointer.

## .set VIRTIO_PCI_CAP_TYPE

`u8`: which region the capability names.

## .set VIRTIO_PCI_CAP_BAR

`u8`: the BAR the region sits in.

## .set VIRTIO_PCI_CAP_OFFSET

`u32`: the region's offset in its BAR.

## .set VIRTIO_PCI_CAP_LENGTH

`u32`: the region's length.

## .set VIRTIO_PCI_CAP_NOTIFY_MULTIPLIER

`u32`: the notify capability's offset multiplier.

## .set VIRTIO_PCI_CAP_COMMON_CFG

`u8`: the common configuration region.

## .set VIRTIO_PCI_CAP_NOTIFY_CFG

`u8`: the notification region.

## .set VIRTIO_PCI_CAP_ISR_CFG

`u8`: the ISR region.

## .set VIRTIO_PCI_CAP_DEVICE_CFG

`u8`: the device configuration region.

## .set VIRTIO_PCI_COMMON_DEVICE_FEATURE_SELECT

`u32`.

## .set VIRTIO_PCI_COMMON_DEVICE_FEATURE

`u32`.

## .set VIRTIO_PCI_COMMON_DRIVER_FEATURE_SELECT

`u32`.

## .set VIRTIO_PCI_COMMON_DRIVER_FEATURE

`u32`.

## .set VIRTIO_PCI_COMMON_MSIX_CONFIG

`u16`.

## .set VIRTIO_PCI_COMMON_NUM_QUEUES

`u16`.

## .set VIRTIO_PCI_COMMON_STATUS

`u8`.

## .set VIRTIO_PCI_COMMON_GENERATION

`u8`.

## .set VIRTIO_PCI_COMMON_QUEUE_SELECT

`u16`.

## .set VIRTIO_PCI_COMMON_QUEUE_SIZE

`u16`.

## .set VIRTIO_PCI_COMMON_QUEUE_MSIX_VECTOR

`u16`.

## .set VIRTIO_PCI_COMMON_QUEUE_ENABLE

`u16`.

## .set VIRTIO_PCI_COMMON_QUEUE_NOTIFY_OFF

`u16`.

## .set VIRTIO_PCI_COMMON_QUEUE_DESC_LOW

`u32`.

## .set VIRTIO_PCI_COMMON_QUEUE_DESC_HIGH

`u32`.

## .set VIRTIO_PCI_COMMON_QUEUE_DRIVER_LOW

`u32`.

## .set VIRTIO_PCI_COMMON_QUEUE_DRIVER_HIGH

`u32`.

## .set VIRTIO_PCI_COMMON_QUEUE_DEVICE_LOW

`u32`.

## .set VIRTIO_PCI_COMMON_QUEUE_DEVICE_HIGH

`u32`.

## .set VIRTIO_PCI_ISR_QUEUE

`u8`: the ISR's used-buffer bit.

## .set PCI_DEV_VENDOR

`u16`: the kernel's record of a PCI device it has brought up, its vendor id.

## .set PCI_DEV_DEVICE

`u16`.

## .set PCI_DEV_SLOT

`u8`.

## .set PCI_DEV_PIN

`u8`: the INTx pin, 1 for INTA.

## .set PCI_DEV_LINE

`u8`: the PLIC line the pin lands on.

## .set PCI_DEV_VIRTIO_ID

`u32`: the virtio device id.

## .set PCI_DEV_COMMON

`addr`: the common configuration.

## .set PCI_DEV_NOTIFY

`addr`: the notification region.

## .set PCI_DEV_NOTIFY_MULTIPLIER

`u64`: the notify capability's offset multiplier.

## .set PCI_DEV_ISR

`addr`: the ISR region.

## .set PCI_DEV_DEVICE_CFG

`addr`: the device configuration.

## .set PCI_DEV_QUEUE_NOTIFY

`addr`: where a notify for the queue last set up goes.

## .set PCI_DEV_BARS

`6 addr`: each BAR's base.

## .set PCI_DEV_SIZE

`u64`: bytes in a record.

## .set PCI_DEV_MAX

`u64`: the records the kernel keeps.
