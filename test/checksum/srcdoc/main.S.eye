j _start [8:43] :fills the ramps, prints the digest of each of the four inputs, and exits with 0
call local digest bytes addr,count u64 > clobber a0-a3,a7,s0 [45:75] :prints the SHA3-256 of the bytes as a d line on the UART
 bytes :arrives in t0
 count :arrives in t1
call local line_reset > cursor lineptr addr [77:81]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr addr [83:89]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr addr [91:99]
 text :a newline and the terminator appended, the cursor left on the terminator
call local line_str string addr > text line u8,cursor lineptr addr [101:114]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_hex byte u8 > text line u8,cursor lineptr addr [116:141]
 text :the byte's two lowercase hex digits appended
