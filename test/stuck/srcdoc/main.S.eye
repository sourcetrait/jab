j _start [8:42] :draws from the rng, opens the display, flips at each of WAIT_TICKS display ticks, draws again, flips once more, prints `stuck random <first> then <second>, flip <status>`, and exits with 0
call local put_char char u8 > text line u8,clobber s3 [44:47]
 text :the character at the cursor in s3, which moves past it
call local put_str string addr > clobber a1,s3 [49:57]
 string :NUL-terminated, put at the cursor without its terminator
call local put_dec value u64 > clobber a0,s3 [59:79] :the value in decimal at the cursor, built backward in digits first
