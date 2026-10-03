set TRACKS u64 [4] :the tracks a file may hold
set TRACK_AT address [5] :a track record's next byte to read
set TRACK_END address [6] :the chunk's end
set TRACK_TICK u64 [7] :the next event's absolute tick
set TRACK_STATUS u8 [8] :the running status
set TRACK_DONE u8 [9]
set TRACK_SIZE u64 [10] :bytes in a track record
set HEADER_BYTES u64 [11] :bytes in the MThd chunk
set CHUNK_HEADER_BYTES u64 [12] :bytes in a chunk's tag and length
set FORMAT_MOST u16 [13] :the latest format taken
set META u8 [14] :the meta event's status
set SYSEX u8 [15]
set SYSEX_ESCAPE u8 [16]
set META_TEMPO u8 [17]
set META_END u8 [18] :the end-of-track meta event
set TEMPO_DEFAULT u64 [19] :microseconds a quarter note before a tempo event
set PERIOD_MICROS u64 [20] :a period in microseconds
ecall sys_midi_play source address,length u64 > status a0 u64 [25:39] :plays the Standard MIDI File, whatever was playing stopped with its notes released, from the next period
 source :ends the run unless the whole file lies inside the program's window
 status :0, sound_open's code, or 3 when the file is not one the player takes
ecall sys_midi_stop > status a0 u64 [40:49] :the piece stops where it is, its notes released
 status :0, or sound_open's code
ecall sys_midi_playing > playing a0 bool [50:56]
 playing :1 while a piece plays
call smf_stop > playing smf_playing u64,clobber a0-a1 [57:70] :stops the sequencer and releases the file's own voices, the calls' left sounding
call local smf_load file address,length u64 > status a0 u64,playing smf_playing u64,clobber a1-a2 [72:191] :reads the file into the tracks and the clock and starts the piece
 status :0, or 3 when the file is refused
call local smf_clock > increment smf_increment u64 [193:204] :the position's step a period from the tempo and the division, 32.32 ticks
call local smf_be32 at address > value a0 u32 [206:218]
call local smf_be16 at address > value a0 u16 [220:227]
call smf_step > position smf_position u64,playing smf_playing u64,clobber a0 [228:296] :one period of the piece, every track's events up to the moved position fired, the piece ended once every track has
call local smf_event track address > clobber a0-a3 [298:428] :fires the event at the track's cursor and moves past it and its next delta, a bad read or the end-of-track event ending the track
call local smf_delta track address > clobber a0-a2 [430:450] :adds the delta at the cursor to the track's tick and moves past it, a track with none left done
call local smf_varint at address,limit address > value a0 u64,next a1 address,read a2 bool [452:472]
 read :0 when the quantity runs past the limit or past four bytes
bss local smf_playing u64 [476:477] :1 while a piece plays
bss local smf_division u64 [478:479] :ticks a quarter note
bss local smf_tempo u64 [480:481] :microseconds a quarter note
bss local smf_position u64 [482:483] :the piece's position, 32.32 ticks
bss local smf_increment u64 [484:485] :the position's step a period
bss local smf_track_count u64 [486:487] :the tracks read
bss local smf_tracks [488:489] :the track records
