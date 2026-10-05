j _start [49:57] :the API port probed by a write of nothing: with none, the sound stream opened, else `workers: no sound` and exit 2; with the port, select
j local select [59:79] :a scenario's letter over the API within SELECT_WAIT, `r` restart and `s` stop_exit, else `workers: no scenario` and exit 2
j local join_with_sound [81:121] :a note held while hart 0 joins a worker held HOLD, then released: `join with sound: start <code>, done <done>, stop <free> <interrupted>`
j local sums [123:168] :two workers summing at once, joined, then stopped: `sums <first> <second>, starts <code> <code>, stop <free> <interrupted>`
j local refusal_codes [170:198] :hart 1 asleep in a worker, then each start in refusals made and its code put after its group's label: `refused hart <codes>, entry <codes>, stack <codes>, overlap <codes>, busy <code>`
j local stop_sleeping [200:216] :hart 1's sleeping worker stopped: `stop sleeping <free> <interrupted>, wait <answer>`
j local stop_spinning [218:240] :a worker that never calls, started on the hart a stopped worker left, then stopped: `stop spinning <free> <interrupted>, start <code>`
j local denied_calls [242:276] :a worker's calls hart 0 keeps, then hart 0's own worker exit: `denied <answers>, worker harts <discovered>, hart 0 exit <answer>`
j local registers [278:334] :twice on hart 1: a worker's registers at its start, then kept across its gate's wait, the wake, a stop's interrupt, and the stop: `registers <run>: entry <changed>, kept <changed>, woke <woken>, stop <free> <interrupted>`
j local pestered [336:379] :a worker waking hart 0 in a tight loop while hart 0 waits once on its word, then awaits TICKS display ticks, then stops it: `pestered: done <done>, woken <0|1>, awaits <ticks>, stop <free> <interrupted>`
j local hart_three [381:423] :a start and a second on hart 3, its stop, and the masks: `hart 3 start <code> then <code>, stop <free> <interrupted>, harts <discovered> <online> <failed>`
j local exit_running [425:436] :two workers spinning, `workers: exit with two running`, then exit 0
j local restart [438:496] :jab.leavehold=1's: a start on hart 1 inside its first exit's hold, retried within RETRY_WAIT while busy, the worker it started stopped: `restart: held, start saw <seen>, then <code>, stopped <word>`, then exit 0; `restart: never held` when no hold came
j local stop_exit [498:562] :jab.leavehold=1's: a stop of hart 1 inside its first exit's hold, the witness read at once, a start on the hart only when it saw working: `stopexit: held, stop saw working, then <code>` or what else the word holds, then `stopexit: the stop took <ticks> ticks`, then exit 0; `stopexit: never held` when no hold came
j local hold_worker job addr [564:577] :a worker held JOB_N ticks, then its job done and hart 0 woken
j local sum_worker job addr [579:595] :a worker summing 1 to JOB_N into JOB_RESULT, then its job done and hart 0 woken
j local sleep_worker job addr [597:605] :a worker asleep on JOB_DONE, which stays 0, until a stop, the wait's answer into JOB_RESULT
j local spin_forever [607:608] :a worker that never calls
j local denied_worker job addr [610:645] :a worker making each call hart 0 keeps, the answers into JOB_ANSWERS, then jab.sys.harts after them, then its job done
j local regs_worker job addr [647:685] :a worker's registers counted at its start into JOB_ENTRY, set, then counted after its gate's wait, through SPIN_CHUNK spins, and after its stop into JOB_KEPT
j local pester job addr [687:706] :a worker waking hart 0 PESTER_WAKES times, those that found it asleep into JOB_COUNT, then its job done, then on until stopped
j local exit_worker [708:709] :a worker out at once
j local restart_worker job addr [711:723] :a worker setting JOB_DONE and waking hart 0, asleep on JOB_GATE, which never moves, until a stop, then JOB_STOPPED set before its exit
call local regs_set [725:739] :every f register, fcsr, vtype at e64 m1, and every v register but v0 given a value of their pattern
call local regs_count job addr > changed a0 u64 [741:773] :the registers no longer as regs_set left them, vl against JOB_VL, v0 its scratch
call local regs_initial > changed a0 u64 [775:800] :the registers not as a start leaves them: f and v 0, fcsr 0, vtype's vill set and vl 0, v0 the scratch
call local join job addr [802:818] :back once the job is done, its results then readable
call local start_raw hart u64,entry addr,stack addr,size u64 > code a0 u64,clobber a1-a4,a7 [820:826] :jab.sys.worker.start with the argument 0, from registers
call local hold_exit > held a0 u64,clobber s0-s4 [828:854] :hart 1's first worker started on the witness word and out at once, back once the word leaves 0 within HELD_WAIT
 held :1 once the exit holds or has held, 0 never
call local start_saw witness u32,answer u64 > seen a1 addr [856:882] :the word naming what the start saw: busy, idle, disagreed when the witness and the answer differ, expired, nothing, or other
call local spin ticks u64 [884:890] :busy that many ticks of the time counter
call local field value i64,label addr > clobber a0-a1,s11 [892:901] :the label, then the value in signed decimal, put at the cursor
call local say_str > clobber a0-a1,a7,s11 [903:911] :a whole line printed on the UART
 line :in a1, NUL-terminated
call local say > clobber a0,a7 [913:918] :the line, from its start to the cursor in s11, ended and printed on the UART
call local put_char char u8 > text line u8,clobber s11 [920:923]
 text :the character at the cursor in s11, which moves past it
call local put_str string addr > clobber a1,s11 [925:933]
 string :in a1, NUL-terminated, put at the cursor without its terminator
call local put_signed value i64 > clobber a0,s11 [935:940] :a minus sign for a negative value, then put_dec of its magnitude
call local put_dec value u64 > clobber a0,s11 [941:961] :the value in decimal at the cursor, built backward in digits first
