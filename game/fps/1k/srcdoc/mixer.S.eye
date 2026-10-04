call local sounds_load disk s0 u64 > samples sound_at SOUND_COUNT addr,frames sound_frames SOUND_COUNT u64,cursor sound_cursor addr,clobber a0-a4,a7 [76:180] :every sound of the engine's stems read off the disk into the sound arena; one not there or not fitting is named on the UART of a debug build and left as none
call local sound_start sound u64,at_player bool,x f64,y f64,z f64 > channel channels MIX_CHANNELS*CHANNEL_SIZE u8,clobber a4-a5,fa3-fa4 [182:298] :a sound started on a channel, at the player or from a world point, full near the eye, nothing past the range, panned by its side
 sound :a SOUND_*, one with no samples ignored
 at_player :1 at the player, else from the point
 channel :a free channel, else the one with the least left to play
call local mixer_update > channels channels MIX_CHANNELS*CHANNEL_SIZE u8,clobber a0-a7 [299:393] :the stream kept MIX_AHEAD frames ahead, what the ring lacks mixed from every channel and written
