call virtio_find id u32 > base a0 address [8:32]
 base :the first modern transport carrying the device id, 0 when none
call virtio_init base address > refused a0 bool,clobber a1 [33:34] :resets the device and claims it, offering VIRTIO_F_VERSION_1 and nothing else
 refused :1 when the device refuses the features
call virtio_init_with base address,features u32 > refused a0 bool [35:58] :virtio_init offering the device's own feature bits beside VIRTIO_F_VERSION_1
 features :the low word of the device's features
 refused :1 when the device refuses the features
call virtio_queue_setup base address,queue u32,virtqueue address > refused a0 bool [59:85] :gives the queue the virtqueue record's rings, VIRTQ_SIZE entries, interrupts wanted
 refused :1 when the device offers fewer entries
call virtio_driver_ok base address [86:91] :the device may now be driven
call virtio_irq_enable base address > clobber a0 [92:100] :lets the transport's line through the PLIC to hart 0's supervisor context
call plic_enable line u64 [101:121] :lets the PLIC line through to hart 0's supervisor context, priority 1 and threshold 0
call plic_service > clobber a0 [122:159] :takes every line the PLIC holds for hart 0's supervisor context, acknowledging what raised it and completing it so the line drops
call virtio_wait_used virtqueue address [160:188] :halts until the virtqueue's used ring moves past what the kernel last saw, the line serviced before returning
call virtio_request base address,queue u32,virtqueue address,request_length u32,request address,response address,response_length u32 > last VQ_LAST_USED(virtqueue) u64,clobber a0 [189:222] :runs one request through the queue, returning once the device has used it with the hart halted meanwhile
 request :the bytes the device reads
 response :where the device writes its answer
 last :moved on past the request
