macro start_worker entry label > answer a0 u64,scratch t0-t4,a1-a5,a7 [33:44] :jab.sys.worker.start of a0's hart on its own stack, a1 the argument, a2 the owner through the sixth operand
j _start [48:55] :the online secondaries: `harts <online>`
j local reserve [57:86] :JAB_RESERVED_GFX_HARTS reserved, its answer, grant, and the reservation's harts, exit 1 if refused; then s0 the grant, s8 its count, s1 the feature's harts, s2 the grant left, s4 the admission: `reserve <code> <grant> owned <harts>`
j local startup [88:129] :the check line; admitted, the feature's claim, its id in s3, a second claim of a hart of the grant left, graphics on the grant left, then feature_run: `startup claim <code> id <id> owned <harts> left <harts>`, `startup second <code> left <harts>`, `startup graphics <harts> refused <harts>`
j local startup_refused [131:154] :the kernel's claim of the feature's harts, graphics on the whole grant, four frames
j local transition [156:216] :the check line; admitted, the held frame published, the claim inside its band, the hold released and the frame joined, then the harts' stop, a claim under a fresh id in s3, graphics refused on its harts, then feature_run: `transition busy <code> left <harts>`, `transition stop <harts> interrupted <harts> hold <word>`, `transition claim <code> id <id> owned <harts> left <harts>`, `transition owner <harts>`
j local transition_refused [218:229] :the kernel's claim of a hart its graphics worker runs on, four frames on the whole grant
j local finish [231:249] :every graphics worker stopped, the frames sent, exit 0: `end stop <harts> interrupted <harts> frames <count>`
j local stop_run [251:252] :exit 1, every line after it unsaid
call local feature_run > clobber a0-a5,a7,s5-s7,s11 [254:338] :the feature on s1's harts under the claim s3: started, four frames on the grant left beside it, its release refused busy, its result joined, its harts stopped, released, the stale id's start and release refused, graphics back, four frames on the whole grant: `feature start <code>`, `feature release <code>`, `feature stop <harts> interrupted <harts>`, `feature released <code> <harts> left <harts>`, `feature stale <code> <code>`, `feature return <harts>`
call local check_line word addr > clobber a0-a1,a7,s11 [340:359] :the word, then the grant's count s8, the feature's harts s1, and the admission s4: `<word><count> want <harts> admit <admitted>`
call local claim_line word addr,answer i64,id u64 > clobber a0-a2,a7,s11 [361:398] :the word, then a claim's answer, its id, the id's harts, and the reservation's: `<word><code> id <id> owned <harts> left <harts>`
call local top_harts harts u64,count u64 > highest a0 u64,clobber a1 [400:416] :the count highest harts of the mask, every one of them when it holds fewer
call local start_graphics harts u64 > refused a0 u64,owned a1 u64,clobber a2-a5,a7 [418:456] :a graphics worker started on each hart under the reservation; the harts refused, and those refused for their owner
call local gfx_start hart u64 > answer a0 u64,clobber a1-a5,a7 [458:464] :the hart's graphics worker under the reservation, its mailbox the argument
call local feature_start harts u64 > answer a0 u64,clobber a1-a5,a7 [466:504] :each hart's feature record cleared and a feature worker started on it under the claim s3; the first refusal's answer, else 0
call local stale_start hart u64,owner u64 > answer a0 u64,clobber a1-a5,a7 [506:510] :a worker that leaves at once, started on the hart under the owner
call local feature_join harts u64 > clobber a0-a1,a7,s11 [512:558] :each hart's feature record waited on until marked, then the hart that made each result and the result: `feature result <hart> <hex>...`
call local frames graphics u64,feature u64,count u64 > clobber a0-a2,a7 [560:584] :that many frames published to the graphics harts and joined, each recording the feature's harts
call local frame_publish graphics u64,feature u64,held u64 > clobber a0-a1,a7 [586:643] :the frame's rows cleared, a job to each graphics worker with its index, their count, and the hold for the hart held, 0 for none, then the workers woken
call local frame_join > clobber a0-a1,a7 [645:707] :each worker of the frame joined, then the frame's record sent over the API and frame_next counted on
call local hold_wait > clobber a0-a1,a7 [709:722] :back once hold_word leaves HOLD_IDLE
call local release_hold [724:734] :hold_word from HOLD_HELD to HOLD_RELEASED by compare-and-swap, an expiry left standing
j local gfx_worker mailbox addr,hart u64 [736:780] :a graphics worker: each job's bands of rows, dealt by index, each row's word and renderer written, a held job's first band held after its first row, until a stop
call local hold_band > clobber a0,a7 [782:811] :held inside a band: HOLD_HELD written and hart 0 woken, then until hart 0 releases it or HOLD_TICKS pass, when HOLD_EXPIRED is set by compare-and-swap
call local row_word frame u64,row u64 > word a0 u64 [813:827] :an xorshift64 run of ROW_STEPS from the frame's number and the row's, plus one
j local feature_worker record addr,hart u64 [829:854] :the feature's bounded work, an xorshift64 run of FEATURE_STEPS from FEATURE_SEED, its result and hart kept and its record marked, hart 0 woken, then on its hart until a stop
j local exit_worker [856:857] :a worker out at once
call local field value i64,label addr > cursor s11 addr,clobber a0-a1 [859:868] :the label then the value, signed, put at the line's cursor
call local hex_field value u64,label addr > cursor s11 addr,clobber a0-a1 [870:879] :the label then the value as sixteen hex digits, put at the cursor
call local say > clobber a0,a7 [881:886] :the line ended at the cursor and printed on the UART
call local put_str > cursor s11 addr,clobber a1 [888:896] :the NUL-terminated string at a1 put at the cursor
call local put_signed value i64 > cursor s11 addr,clobber a0 [898:903] :the value in decimal, a minus before a negative, put at the cursor
call local put_dec value u64 > cursor s11 addr,clobber a0 [904:924] :the value in decimal put at the cursor
call local put_hex value u64 > cursor s11 addr [926:942] :the value as sixteen lowercase hex digits put at the cursor
