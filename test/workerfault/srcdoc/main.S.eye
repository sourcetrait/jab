j _start [11:38] :waits SELECT_WAIT for the scenario's letter over the API and runs its scenario; with none, `workerfault: no scenario` and exit 2
j local store [40:48] :a worker's store into the kernel, hart 0 then in forever
j local two [50:66] :two workers through one gate, each storing into the kernel at an address of its own, hart 0 then in forever
j local joined [68:79] :a worker storing into the kernel LATE in, while hart 0 joins it in jab.sys.worker.wait on a word nobody sets
j local address [81:89] :a worker's wait on a word outside the window, hart 0 then in forever
j local printing [91:121] :the sound stream live, a worker through the gate storing into the kernel while hart 0 prints LONG_BYTES on one line; the line after it is never printed
j local forever [123:125] :hart 0 awaits more bytes over the API, which never come
j local refused [127:130] :a start refused: `workerfault: a start refused` and exit 3
j local store_worker [132:136] :a worker's store at KERNEL
j local gated_worker argument u64 [138:149] :a worker through the gate at go, then a store at KERNEL plus eight times its argument's low four bits
j local late_worker [151:161] :a worker busy LATE ticks, then a store at KERNEL
j local wait_worker [163:169] :a worker's jab.sys.worker.wait on KERNEL
call local start_one hart u64,entry addr,argument u64 > code a0 u64,clobber a3-a4,a7 [171:180] :jab.sys.worker.start on the hart's own stack in stacks
call local echo > clobber a0-a1,a7,s3 [182:194] :`workerfault: scenario <name>` on the UART
 name :in a1, NUL-terminated
call local say_str > clobber a0-a1,a7,s3 [196:204] :a whole line printed on the UART
 line :in a1, NUL-terminated
call local say > clobber a0,a7 [206:211] :the line, from its start to the cursor in s3, ended and printed on the UART
call local put_str string addr > clobber a1,s3 [213:221]
 string :in a1, NUL-terminated, put at the cursor without its terminator
