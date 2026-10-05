ecall sys_keyboard_input > code a0 u16,value a1 u16 [12:25] :the next key event, bringing the keyboard up on the first call
 code :Linux's, 0 with none waiting or no keyboard
 value :0 released, 1 pressed, 2 held
call keyboard_open > status a0 u64,state keyboard_state u64,base keyboard_base addr,clobber a1-a3 [26:114] :brings the keyboard up, its queue stocked and its line let through
 status :0, or 1 with no keyboard on the machine, 2 when the device refuses the kernel or its source stuck; 0 at once when open
call local keyboard_find > base a0 addr [116:151]
 base :the first virtio-input transport whose EV_KEY bits include JAB_KEY_A, 0 when none
call keyboard_drain > head key_head u64,clobber a0 [152:212] :moves every event the device delivered into the ring, EV_KEY events only, and hands the buffers back
 head :on past each key event kept, none kept while the ring is full
call keyboard_pending > pending a0 bool [213:228]
 pending :1 when a key event waits in the ring or with the device
call local keyboard_progress > progress a0 u64 [230:233] :the keyboard's queue's used index
call local keyboard_fault > state keyboard_state u64 [235:239] :its source stuck: 3
call local keyboard_take > code a0 u16,value a1 u16,tail key_tail u64 [241:259]
 code :the oldest key event's, both 0 with the ring empty
