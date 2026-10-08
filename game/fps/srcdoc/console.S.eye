call local console_read > held console_buf CONSOLE_CAPACITY u8,pending console_pending u32,clobber a0-a5,a7,fa0-fa6 [6:47] :what the host has sent taken in behind what waits, every whole frame done, the rest kept
call local console_frame frame addr > record console_record REPORT_SIZE u8,camera camera 15 f32,sector cam_sector i32,report report_pending u8,forget tile_forget u8,flags tile_pending_flags u64,changed tile_config_changed u8,seed rng u64,end measure_end u8,cadence cadence u32,workers workers_active u32,grain band_grain u32,stall stall_on u8,forced flip_first u8,standing stall_us u32,once stall_once u32,spin consume_spin u32,commands packet_command_cap u32,spans packet_span_cap u32,held job_delay_worker u8,hold job_delay_us u32,cancel job_cancel u8,fault job_fault_worker u8,relit census_stale u8,chunk census_chunk u32,clobber a0-a5,a7,fa0-fa6 [49:248] :a frame done by its kind byte, P placing the camera, T a trace, F a round, N a noise, L the tiles forgotten at the next boundary with construction lifted or frozen, R the generator seeded from bytes 4 to 11, E the measurement closed after this frame's records, C the cadence from this frame's flip on, W the raster's workers and grain from the next drawing on, S the cadence fixture's stalls, K the packet's bounds, J the jobs' hold, cancel, and fault, Q the census's chunk, then reported as REPORT_CONSOLE; an unknown kind only reports
 flags :the L frame's byte 5, CONFIG_FROZEN, else CONFIG_UNLIMITED
 cadence :the C frame's byte 4, a value past CADENCE_COUNT leaving it
 workers :the W frame's byte 4, held to the workers started
 grain :the W frame's bytes 8 to 11, held to the screen's rows
 stall :a debug build's alone, as are forced, standing, once, and spin, the S frame's bytes
 commands :a debug build's alone, as is spans, the K frame's words from byte 4, each 0 for none
 held :a debug build's alone, as are hold, cancel, and fault, the J frame's bytes
 relit :a CENSUS build's alone, as is chunk, set by an L that rewrites the lumels
 chunk :the Q frame's word from byte 4, 0 for the build's bound
call local console_trace > record report_record REPORT_SIZE u8,hit trace_hit TRACE_SIZE u8,clobber a0-a5,a7,fa0-fa6 [250:293] :a trace from the eye along the forward over the trace's range, the geometry and the androids alone, answered as REPORT_TRACE in millimetres
