set PAD_RING u64 [6] :the events the pad's ring holds
set PAD_ENTRY_SIZE u64 [7] :bytes in a ring entry, the type at 0, the code at 2, the value at 4
set PAD_KEYS_BITS u64 [8] :the gamepad keys the mask holds from JAB_BTN_GAMEPAD
set BTN_SOUTH_BYTE u64 [9] :the byte of the EV_KEY bitmap holding BTN_SOUTH
set BTN_SOUTH_BIT u64 [10] :its bit there
set ABS_BITMAP_BYTES u64 [11] :bytes of the EV_ABS bitmap kept
set PAD_PORT_MAGIC u32 [12] :`JPAD` as the little-endian word a load sees
set PAD_PORT_VERSION u32 [13] :the header version the kernel takes
set PAD_PORT_HEADER_MAGIC u32 [14] :the port header's fields
set PAD_PORT_HEADER_VERSION u32 [15]
set PAD_PORT_HEADER_NAME u8 [16] :the name, JAB_PAD_NAME_BYTES
set PAD_PORT_HEADER_KEYS u64 [17] :the buttons
set PAD_PORT_HEADER_AXES u64 [18] :the axes the pad has, a bit per code
set PAD_PORT_HEADER_ABSINFO i32 [19] :every axis's absinfo, JAB_PAD_AXIS_ENTRY bytes each
set PAD_PORT_HEADER_BYTES u64 [20] :bytes in the header
set PAD_PORT_EVENT_BYTES u64 [21] :bytes in a port event
set PAD_STREAM_BYTES u64 [22] :the stream buffer, a header and a port buffer besides
set PAD_SOURCE_DEVICE u64 [23] :a pad on a virtio-input device
set PAD_SOURCE_PORT u64 [24] :a pad on the port
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
call pad_open > status a0 u64,state pad_state u64,source pad_source u64,clobber a1-a5 [137:242] :brings the pad up, a virtio-input pad with its queue stocked, its line let through, its ranges and name read, or with none the pad's port with its header taken
 status :0, 1 with no pad, 2 when the device refuses the kernel or the port's header is not one the kernel knows, asked again answering as before at once
rodata local msg_pad_at 13 u8 [161:162] :the debug line naming the pad's transport, under DEBUG only
rodata local msg_no_pad 13 u8 [225:226] :the debug line for a machine without one, under DEBUG only
call local pad_port_open > status a0 u64,clobber a1-a5 [244:322] :takes the pad's port as the pad once its header has arrived whole, the hart halted on the serial device's line meanwhile
 status :0 with the pad open on the port, 1 with no port, 2 with a header that is not the kernel's
rodata local msg_pad_port 18 u8 [300:301] :the debug line for a pad on the port, under DEBUG only
rodata local msg_pad_port_refused 23 u8 [314:315] :the debug line for a header refused, under DEBUG only
call local pad_port_fill > length pad_stream_length u64,clobber a0-a5 [324:340] :takes what the port has delivered into the stream buffer after what it holds, whole port buffers only
call local pad_stream_consume count u64 > length pad_stream_length u64 [342:358] :drops that many bytes from the front of the stream buffer, moving what follows to the front
j local pad_port_drain > clobber a0-a5 [360:387] :takes what the port delivered into the stream, then every whole event in it into the state and the ring
call local pad_queue_setup > refused a0 bool,clobber a2 [389:416] :gives the pad's event queue, queue 0, the pad queue record's rings, PADQ_SIZE entries
 refused :1 when the device offers fewer
call local pad_find > base a0 addr [418:460]
 base :the first virtio-input transport whose EV_KEY bits include BTN_SOUTH and whose EV_ABS bits include ABS_X, 0 when none
call local pad_ranges > bits pad_abs_bits u64,absinfo pad_absinfo,raw pad_raw,clobber a0 [462:526] :reads the axes the pad has from its EV_ABS bitmap and each one's absinfo from the config space, then sets each raw value to rest
call local pad_rest > raw pad_raw,clobber a0 [528:566] :sets every axis the pad has to rest, the middle of its range or its minimum for ABS_GAS and ABS_BRAKE
call local pad_name_read > name pad_name,length pad_name_length u64 [568:595] :reads the device's name from the config space, NUL-terminated, at most JAB_PAD_NAME_BYTES less one
call local pad_axis_present code u64 > present a0 bool [597:607]
call pad_drain > clobber a0-a5 [608:612] :moves every event the pad has delivered, from the device or the port, into the state and the ring
j local pad_input_drain > clobber a0-a2 [614:664] :the device's events out of its used buffers, each buffer handed back once taken
call local pad_accept type u16,code u16,value i32 > keys pad_keys u32,raw pad_raw,head pad_head u64 [666:716] :takes one event into the state and the ring, EV_KEY and EV_ABS only
call pad_pending > pending a0 bool [717:735]
 pending :1 when a pad event waits in the ring or with the device, or bytes wait on the port
call local pad_take > type a0 u16,code a1 u16,value a2 i32,tail pad_tail u64 [737:757]
 type :the oldest event's, all three 0 with the ring empty
call local pad_normalise code u64 > value a0 i16 [759:836]
 value :the axis normalised from its own range to JAB_PAD_FULL either way, 0 for an axis the pad lacks
bss local pad_queue [840:842] :the pad's event queue record
bss local pad_events [843:844] :the device's event buffers, one per descriptor
bss local pad_ring [845:846] :the events for sys_pad_input, PAD_RING entries
bss local pad_head u64 [847:848] :the count of events put in the ring
bss local pad_tail u64 [849:850] :the count taken from it
bss local pad_base addr [851:852] :the pad's transport
bss local pad_state u64 [853:854] :0 until opened, then pad_open's answer plus 1
bss local pad_keys u32 [855:856] :the keys held, a bit each from JAB_BTN_GAMEPAD
bss local pad_abs_bits u64 [857:858] :the axes the pad has, a bit per code
bss local pad_name_length u64 [859:860] :the name's length
bss local pad_name 128 u8 [861:862] :the name, NUL-terminated
bss local pad_source u64 [863:864] :where the pad came from, PAD_SOURCE_DEVICE or PAD_SOURCE_PORT
bss local pad_stream_length u64 [865:867] :the bytes the stream buffer holds
bss local pad_stream 2048 u8 [868:870] :the port's bytes, reassembled
bss local pad_raw 64 i32 [871:872] :each axis's raw value
bss local pad_absinfo [873:874] :each axis's absinfo, JAB_PAD_AXIS_ENTRY bytes apiece
