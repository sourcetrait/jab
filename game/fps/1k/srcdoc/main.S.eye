j _start > disk s0 u64 [49:142] :the program, the map loaded and held to its format, the title drawn, then the frame loop
 disk :the program's disk, held for the whole run and read by the loaders
j local frame before s7 u64,count s8 u64 > seconds frame_seconds f32,game game_us u32,drawing frame_us u32,clock frame_clock 16 u64 [143:257] :a frame and every frame after, never returning; at its start the frame before's records over the API
 before :the frame before's time
 count :the frames drawn
j local no_display [259:261] :exits 1, the machine having no display
j local no_sound [263:265] :exits 2, the machine having no sound device
j local no_disk [267:269] :exits 3, no disk carrying serial fps
j local no_name [271:273] :exits 4, the disk having no /map/name
j local no_map [275:280] :exits 5, the map not on the disk
j local bad_magic [282:287] :exits 6, the file not a Jab FPS map
j local short_file [289:299] :exits 7, the file ending before its structures do
j local map_too_big [301:310] :exits 7, the map not fitting its buffer
j local too_many word a1 addr [312:322] :exits 8, the map holding more of a kind than this build does
 word :the kind's word, NUL-terminated
j local path_too_long material u32 [324:334] :exits 9, a material's name too long for a path
j local load_failed material u32,code u64 [336:349] :exits 10, a material's texture failing to load
 code :a JAB_PNG_* or a LOAD_*
j local check_failed word a1 addr,index a2 u32,what a3 addr [351:365] :exits 11, a record breaking a rule of the format
 word :the record's word, NUL-terminated
 what :what is wrong with it, NUL-terminated
j local map_lacks lack a1 addr [367:373] :exits 11, the map lacking something it must hold
 lack :the lack, NUL-terminated
j local bad_directory how a1 addr [375:383] :exits 12, the section directory broken
 how :how it is broken, NUL-terminated
call local line_map > cursor a0 addr,text line u8,clobber a1 [385:393] :begins the UART line with the prefix and the map's path
call local line_end cursor addr > clobber a0,a7 [395:400] :ends the line at the cursor with a newline and prints it on the UART
call local frame_records end u64,frame u32 > records clock_records 192 u8,marker end_record REPORT_SIZE u8,closed measure_end u8,clobber a0-a1,a7 [402:543] :the frame's three records over the API, its clock, its drawing, and its presentation, then the end marker when an E closed the measurement on it
 end :the tick its await ended, the next frame's start
 frame :its number, from 0
call local load_report ms s5 u64 > clobber a0-a1,a7 [544:610] :a debug build's load line on the UART, the counts of what loaded
 ms :the load's milliseconds
call local frame_report ticks s10 u64 > clobber a0-a1,a7 [612:750] :a debug build's frame line on the UART, the counts, the ticks by phase, the spans and pixels, the light, the rejected pixels, the samples, and the tiles
 ticks :the frame's drawing ticks
call local count_report > clobber a0-a1,a7 [751:799] :a COUNT build's count line on the UART after the frame line: the divides span_fill made and avoided, the blocks shifted and short, the negative steps off sixteen in u and v, the flat spans, and the mismatches
call local sectors_report > clobber a0-a1,a7 [801:830] :a debug build's sectors line on the UART, the last frame's walk in order
call local sector_at index u32 > record a0 addr [832:837]
call local loop_at index u32 > record a0 addr [839:844]
call local wall_at index u32 > record a0 addr [846:851]
call local vertex_at index u32 > record a0 addr [853:858]
call local portal_at index u32 > record a0 addr [860:865]
call local entity_at index u32 > record a0 addr [867:872]
call local material_at index u32 > record a0 addr [874:879]
call local name_at offset u32 > name a0 addr [881:884] :a name in the names table
call local clear_screen > screen JAB_DISPLAY_BASE u32,clobber a0 [886:887] :the framebuffer black
call local fill_screen colour u32 > screen JAB_DISPLAY_BASE u32 [888:899] :the framebuffer one colour
call local read_file buffer addr,capacity u64,disk u64,path addr > bytes a0 u64,contents 0(buffer) u8,clobber a1-a4,a7 [901:953] :a file off a disk read whole, a page at a time, as much as the buffer holds
 path :the path from the root, NUL-terminated
 bytes :the bytes read, 0 when the file is not there
call local str_len string addr > length a1 u64 [955:964]
 string :NUL-terminated, kept in a0
call local append_str cursor addr,string addr > cursor a0 addr,text 0(cursor) u8,clobber a1 [966:975] :appends a string at the cursor
 string :NUL-terminated
call local append_dec cursor addr,value u64 > cursor a0 addr,digits 0(cursor) u8,clobber a1 [977:996] :appends a number in decimal at the cursor
