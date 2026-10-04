j _start [8:27] :prints the pad's name and four axes' ranges, then reports pad events
j local frame [28:35] :halts for a pad event and reports what came, exiting with 0 once BTN_SOUTH is released
j local no_pad [37:39] :says so on the UART and exits with 2
call local print_axis code u64 > clobber a0-a1,a7,s1-s3 [41:73] :prints the pad's own range for the axis, or none
 code :arrives in s0, a JAB_ABS_*
call local read_pad > quit quit bool,clobber a0-a2,a7,s1-s3 [75:112] :takes every pad event waiting, reporting each and the state after it
 quit :1 once BTN_SOUTH is released
call local print_state > clobber a0,a7,s1 [114:136] :prints the keys and four axes from a fresh read of the state
call local print_axis_value code u64 > clobber a0 [138:150] :appends a space and the state record's value for the axis
 code :arrives in s1, a JAB_ABS_*
call local line_begin > length line_len u64 [152:155]
 length :0, the line begun empty
call local line_str string addr > text line u8,length line_len u64,clobber a0 [157:171]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_int value i64 > text line u8,length line_len u64,clobber a0 [173:206]
 text :the value in decimal appended, a minus first when negative
call local line_end > length line_len u64,clobber a0,a7 [208:218] :the newline and the terminator, then the line to the UART
 length :0, the next line begun
