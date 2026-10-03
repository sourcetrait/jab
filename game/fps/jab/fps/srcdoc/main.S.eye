set MAP_BYTES [8] :the map buffer's bytes
set FILE_BYTES [9] :the file buffer's bytes, a texture file at most
set PIXEL_BYTES [10] :the pixel arena's bytes, the textures' records
set AMBIENT_BYTES [11] :the ambient arena's bytes
set FONT_BYTES [12] :the soundfont buffer's bytes
set PAGE_BYTES [13] :the most read_file reads a call
set NAME_BYTES [14] :the map name's buffer
set PATH_BYTES [15] :a path's buffer
set LINE_BYTES [16] :a UART line's buffer
set DIGITS_BYTES [17] :append_dec's scratch
set TITLE_SCALE [18] :the title's scale, four times the console's cell
set TITLE_CELL [19] :a title cell's width in pixels
set TITLE_HEIGHT [20] :the title's height in pixels
set TITLE_Y [21] :the title's top row, centred
set TITLE_COLOR u32 [22] :the title's colour
set MS_TICKS [23] :the time ticks a millisecond
set US_TICKS [24] :the time ticks a microsecond
set LOAD_TOO_BIG u64 [25] :a texture's file larger than its buffer, beyond the kernel's PNG codes
set LOAD_ARENA_FULL u64 [26] :a texture's record not fitting the pixel arena
set CLOCK_ORIGIN u64 [27] :frame_clock's tick of the program's start
set CLOCK_START u64 [28] :the frame's start, the tick its await ended
set CLOCK_REPORT u64 [29] :the frame's reporting in ticks, the frame before's records and its own state's
set CLOCK_HUD u64 [30] :the crosshair's ticks
set CLOCK_MIX u64 [31] :mixer_update's ticks
set CLOCK_FLIP u64 [32] :the flip call's ticks
set CLOCK_FLIP_DONE u64 [33] :the tick the flip returned
set CLOCK_AWAIT u64 [34] :the tick the reporting ended and the await began
set CLOCK_FLIP_STATUS u64 [35] :the flip's status, jab.sys.display.flip's code
set CLOCK_SIZE [36] :frame_clock's bytes
j _start > disk s0 u64 [40:133] :the program, the map loaded and held to its format, the title drawn, then the frame loop
 disk :the program's disk, held for the whole run and read by the loaders
j local frame before s7 u64,count s8 u64 > seconds frame_seconds f32,game game_us u32,drawing frame_us u32,clock frame_clock 9 u64 [134:223] :a frame and every frame after, never returning; at its start the frame before's records over the API
 before :the frame before's time
 count :the frames drawn
j local no_display [225:227] :exits 1, the machine having no display
j local no_sound [229:231] :exits 2, the machine having no sound device
j local no_disk [233:235] :exits 3, no disk carrying serial fps
j local no_name [237:239] :exits 4, the disk having no /map/name
j local no_map [241:246] :exits 5, the map not on the disk
j local bad_magic [248:253] :exits 6, the file not a Jab FPS map
j local short_file [255:265] :exits 7, the file ending before its structures do
j local map_too_big [267:276] :exits 7, the map not fitting its buffer
j local too_many word a1 addr [278:288] :exits 8, the map holding more of a kind than this build does
 word :the kind's word, NUL-terminated
j local path_too_long material u32 [290:300] :exits 9, a material's name too long for a path
j local load_failed material u32,code u64 [302:315] :exits 10, a material's texture failing to load
 code :a JAB_PNG_* or a LOAD_*
j local check_failed word a1 addr,index a2 u32,what a3 addr [317:331] :exits 11, a record breaking a rule of the format
 word :the record's word, NUL-terminated
 what :what is wrong with it, NUL-terminated
j local map_lacks lack a1 addr [333:339] :exits 11, the map lacking something it must hold
 lack :the lack, NUL-terminated
j local bad_directory how a1 addr [341:349] :exits 12, the section directory broken
 how :how it is broken, NUL-terminated
