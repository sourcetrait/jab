set BYTES u64 [3] :the bytes asked for in each draw
set LINE_BYTES u64 [4] :room for a line
set DIGITS_BYTES u64 [5] :room for a decimal's digits
j _start [9:14] :draws into first and then second, printing each, and exits with 0
j local no_rng [16:18] :says so on the UART and exits with 2
call local draw buffer addr > bytes 0(buffer) u8,clobber a0-a1,a7,s1-s2 [20:48] :fills the buffer from the device and prints the count given and then the bytes
 buffer :arrives in s0, BYTES long, no_rng taken with no device
call local line_begin > length line_len u64 [50:53]
 length :0, the line begun empty
call local line_str string addr > text line u8,length line_len u64,clobber a0 [55:69]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_int value i64 > text line u8,length line_len u64,clobber a0 [71:104]
 text :the value in decimal appended, a minus first when negative
call local line_end > length line_len u64,clobber a0,a7 [106:116] :the newline and the terminator, then the line to the UART
 length :0, the next line begun
bss local line_len u64 [120:121] :the line's length so far
bss local line 320 u8 [122:123] :the line being built
bss local digits 24 u8 [124:125] :line_int's digits, built backward
bss local first 64 u8 [126:127] :the first draw
bss local second 64 u8 [128:129] :the second draw
rodata local msg_no_rng 16 u8 [132:133] :the line for a machine with no rng device
rodata local msg_bytes 7 u8 [134:135] :the count line's first word
rodata local msg_space 2 u8 [136:137] :the space after each byte
