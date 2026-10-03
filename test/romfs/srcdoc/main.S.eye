set DISK u8 [3] :the romfs disk's id
set PAGE u64 [4] :the bytes a read asks for, never lining up with a sector
set COLUMNS u64 [5] :the bytes a hex line carries
j _start [9:154] :prints a find for every path, the binary file as hex, the empty file's read, and the overflowing directory, and exits with 0, or 1 at a missing file
call local find_one path address > code a0 u64,offset a1 u64,record rec u8,clobber a2-a3,a7 [156:163] :looks the path up from the root of DISK
 path :NUL-terminated
 code :0 with the record written, 1 when nothing of that name is there, 2 when a component is not a directory
 offset :the entry's own, to list or read it with
call local line_reset > cursor lineptr address [165:169]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr address [171:177]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr address [179:187]
 text :a newline and the terminator appended where the line ends, the cursor left on the terminator
call local line_str string address > text line u8,cursor lineptr address [189:202]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr address [204:228]
 text :the value in decimal appended, built backward in digits first
call local line_hex byte u8 > text line u8,cursor lineptr address [230:255]
 text :the byte's two lowercase hex digits appended
rodata local paths 14 address [259:273] :the paths looked for, ended by 0
rodata local path_readme 11 u8 [275:276] :a text file
rodata local path_empty 7 u8 [277:278] :an empty file
rodata local path_png 36 u8 [279:280] :a binary file
rodata local path_font 19 u8 [281:282] :a large text file
rodata local path_symlink 21 u8 [283:284] :a symbolic link
rodata local path_hardlink 20 u8 [285:286] :a hard link
rodata local path_fifo 16 u8 [287:288] :a fifo
rodata local path_block 17 u8 [289:290] :a block device
rodata local path_char 16 u8 [291:292] :a character device
rodata local path_socket 18 u8 [293:294] :a socket
rodata local path_folder 23 u8 [295:296] :a directory
rodata local path_max 162 u8 [297:302] :a path whose last name is 127 characters, the most a record carries and a linux mount reads
rodata local path_over 195 u8 [303:309] :a path whose last name is 165 characters, past both
rodata local path_over_dir 29 u8 [310:311] :the directory holding path_over's name
rodata local word_f 3 u8 [313:314] :a find line's first word
rodata local word_x 3 u8 [315:316] :a hex line's first word
rodata local word_png 11 u8 [317:318] :the binary file's count line's first words
rodata local word_empty 7 u8 [319:320] :the empty file's line's first word
rodata local word_over 6 u8 [321:322] :an overflowing directory entry's line's first word
bss local rec 144 u8 [326:327] :the romfs record a find wrote
bss local recs 2304 u8 [328:329] :a page of romfs records
bss local buf 4096 u8 [330:331] :a page of the binary file, or the empty file's read
bss local line 512 u8 [332:333] :the line being built
bss local lineptr address [334:335] :the cursor in line
bss local digits 32 u8 [336:337] :line_dec's digits, built backward
