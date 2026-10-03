set SERIAL_API_PORT u32 [6] :the API's port
set SERIAL_API_RX_QUEUE u32 [7] :its receive queue
set SERIAL_API_TX_QUEUE u32 [8] :its transmit queue
set API_BUFFER_BYTES u64 [9] :bytes in a buffer offered for the API's receive queue
set API_RING_BYTES u64 [10] :bytes the API's ring holds, as much as the buffers do
set SERIAL_CONTROL_BYTES u64 [11] :a control message buffer, a port's name included
set SERIAL_PAD_PORT u32 [12] :the pad's port, jab.pad
set SERIAL_PAD_RX_QUEUE u32 [13] :its receive queue
set SERIAL_PAD_TX_QUEUE u32 [14] :its transmit queue
set PAD_PORT_BUFFER_BYTES u64 [15] :bytes in a buffer offered for the pad's receive queue
set SERIAL_DEBUG_PORT u32 [17] :the debug channel's port, under DEBUG only
set SERIAL_DEBUG_TX_QUEUE u32 [18] :its transmit queue
set DEBUG_LINE_BYTES u64 [19] :the longest debug line gathered before it goes out
call serial_open > status a0 u64,state serial_state u64,ports serial_ports u64,base serial_base addr,clobber a1-a3 [25:175] :brings the virtio-serial device up with each known port the device names opened
 status :0, 1 with no virtio-serial device, 2 when the device refuses the kernel, asked again answering as before at once
call local serial_stock virtqueue addr,buffers addr,size u32 > clobber a1 [177:197] :makes every descriptor of the receive queue a buffer of that many bytes the device may write, all offered at once
call local serial_control_send event u16,port u32,value u16 > clobber a0-a3 [199:213] :sends the device a control message, returning once it has taken it
call local serial_control_drain > ports serial_ports u64,clobber a0-a3 [215:282] :takes every control message the device delivered, answering for each known port it adds
call serial_send virtqueue addr,queue u32,bytes addr,length u32 > last VQ_LAST_USED(virtqueue) u64 [283:312] :gives the device the bytes through the queue, the hart halted until it has taken them
call api_up > up a0 bool [313:327]
 up :1 when the API's port came up with the device
ecall sys_api_write buffer addr,length u64 > status a0 u64 [328:348] :sends the bytes to the host over the API, returning once the device has taken them
 buffer :ends the run unless the whole of it lies inside the program's window
 status :0, or 1 with no API port
ecall sys_api_read buffer addr,capacity u64 > read a0 u64,waiting a1 u64 [349:389] :the bytes the host has sent, oldest first, at most the capacity; never waits
 buffer :ends the run unless the whole of it lies inside the program's window
 read :0 with none waiting or no API port
 waiting :the bytes still waiting, in the ring and with the device
call local api_drain > head api_head u64,clobber a0-a3 [391:453] :moves every buffer the device has filled into the ring, whole buffers while it has room, and hands each back
call local api_waiting > waiting a0 u64 [455:479]
 waiting :the bytes in the ring and in buffers the device filled that the ring had no room for
call api_pending > pending a0 bool [480:505]
 pending :1 when bytes wait for the program, what sys_await tests for JAB_AWAIT_API
call pad_port_up > up a0 bool [506:520]
 up :1 when the pad's port came up with the device
call serial_pad_read buffer addr,capacity u64 > copied a0 u64,clobber a2-a5 [521:578] :copies what the host delivered on the pad's port, whole buffers only and in order, each handed back as it is taken
call serial_pad_pending > pending a0 bool [579:589]
 pending :1 when the pad's port holds bytes serial_pad_read has not taken
call debug_putc char u8 > clobber a0-a3 [590:604] :adds the character to the debug line, sending the line at a newline or when full; under DEBUG only
call debug_flush > clobber a0-a3 [605:650] :sends the debug line to the debug port, or to the UART when that port is not up; under DEBUG only
call debug_puts string addr > clobber a0-a3 [651:668]
 string :NUL-terminated
call debug_put_hex value u64 > clobber a0-a3 [669:701] :writes 0x and sixteen hex digits to the debug line
call debug_put_dec value u64 > clobber a0-a3 [702:728] :writes in decimal to the debug line
bss local serial_control_rx_queue [732:734] :the control receive queue's record
bss local serial_control_tx_queue [735:737] :the control transmit queue's record
bss local serial_api_rx_queue [738:740] :the API's receive queue record
bss local serial_api_tx_queue [741:744] :the API's transmit queue record
bss serial_pad_rx_queue [745:747] :the pad's receive queue record
bss local serial_pad_tx_queue [748:751] :the pad's transmit queue record
bss local serial_debug_tx_queue [752:754] :the debug channel's transmit queue record, under DEBUG only
bss local debug_line 256 u8 [755:756] :the debug line gathering
bss local debug_length u64 [757:760] :its bytes so far
bss local serial_api_buffers 2048 u8 [761:762] :the API's receive buffers
bss local serial_pad_buffers 2048 u8 [763:764] :the pad's receive buffers
bss local api_ring 2048 u8 [765:766] :the bytes from the host the program has not read
bss local api_head u64 [767:768] :the count of bytes put in the ring
bss local api_tail u64 [769:770] :the count taken from it
bss local serial_control_buffers 512 u8 [771:772] :the control receive buffers
bss local serial_control_message 8 u8 [773:774] :a control message the kernel sends
bss local serial_base addr [775:776] :the device's transport
bss local serial_state u64 [777:778] :0 until opened, then serial_open's answer plus 1
bss local serial_ports u64 [779:780] :a bit per port the device named and the kernel answered for
