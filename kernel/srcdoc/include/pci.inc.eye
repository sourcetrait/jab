set PCI_CFG_VENDOR u16 [1] :the configuration header's vendor id, type 0
set PCI_CFG_DEVICE u16 [2]
set PCI_CFG_COMMAND u16 [3]
set PCI_CFG_STATUS u16 [4]
set PCI_CFG_HEADER_TYPE u8 [5]
set PCI_CFG_BAR0 u32 [6] :the first of the BARs
set PCI_CFG_SUBSYSTEM_DEVICE u16 [7]
set PCI_CFG_CAPABILITIES u8 [8] :the offset of the first capability
set PCI_CFG_INTERRUPT_PIN u8 [9]
set PCI_CFG_SIZE u64 [10] :a function's configuration space in bytes
set PCI_BAR_COUNT u64 [11] :the BARs of a type 0 header
set PCI_COMMAND_MEMORY u16 [12] :command's memory space enable
set PCI_COMMAND_MASTER u16 [13] :command's bus master enable
set PCI_COMMAND_INTX_DISABLE u16 [14]
set PCI_STATUS_CAPABILITIES u16 [15] :status's capability list present
set PCI_HEADER_TYPE_MASK u8 [16] :the header type without the multi-function bit
set PCI_BAR_IO u32 [17] :a BAR in I/O space
set PCI_BAR_TYPE_MASK u32 [18] :a memory BAR's type field
set PCI_BAR_TYPE_64 u32 [19] :a memory BAR spanning two slots
set PCI_BAR_ADDRESS_MASK u32 [20] :a memory BAR's address bits
set PCI_VENDOR_NONE u16 [21] :the vendor id read where no function answers
set PCI_CAP_VENDOR u8 [22] :a vendor-specific capability, as virtio's are
set PCI_VIRTIO_VENDOR u16 [24] :virtio's vendor id
set PCI_VIRTIO_DEVICE_MODERN u16 [25] :a modern device's id less its virtio device id
set PCI_VIRTIO_DEVICE_TRANSITIONAL u16 [26] :the first transitional device id
set PCI_VIRTIO_DEVICE_TRANSITIONAL_LAST u16 [27] :the last transitional device id
set VIRTIO_PCI_CAP_NEXT u8 [29] :a virtio capability's next pointer
set VIRTIO_PCI_CAP_TYPE u8 [30] :which region the capability names
set VIRTIO_PCI_CAP_BAR u8 [31] :the BAR the region sits in
set VIRTIO_PCI_CAP_OFFSET u32 [32] :the region's offset in its BAR
set VIRTIO_PCI_CAP_LENGTH u32 [33] :the region's length
set VIRTIO_PCI_CAP_NOTIFY_MULTIPLIER u32 [34] :the notify capability's offset multiplier
set VIRTIO_PCI_CAP_COMMON_CFG u8 [35] :the common configuration region
set VIRTIO_PCI_CAP_NOTIFY_CFG u8 [36] :the notification region
set VIRTIO_PCI_CAP_ISR_CFG u8 [37] :the ISR region
set VIRTIO_PCI_CAP_DEVICE_CFG u8 [38] :the device configuration region
set VIRTIO_PCI_COMMON_DEVICE_FEATURE_SELECT u32 [40]
set VIRTIO_PCI_COMMON_DEVICE_FEATURE u32 [41]
set VIRTIO_PCI_COMMON_DRIVER_FEATURE_SELECT u32 [42]
set VIRTIO_PCI_COMMON_DRIVER_FEATURE u32 [43]
set VIRTIO_PCI_COMMON_MSIX_CONFIG u16 [44]
set VIRTIO_PCI_COMMON_NUM_QUEUES u16 [45]
set VIRTIO_PCI_COMMON_STATUS u8 [46]
set VIRTIO_PCI_COMMON_GENERATION u8 [47]
set VIRTIO_PCI_COMMON_QUEUE_SELECT u16 [48]
set VIRTIO_PCI_COMMON_QUEUE_SIZE u16 [49]
set VIRTIO_PCI_COMMON_QUEUE_MSIX_VECTOR u16 [50]
set VIRTIO_PCI_COMMON_QUEUE_ENABLE u16 [51]
set VIRTIO_PCI_COMMON_QUEUE_NOTIFY_OFF u16 [52]
set VIRTIO_PCI_COMMON_QUEUE_DESC_LOW u32 [53]
set VIRTIO_PCI_COMMON_QUEUE_DESC_HIGH u32 [54]
set VIRTIO_PCI_COMMON_QUEUE_DRIVER_LOW u32 [55]
set VIRTIO_PCI_COMMON_QUEUE_DRIVER_HIGH u32 [56]
set VIRTIO_PCI_COMMON_QUEUE_DEVICE_LOW u32 [57]
set VIRTIO_PCI_COMMON_QUEUE_DEVICE_HIGH u32 [58]
set VIRTIO_PCI_ISR_QUEUE u8 [59] :the ISR's used-buffer bit
set PCI_DEV_VENDOR u16 [61] :the kernel's record of a PCI device it has brought up, its vendor id
set PCI_DEV_DEVICE u16 [62]
set PCI_DEV_SLOT u8 [63]
set PCI_DEV_PIN u8 [64] :the INTx pin, 1 for INTA
set PCI_DEV_LINE u8 [65] :the PLIC line the pin lands on
set PCI_DEV_VIRTIO_ID u32 [66] :the virtio device id
set PCI_DEV_COMMON address [67] :the common configuration
set PCI_DEV_NOTIFY address [68] :the notification region
set PCI_DEV_NOTIFY_MULTIPLIER u64 [69] :the notify capability's offset multiplier
set PCI_DEV_ISR address [70] :the ISR region
set PCI_DEV_DEVICE_CFG address [71] :the device configuration
set PCI_DEV_QUEUE_NOTIFY address [72] :where a notify for the queue last set up goes
set PCI_DEV_BARS 6 address [73] :each BAR's base
set PCI_DEV_SIZE u64 [74] :bytes in a record
set PCI_DEV_MAX u64 [75] :the records the kernel keeps
