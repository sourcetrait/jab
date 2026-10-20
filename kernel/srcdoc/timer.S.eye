call frame_clock_init > tick frame_tick u64 [17:23]
 tick :now
call frame_ready > ready a0 bool,stamp a1 u64,tick a2 u64 [24:34]
 ready :1 once the next tick has come
 stamp :the rdtime it read
 tick :the next tick it held that rdtime against
call frame_flipped stamp u64 > tick frame_tick u64,told frame_reported u64,clobber a0-a2,t0-t3 [35:51] :a flip went through now, the clock stepped by frame_next
 stamp :the flip's acceptance, its receipt's own stamp
 tick :one period on, or one period from now once a whole period has gone
 told :0, the tick the program was told of answered
call frame_next tick u64,stamp u64,end u64 > tick a0 u64,clobber t0-t2 [52:73] :the next eligibility after a presented flip by the build's rule: P0's, a period on from the tick while the present ended within one of it, else a period from the end; P2's, a period on while the acceptance is under FRAME_EPS past the tick, else a period from the acceptance
ecall sys_frame_step tick u64,stamp u64,end u64 > status a0 u64,tick a1 u64 [74:90] :under DEBUG, frame_next over the ticks the program gives, nothing presented and the clock untouched
 status :0, or 1 when the acceptance is before the tick, refused as an early flip is
 tick :the rule's next tick, or the tick as it stood with 1
ecall sys_await mask u64 > events a0 u64,tick frame_tick u64,told frame_reported u64 [91:227] :halts until something in the mask has happened, bringing each named device up; a shutdown sends the hart to the boundary
 mask :JAB_AWAIT_* bits, a bit with no device behind it dropped
 events :the bits that fired; 0 when nothing in the mask can happen, at once for 0
 tick :moved past now when told and not yet answered by a flip
 told :1 when the display's bit fired
