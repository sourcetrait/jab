call serial_open > status a0 u64,state serial_state u64,ports serial_ports u64,base serial_base addr,clobber a1-a3 [25:177] :brings the virtio-serial device up with each known port the device names opened
 status :0, 1 with no virtio-serial device, 2 when the device refuses the kernel, asked again answering as before at once
call local serial_stock virtqueue addr,buffers addr,size u32 > clobber a1 [179:199] :makes every descriptor of the receive queue a buffer of that many bytes the device may write, all offered at once
call local serial_control_send event u16,port u32,value u16 > clobber a0-a3 [201:215] :sends the device a control message, returning once it has taken it
call local serial_control_drain > ports serial_ports u64,clobber a0-a3 [217:284] :takes every control message the device delivered, answering for each known port it adds
call serial_send virtqueue addr,queue u32,bytes addr,length u32 > last VQ_LAST_USED(virtqueue) u64 [285:320] :gives the device the bytes through the queue, the hart halted until it has taken them or its source is masked, the bytes then abandoned
call serial_source > source a0 u64 [321:324] :the console's interrupt source
call local serial_progress > progress a0 u64 [326:349] :every queue's used index summed
call local serial_fault > state serial_state u64 [351:357] :its source stuck: 3, every port down
call api_up > up a0 bool [358:372]
 up :1 when the API's port came up with the device
ecall sys_api_write buffer addr,length u64 > status a0 u64 [373:393] :sends the bytes to the host over the API, returning once the device has taken them
 buffer :ends the run unless the whole of it lies inside the program's window
 status :0, or 1 with no API port
ecall sys_api_read buffer addr,capacity u64 > read a0 u64,waiting a1 u64 [394:434] :the bytes the host has sent, oldest first, at most the capacity; never waits
 buffer :ends the run unless the whole of it lies inside the program's window
 read :0 with none waiting or no API port
 waiting :the bytes still waiting, in the ring and with the device
call local api_drain > head api_head u64,clobber a0-a3 [436:498] :moves every buffer the device has filled into the ring, whole buffers while it has room, and hands each back
call local api_waiting > waiting a0 u64 [500:524]
 waiting :the bytes in the ring and in buffers the device filled that the ring had no room for
call api_pending > pending a0 bool [525:550]
 pending :1 when bytes wait for the program, what sys_await tests for JAB_AWAIT_API
call pad_port_up > up a0 bool [551:565]
 up :1 when the pad's port came up with the device
call serial_pad_read buffer addr,capacity u64 > copied a0 u64,clobber a2-a5 [566:623] :copies what the host delivered on the pad's port, whole buffers only and in order, each handed back as it is taken
call serial_pad_pending > pending a0 bool [624:634]
 pending :1 when the pad's port holds bytes serial_pad_read has not taken
call debug_putc char u8 > clobber a0-a3 [635:649] :adds the character to the debug line, sending the line at a newline or when full; under DEBUG only
call debug_flush > clobber a0-a3 [650:697] :sends the debug line to the debug port, or to the UART when that port is not up; under DEBUG only
call debug_puts string addr > clobber a0-a3 [698:715]
 string :NUL-terminated
call debug_put_hex value u64 > clobber a0-a3 [716:748] :writes 0x and sixteen hex digits to the debug line
call debug_put_dec value u64 > clobber a0-a3 [749:775] :writes in decimal to the debug line
