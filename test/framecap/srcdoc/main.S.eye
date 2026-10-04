j _start [7:76] :flips without waiting, then paced, then with bad rectangles, reports each on the UART, and exits with 0
j local no_display [78:80] :says so on the UART and exits with 1
j local flip_failed [82:84] :says a flip after await failed on the UART and exits with 2
call local two_digits value u64,at addr > digits 0(at) u8 [86:94]
 value :under a hundred
 digits :the value's two decimal digits
