call ram_banks tree addr,table addr,capacity u64 > code a0 u64,banks a1 u64 [27:189] :the root's memory nodes' reg entries as banks, a base and an end each, into the table sorted by base, held to the RAM rules
 tree :checked by dtb_check
 code :RAM_OK, or the first fault met: RAM_CELLS, RAM_REG, RAM_EMPTY, RAM_OVERFLOW, RAM_LOW, RAM_HIGH, RAM_TOO_MANY, then RAM_NO_BANK or RAM_OVERLAP
 banks :those read, every one with RAM_OK
call local ram_cells cells addr,count u64 > value a0 u64 [191:202] :a value of one or two big-endian cells, the high one first
call ram_backed table addr,count u64,base u64,end u64 > backed a0 bool [203:221] :whether one bank holds the whole range
call ram_free table addr,count u64,free addr,capacity u64,reserved u64 > ranges a0 u64 [222:251] :each bank less RAM's base to the reservations' end, what lies past it a free range into free, at most capacity
 reserved :the reservations' end
call ram_topology tree addr > banks ram_bank_table u8,count ram_bank_count u64,installed ram_installed u64,free ram_free_table u8,ranges ram_free_count u64,clobber a0-a4 [252:338] :machine mode, from _start: the banks read and held, the kernel, the framebuffer, and the program's window each proved backed, and the free view built; a refusal ends the boot with its line and 1
call ram_report > clobber a0-a3 [339:373] :under DEBUG, a line a free range on the debug channel, `jab: ram free <base>-<end>`, or `jab: ram free none`
