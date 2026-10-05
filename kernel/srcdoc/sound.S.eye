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
call sound_open > status a0 u64,state sound_state u64,live sound_live u64,clobber a1-a6 [92:244] :brings the sound device up with its stream set to the one format, started, and every period mixed and offered
 status :0, 1 with no sound device, 2 when the device refuses the kernel or a request, asked again answering as before at once
call local sound_queue_setup > refused a0 bool,clobber a2 [246:274] :gives the tx queue the sound queue record's rings, SNDQ_SIZE entries
 refused :1 when the device offers fewer
call local sound_control_simple code u32 > failed a0 bool,clobber a1-a6 [276:282] :runs a request that takes only the stream
 failed :0 when the device said OK, else 1, its source stuck included
call local sound_control length u32 > failed a0 bool,clobber a1-a6 [284:311] :runs the request of that many bytes in sound_request through the control queue, the hart halted until the device answers
 failed :0 when the device said OK, else 1, its source stuck included
call sound_service > clobber a0 [312:357] :keeps the stream running, every period the device returned mixed afresh and offered again, the file player stepped a period first; nothing until the stream is live
call local sound_mix samples addr > clobber a0-a7 [359:426] :fills a period's samples from the ring's frames and the synthesizer's voices, clipped to the sample range
 samples :where the period's samples go
call local sound_submit period u64 > busy sound_busy u8,submitted sound_submitted u64 [428:452] :offers the period, full, to the device
call local sound_drain > returned sound_returned u64,failed sound_failed u64,last sound_last_return u64 [454:496] :frees every period the device has returned, reading each one's status
call sound_stalled > stalled a0 bool,live sound_live u64,state sound_state u64 [497:535]
 stalled :1 when the live stream has a period in flight and no return for SOUND_STALL_TICKS, the stream then dead with a line on the UART
call sound_tick [536:569] :a checkpoint for a long loop inside a call, draining the interrupts when the device has returned a period; keeps every register, t ones included
call local sound_wait > clobber a0 [571:591] :halts until the device's line or the poll timer, then drains the interrupts and reports
call sound_flush > live sound_live u64,clobber a0-a3 [592:699] :plays the stream out for a program's exit; nothing with no live stream, and done once it dies
call local sound_progress > progress a0 u64 [701:707] :the control and transmit queues' used indexes summed
call local sound_fault > live sound_live u64,state sound_state u64 [709:717] :its source stuck: the stream dead, as sound_stalled leaves it
call sound_pending > room a0 bool [718:727]
 room :1 when the ring has room for a period, so a write can take more
