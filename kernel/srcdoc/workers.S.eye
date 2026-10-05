j hart_idle [10:24] :a secondary between its workers, on its record's stack with sie SEIE alone: a shutdown parks it, a start enters it, else wfi and the drain
j local worker_enter [26:124] :a start taken by compare and swap and hart 0 woken, the floating-point and vector state reset, then the program entered in user mode at the worker's entry with its argument, its hart id, and its stack; a start hart 0 took back first leaves the hart failed and parked; under DEBUG a jab.noack knob naming the hart holds it until hart 0 has taken the start back
j worker_leave [125:153] :the worker out of the program for good, by its exit or a forced stop: the kernel stack's canary checked, the hart idle with release ordering, its live bit cleared, hart 0 woken, then hart_idle; a canary overwritten ends the run with its line
ecall sys_worker_exit > denied a0 u64 [154:159] :a worker's end, by worker_leave
 denied :JAB_DENIED, on hart 0
call hart_wake hart u64 > clobber a0 [160:173] :the wake's identity into the hart's supervisor file after fence w, o, so every store before it lands first; nothing for a hart with no file
ecall sys_worker_wake mask u64 > woken a0 u64 [174:201] :wakes every hart in the mask asleep in jab.sys.worker.wait, after fence rw, rw
ecall sys_worker_wait word addr,value u32 > answer a0 u64 [202:257] :sleeps while the word holds the value, draining on each wake and on hart 0 reporting; a shutdown sends the hart to the boundary
 word :inside the program's window on 4 bytes, the run ended otherwise
 answer :JAB_WAIT_CHANGED once the word differs, JAB_WAIT_STOP once a stop is asked of the worker, checked first
ecall sys_worker_start hart u64,entry addr,argument u64,stack addr,size u64 > code a0 u64 [258:390] :hart 0's: a worker started on an online idle secondary, returning once the hart has taken the start
 code :JAB_START_*, every refusal decided before anything is written; JAB_START_NO_ACK when the hart missed WORK_START_TICKS, failed for the run
call local stop_pending harts u64 > running a0 u64 [392:419] :those of the harts whose worker is not idle, read before fence r, rw
ecall sys_worker_stop mask u64 > free a0 u64,interrupted a1 u64 [420:511] :hart 0's: the mask's workers asked to stop, interrupted past WORK_STOP_TICKS, and the run ended with one still in past WORK_FORCE_TICKS more
 free :every online secondary in the mask, none running a worker now
 interrupted :those stopped where they were
call shutdown_enter > owner shutdown_owner u64,unanswered shutdown_unanswered u64,clobber a0 [512:610] :the run's end claimed for the hart, every other online hart woken and waited for to halt within SHUTDOWN_TICKS; behind another hart's claim the hart parks; under DEBUG a jab.claimhold knob holds a won claim that many ms before the wakes
 unanswered :the harts that did not halt in the bound
j shutdown_park > halted HART_WORK u64 [611:618] :a hart stopped for another's shutdown: its interrupts off, its state halted after fence rw, w, then wfi for good
