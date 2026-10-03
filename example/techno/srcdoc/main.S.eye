set DISK u8 [3] :the romfs disk's id
set PIECE_BYTES u64 [4] :the most of the piece read, 96 KiB
set TITLE_CELLS u64 [5] :the title's characters
set TITLE_SCALE u64 [6] :four times the console's cell, in 256ths
set TITLE_WIDTH u64 [7] :the title's width in pixels, bold adding one
set TITLE_HEIGHT u64 [8] :the title's height in pixels
set TITLE_X i64 [9] :the title's left, centred on the screen
set TITLE_Y i64 [10] :the title's top, centred on the screen
set TITLE_COLOR u32 [11] :the title's off-white
j _start [15:36] :opens the display and the sound, reads the piece, shows the title, and plays the piece
j local playing [37:41] :waits a tick at a time while the piece plays, then exits with 0
j local no_display [43:45] :says so on the UART and exits with 1
j local no_sound [47:49] :says so on the UART and exits with 2
j local no_piece [51:53] :says so on the UART and exits with 3
j local refused [55:57] :says jab.sys.midi.play refused the piece on the UART and exits with 4
call local read_piece > piece piece u8,length piece_length u64,clobber a0-a4,a7,s0-s2 [59:90] :the piece off the romfs into memory, its length kept
 piece :at most PIECE_BYTES of the file
 length :0 when the file is missing
bss local piece_length u64 [94:95] :the piece's bytes in memory
bss local rec 144 u8 [96:97] :the piece's romfs record
bss local piece 98304 u8 [98:99] :the piece, a Standard MIDI File
rodata local piece_path 15 u8 [102:103] :the piece's path on the romfs
rodata local title 10 u8 [104:105] :the title shown while the piece plays
rodata local msg_no_display 20 u8 [106:107] :the line for a machine with no display
rodata local msg_no_sound 18 u8 [108:109] :the line for a machine with no sound
rodata local msg_no_piece 38 u8 [110:111] :the line for a romfs without the piece
rodata local msg_refused 31 u8 [112:113] :the line for a piece jab.sys.midi.play refused
