set LINE_BYTES u64 [3] :room for a line
set DIGITS_BYTES u64 [4] :room for a decimal's digits
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
call local line_str string address > text line u8,length line_len u64,clobber a0 [157:171]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_int value i64 > text line u8,length line_len u64,clobber a0 [173:206]
 text :the value in decimal appended, a minus first when negative
call local line_end > length line_len u64,clobber a0,a7 [208:218] :the newline and the terminator, then the line to the UART
 length :0, the next line begun
bss local line_len u64 [222:223] :the line's length so far
bss local line 160 u8 [224:225] :the line being built
bss local digits 24 u8 [226:228] :line_int's digits, built backward
bss local axis_record 5 i32 [229:230] :an axis's range as jab.sys.pad.axis wrote it
bss local state_record 132 u8 [231:232] :the pad's state as jab.sys.pad.read wrote it
bss local name_buffer 128 u8 [233:234] :the pad's name
bss local quit bool [235:236] :set once BTN_SOUTH is released
rodata local msg_ready 12 u8 [239:240] :the first line
rodata local msg_no_pad 13 u8 [241:242] :the line for a machine with no pad
rodata local msg_name 6 u8 [243:244] :the name line's first word
rodata local msg_axis 6 u8 [245:246] :an axis line's first word
rodata local msg_none 6 u8 [247:248] :an axis line's end when the pad has no such axis
rodata local msg_pad 5 u8 [249:250] :an event line's first word
rodata local msg_state 7 u8 [251:252] :a state line's first word
rodata local msg_space 2 u8 [253:254] :a space
