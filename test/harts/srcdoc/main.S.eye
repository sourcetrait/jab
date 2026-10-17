j _start [10:72] :awaits HOLD_TICKS display ticks, prints `harts <discovered> <online> <failed>`, jab.sys.harts's masks in decimal, then `window <pages> <wrong>` from the window probe over its last GiB, and exits with 0
call local put_char char u8 > text line u8,clobber s3 [74:77]
 text :the character at the cursor in s3, which moves past it
call local put_str string addr > clobber a1,s3 [79:87]
 string :NUL-terminated, put at the cursor without its terminator
call local put_dec value u64 > clobber a0,s3 [89:109] :the value in decimal at the cursor, built backward in digits first
