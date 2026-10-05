call harts_topology tree addr > discovered harts_discovered u64,refused harts_refused u64,intc harts_intc u32,clobber a0-a7 [20:235] :machine mode, hart 0, after the bss clear: the tree checked, every usable cpu's timebase, its own else /cpus's, held to QEMU_VIRT_TIMEBASE, every usable cpu under /cpus discovered with its interrupt controller's phandle, every problem kept to name, under DEBUG /chosen's bootargs copied; a tree refused or another timer ends the run with its line on the UART and status 1
 refused :every discovered hart but 0 when the tree had a problem, each kept parked
 intc :JAB_HARTS_MAX entries by hart id, 0 for a cpu with none
call local harts_problem kind u64,id u64 > count harts_problem_count u64,problems harts_problems u64 [237:251] :a topology problem counted, and kept to name while the table has room
call local cpu_usable tree addr,node u32 > usable a0 bool,clobber a1-a5 [253:284] :1 for a cpu whose status is absent or "okay"
call local timebase_of tree addr,node u32 > hz a0 u64,present a1 bool,clobber a2-a5 [286:316] :the node's own timebase-frequency, one cell or two, the high cell first
 hz :0 when absent or of another length
 present :1 when the node has one, of any length
call hart_record hart u64 > record a0 addr [317:326] :a hart's record, at the top of its kernel stack in hart_areas
call hart_self_check hart u64 > broken a0 bool,id HART_ID u64,result HART_RESULT u64 [327:346] :tp the hart's record: its id written to the record and its canary, HART_CANARY xored with its id, to its stack's bottom, both read back
 broken :1 when either reads back wrong, also the record's result
call hart_swap record addr,from u64,to u64 > moved a0 bool [347:360] :the record's state moved from one value to another by compare and swap, lr and sc
 moved :0 when the state was not from, which it keeps
call harts_masks > online a0 u64,failed a1 u64,released a2 u64 [361:401] :the discovered harts' masks by the states in their records
 released :released and not yet in
call harts_release > clobber a0-a2 [402:539] :supervisor mode, hart 0, after serial_open: each discovered hart refused by the tree or without an interrupt file failed, every other released, its state, its slot, and the wake into its supervisor file, one whose release store faults failed with no file; then the check-in waited for, a hart still released after HART_CHECKIN_TICKS failed; under DEBUG a jab.stray knob of 1 makes a stray store access fault
j hart_main hart u64 [540:596] :a secondary's supervisor entry from hart_park's mret, sp its record: its supervisor setup and self-check, its state swapped from released to online and hart 0 woken, then hart_idle; a hart hart 0 failed first parks for the run touching nothing; under DEBUG a jab.late knob naming it holds it until hart 0 has failed it
 hart :mhartid, as hart_park's mret hands it in a0
call harts_report > clobber a0-a3 [597:772] :under DEBUG, on the debug channel: the masks, every problem kept, the bootargs, and every discovered hart's line, an online hart's id, result, and canary read back
call knob_value name addr > value a0 u64 [773:828] :under DEBUG, a knob's decimal value from /chosen's bootargs
 name :the knob with its '=', matched at a token's start
 value :-1 when absent or not a run of digits alone
ecall sys_harts > discovered a0 u64,online a1 u64,failed a2 u64 [829:836] :the discovered mask and, read from the records, the online and failed
