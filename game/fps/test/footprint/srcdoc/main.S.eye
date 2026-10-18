j _start [12:14] :the cases on the UART, then exit 0
call local cases_run > clobber a0-a7 [16:68] :each case's row_derivative on the UART, a line a case: its index, its four inputs, and its value or saturated
call local line_reset [70:74]
call local line_char char u8 [76:82]
call local line_nl [84:92] :the newline and the terminator
call local line_str string addr [94:107]
 string :NUL-terminated
call local line_signed value i64 > clobber a0 [109:139] :in decimal, a minus before a negative one
