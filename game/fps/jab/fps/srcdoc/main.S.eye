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
j _start > disk s0 u64 [30:121] :the program, the map loaded and held to its format, the title drawn, then the frame loop
 disk :the program's disk, held for the whole run and read by the loaders
j local frame before s7 u64,count s8 u64 > seconds frame_seconds f32,game game_us u32,drawing frame_us u32 [122:176] :a frame and every frame after, never returning
 before :the frame before's time
 count :the frames drawn
j local no_display [178:180] :exits 1, the machine having no display
j local no_sound [182:184] :exits 2, the machine having no sound device
j local no_disk [186:188] :exits 3, no disk carrying serial fps
j local no_name [190:192] :exits 4, the disk having no /map/name
j local no_map [194:199] :exits 5, the map not on the disk
j local bad_magic [201:206] :exits 6, the file not a Jab FPS map
j local short_file [208:218] :exits 7, the file ending before its structures do
j local map_too_big [220:229] :exits 7, the map not fitting its buffer
j local too_many word a1 addr [231:241] :exits 8, the map holding more of a kind than this build does
 word :the kind's word, NUL-terminated
j local path_too_long material u32 [243:253] :exits 9, a material's name too long for a path
j local load_failed material u32,code u64 [255:268] :exits 10, a material's texture failing to load
 code :a JAB_PNG_* or a LOAD_*
j local check_failed word a1 addr,index a2 u32,what a3 addr [270:284] :exits 11, a record breaking a rule of the format
 word :the record's word, NUL-terminated
 what :what is wrong with it, NUL-terminated
j local map_lacks lack a1 addr [286:292] :exits 11, the map lacking something it must hold
 lack :the lack, NUL-terminated
j local bad_directory how a1 addr [294:302] :exits 12, the section directory broken
 how :how it is broken, NUL-terminated
call local line_map > cursor a0 addr,text line u8,clobber a1 [304:312] :begins the UART line with the prefix and the map's path
call local line_end cursor addr > clobber a0,a7 [314:321] :ends the line at the cursor with a newline and prints it on the UART
call local load_report ms s5 u64 > clobber a0-a1,a7 [322:388] :a debug build's load line on the UART, the counts of what loaded
 ms :the load's milliseconds
call local frame_report ticks s10 u64 > clobber a0-a1,a7 [390:526] :a debug build's frame line on the UART, the counts, the ticks by phase, the spans and pixels, the light, the rejected pixels, the samples, and the tiles
 ticks :the frame's drawing ticks
call local sectors_report > clobber a0-a1,a7 [528:557] :a debug build's sectors line on the UART, the last frame's walk in order
call local sector_at index u32 > record a0 addr [559:564]
call local loop_at index u32 > record a0 addr [566:571]
call local wall_at index u32 > record a0 addr [573:578]
call local vertex_at index u32 > record a0 addr [580:585]
call local portal_at index u32 > record a0 addr [587:592]
call local entity_at index u32 > record a0 addr [594:599]
call local material_at index u32 > record a0 addr [601:606]
call local name_at offset u32 > name a0 addr [608:611] :a name in the names table
call local clear_screen > screen JAB_DISPLAY_BASE u32,clobber a0 [613:614] :the framebuffer black
call local fill_screen colour u32 > screen JAB_DISPLAY_BASE u32 [615:626] :the framebuffer one colour
call local read_file buffer addr,capacity u64,disk u64,path addr > bytes a0 u64,contents 0(buffer) u8,clobber a1-a4,a7 [628:680] :a file off a disk read whole, a page at a time, as much as the buffer holds
 path :the path from the root, NUL-terminated
 bytes :the bytes read, 0 when the file is not there
call local str_len string addr > length a1 u64 [682:691]
 string :NUL-terminated, kept in a0
call local append_str cursor addr,string addr > cursor a0 addr,text 0(cursor) u8,clobber a1 [693:702] :appends a string at the cursor
 string :NUL-terminated
