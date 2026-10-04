j _start [5:6] :says it is ready on the UART, then reports key events
j local wait [7:8] :halts until a key event is waiting
j local next [9:34] :reports every key event waiting on the UART, exiting with 0 once the space bar is released
