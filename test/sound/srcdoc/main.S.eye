j _start [9:13] :opens the sound and plays the wave a period at a time
j local next left u64,phase u32 [14:47] :one period of the wave into the stream, until no periods are left
 left :arrives in s0, the periods still to play
 phase :arrives in s1, in 1/2^32 cycles
j local done [48:49] :exits with 0, which plays the ring out
j local no_sound [51:53] :says so on the UART and exits with 2
