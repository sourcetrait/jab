j _start [5:27] :prints `harts <discovered> <online> <failed>`, jab.sys.harts's masks in decimal, and exits with 0
call local put_char char u8 > text line u8,clobber s3 [29:32]
 text :the character at the cursor in s3, which moves past it
call local put_str string addr > clobber a1,s3 [34:42]
 string :NUL-terminated, put at the cursor without its terminator
call local put_dec value u64 > clobber a0,s3 [44:64] :the value in decimal at the cursor, built backward in digits first
