j _start [5:12] :calls the kernel with sp inside the kernel, at zero, and past the end of RAM, then exits with 3
rodata local msg_kernel 32 u8 [15:16] :the line printed with sp inside the kernel
rodata local msg_zero 22 u8 [17:18] :the line printed with sp at zero
rodata local msg_past 34 u8 [19:20] :the line printed with sp past the end of RAM
