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
