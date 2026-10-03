j _start [5:6] :says it is ready on the UART, then reports key events
j local wait [7:8] :halts until a key event is waiting
j local next [9:34] :reports every key event waiting on the UART, exiting with 0 once the space bar is released
data local report 4 u8 [37:38] :the line printed for each event, the code and the value following
data local code_digits 4 u8 [39:40] :the code's three digits and a space, written for each event
data local value_digit 3 u8 [41:42] :the value's digit, a newline, and the terminator
rodata local ready 13 u8 [45:46] :the line printed before the first wait
