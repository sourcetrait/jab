j _start [5:10] :prints before, stores into the kernel's memory at 0x80000000, and would print after and exit with 0
rodata local before 25 u8 [13:14] :the line printed before the store
rodata local after 24 u8 [15:16] :the line that must never print
