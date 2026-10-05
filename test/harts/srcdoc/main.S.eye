j _start [7:34] :awaits HOLD_TICKS display ticks, then prints `harts <discovered> <online> <failed>`, jab.sys.harts's masks in decimal, and exits with 0
call local put_char char u8 > text line u8,clobber s3 [36:39]
 text :the character at the cursor in s3, which moves past it
call local put_str string addr > clobber a1,s3 [41:49]
 string :NUL-terminated, put at the cursor without its terminator
call local put_dec value u64 > clobber a0,s3 [51:71] :the value in decimal at the cursor, built backward in digits first