call local line_map > cursor a0 addr,text line u8,clobber a1 [351:359] :begins the UART line with the prefix and the map's path
call local line_end cursor addr > clobber a0,a7 [361:366] :ends the line at the cursor with a newline and prints it on the UART
call local frame_records end u64,frame u32 > records record_pair 128 u8,marker end_record REPORT_SIZE u8,closed measure_end u8,clobber a0-a1,a7 [368:476] :the frame's two records over the API, its clock and its drawing, then the end marker when an E closed the measurement on it
 end :the tick its await ended, the next frame's start
 frame :its number, from 0
call local load_report ms s5 u64 > clobber a0-a1,a7 [477:543] :a debug build's load line on the UART, the counts of what loaded
 ms :the load's milliseconds
call local frame_report ticks s10 u64 > clobber a0-a1,a7 [545:681] :a debug build's frame line on the UART, the counts, the ticks by phase, the spans and pixels, the light, the rejected pixels, the samples, and the tiles
 ticks :the frame's drawing ticks
call local sectors_report > clobber a0-a1,a7 [683:712] :a debug build's sectors line on the UART, the last frame's walk in order
call local sector_at index u32 > record a0 addr [714:719]
call local loop_at index u32 > record a0 addr [721:726]
call local wall_at index u32 > record a0 addr [728:733]
call local vertex_at index u32 > record a0 addr [735:740]
call local portal_at index u32 > record a0 addr [742:747]
call local entity_at index u32 > record a0 addr [749:754]
call local material_at index u32 > record a0 addr [756:761]
call local name_at offset u32 > name a0 addr [763:766] :a name in the names table
call local clear_screen > screen JAB_DISPLAY_BASE u32,clobber a0 [768:769] :the framebuffer black
call local fill_screen colour u32 > screen JAB_DISPLAY_BASE u32 [770:781] :the framebuffer one colour
call local read_file buffer addr,capacity u64,disk u64,path addr > bytes a0 u64,contents 0(buffer) u8,clobber a1-a4,a7 [783:835] :a file off a disk read whole, a page at a time, as much as the buffer holds
 path :the path from the root, NUL-terminated
 bytes :the bytes read, 0 when the file is not there
call local str_len string addr > length a1 u64 [837:846]
 string :NUL-terminated, kept in a0
call local append_str cursor addr,string addr > cursor a0 addr,text 0(cursor) u8,clobber a1 [848:857] :appends a string at the cursor
 string :NUL-terminated