call local append_dec cursor addr,value u64 > cursor a0 addr,digits 0(cursor) u8,clobber a1 [704:723] :appends a number in decimal at the cursor
bss local rec JAB_ROMFS_ENTRY u8 [727:728] :the romfs record read_file finds the file into
bss local digits DIGITS_BYTES u8 [729:730] :append_dec's scratch, the digits built backwards from its end
bss local line LINE_BYTES u8 [731:732] :the UART line in hand
bss local name NAME_BYTES u8 [733:734] :the map's name, NUL-terminated
bss local map_path PATH_BYTES u8 [735:736] :the map's path, /map/<name>.jabfps.map
bss local tile_path PATH_BYTES u8 [737:739] :the path of the file the loaders read
bss local map_bytes u64 [740:741] :the map's bytes read
bss local pixel_cursor addr [742:743] :the pixel arena's next free byte
bss local ambient_cursor addr [744:745] :the ambient arena's next free byte
bss local sections KIND_COUNT*2 u64 [746:747] :the sections as the loader placed them, an entry a kind
bss local spawn_index i32 [748:749] :the map's first spawn, -1 for none
bss local sprite_count u32 [750:751] :the map's sprite entities
bss local texture_count u32 [752:753] :the materials whose texture loaded
bss local missing_count u32 [754:755] :the materials whose texture is not on the disk
bss local frame_us u32 [756:757] :the last frame's drawing in microseconds
bss local game_us u32 [758:759] :the last frame's game in microseconds
bss local frame_seconds f32 [760:762] :the seconds since the frame before, clamped
bss local material_record MAX_MATERIALS addr [763:764] :each material's texture record in the pixel arena, 0 for none
bss local ambient_at MAX_AMBIENTS addr [765:766] :each ambient piece's bytes in its arena, 0 for none
bss local ambient_bytes MAX_AMBIENTS u64 [767:769] :each ambient piece's byte count
bss local map MAP_BYTES u8 [770:772] :the map file
bss local file FILE_BYTES u8 [773:775] :a texture's file
bss local pixels PIXEL_BYTES u8 [776:778] :the pixel arena, the textures' records
bss local ambient_arena AMBIENT_BYTES u8 [779:781] :the ambient arena
bss local font FONT_BYTES u8 [782:783] :the soundfont
rodata local serial_fps 4 u8 [786:787] :the program disk's serial
rodata local path_name 10 u8 [788:789] :the file naming the map
rodata local word_map_dir 6 u8 [790:791]
rodata local word_map_ext 12 u8 [792:793]
rodata local word_png_ext 5 u8 [794:795]
rodata local word_mid_ext 5 u8 [796:797]
rodata local word_slash 2 u8 [798:799]
rodata local msg_prefix 6 u8 [800:801]
rodata local msg_material 15 u8 [802:803]
rodata local word_colon 3 u8 [804:805]
rodata local word_not_on_disk 20 u8 [806:807]
rodata local word_not_map 22 u8 [808:809]
rodata local word_ends_at 10 u8 [810:811]
rodata local word_before_structures 32 u8 [812:813]
rodata local word_not_fit 18 u8 [814:815]
rodata local word_bytes 7 u8 [816:817]
rodata local word_holds_more 13 u8 [818:819]
rodata local word_than_build 23 u8 [820:821]
rodata local word_name_too_long 31 u8 [822:823]
rodata local msg_load_failed 32 u8 [824:825]
rodata local word_code 7 u8 [826:827]
rodata local word_directory 22 u8 [828:829]
rodata local msg_no_display 17 u8 [830:831]
rodata local msg_no_sound 15 u8 [832:833]
rodata local msg_no_disk 28 u8 [834:835]
rodata local msg_no_name 32 u8 [836:838]
rodata local msg_ambient 14 u8 [839:840]
rodata local word_space 2 u8 [841:842]
rodata local word_loaded 12 u8 [843:844]
rodata local word_ms 6 u8 [845:846]
rodata local word_sectors 11 u8 [847:848]
rodata local word_walls 9 u8 [849:850]
rodata local word_vertices 12 u8 [851:852]
rodata local word_portals 11 u8 [853:854]
rodata local word_entities 12 u8 [855:856]
rodata local word_lights 10 u8 [857:858]
rodata local word_lumel_maps 14 u8 [859:860]
rodata local word_sprites 11 u8 [861:862]
rodata local word_materials 13 u8 [863:864]
rodata local word_textures 12 u8 [865:866]
rodata local word_missing 9 u8 [867:868]
rodata local word_missing_file 9 u8 [869:870]
rodata local word_not_fit_arena 24 u8 [871:872]
rodata local msg_frame 15 u8 [873:874]
rodata local msg_sectors 14 u8 [875:876]
rodata local word_us 6 u8 [877:878]
rodata local word_pieces 10 u8 [879:880]
rodata local word_planes 10 u8 [881:882]
rodata local word_openings 12 u8 [883:884]
rodata local word_uncovered 55 u8 [885:886]
rodata local word_comma 3 u8 [887:888]
rodata local word_spans 9 u8 [889:890]
rodata local word_pixels 10 u8 [891:892]
rodata local word_lit_spans 13 u8 [893:894]
rodata local word_lit_pixels 14 u8 [895:896]
rodata local word_light_us 12 u8 [897:898]
rodata local word_rejected 12 u8 [899:900]
rodata local word_lumel_samples 11 u8 [901:902]
rodata local word_tiles_built 15 u8 [903:904]
rodata local word_tiled 9 u8 [905:906]
rodata local word_resets 10 u8 [907:911]
rodata local k_seconds_a_tick f32 [912:913] :a time tick in seconds
rodata local k_dt_max f32 [914:932] :the frame's seconds at most
