set RAMP u64 [3] :the short ramp's length
set LONG u64 [4] :the long ramp's length, many blocks
j _start [8:43] :fills the ramps, prints the digest of each of the four inputs, and exits with 0
call local digest bytes address,count u64 > clobber a0-a3,a7,s0 [45:75] :prints the SHA3-256 of the bytes as a d line on the UART
 bytes :arrives in t0
 count :arrives in t1
call local line_reset > cursor lineptr address [77:81]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr address [83:89]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr address [91:99]
 text :a newline and the terminator appended, the cursor left on the terminator
call local line_str string address > text line u8,cursor lineptr address [101:114]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_hex byte u8 > text line u8,cursor lineptr address [116:141]
 text :the byte's two lowercase hex digits appended
rodata local abc 3 u8 [144:145] :the standard's own three-byte vector, unterminated
rodata local word_d 3 u8 [146:147] :a line's first word
bss local out 32 u8 [151:152] :the digest as it came back in a0 to a3
bss local ramp 200 u8 [153:154] :the short ramp, each byte its index
bss local long 100000 u8 [155:156] :the long ramp, each byte its index modulo 251
bss local line 256 u8 [157:158] :the line being built
bss local lineptr address [159:160] :the cursor in line
