call vpci_init record addr > refused a0 bool,clobber a1 [10:11] :resets the device and claims it, offering VIRTIO_F_VERSION_1 and nothing else
 record :the device's PCI_DEV_* record
 refused :1 when the device refuses the features
call vpci_init_with record addr,features u32 > refused a0 bool [12:47] :vpci_init offering the device's own feature bits beside VIRTIO_F_VERSION_1
 features :the low word of the device's features
 refused :1 when the device refuses the features, has no common configuration, or reads back no reset within VIRTIO_RESET_TICKS
call vpci_queue_setup record addr,queue u16,virtqueue addr > refused a0 bool,notify PCI_DEV_QUEUE_NOTIFY(record) addr [48:81] :gives the queue the virtqueue record's rings, VIRTQ_SIZE entries, enabled
 refused :1 when the device offers fewer entries
 notify :where a notify for this queue goes
call vpci_driver_ok record addr [82:88] :the device may now be driven
call vpci_notify record addr,queue u16 [89:94] :tells the device the queue set up last has new buffers
call vpci_reset record addr [95:110] :a fault routine's reset of the device: status 0 to its common configuration, read back as 0 within VIRTIO_RESET_TICKS of the write's end, else device_reset_refused with its line; nothing for a device with no common configuration
