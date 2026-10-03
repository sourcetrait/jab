set MIX_CHANNELS [1] :the channels mixed
set MIX_AHEAD [2] :the frames the stream is kept ahead of what plays, three periods
set MIX_MAX [3] :the most frames mixed a frame
set CHANNEL_DATA addr [4] :a channel's samples
set CHANNEL_FRAMES u64 [5] :the sound's frames
set CHANNEL_POSITION u64 [6] :the next frame to play
set CHANNEL_LEFT i32 [7] :the left gain in 256ths
set CHANNEL_RIGHT i32 [8] :the right gain in 256ths
set CHANNEL_SIZE [9] :a channel's bytes
set SOUND_BYTES [10] :the sound arena's bytes
rodata local sound_stems SOUND_COUNT addr [14:20] :the engine's stems by SOUND_*
rodata local k_mix_near_d f64 [21:22] :the distance from the eye within which a sound is full
rodata local k_mix_range_d f64 [23:24] :the distance past that over which it falls to nothing
rodata local k_mix_pan_d f64 [25:26] :the pan at most either way
rodata local k_gain_full_d f64 [27:28] :a sound's full gain, three eighths in 256ths, so three sounds together stay under full scale
rodata local k_mix_level_eps_d f64 [29:30] :a level distance under which a sound is centred
rodata local word_sound_g1_shot 8 u8 [31:32]
rodata local word_sound_g1_reload 10 u8 [33:34]
rodata local word_sound_g1_empty 9 u8 [35:36]
rodata local word_sound_g1_bolt 8 u8 [37:38]
rodata local word_sound_footstep1 10 u8 [39:40]
rodata local word_sound_footstep2 10 u8 [41:42]
rodata local word_sound_servo 6 u8 [43:44]
rodata local word_sound_alert 6 u8 [45:46]
rodata local word_sound_spark 6 u8 [47:48]
rodata local word_sound_struck 7 u8 [49:50]
rodata local word_sound_destroy 8 u8 [51:52]
rodata local word_sound_pickup 7 u8 [53:54]
rodata local word_sound_door_open 10 u8 [55:56]
rodata local word_sound_door_close 11 u8 [57:58]
rodata local word_sound_gate 5 u8 [59:60]
rodata local word_sound_respawn 8 u8 [61:62]
rodata local word_sound_dir 8 u8 [63:64]
rodata local word_pcm_ext 5 u8 [65:67]
rodata local msg_sound 12 u8 [68:69]
rodata local msg_sounds 13 u8 [70:72]
call local sounds_load disk s0 u64 > samples sound_at SOUND_COUNT addr,frames sound_frames SOUND_COUNT u64,cursor sound_cursor addr,clobber a0-a4,a7 [76:180] :every sound of the engine's stems read off the disk into the sound arena; one not there or not fitting is named on the UART of a debug build and left as none
call local sound_start sound u64,at_player bool,x f64,y f64,z f64 > channel channels MIX_CHANNELS*CHANNEL_SIZE u8,clobber a4-a5,fa3-fa4 [182:298] :a sound started on a channel, at the player or from a world point, full near the eye, nothing past the range, panned by its side
 sound :a SOUND_*, one with no samples ignored
 at_player :1 at the player, else from the point
 channel :a free channel, else the one with the least left to play
call local mixer_update > channels channels MIX_CHANNELS*CHANNEL_SIZE u8,clobber a0-a7 [299:393] :the stream kept MIX_AHEAD frames ahead, what the ring lacks mixed from every channel and written
bss local sound_cursor addr [397:398] :the sound arena's next free byte
bss local sound_at SOUND_COUNT addr [399:400] :each sound's samples in the arena, 0 for none
bss local sound_frames SOUND_COUNT u64 [401:402] :each sound's frames
bss local channels MIX_CHANNELS*CHANNEL_SIZE u8 [403:404] :the channels, CHANNEL_* fields
bss local mixbuf MIX_MAX*2 i32 [405:407] :the mix, a pair a frame, clipped in place to 16-bit pairs
bss local sound_arena SOUND_BYTES u8 [408:409] :the sounds' samples
