j _start [9:154] :prints a find for every path, the binary file as hex, the empty file's read, and the overflowing directory, and exits with 0, or 1 at a missing file
call local find_one path addr > code a0 u64,offset a1 u64,record rec u8,clobber a2-a3,a7 [156:163] :looks the path up from the root of DISK
 path :NUL-terminated
 code :0 with the record written, 1 when nothing of that name is there, 2 when a component is not a directory
 offset :the entry's own, to list or read it with
call local line_reset > cursor lineptr addr [165:169]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr addr [171:177]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr addr [179:187]
 text :a newline and the terminator appended where the line ends, the cursor left on the terminator
call local line_str string addr > text line u8,cursor lineptr addr [189:202]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr addr [204:228]
 text :the value in decimal appended, built backward in digits first
call local line_hex byte u8 > text line u8,cursor lineptr addr [230:255]
 text :the byte's two lowercase hex digits appended
