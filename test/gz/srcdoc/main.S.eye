j _start [10:101] :inflates every file in paths, prints a g line for each and the first one's contents as hex, and exits with 0, or 1 at a missing file
call local line_reset > cursor lineptr addr [103:107]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr addr [109:115]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr addr [117:125]
 text :a newline and the terminator appended where the line ends, the cursor left on the terminator
call local line_str string addr > text line u8,cursor lineptr addr [127:140]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr addr [142:166]
 text :the value in decimal appended, built backward in digits first
call local line_hex byte u8 > text line u8,cursor lineptr addr [168:193]
 text :the byte's two lowercase hex digits appended
