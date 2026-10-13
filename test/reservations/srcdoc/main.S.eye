j _start [17:36] :the online secondaries, the lowest, and the highest with its bit kept: `harts <online> <lowest> <highest>`
j local legacy [38:76] :before a reservation: a3 across jab.sys.harts, the unowned harts, a raw start with a5 at A5_SENTINEL, and the five-operand form with a5 as its size: `legacy a3 <a3> owned <harts> start <code> size <code>`
j local refused [78:113] :a reservation past the secondaries, a worker started, a reservation beside it, then a claim with no reservation: `refused short <code> <grant> start <code> busy <code> unreserved <code>`
j local reserve [115:152] :the floor, one short of the secondaries, reserved, the grant's and the unowned masks, then a second reservation: `reserve <floor> <code> <grant> owned <grant> <unowned> again <code>`
j local owner [154:184] :after the reservation: a raw start with a5 at A5_SENTINEL, the five-operand form with a5 left at it, and the reservation named: `owner sentinel <code> five <code> reserved <code>`
j local claim_refused [186:227] :claims of an empty mask, hart 0, a hart past the machine, the highest while its worker runs, and the whole grant: `claim refused empty <code> main <code> past <code> busy <code> floor <code> start <code>`
j local claim [229:263] :the highest claimed, its id's harts and the grant's, it claimed again, and the lowest: `claim <code> id <id> owned <harts> <grant> again <code> second <code>`
j local cross [265:323] :each owner's start on the other's hart; a worker of each at once, the claim's through the macro's sixth operand from a1; a start on the claim's busy hart under the reservation; the claim's release: `cross <code> <code> both <code> <code> order <code> release busy <code>`
j local returned [325:356] :the claim released, the grant, then its id's release and a start under it: `returned <code> <harts> owned <grant> stale <code> <code>`
j local reclaim [358:394] :the highest claimed again, the old id's start and release, the grant, and a third claim of it: `reclaim <code> id <id> stale <code> <code> owned <grant> again <code>`
j local released [396:415] :the new claim released, then no owner and the reservation: `released <code> none <code> reserved <code>`
j local denied [417:448] :a worker's four ownership calls and their answers, then exit 0: `denied start <code> answers <answers>`
call local start_on hart u64,entry addr,argument u64,owner u64 > code a0 u64,clobber a3-a5,a7 [450:461] :jab.sys.worker.start on the hart's own stack, the owner in a5
call local stack_of hart u64 > stack a0 addr [463:469] :the hart's own STACK_BYTES in stacks
call local stop_mask harts u64 > clobber a0-a1,a7 [471:473] :back once each of the harts is free of its worker
call local join job addr > clobber a0-a1,a7 [475:491] :back once the job's worker has marked it done, its answers then readable
j local exit_worker [493:494] :a worker out at once
j local sleep_worker job addr [496:501] :a worker asleep on its job's word, which stays 0, until a stop
j local denied_worker job addr [503:526] :a worker making the four ownership calls, each answer into its job, then its job done and hart 0 woken
call local field value i64,label addr > cursor s11 addr,clobber a0-a1 [528:537] :the label then the value, signed, put at the line's cursor
call local say > clobber a0,a7 [539:544] :the line ended at the cursor and printed on the UART
call local put_str > cursor s11 addr,clobber a1 [546:554] :the NUL-terminated string at a1 put at the cursor
call local put_signed value i64 > cursor s11 addr,clobber a0 [556:561] :the value in decimal, a minus before a negative, put at the cursor
call local put_dec value u64 > cursor s11 addr,clobber a0 [562:582] :the value in decimal put at the cursor
