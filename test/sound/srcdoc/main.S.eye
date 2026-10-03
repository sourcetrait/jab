set PERIODS_TO_PLAY u64 [3] :the periods played, a second
set AMPLITUDE i16 [4] :the wave's height either side of silence
set STEP u32 [5] :440 Hz as a phase step in 1/2^32 cycles a frame at 48 kHz
j _start [9:13] :opens the sound and plays the wave a period at a time
j local next left u64,phase u32 [14:47] :one period of the wave into the stream, until no periods are left
 left :arrives in s0, the periods still to play
 phase :arrives in s1, in 1/2^32 cycles
j local done [48:49] :exits with 0, which plays the ring out
j local no_sound [51:53] :says so on the UART and exits with 2
bss local period 1920 i16 [57:58] :one period of frames, left then right
rodata local msg_no_sound 17 u8 [61:62] :the line for a machine with no sound, or a refused write
