j _start [5:14] :says which build it is on the UART and exits with 0
rodata local msg_debug 21 u8 [9:10] :the line a debug build adds, defined only with DEBUG
rodata local msg_done 14 u8 [17:18] :the line every build prints
