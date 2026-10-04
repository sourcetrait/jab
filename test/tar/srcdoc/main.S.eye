j _start [8:86] :reads the archive off the romfs, prints its length, every entry, and two finds, and exits with 0, or 1 without the archive
call local find_one path addr > clobber a0-a3,a7,s7 [88:124] :prints the find's code, and the size and name when the path is there
 path :NUL-terminated
call local line_reset > cursor lineptr addr [126:130]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr addr [132:138]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr addr [140:148]
 text :a newline and the terminator appended where the line ends, the cursor left on the terminator
call local line_str string addr > text line u8,cursor lineptr addr [150:163]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr addr [165:189]
 text :the value in decimal appended, built backward in digits first
