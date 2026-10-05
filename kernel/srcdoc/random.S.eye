ecall sys_random buffer addr,length u64 > status a0 u64,given a1 u64 [9:61] :fills the buffer from the machine's entropy device, bringing it up on the first call
 buffer :ends the run unless the whole of it lies inside the program's window
 status :0, or 1 when there is no rng device, it refused the kernel, or its source stuck
 given :the bytes the device wrote, 0 for a length of 0 or with no device
call local random_open > status a0 u64,state random_state u64,base random_base addr,clobber a1-a3 [63:135] :brings the rng device up, its queue set up and its line let through
 status :0, or 1 with no rng device, 2 when the device refuses the kernel, asked again answering as before at once
call local random_progress > progress a0 u64 [137:140] :the rng's queue's used index
call local random_fault > state random_state u64 [142:146] :its source stuck: 3, every call refused
