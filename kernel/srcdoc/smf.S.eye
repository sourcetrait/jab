ecall sys_midi_play source addr,length u64 > status a0 u64 [25:39] :plays the Standard MIDI File, whatever was playing stopped with its notes released, from the next period
 source :ends the run unless the whole file lies inside the program's window
 status :0, sound_open's code, or 3 when the file is not one the player takes
ecall sys_midi_stop > status a0 u64 [40:49] :the piece stops where it is, its notes released
 status :0, or sound_open's code
ecall sys_midi_playing > playing a0 bool [50:56]
 playing :1 while a piece plays
call smf_stop > playing smf_playing u64,clobber a0-a1 [57:70] :stops the sequencer and releases the file's own voices, the calls' left sounding
call local smf_load file addr,length u64 > status a0 u64,playing smf_playing u64,clobber a1-a2 [72:191] :reads the file into the tracks and the clock and starts the piece
 status :0, or 3 when the file is refused
call local smf_clock > increment smf_increment u64 [193:204] :the position's step a period from the tempo and the division, 32.32 ticks
call local smf_be32 at addr > value a0 u32 [206:218]
call local smf_be16 at addr > value a0 u16 [220:227]
call smf_step > position smf_position u64,playing smf_playing u64,clobber a0 [228:296] :one period of the piece, every track's events up to the moved position fired, the piece ended once every track has
call local smf_event track addr > clobber a0-a3 [298:428] :fires the event at the track's cursor and moves past it and its next delta, a bad read or the end-of-track event ending the track
call local smf_delta track addr > clobber a0-a2 [430:450] :adds the delta at the cursor to the track's tick and moves past it, a track with none left done
call local smf_varint at addr,limit addr > value a0 u64,next a1 addr,read a2 bool [452:472]
 read :0 when the quantity runs past the limit or past four bytes
