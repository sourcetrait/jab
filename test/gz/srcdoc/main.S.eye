set DISK u8 [3] :the romfs disk's id
set GZBUF u64 [4] :room for a compressed file, 64 KiB
set OUTBUF u64 [5] :room for a file's contents, 64 KiB
set COLUMNS u64 [6] :the bytes a hex line carries
j _start [10:101] :inflates every file in paths, prints a g line for each and the first one's contents as hex, and exits with 0, or 1 at a missing file
call local line_reset > cursor lineptr address [103:107]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr address [109:115]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr address [117:125]
 text :a newline and the terminator appended where the line ends, the cursor left on the terminator
call local line_str string address > text line u8,cursor lineptr address [127:140]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr address [142:166]
 text :the value in decimal appended, built backward in digits first
call local line_hex byte u8 > text line u8,cursor lineptr address [168:193]
 text :the byte's two lowercase hex digits appended
rodata local paths 7 address [197:204] :the files inflated, ended by 0
rodata local path_text 13 u8 [206:207] :a text file's path on the romfs
rodata local path_random 15 u8 [208:209] :a random file's path on the romfs
rodata local path_tiny 13 u8 [210:211] :a tiny file's path on the romfs
rodata local path_empty 10 u8 [212:213] :an empty file's path on the romfs
rodata local path_png 13 u8 [214:215] :a compressed PNG's path on the romfs
rodata local path_font 11 u8 [216:217] :a source file's path on the romfs
rodata local word_g 3 u8 [219:220] :a file line's first word
rodata local word_x 3 u8 [221:222] :a hex line's first word
bss local rec 144 u8 [226:227] :a file's romfs record
bss local gzbuf 65536 u8 [228:229] :the compressed file as read
bss local outbuf 65536 u8 [230:231] :the contents inflated
bss local line 512 u8 [232:233] :the line being built
bss local lineptr address [234:235] :the cursor in line
bss local digits 32 u8 [236:237] :line_dec's digits, built backward
