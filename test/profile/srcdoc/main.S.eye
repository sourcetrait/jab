j _start [11:85] :zeroes one block, cleans, flushes, and invalidates the next, reads the counters, prints a line for each, and exits with 0
call local fill > bytes blocks u8 [87:96] :both blocks filled with FILL
call local count block addr,byte u8 > count a0 u64 [98:110] :how many of the block's 64 bytes equal byte
call local line_begin > length line_len u64 [112:115]
 length :0, the line begun empty
call local line_str string addr > text line u8,length line_len u64,clobber a0 [117:131]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_int value i64 > text line u8,length line_len u64,clobber a0 [133:166]
 text :the value in decimal appended, a minus first when negative
call local line_end > length line_len u64,clobber a0,a7 [168:178] :the newline and the terminator, then the line to the UART
 length :0, the next line begun
