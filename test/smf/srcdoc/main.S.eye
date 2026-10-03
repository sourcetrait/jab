set DISK u8 [3] :the romfs disk's id
set PIECE_BYTES u64 [4] :room for the piece, 4 KiB
set LINGER u64 [5] :the wait after the piece ends, a fifth of a second in ticks
j _start [9:47] :opens the sound, reads the piece, plays it, spins until it ends and a moment more, and exits with 0
j local no_sound [49:51] :says so on the UART and exits with 2
j local no_file [52:54] :says so on the UART and exits with 1
j local refused [55:57] :says so on the UART and exits with 3
rodata local path 11 u8 [60:61] :the piece's path on the romfs
rodata local msg_no_sound 15 u8 [62:63] :the line for a machine with no sound
rodata local msg_no_file 35 u8 [64:65] :the line for a romfs without the piece
rodata local msg_refused 35 u8 [66:67] :the line for a piece the player refused
bss local rec 144 u8 [71:72] :the piece's romfs record
bss local piece 4096 u8 [73:74] :the piece, a Standard MIDI File
