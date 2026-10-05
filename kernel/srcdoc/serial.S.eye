call serial_open > status a0 u64,state serial_state u64,ports serial_ports u64,base serial_base addr,clobber a1-a3 [25:198] :brings the virtio-serial device up with each known port the device names opened
 status :0, 1 with no virtio-serial device, 2 when the device refuses the kernel or its source fails while it comes up, the state then 3, asked again answering as before at once
call local serial_stock virtqueue addr,buffers addr,size u32 > clobber a1 [200:220] :makes every descriptor of the receive queue a buffer of that many bytes the device may write, all offered at once
call local serial_control_send event u16,port u32,value u16 > abandoned a0 bool,clobber a1-a3 [222:236] :sends the device a control message, returning once it has taken it or its source is masked
 abandoned :serial_send's
call local serial_control_drain > abandoned a0 bool,ports serial_ports u64,clobber a1-a3 [238:308] :takes every control message the device delivered, answering for each known port it adds, until an answer is abandoned
 abandoned :1 when an answer was, the messages after it left
call serial_send virtqueue addr,queue u32,bytes addr,length u32 > abandoned a0 bool,last VQ_LAST_USED(virtqueue) u64,clobber a1 [309:357] :gives the device the bytes through the queue, the hart halted until it has taken them or its source is masked, the bytes then abandoned
 abandoned :1 when its source was masked, how many of the bytes the host took unknown
call serial_source > source a0 u64 [358:361] :the console's interrupt source
call local serial_progress > progress a0 u64 [363:386] :every queue's used index summed
call local serial_fault > state serial_state u64 [388:394] :its source stuck: 3, every port down, a pad on its port failed with it and the device reset (pad_port_fault)
call api_up > up a0 bool [395:409]
 up :1 when the API's port came up with the device
ecall sys_api_write buffer addr,length u64 > status a0 u64 [410:435] :sends the bytes to the host over the API, returning once the device has taken them
 buffer :ends the run unless the whole of it lies inside the program's window
 status :0, 1 with no API port, 2 when its source failed during the send, a prefix of the bytes perhaps at the host; the calls after it answering 1
ecall sys_api_read buffer addr,capacity u64 > read a0 u64,waiting a1 u64 [436:476] :the bytes the host has sent, oldest first, at most the capacity; never waits
 buffer :ends the run unless the whole of it lies inside the program's window
 read :0 with none waiting or no API port
 waiting :the bytes still waiting, in the ring and with the device
call local api_drain > head api_head u64,clobber a0-a3 [478:540] :moves every buffer the device has filled into the ring, whole buffers while it has room, and hands each back
call local api_waiting > waiting a0 u64 [542:566]
 waiting :the bytes in the ring and in buffers the device filled that the ring had no room for
call api_pending > pending a0 bool [567:592]
 pending :1 when bytes wait for the program, what sys_await tests for JAB_AWAIT_API
call pad_port_up > up a0 bool [593:607]
 up :1 when the pad's port came up with the device
call serial_pad_read buffer addr,capacity u64 > copied a0 u64,clobber a2-a5 [608:665] :copies what the host delivered on the pad's port, whole buffers only and in order, each handed back as it is taken
call serial_pad_pending > pending a0 bool [666:676]
 pending :1 when the pad's port holds bytes serial_pad_read has not taken
call serial_report > clobber a0-a3 [677:699] :under DEBUG, the serial device's transport on the debug channel, nothing with no device
call debug_putc char u8 > clobber a0-a3 [700:714] :adds the character to the debug line, sending the line at a newline or when full; under DEBUG only
call debug_flush > clobber a0-a3 [715:762] :sends the debug line to the debug port, or to the UART when that port is not up, a line the port abandons dropped; under DEBUG only
call debug_puts string addr > clobber a0-a3 [763:780]
 string :NUL-terminated
call debug_put_hex value u64 > clobber a0-a3 [781:813] :writes 0x and sixteen hex digits to the debug line
call debug_put_dec value u64 > clobber a0-a3 [814:840] :writes in decimal to the debug line
