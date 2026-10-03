set CONSOLE_FRAME [1] :a console frame's bytes
set CONSOLE_CAPACITY [2] :the console buffer's bytes
call local console_read > held console_buf CONSOLE_CAPACITY u8,pending console_pending u32,clobber a0-a5,a7,fa0-fa6 [6:47] :what the host has sent taken in behind what waits, every whole frame done, the rest kept
call local console_frame frame addr > record console_record REPORT_SIZE u8,camera camera 15 f32,sector cam_sector i32,report report_pending u8,budget tile_budget_frame u64,seed rng u64,end measure_end u8,clobber a0-a5,a7,fa0-fa6 [49:140] :a frame done by its kind byte, P placing the camera, T a trace, F a round, N a noise, L the tiles reset, R the generator seeded from bytes 4 to 11, E the measurement closed after this frame's records, then reported as REPORT_CONSOLE; an unknown kind only reports
call local console_trace > record report_record REPORT_SIZE u8,hit trace_hit TRACE_SIZE u8,clobber a0-a5,a7,fa0-fa6 [142:185] :a trace from the eye along the forward over the trace's range, the geometry and the androids alone, answered as REPORT_TRACE in millimetres
rodata local k_thousand_d f64 [189:190] :millimetres a metre
bss local console_buf CONSOLE_CAPACITY u8 [194:195] :the bytes from the host, a partial frame at the front
bss local console_record REPORT_SIZE u8 [196:197] :the console's answer
bss local console_pending u32 [198:199] :the bytes kept
bss local report_pending u8 [200:201] :1 when the next frame is reported on the UART
bss local measure_end u8 [202:203] :set by an E, cleared once the end marker has gone out
