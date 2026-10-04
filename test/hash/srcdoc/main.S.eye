j _start [8:49] :fills buf with the ramp, prints the hash of every prefix in lengths, and exits with 0
call local line_reset > cursor lineptr addr [51:55]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr addr [57:63]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr addr [65:73]
 text :a newline and the terminator appended, the cursor left on the terminator
call local line_str string addr > text line u8,cursor lineptr addr [75:88]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr addr [90:114]
 text :the value in decimal appended, built backward in digits first
call local line_hex byte u8 > text line u8,cursor lineptr addr [116:141]
 text :the byte's two lowercase hex digits appended
