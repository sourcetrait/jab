set DISK u8 [3] :the romfs disk's id
set BUFFER u64 [4] :room for the archive, 32 KiB
j _start [8:86] :reads the archive off the romfs, prints its length, every entry, and two finds, and exits with 0, or 1 without the archive
call local find_one path address > clobber a0-a3,a7,s7 [88:124] :prints the find's code, and the size and name when the path is there
 path :NUL-terminated
call local line_reset > cursor lineptr address [126:130]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr address [132:138]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr address [140:148]
 text :a newline and the terminator appended where the line ends, the cursor left on the terminator
call local line_str string address > text line u8,cursor lineptr address [150:163]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr address [165:189]
 text :the value in decimal appended, built backward in digits first
rodata local path_tar 9 u8 [192:193] :the archive's path on the romfs
rodata local path_note 13 u8 [194:195] :a name the archive holds
rodata local path_missing 17 u8 [196:197] :a name the archive does not hold
rodata local word_archive 9 u8 [198:199] :the length line's first word
rodata local word_t 3 u8 [200:201] :an entry line's first word
rodata local word_f 3 u8 [202:203] :a find line's first word
bss local archive_len u64 [207:208] :the archive's bytes in memory
bss local rec 296 u8 [209:210] :the archive's romfs record, then a find's tar record
bss local recs 4736 u8 [211:212] :a page of tar records
bss local archive 32768 u8 [213:214] :the archive as read
bss local line 512 u8 [215:216] :the line being built
bss local lineptr address [217:218] :the cursor in line
bss local digits 32 u8 [219:220] :line_dec's digits, built backward
