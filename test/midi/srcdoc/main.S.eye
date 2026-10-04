j _start [12:29] :opens the sound, plays the note for HOLD, releases it, spins for TAIL, and exits with 0
call local spin ticks u64 [31:37] :the ticks go by with the hart busy the whole time
j local no_sound [39:41] :says so on the UART and exits with 2
