j _start [15:36] :opens the display and the sound, reads the piece, shows the title, and plays the piece
j local playing [37:41] :waits a tick at a time while the piece plays, then exits with 0
j local no_display [43:45] :says so on the UART and exits with 1
j local no_sound [47:49] :says so on the UART and exits with 2
j local no_piece [51:53] :says so on the UART and exits with 3
j local refused [55:57] :says jab.sys.midi.play refused the piece on the UART and exits with 4
call local read_piece > piece piece u8,length piece_length u64,clobber a0-a4,a7,s0-s2 [59:90] :the piece off the romfs into memory, its length kept
 piece :at most PIECE_BYTES of the file
 length :0 when the file is missing
