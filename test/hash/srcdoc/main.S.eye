set LONGEST u64 [3] :the ramp's length, the longest prefix hashed
set MODULUS u64 [4] :the ramp's period, each byte its index modulo this
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
rodata local lengths 26 i64 [145:150] :the prefix lengths hashed, reaching the four paths and the boundaries between them, ended by -1
rodata local word_h 3 u8 [151:152] :a line's first word
bss local buf 20000 u8 [156:157] :the ramp
bss local line 128 u8 [158:159] :the line being built
bss local lineptr addr [160:161] :the cursor in line
bss local digits 32 u8 [162:163] :line_dec's digits, built backward
