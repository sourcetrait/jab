set SOUND_STREAM u32 [6] :the playback stream's id
set PERIOD_BYTES u64 [7] :a period's samples in bytes
set PERIOD_STRIDE u64 [8] :a period's transfer, the stream id then the samples
set RING_MASK u64 [9] :an index's place in the ring
set ACCUM_BYTES u64 [10] :the mixer's accumulator, two 32-bit samples a frame
set SOUND_STALL_TICKS u64 [11] :how long a backend with periods in flight may return nothing before it has stopped
set SOUND_POLL_TICKS u64 [12] :how often a wait on the stream alone wakes to look for a stall
set SOUND_DRAIN_PERIODS u64 [13] :the periods of silence the exit plays past the last with content
set SOUND_FLUSH_TICKS u64 [14] :the longest the exit waits for the ring and the voices to end
ecall sys_sound_open > status a0 u64 [19:24]
 status :sound_open's
ecall sys_sound_write buffer addr,frames u64 > status a0 u64,taken a1 u64 [25:68] :queues frames from the buffer into the ring, as many as it has room for, opening the device on the first call
 buffer :ends the run unless the frames taken lie inside the program's window
 status :0, or sound_open's code
 taken :0 unless the status is 0
ecall sys_sound_ready > status a0 u64,room a1 u64 [69:79]
 status :0, or sound_open's code
 room :the frames a write would take now
call local sound_room > room a0 u64 [81:91]
 room :the frames the ring has room for
call sound_open > status a0 u64,state sound_state u64,live sound_live u64,clobber a1-a6 [92:242] :brings the sound device up with its stream set to the one format, started, and every period mixed and offered
 status :0, 1 with no sound device, 2 when the device refuses the kernel or a request, asked again answering as before at once
rodata local msg_sound_at 15 u8 [117:118] :the debug line naming the device's transport, under DEBUG only
rodata local msg_no_sound 15 u8 [217:218] :the debug line for a machine without one, under DEBUG only
rodata local msg_sound_refused 20 u8 [231:232] :the debug line for a device that refused, under DEBUG only
call local sound_queue_setup > refused a0 bool,clobber a2 [244:272] :gives the tx queue the sound queue record's rings, SNDQ_SIZE entries
 refused :1 when the device offers fewer
call local sound_control_simple code u32 > failed a0 bool,clobber a1-a6 [274:280] :runs a request that takes only the stream
 failed :0 when the device said OK, else 1
call local sound_control length u32 > failed a0 bool,clobber a1-a6 [282:307] :runs the request of that many bytes in sound_request through the control queue, the hart halted until the device answers
 failed :0 when the device said OK, else 1
call sound_service > clobber a0 [308:353] :keeps the stream running, every period the device returned mixed afresh and offered again, the file player stepped a period first; nothing until the stream is live
call local sound_mix samples addr > clobber a0-a7 [355:422] :fills a period's samples from the ring's frames and the synthesizer's voices, clipped to the sample range
 samples :where the period's samples go
call local sound_submit period u64 > busy sound_busy u8,submitted sound_submitted u64 [424:448] :offers the period, full, to the device
call local sound_drain > returned sound_returned u64,failed sound_failed u64,last sound_last_return u64 [450:492] :frees every period the device has returned, reading each one's status
call sound_stalled > stalled a0 bool,live sound_live u64,state sound_state u64 [493:531]
 stalled :1 when the live stream has a period in flight and no return for SOUND_STALL_TICKS, the stream then dead with a line on the UART
call sound_tick [532:565] :a checkpoint for a long loop inside a call, servicing the PLIC when the device has returned a period; keeps every register, t ones included
call local sound_wait > clobber a0 [567:586] :halts until the device's line or the poll timer, then services the PLIC
call sound_flush > live sound_live u64,clobber a0-a3 [587:690] :plays the stream out for a program's exit; nothing with no live stream
rodata local msg_sound_counts 22 u8 [677:678] :the debug line on the stream's counts, under DEBUG only
rodata local msg_sound_returned 11 u8 [679:680] :that line's returned field
rodata local msg_sound_failed 9 u8 [681:682] :that line's failed field
call sound_pending > room a0 bool [691:700]
 room :1 when the ring has room for a period, so a write can take more
bss local sound_control_queue [704:706] :the control queue's record
bss local sound_queue [707:709] :the tx queue's record
bss local sound_periods [710:711] :the periods, each the stream id then its samples, PERIOD_STRIDE apart
bss local sound_status [712:713] :each period's status record, written by the device
bss local sound_request 24 u8 [714:715] :a control request
bss local sound_response u32 [716:718] :its status
bss sound_base addr [719:720] :the device's transport
bss local sound_state u64 [721:723] :0 until opened, then sound_open's answer plus 1
bss sound_live u64 [724:725] :1 while the stream runs
bss local sound_head u64 [726:727] :the count of frames put in the ring
bss local sound_tail u64 [728:730] :the count taken from it
bss local sound_ring 16384 i16 [731:732] :the frames queued, left then right
bss local sound_accum 1920 i32 [733:734] :the mixer's accumulator
bss local sound_busy 8 u8 [735:737] :1 for each period in flight
bss local sound_submitted u64 [738:739] :the periods offered
bss local sound_returned u64 [740:741] :the periods returned
bss local sound_failed u64 [742:743] :the returns whose status was not OK
bss local sound_last_return u64 [744:745] :the time of the last return
rodata local msg_sound_stalled 20 u8 [748:749] :the line a stalled stream ends with on the UART
