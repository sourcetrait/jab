ecall sys_random buffer addr,length u64 > status a0 u64,given a1 u64 [9:58] :fills the buffer from the machine's entropy device, bringing it up on the first call
 buffer :ends the run unless the whole of it lies inside the program's window
 status :0, or 1 when there is no rng device or it refused the kernel
 given :the bytes the device wrote, 0 for a length of 0 or with no device
call local random_open > status a0 u64,state random_state u64,base random_base addr,clobber a1-a3 [60:130] :brings the rng device up, its queue set up and its line let through
 status :0, or 1 with no rng device, 2 when the device refuses the kernel, asked again answering as before at once
rodata local msg_rng_at 13 u8 [85:86] :the debug line naming the device's transport, under DEBUG only
rodata local msg_no_rng 13 u8 [113:114] :the debug line for a machine without one, under DEBUG only
bss local random_queue [134:136] :the device's virtqueue record
bss local random_base addr [137:138] :the device's transport
bss local random_state u64 [139:140] :0 until opened, then random_open's answer plus 1
