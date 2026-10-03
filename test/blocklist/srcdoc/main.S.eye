j _start [5:62] :lists the disks, prints a line for each and the page's answer, tries a write to the first, and exits with 0
call local line_reset > cursor lineptr addr [64:68]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr addr [70:76]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr addr [78:86]
 text :a newline and the terminator appended where the line ends, the cursor left on the terminator
call local line_str string addr > text line u8,cursor lineptr addr [88:101]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr addr [103:127]
 text :the value in decimal appended, built backward in digits first
rodata local word_disk 6 u8 [130:131] :a disk line's first word
rodata local word_kind 7 u8 [132:133] :the word before a disk's kind
rodata local word_sectors 10 u8 [134:135] :the word before a disk's sectors
rodata local word_serial 9 u8 [136:137] :the word before a disk's serial
rodata local word_count 7 u8 [138:139] :the page line's first word
rodata local word_next 7 u8 [140:141] :the word before the next page's id
rodata local word_write 7 u8 [142:143] :the write line's first word
bss local disks 320 u8 [147:148] :the disk records jab.sys.block.list wrote
bss local sector 512 u8 [149:150] :the sector written to the first disk, zeroes
bss local line 256 u8 [151:152] :the line being built
bss local lineptr addr [153:154] :the cursor in line
bss local digits 32 u8 [155:156] :line_dec's digits, built backward
