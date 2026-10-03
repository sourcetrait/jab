set BLOCK_BYTES u64 [3] :a cache block, 64 bytes under RVA23
set FILL u8 [4] :the byte both blocks are filled with first
set SPIN u64 [5] :the spin between the counters' two readings
set LINE_BYTES u64 [6] :room for a line
set DIGITS_BYTES u64 [7] :room for a decimal's digits
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
bss local blocks 128 u8 [182:184] :two cache blocks, aligned to one
bss local line_len u64 [185:186] :the line's length so far
bss local line 160 u8 [187:188] :the line being built
bss local digits 24 u8 [189:190] :line_int's digits, built backward
rodata local msg_zero 6 u8 [193:194] :the zero line's first word
rodata local msg_untouched 12 u8 [195:196] :before the count of the next block's bytes still filled
rodata local msg_kept 6 u8 [197:198] :the line of the bytes kept through clean, flush, and inval
rodata local msg_rising 8 u8 [199:200] :the line of whether each counter rose, 1 or 0
rodata local msg_space 2 u8 [201:202] :between two numbers
rodata local msg_hpm3 6 u8 [203:204] :the performance counters' line
rodata local msg_hpm18 8 u8 [205:206] :before hpmcounter18's reading
