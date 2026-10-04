j _start [10:95] :sizes and decodes every PNG in table, loads every directory in loads, reports each, and exits with 0, or 1 at a missing file
call local report code u64,word addr > clobber a0,a7,s6-s10 [97:200] :prints the line opening with word, and on success the sprite's pixels, span table, and flags
 code :a sprite call's JAB_PNG_*
call local line_reset > cursor lineptr addr [202:206]
 cursor :the start of line
call local line_char char u8 > text line u8,cursor lineptr addr [208:214]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr addr [216:224]
 text :a newline and the terminator appended where the line ends, the cursor left on the terminator
call local line_str string addr > text line u8,cursor lineptr addr [226:239]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_dec value u64 > text line u8,cursor lineptr addr [241:265]
 text :the value in decimal appended, built backward in digits first
call local line_hex byte u8 > text line u8,cursor lineptr addr [267:292]
 text :the byte's two lowercase hex digits appended
