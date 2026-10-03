call frame_clock_init: -> tick frame_tick u64
 tick now
call frame_ready: -> ready a0 bool
 ready 1 once the next tick has come
call frame_flipped: -> tick frame_tick u64,told frame_reported u64
 A flip went through now
 tick one period on, or one period from now once a whole period has gone
 told 0, the tick the program was told of answered
ecall sys_await: mask a0 u64 -> events a0 u64,tick frame_tick u64,told frame_reported u64
 Halts until something in the mask has happened, bringing each named device up
 mask JAB_AWAIT_* bits, a bit with no device behind it dropped
 events the bits that fired; 0 when nothing in the mask can happen, at once for 0
 tick moved past now when told and not yet answered by a flip
 told 1 when the display's bit fired
