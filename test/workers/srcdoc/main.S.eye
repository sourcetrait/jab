j _start [38:43] :the sound stream opened, else `workers: no sound` and exit 2
j local join_with_sound [45:85] :a note held while hart 0 joins a worker held HOLD, then released: `join with sound: start <code>, done <done>, stop <free> <interrupted>`
j local sums [87:132] :two workers summing at once, joined, then stopped: `sums <first> <second>, starts <code> <code>, stop <free> <interrupted>`
j local refusal_codes [134:162] :hart 1 asleep in a worker, then each start in refusals made and its code put after its group's label: `refused hart <codes>, entry <codes>, stack <codes>, overlap <codes>, busy <code>`
j local stop_sleeping [164:180] :hart 1's sleeping worker stopped: `stop sleeping <free> <interrupted>, wait <answer>`
j local stop_spinning [182:204] :a worker that never calls, started on the hart a stopped worker left, then stopped: `stop spinning <free> <interrupted>, start <code>`
j local denied_calls [206:240] :a worker's calls hart 0 keeps, then hart 0's own worker exit: `denied <answers>, worker harts <discovered>, hart 0 exit <answer>`
j local registers [242:298] :twice on hart 1: a worker's registers at its start, then kept across its gate's wait, the wake, a stop's interrupt, and the stop: `registers <run>: entry <changed>, kept <changed>, woke <woken>, stop <free> <interrupted>`
j local pestered [300:343] :a worker waking hart 0 in a tight loop while hart 0 waits once on its word, then awaits TICKS display ticks, then stops it: `pestered: done <done>, woken <0|1>, awaits <ticks>, stop <free> <interrupted>`
j local hart_three [345:387] :a start and a second on hart 3, its stop, and the masks: `hart 3 start <code> then <code>, stop <free> <interrupted>, harts <discovered> <online> <failed>`
j local exit_running [389:400] :two workers spinning, `workers: exit with two running`, then exit 0
j local hold_worker job addr [402:415] :a worker held JOB_N ticks, then its job done and hart 0 woken
j local sum_worker job addr [417:433] :a worker summing 1 to JOB_N into JOB_RESULT, then its job done and hart 0 woken
j local sleep_worker job addr [435:443] :a worker asleep on JOB_DONE, which stays 0, until a stop, the wait's answer into JOB_RESULT
j local spin_forever [445:446] :a worker that never calls
j local denied_worker job addr [448:483] :a worker making each call hart 0 keeps, the answers into JOB_ANSWERS, then jab.sys.harts after them, then its job done
j local regs_worker job addr [485:523] :a worker's registers counted at its start into JOB_ENTRY, set, then counted after its gate's wait, through SPIN_CHUNK spins, and after its stop into JOB_KEPT
j local pester job addr [525:544] :a worker waking hart 0 PESTER_WAKES times, those that found it asleep into JOB_COUNT, then its job done, then on until stopped
call local regs_set [546:560] :every f register, fcsr, vtype at e64 m1, and every v register but v0 given a value of their pattern
call local regs_count job addr > changed a0 u64 [562:594] :the registers no longer as regs_set left them, vl against JOB_VL, v0 its scratch
call local regs_initial > changed a0 u64 [596:621] :the registers not as a start leaves them: f and v 0, fcsr 0, vtype's vill set and vl 0, v0 the scratch
call local join job addr [623:639] :back once the job is done, its results then readable
call local start_raw hart u64,entry addr,stack addr,size u64 > code a0 u64,clobber a1-a4,a7 [641:647] :jab.sys.worker.start with the argument 0, from registers
call local spin ticks u64 [649:655] :busy that many ticks of the time counter
call local field value i64,label addr > clobber a0-a1,s11 [657:666] :the label, then the value in signed decimal, put at the cursor
call local say_str > clobber a0-a1,a7,s11 [668:676] :a whole line printed on the UART
 line :in a1, NUL-terminated
call local say > clobber a0,a7 [678:683] :the line, from its start to the cursor in s11, ended and printed on the UART
call local put_char char u8 > text line u8,clobber s11 [685:688]
 text :the character at the cursor in s11, which moves past it
call local put_str string addr > clobber a1,s11 [690:698]
 string :in a1, NUL-terminated, put at the cursor without its terminator
call local put_signed value i64 > clobber a0,s11 [700:705] :a minus sign for a negative value, then put_dec of its magnitude
call local put_dec value u64 > clobber a0,s11 [706:726] :the value in decimal at the cursor, built backward in digits first
