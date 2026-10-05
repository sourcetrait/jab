ecall sys_pad_read record addr > status a0 u64,record 0(record) [29:67] :writes the pad's state into a JAB_PAD_ENTRY record, the keys held and every axis normalised, bringing the pad up on the first call
 record :ends the run unless the whole of it lies inside the program's window
 status :0, or 1 with no pad
ecall sys_pad_input > type a0 u16,code a1 u16,value a2 i32 [68:83] :the oldest waiting pad event in evdev's terms, bringing the pad up on the first call
 type :JAB_EV_KEY or JAB_EV_ABS, 0 with none waiting or no pad
 value :signed, raw as the pad sent it
ecall sys_pad_axis buffer addr,code u64 > status a0 u64 [84:114] :writes the pad's absinfo for the axis into a JAB_PAD_AXIS_ENTRY record, as virtio reported it
 buffer :ends the run unless the whole record lies inside the program's window
 status :0, 1 with no pad, 2 when the pad has no such axis
ecall sys_pad_name buffer addr > status a0 u64,length a1 u64 [115:136] :writes the pad's name, NUL-terminated, into a buffer of JAB_PAD_NAME_BYTES
 buffer :ends the run unless the whole of it lies inside the program's window
 status :0, or 1 with no pad
 length :0 with no pad
call pad_open > status a0 u64,state pad_state u64,source pad_source u64,clobber a1-a5 [137:244] :brings the pad up, a virtio-input pad with its queue stocked, its line let through, its ranges and name read, or with none the pad's port with its header taken
 status :0, 1 with no pad, 2 when the device refuses the kernel, the port's header is not one the kernel knows, or the pad's source failed, asked again answering as before at once
call local pad_port_open > status a0 u64,clobber a1-a5 [246:327] :takes the pad's port as the pad once its header has arrived whole, the hart halted on the serial device's line meanwhile, refused once that line is masked
 status :0 with the pad open on the port, 1 with no port, 2 with a header that is not the kernel's or a stuck port
call local pad_port_fill > length pad_stream_length u64,clobber a0-a5 [329:345] :takes what the port has delivered into the stream buffer after what it holds, whole port buffers only
call local pad_stream_consume count u64 > length pad_stream_length u64 [347:363] :drops that many bytes from the front of the stream buffer, moving what follows to the front
j local pad_port_drain > clobber a0-a5 [365:392] :takes what the port delivered into the stream, then every whole event in it into the state and the ring
call local pad_queue_setup > refused a0 bool,clobber a2 [394:421] :gives the pad's event queue, queue 0, the pad queue record's rings, PADQ_SIZE entries
 refused :1 when the device offers fewer
call local pad_find > base a0 addr [423:465]
 base :the first virtio-input transport whose EV_KEY bits include BTN_SOUTH and whose EV_ABS bits include ABS_X, 0 when none
call local pad_ranges > bits pad_abs_bits u64,absinfo pad_absinfo,raw pad_raw,clobber a0 [467:531] :reads the axes the pad has from its EV_ABS bitmap and each one's absinfo from the config space, then sets each raw value to rest
call local pad_rest > raw pad_raw,clobber a0 [533:571] :sets every axis the pad has to rest, the middle of its range or its minimum for ABS_GAS and ABS_BRAKE
call local pad_name_read > name pad_name,length pad_name_length u64 [573:600] :reads the device's name from the config space, NUL-terminated, at most JAB_PAD_NAME_BYTES less one
call local pad_axis_present code u64 > present a0 bool [602:612]
call pad_drain > clobber a0-a5 [613:617] :moves every event the pad has delivered, from the device or the port, into the state and the ring
j local pad_input_drain > clobber a0-a2 [619:669] :the device's events out of its used buffers, each buffer handed back once taken
call local pad_accept type u16,code u16,value i32 > keys pad_keys u32,raw pad_raw,head pad_head u64 [671:719] :takes one event into the state and the ring, EV_KEY and EV_ABS only
call local pad_progress > progress a0 u64 [721:724] :the pad's queue's used index
call local pad_fault > state pad_state u64 [726:732] :its source stuck: 3, the device reset (virtio_reset)
j pad_port_fault source u64 > state pad_state u64 [733:747] :serial_fault's tail, the serial device's source in a0: a pad open on the port goes to 3 with it, then the serial device reset (virtio_reset)
call pad_pending > pending a0 bool [748:766]
 pending :1 when a pad event waits in the ring or with the device, or bytes wait on the port
call local pad_take > type a0 u16,code a1 u16,value a2 i32,tail pad_tail u64 [768:788]
 type :the oldest event's, all three 0 with the ring empty
call local pad_normalise code u64 > value a0 i16 [790:867]
 value :the axis normalised from its own range to JAB_PAD_FULL either way, 0 for an axis the pad lacks
