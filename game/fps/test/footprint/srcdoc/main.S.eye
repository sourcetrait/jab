j _start [15:26] :the cases on the UART, then the pattern flipped and held
call local cases_run > clobber a0-a7 [28:80] :each case's row_derivative on the UART, a line a case: its index, its four inputs, and its value or saturated
call local pattern_draw [82:121] :the screen laid with the sentinel, then each run of LEVELS codes as runs holds it
call local line_reset [123:127]
call local line_char char u8 [129:135]
call local line_nl [137:145] :the newline and the terminator
call local line_str string addr [147:160]
 string :NUL-terminated
call local line_signed value i64 > clobber a0 [162:192] :in decimal, a minus before a negative one
