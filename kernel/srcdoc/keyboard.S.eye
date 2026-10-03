set KEYBOARD_RING u64 [6] :the key events the kernel's ring holds
set KEYBOARD_ENTRY_SIZE u64 [7] :bytes in a ring entry, the code at 0 and the value at 2
ecall sys_keyboard_input > code a0 u16,value a1 u16 [12:25] :the next key event, bringing the keyboard up on the first call
 code :Linux's, 0 with none waiting or no keyboard
 value :0 released, 1 pressed, 2 held
call keyboard_open > status a0 u64,state keyboard_state u64,base keyboard_base addr,clobber a1-a3 [26:112] :brings the keyboard up, its queue stocked and its line let through
 status :0, or 1 with no keyboard on the machine, 2 when the device refuses the kernel; 0 at once when open
rodata local msg_keyboard_at 18 u8 [50:51] :the debug line naming the keyboard's transport, under DEBUG only
rodata local msg_no_keyboard 18 u8 [101:102] :the debug line for a machine without one, under DEBUG only
call local keyboard_find > base a0 addr [114:149]
 base :the first virtio-input transport whose EV_KEY bits include JAB_KEY_A, 0 when none
call keyboard_drain > head key_head u64,clobber a0 [150:210] :moves every event the device delivered into the ring, EV_KEY events only, and hands the buffers back
 head :on past each key event kept, none kept while the ring is full
call keyboard_pending > pending a0 bool [211:226]
 pending :1 when a key event waits in the ring or with the device
call local keyboard_take > code a0 u16,value a1 u16,tail key_tail u64 [228:246]
 code :the oldest key event's, both 0 with the ring empty
bss local keyboard_queue [250:252] :the keyboard's virtqueue record
bss local keyboard_events [253:254] :the device's event buffers, one per descriptor
bss local key_ring [255:256] :the kernel's ring of key events, KEYBOARD_RING entries
bss local key_head u64 [257:258] :the count of key events put in the ring
bss local key_tail u64 [259:260] :the count of key events taken from it
bss local keyboard_base addr [261:262] :the keyboard's transport
bss local keyboard_state u64 [263:264] :1 once open
