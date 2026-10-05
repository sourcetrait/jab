call virtio_find id u32 > base a0 addr [8:32]
 base :the first modern transport carrying the device id, 0 when none
call virtio_init base addr > refused a0 bool,clobber a1 [33:34] :resets the device and claims it, offering VIRTIO_F_VERSION_1 and nothing else
 refused :1 when the device refuses the features
call virtio_init_with base addr,features u32 > refused a0 bool [35:58] :virtio_init offering the device's own feature bits beside VIRTIO_F_VERSION_1
 features :the low word of the device's features
 refused :1 when the device refuses the features
call virtio_queue_setup base addr,queue u32,virtqueue addr > refused a0 bool [59:85] :gives the queue the virtqueue record's rings, VIRTQ_SIZE entries, interrupts wanted
 refused :1 when the device offers fewer entries
call virtio_driver_ok base addr [86:91] :the device may now be driven
call virtio_reset source u64 [92:111] :a fault routine's last step: the source's mmio transport reset, its status read back as 0 within VIRTIO_RESET_TICKS of the write's end, else device_reset_refused
j device_reset_refused source u64 [112:117] :its line, naming the source, the hart's fault, the run ended with 1
call virtio_wait_used virtqueue addr,source u64 > stuck a1 bool [118:169] :halts until the virtqueue's used ring moves past what the kernel last saw or its source is masked, draining and reporting before returning
 stuck :1 when its source is masked, whatever the used ring says, a completion in the last drain included
call virtio_request base addr,queue u32,virtqueue addr,request_length u32,request addr,response addr,response_length u32 > stuck a1 bool,last VQ_LAST_USED(virtqueue) u64,clobber a0 [170:207] :runs one request through the queue, returning once the device has used it with the hart halted meanwhile
 request :the bytes the device reads
 response :where the device writes its answer
 last :moved on past the request, unless its source stuck
