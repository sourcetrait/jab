call pci_scan > devices pci_devices,count pci_count u64,clobber a0-a2 [9:51] :walks bus 0 once for virtio devices and brings each up into a record, later calls doing nothing
call pci_config function u64 > config a0 addr [52:56]
 function :a device and function on bus 0, the device in bits 3 to 7 and the function in bits 0 to 2
 config :its configuration space
call local pci_bring_up function u64 > count pci_count u64,base pci_next_base addr,clobber a0-a2 [58:129] :fills the next record: ids, slot, pin and line, BARs assigned, decoding and mastering on, the virtio capabilities read
call local pci_assign_bar config addr,record addr,bar u64 > slots a0 u64,base pci_next_base addr [131:183] :sizes the BAR and gives it the window's next base aligned to its size, written and kept in the record's PCI_DEV_BARS
 slots :the BAR slots it took, two for a 64-bit BAR, one for an I/O BAR or an absent one, left alone
call local pci_capabilities config addr,record addr > common PCI_DEV_COMMON(record) addr,notify PCI_DEV_NOTIFY(record) addr,multiplier PCI_DEV_NOTIFY_MULTIPLIER(record) u64,isr PCI_DEV_ISR(record) addr,device PCI_DEV_DEVICE_CFG(record) addr [185:229] :each virtio capability's region kept by type as its BAR's base plus its offset
call pci_count_of > count a0 u64 [230:235]
 count :the virtio devices the scan found
call pci_device index u64 > record a0 addr [236:243]
call pci_service_line line u64 [244:260] :reads the ISR of every device on the PLIC line, which drops the level
