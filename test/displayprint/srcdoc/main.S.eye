j _start [5:11] :prints to the UART, opens the display, prints by each call, and idles
j local idle [12:14] :waits a tick at a time forever, so the screen can be read
j local no_display [16:18] :says so on the UART and exits with 1
rodata local uart_first 12 u8 [21:22] :jab.sys.print's line before the display is open
rodata local on_screen 11 u8 [23:24] :jab.sys.print's line once the display is open
rodata local uart_again 12 u8 [25:26] :jab.sys.uart.print's line
rodata local line_two 10 u8 [27:28] :jab.sys.display.print's line
rodata local msg_no_display 26 u8 [29:30] :the line for a machine with no display
