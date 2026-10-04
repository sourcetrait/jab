j _start > disk s0 u64 [50:146] :the program, the map loaded and held to its format, the title drawn, then the frame loop
 disk :the program's disk, held for the whole run and read by the loaders
j local frame before s7 u64,count s8 u64 > seconds frame_seconds f32,game game_us u32,drawing frame_us u32,clock frame_clock 17 u64,reported tick_reported u8 [147:270] :a frame and every frame after, never returning; at its start the frame before's records over the API; presented under the cadence in force, awaiting the display's tick or the pad after the reporting under cadence 0 alone
 before :the frame before's time
 count :the frames drawn
j local no_display [272:274] :exits 1, the machine having no display
j local no_sound [276:278] :exits 2, the machine having no sound device
j local no_disk [280:282] :exits 3, no disk carrying serial fps
j local no_name [284:286] :exits 4, the disk having no /map/name
j local no_map [288:293] :exits 5, the map not on the disk
j local bad_magic [295:300] :exits 6, the file not a Jab FPS map
j local short_file [302:312] :exits 7, the file ending before its structures do
j local map_too_big [314:323] :exits 7, the map not fitting its buffer
j local too_many word a1 addr [325:335] :exits 8, the map holding more of a kind than this build does
 word :the kind's word, NUL-terminated
j local path_too_long material u32 [337:347] :exits 9, a material's name too long for a path
j local load_failed material u32,code u64 [349:362] :exits 10, a material's texture failing to load
 code :a JAB_PNG_* or a LOAD_*
j local check_failed word a1 addr,index a2 u32,what a3 addr [364:378] :exits 11, a record breaking a rule of the format
 word :the record's word, NUL-terminated
 what :what is wrong with it, NUL-terminated
j local map_lacks lack a1 addr [380:386] :exits 11, the map lacking something it must hold
 lack :the lack, NUL-terminated
j local bad_directory how a1 addr [388:396] :exits 12, the section directory broken
 how :how it is broken, NUL-terminated
call local line_map > cursor a0 addr,text line u8,clobber a1 [398:406] :begins the UART line with the prefix and the map's path
call local line_end cursor addr > clobber a0,a7 [408:413] :ends the line at the cursor with a newline and prints it on the UART
call local frame_records end u64,frame u32 > records clock_records 192 u8,marker end_record REPORT_SIZE u8,closed measure_end u8,clobber a0-a1,a7 [415:554] :the frame's three records over the API, its clock, its drawing, and its presentation, then the end marker when an E closed the measurement on it
 end :the tick its await ended, the next frame's start
 frame :its number, from 0
call local flip_attempt > status a0 u64,end a1 u64,clock frame_clock 17 u64,reported tick_reported u8,clobber a7 [556:581] :one jab.sys.display.flip, its call's ticks added to the frame's flip, its status and end kept, counted, a refusal when answered as early; a presented flip ends the reported tick
 status :jab.sys.display.flip's code
 end :the tick the call returned
call local pacing_step start u64,cadence u32 > end a0 u64,clock frame_clock 17 u64,reported tick_reported u8,latched pad_latched u32,clobber a1-a2,a7 [583:629] :cadences 1 and 2: the frame flipped once presenting it is no longer early, the display's tick or the pad awaited meanwhile, a wake on the pad alone consumed and the wait taken again, a refusal waited out and the flip tried again; under 2 a frame ready after its tick waits for the next
 start :the step's first tick, the mix's end
 end :the step's last tick; the step less its awaits and its flips is the pacing
call local pacing_await > events a0 u64,clock frame_clock 17 u64,reported tick_reported u8,latched pad_latched u32,clobber a1-a2,a7 [631:655] :one of the pacing step's awaits, the display's tick or the pad, its ticks added to the wait; a display wake reports the tick, a wake on the pad alone is consumed
 events :jab.sys.await's bits
call local pad_consume > latched pad_latched u32,clock frame_clock 17 u64,clobber a0-a2,a7 [657:699] :a wake on the pad in the pacing step counted and every event the pad has delivered taken, each gamepad press latched for camera_look and counted; on a debug build an S's spin after
call local draw_or_stall > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,stats stats 22 u64,clobber a0-a7,fa0-fa7 [700:736] :on a debug build, world_draw unless an S stands a stall or set this frame's own, which zeroes the drawing's statistics as world_draw does and spins on rdtime for its microseconds
call local load_report ms s5 u64 > clobber a0-a1,a7 [737:803] :a debug build's load line on the UART, the counts of what loaded
 ms :the load's milliseconds
call local frame_report ticks s10 u64 > clobber a0-a1,a7 [805:943] :a debug build's frame line on the UART, the counts, the ticks by phase, the spans and pixels, the light, the rejected pixels, the samples, and the tiles
 ticks :the frame's drawing ticks
call local count_report > clobber a0-a1,a7 [944:992] :a COUNT build's count line on the UART after the frame line: the divides span_fill made and avoided, the blocks shifted and short, the negative steps off sixteen in u and v, the flat spans, and the mismatches
call local sectors_report > clobber a0-a1,a7 [994:1023] :a debug build's sectors line on the UART, the last frame's walk in order
call local sector_at index u32 > record a0 addr [1025:1030]
call local loop_at index u32 > record a0 addr [1032:1037]
call local wall_at index u32 > record a0 addr [1039:1044]
call local vertex_at index u32 > record a0 addr [1046:1051]
call local portal_at index u32 > record a0 addr [1053:1058]
call local entity_at index u32 > record a0 addr [1060:1065]
call local material_at index u32 > record a0 addr [1067:1072]
call local name_at offset u32 > name a0 addr [1074:1077] :a name in the names table
call local clear_screen > screen JAB_DISPLAY_BASE u32,clobber a0 [1079:1080] :the framebuffer black
call local fill_screen colour u32 > screen JAB_DISPLAY_BASE u32 [1081:1092] :the framebuffer one colour
call local read_file buffer addr,capacity u64,disk u64,path addr > bytes a0 u64,contents 0(buffer) u8,clobber a1-a4,a7 [1094:1146] :a file off a disk read whole, a page at a time, as much as the buffer holds
 path :the path from the root, NUL-terminated
 bytes :the bytes read, 0 when the file is not there
call local str_len string addr > length a1 u64 [1148:1157]
 string :NUL-terminated, kept in a0
call local append_str cursor addr,string addr > cursor a0 addr,text 0(cursor) u8,clobber a1 [1159:1168] :appends a string at the cursor
 string :NUL-terminated
call local append_dec cursor addr,value u64 > cursor a0 addr,digits 0(cursor) u8,clobber a1 [1170:1189] :appends a number in decimal at the cursor
