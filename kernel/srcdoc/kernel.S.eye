j kmain [7:77] :the supervisor entry from _start's mret, bringing the kernel up and entering the program at JAB_PROGRAM_BASE in user mode, sp at JAB_STACK_TOP and every other register 0
rodata local msg_banner 29 u8 [34:91] :the banner on the debug channel, under DEBUG only
ecall sys_kernel_flags > flags a0 u32 [78:88]
 flags :kernel_flags
set KERNEL_FLAG_DEBUG u32 [85] :the flag JAB_KERNEL_DEBUG when assembled with DEBUG, else 0
rodata kernel_flags u32 [92:93] :the mask of what the kernel was built with
bss local kernel_stack 16384 u8 [97:99] :the kernel's stack
bss kernel_stack_top [100] :the top of the kernel's stack, empty
