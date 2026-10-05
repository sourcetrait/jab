j _start hart u64,tree addr > stack sp addr [6:48] :every hart's reset entry: hart 0 sets up machine mode, clears bss, reads the device tree, and mrets into kmain as supervisor, every other hart parking
 hart :mhartid, as QEMU's reset vector hands it in a0
 tree :the device tree QEMU's reset vector hands every hart in a1
 stack :kernel_stack_top, the stack the bootstrap and kmain run on
j local park [50:54] :a hart other than 0 waits here for good
j local mtrap [55:70] :the machine-mode trap vector: a trap not delegated prints its line on the UART and halts
