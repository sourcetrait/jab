j kmain [7:75] :the supervisor entry from _start's mret, bringing the kernel up and entering the program at JAB_PROGRAM_BASE in user mode, sp at JAB_STACK_TOP and every other register 0
rodata local msg_banner 29 u8 [32:89] :the banner on the debug channel, under DEBUG only
ecall sys_kernel_flags > flags a0 u32 [76:86]
 flags :kernel_flags
set KERNEL_FLAG_DEBUG u32 [83] :the flag JAB_KERNEL_DEBUG when assembled with DEBUG, else 0
rodata kernel_flags u32 [90:91] :the mask of what the kernel was built with
bss local kernel_stack 16384 u8 [95:97] :the kernel's stack
bss kernel_stack_top [98] :the top of the kernel's stack, empty
