set DISK u8 [3] :the romfs disk's id
set PNGBUF u64 [4] :room for a PNG, 64 KiB
set SPRITEBUF u64 [5] :room for a sprite, 64 KiB
set COLUMNS u64 [6] :the bytes a hex line carries
j _start [10:95] :sizes and decodes every PNG in table, loads every directory in loads, reports each, and exits with 0, or 1 at a missing file
call local report code u64,word address > clobber a0,a7,s6-s10 [97:200] :prints the line opening with word, and on success the sprite's pixels, span table, and flags
 code :a sprite call's JAB_PNG_*
call local line_reset > cursor lineptr address [202:206]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr address [208:214]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr address [216:224]
 text :a newline and the terminator appended where the line ends, the cursor left on the terminator
call local line_str string address > text line u8,cursor lineptr address [226:239]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr address [241:265]
 text :the value in decimal appended, built backward in digits first
call local line_hex byte u8 > text line u8,cursor lineptr address [267:292]
 text :the byte's two lowercase hex digits appended
rodata local table 78 u64 [296:322] :the path, the frames, and the capacity of each decode, ended by a 0 path
rodata local loads 14 u64 [324:331] :the directory and the capacity of each load, ended by a 0 directory
rodata local path_rgba8 11 u8 [333:334] :an RGBA PNG at 8 bits
rodata local path_rgb8 10 u8 [335:336] :an RGB PNG at 8 bits
rodata local path_grey8 11 u8 [337:338] :a grey PNG at 8 bits
rodata local path_grey4 11 u8 [339:340] :a grey PNG at 4 bits
rodata local path_grey2 11 u8 [341:342] :a grey PNG at 2 bits
rodata local path_grey1 11 u8 [343:344] :a grey PNG at 1 bit
rodata local path_ga8 9 u8 [345:346] :a grey PNG with alpha at 8 bits
rodata local path_idx8 10 u8 [347:348] :an indexed PNG at 8 bits
rodata local path_idx4 10 u8 [349:350] :an indexed PNG at 4 bits
rodata local path_idx2 10 u8 [351:352] :an indexed PNG at 2 bits
rodata local path_idx1 10 u8 [353:354] :an indexed PNG at 1 bit
rodata local path_sheet 11 u8 [355:356] :a sheet decoded as two frames
rodata local path_split 11 u8 [357:358]
rodata local path_big 9 u8 [359:360]
rodata local path_extras 12 u8 [361:362]
rodata local path_depth16 13 u8 [363:364]
rodata local path_interlaced 16 u8 [365:366]
rodata local path_badcrc 12 u8 [367:368]
rodata local path_badadler 14 u8 [369:370]
rodata local path_badfilter 15 u8 [371:372]
rodata local path_short 11 u8 [373:374]
rodata local path_truncated 15 u8 [375:376]
rodata local path_notpng 12 u8 [377:378]
rodata local dir_walker 8 u8 [379:380] :a directory of four frames
rodata local dir_mixed 7 u8 [381:382] :a directory whose second frame is another size
rodata local dir_nozero 8 u8 [383:384] :a directory with no 0.png
rodata local dir_missing 9 u8 [385:386] :a directory that is not there
rodata local word_s 3 u8 [388:389] :a size line's first word
rodata local word_p 3 u8 [390:391] :a decode line's first word
rodata local word_l 3 u8 [392:393] :a load line's first word
rodata local word_x 3 u8 [394:395] :a pixel hex line's first word
rodata local word_y 3 u8 [396:397] :a span table hex line's first word
rodata local word_f 3 u8 [398:399] :the flags line's first word
rodata local msg_done 6 u8 [400:401] :the last line
rodata local msg_missing 27 u8 [402:403] :the line for a missing fixture
bss local rec 144 u8 [407:408] :a file's romfs record
bss local pngbuf 65536 u8 [409:410] :the PNG as read
bss local sprite 65536 u8 [411:412] :the sprite record decoded into
bss local line 512 u8 [413:414] :the line being built
bss local lineptr address [415:416] :the cursor in line
bss local digits 32 u8 [417:418] :line_dec's digits, built backward