call local append_dec cursor addr,value u64 > cursor a0 addr,digits 0(cursor) u8,clobber a1 [859:878] :appends a number in decimal at the cursor
bss local rec JAB_ROMFS_ENTRY u8 [882:883] :the romfs record read_file finds the file into
bss local digits DIGITS_BYTES u8 [884:885] :append_dec's scratch, the digits built backwards from its end
bss local line LINE_BYTES u8 [886:887] :the UART line in hand
bss local name NAME_BYTES u8 [888:889] :the map's name, NUL-terminated
bss local map_path PATH_BYTES u8 [890:891] :the map's path, /map/<name>.jabfps.map
bss local tile_path PATH_BYTES u8 [892:894] :the path of the file the loaders read
bss local map_bytes u64 [895:896] :the map's bytes read
bss local pixel_cursor addr [897:898] :the pixel arena's next free byte
bss local ambient_cursor addr [899:900] :the ambient arena's next free byte
bss local sections KIND_COUNT*2 u64 [901:902] :the sections as the loader placed them, an entry a kind
bss local spawn_index i32 [903:904] :the map's first spawn, -1 for none
bss local sprite_count u32 [905:906] :the map's sprite entities
bss local texture_count u32 [907:908] :the materials whose texture loaded
bss local missing_count u32 [909:910] :the materials whose texture is not on the disk
bss local frame_us u32 [911:912] :the last frame's drawing in microseconds
bss local game_us u32 [913:914] :the last frame's game in microseconds
bss local frame_seconds f32 [915:917] :the seconds since the frame before, clamped
bss local frame_clock 9 u64 [918:919] :the frame's marks and phases in ticks, CLOCK_* fields
bss local record_pair 128 u8 [920:921] :the frame and draw records, written as one
bss local end_record REPORT_SIZE u8 [922:924] :the end marker, REPORT_END
bss local material_record MAX_MATERIALS addr [925:926] :each material's texture record in the pixel arena, 0 for none
bss local ambient_at MAX_AMBIENTS addr [927:928] :each ambient piece's bytes in its arena, 0 for none
bss local ambient_bytes MAX_AMBIENTS u64 [929:931] :each ambient piece's byte count
bss local map MAP_BYTES u8 [932:934] :the map file
bss local file FILE_BYTES u8 [935:937] :a texture's file
bss local pixels PIXEL_BYTES u8 [938:940] :the pixel arena, the textures' records
bss local ambient_arena AMBIENT_BYTES u8 [941:943] :the ambient arena
bss local font FONT_BYTES u8 [944:945] :the soundfont
rodata local serial_fps 4 u8 [948:949] :the program disk's serial
rodata local path_name 10 u8 [950:951] :the file naming the map
rodata local word_map_dir 6 u8 [952:953]
rodata local word_map_ext 12 u8 [954:955]
rodata local word_png_ext 5 u8 [956:957]
rodata local word_mid_ext 5 u8 [958:959]
rodata local word_slash 2 u8 [960:961]
rodata local msg_prefix 6 u8 [962:963]
rodata local msg_material 15 u8 [964:965]
rodata local word_colon 3 u8 [966:967]
rodata local word_not_on_disk 20 u8 [968:969]
rodata local word_not_map 22 u8 [970:971]
rodata local word_ends_at 10 u8 [972:973]
rodata local word_before_structures 32 u8 [974:975]
rodata local word_not_fit 18 u8 [976:977]
rodata local word_bytes 7 u8 [978:979]
rodata local word_holds_more 13 u8 [980:981]
rodata local word_than_build 23 u8 [982:983]
rodata local word_name_too_long 31 u8 [984:985]
rodata local msg_load_failed 32 u8 [986:987]
rodata local word_code 7 u8 [988:989]
rodata local word_directory 22 u8 [990:991]
rodata local msg_no_display 17 u8 [992:993]
rodata local msg_no_sound 15 u8 [994:995]
rodata local msg_no_disk 28 u8 [996:997]
rodata local msg_no_name 32 u8 [998:1000]
rodata local msg_ambient 14 u8 [1001:1002]
rodata local word_space 2 u8 [1003:1004]
rodata local word_loaded 12 u8 [1005:1006]
rodata local word_ms 6 u8 [1007:1008]
rodata local word_sectors 11 u8 [1009:1010]
rodata local word_walls 9 u8 [1011:1012]
rodata local word_vertices 12 u8 [1013:1014]
rodata local word_portals 11 u8 [1015:1016]
rodata local word_entities 12 u8 [1017:1018]
rodata local word_lights 10 u8 [1019:1020]
rodata local word_lumel_maps 14 u8 [1021:1022]
rodata local word_sprites 11 u8 [1023:1024]
rodata local word_materials 13 u8 [1025:1026]
rodata local word_textures 12 u8 [1027:1028]
rodata local word_missing 9 u8 [1029:1030]
rodata local word_missing_file 9 u8 [1031:1032]
rodata local word_not_fit_arena 24 u8 [1033:1034]
rodata local msg_frame 15 u8 [1035:1036]
rodata local msg_sectors 14 u8 [1037:1038]
rodata local word_us 6 u8 [1039:1040]
rodata local word_pieces 10 u8 [1041:1042]
rodata local word_planes 10 u8 [1043:1044]
rodata local word_openings 12 u8 [1045:1046]
rodata local word_uncovered 55 u8 [1047:1048]
rodata local word_comma 3 u8 [1049:1050]
rodata local word_spans 9 u8 [1051:1052]
rodata local word_pixels 10 u8 [1053:1054]
rodata local word_lit_spans 13 u8 [1055:1056]
rodata local word_lit_pixels 14 u8 [1057:1058]
rodata local word_light_us 12 u8 [1059:1060]
rodata local word_rejected 12 u8 [1061:1062]
rodata local word_lumel_samples 11 u8 [1063:1064]
rodata local word_tiles_built 15 u8 [1065:1066]
rodata local word_tiled 9 u8 [1067:1068]
rodata local word_resets 10 u8 [1069:1073]
rodata local k_seconds_a_tick f32 [1074:1075] :a time tick in seconds
rodata local k_dt_max f32 [1076:1094] :the frame's seconds at most
