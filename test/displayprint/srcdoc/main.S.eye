j _start [5:11] :prints to the UART, opens the display, prints by each call, and idles
j local idle [12:14] :waits a tick at a time forever, so the screen can be read
j local no_display [16:18] :says so on the UART and exits with 1
