j kmain hart u64 [8:82] :the supervisor entry from _start's mret, bss already cleared and the tree read: the hart's record in tp, the tables built and its paging on, its self-check, the kernel brought up, the secondaries released, and the program entered at JAB_PROGRAM_BASE in user mode, sp at JAB_STACK_TOP, sscratch its record, and every other register 0
ecall sys_kernel_flags > flags a0 u32 [83:93]
 flags :kernel_flags
