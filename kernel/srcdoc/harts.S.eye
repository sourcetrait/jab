call harts_topology tree addr > discovered harts_discovered u64,online harts_online u64,failed harts_failed u64,intc harts_intc u32,clobber a0-a7 [17:233] :machine mode, hart 0, after the bss clear: the tree checked, every usable cpu's timebase, its own else /cpus's, held to QEMU_VIRT_TIMEBASE, every usable cpu under /cpus discovered with its interrupt controller's phandle, every problem kept to name, under DEBUG /chosen's bootargs copied; a tree refused or another timer ends the run with its line on the UART and status 1
 intc :JAB_HARTS_MAX entries by hart id, 0 for a cpu with none
call local harts_problem kind u64,id u64 > count harts_problem_count u64,problems harts_problems u64 [235:249] :a topology problem counted, and kept to name while the table has room
call local cpu_usable tree addr,node u32 > usable a0 bool,clobber a1-a5 [251:282] :1 for a cpu whose status is absent or "okay"
call local timebase_of tree addr,node u32 > hz a0 u64,present a1 bool,clobber a2-a5 [284:315] :the node's own timebase-frequency, one cell or two, the high cell first
 hz :0 when absent or of another length
 present :1 when the node has one, of any length
call harts_report > clobber a0-a3 [316:419] :under DEBUG, on the debug channel: the masks, every problem kept, and the bootargs
call knob_value name addr > value a0 u64 [420:475] :under DEBUG, a knob's decimal value from /chosen's bootargs
 name :the knob with its '=', matched at a token's start
 value :-1 when absent or not a run of digits alone
ecall sys_harts > discovered a0 u64,online a1 u64,failed a2 u64 [476:486]
