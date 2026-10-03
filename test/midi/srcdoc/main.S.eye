set CHANNEL u8 [3] :the MIDI channel played
set PROGRAM u8 [4] :the General MIDI program, the square lead
set NOTE u8 [5] :the A at 440 Hz
set VELOCITY u8 [6] :full velocity
set HOLD u64 [7] :how long the note sounds, a second in ticks
set TAIL u64 [8] :how long the program spins after the release, half a second in ticks
j _start [12:29] :opens the sound, plays the note for HOLD, releases it, spins for TAIL, and exits with 0
call local spin ticks u64 [31:37] :the ticks go by with the hart busy the whole time
j local no_sound [39:41] :says so on the UART and exits with 2
rodata local msg_no_sound 16 u8 [44:45] :the line for a machine with no sound
