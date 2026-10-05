j _start hart u64,tree addr > stack sp addr [8:56] :every hart's reset entry: each sets up machine mode; hart 0 then clears bss, reads the device tree and the interrupt platform, sets up the root domain, and mrets into kmain as supervisor; every other hart parks
 hart :mhartid, as QEMU's reset vector hands it in a0
 tree :the device tree QEMU's reset vector hands every hart in a1
 stack :hart 0's record, the top of its stack in hart_areas, which the bootstrap and kmain run on
j local hart_park hart u64 [58:84] :machine mode, no stack: the hart's supervisor file opened for the wake, then asleep until its release slot holds its record, the wake claimed; then its paging on and an mret into hart_main on its own stack; a hart at or past JAB_HARTS_MAX parks for good
 hart :mhartid, in t0
j local mtrap [85:102] :the machine-mode trap vector: a trap not delegated prints its line on the UART under the line lock and ends the run with 1
