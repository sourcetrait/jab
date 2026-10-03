set FLIPS u64 [3] :the flips in each run, sixty-four
j _start [7:76] :flips without waiting, then paced, then with bad rectangles, reports each on the UART, and exits with 0
j local no_display [78:80] :says so on the UART and exits with 1
j local flip_failed [82:84] :says a flip after await failed on the UART and exits with 2
call local two_digits value u64,at addr > digits 0(at) u8 [86:94]
 value :under a hundred
 digits :the value's two decimal digits
data local refused 8 u8 [97:98] :the refused flips' line, its digits following
data local refused_digits 4 u8 [99:100] :the refused flips' count, a newline, and the terminator
data local badrect 8 u8 [101:102] :the bad rectangle's line, its digits following
data local badrect_digits 4 u8 [103:104] :the bad rectangle's code, a newline, and the terminator
data local rects 6 u8 [105:106] :the list's line, its digits following
data local rects_digits 4 u8 [107:108] :the list's code, a newline, and the terminator
data local badrects 9 u8 [109:110] :the bad list's line, its digits following
data local badrects_digits 4 u8 [111:112] :the bad list's code, a newline, and the terminator
data local norects 8 u8 [113:114] :the empty list's line, its digits following
data local norects_digits 4 u8 [115:116] :the empty list's code, a newline, and the terminator
data local flags 6 u8 [117:118] :the kernel flags' line, its digits following
data local flags_digits 4 u8 [119:120] :the kernel's flags, a newline, and the terminator
rodata local two_rects 8 u32 [124:126] :two rectangles apart on the screen
rodata local bad_rects 8 u32 [127:129] :two rectangles, the second reaching past the bottom
rodata local paced 7 u8 [130:131] :the last line, once every check has run
rodata local msg_no_display 22 u8 [132:133] :the line for a machine with no display
rodata local msg_flip_failed 37 u8 [134:135] :the line for a flip after await that failed
