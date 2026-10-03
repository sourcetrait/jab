call vpci_init record address > refused a0 bool,clobber a1 [10:11] :resets the device and claims it, offering VIRTIO_F_VERSION_1 and nothing else
 record :the device's PCI_DEV_* record
 refused :1 when the device refuses the features
call vpci_init_with record address,features u32 > refused a0 bool [12:39] :vpci_init offering the device's own feature bits beside VIRTIO_F_VERSION_1
 features :the low word of the device's features
 refused :1 when the device refuses the features
call vpci_queue_setup record address,queue u16,virtqueue address > refused a0 bool,notify PCI_DEV_QUEUE_NOTIFY(record) address [40:73] :gives the queue the virtqueue record's rings, VIRTQ_SIZE entries, enabled
 refused :1 when the device offers fewer entries
 notify :where a notify for this queue goes
call vpci_driver_ok record address [74:80] :the device may now be driven
call vpci_notify record address,queue u16 [81:84] :tells the device the queue set up last has new buffers
