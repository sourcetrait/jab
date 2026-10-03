set VOICES u64 [4] :the chip-tune voices
set CHANNELS u64 [5]
set PERCUSSION u64 [6] :the percussion channel
set TOP u64 [7] :the envelope's full level, 16.16 with the amplitude in the high half
set FRAMES_PER_MS u64 [8]
set LFO_HZ u32 [9] :the LFO's step for one hertz, 2^32 / JAB_SOUND_RATE
set BEND_SCALE u64 [10] :what a full bend of 8192 times the step, shifted down 29, moves it by
set VOICE_STAGE u8 [12] :a voice's fields, 0 free, 1 attack, 2 decay, 3 sustain, 4 release
set VOICE_CHANNEL u8 [13]
set VOICE_NOTE u8 [14] :the MIDI note, for identity
set VOICE_VELOCITY u8 [15]
set VOICE_WAVE u8 [16]
set VOICE_DUTY u8 [17]
set VOICE_HELD u8 [18] :released under the pedal and waiting for it
set VOICE_DEPTH u8 [19] :the vibrato's
set VOICE_PHASE u32 [20]
set VOICE_STEP u32 [21] :the note's own
set VOICE_DECAY u32 [22] :a frame, once the top is reached
set VOICE_SUSTAIN u32 [23] :the level the decay settles at
set VOICE_RELEASE_MS u32 [24]
set VOICE_LFO_PHASE u32 [25]
set VOICE_LFO_STEP u32 [26] :a frame
set VOICE_AGE u32 [27] :from the note-on counter
set VOICE_LFSR u32 [28] :the noise
set VOICE_SOURCE u8 [29] :whose note, SOURCE_LIVE or SOURCE_FILE
set VOICE_LEVEL i64 [30] :0 to TOP
set VOICE_DELTA i64 [31] :a frame
set VOICE_SIZE u64 [32] :bytes in a voice
set STAGE_ATTACK u8 [33]
set STAGE_DECAY u8 [34]
set STAGE_SUSTAIN u8 [35]
set STAGE_RELEASE u8 [36]
set DRUM_NOTE u8 [38] :a drum spec's own note, in the spare byte
set DRUM_FIRST u64 [39] :the first note of General MIDI's kit
set DRUM_LAST u64 [40] :its last
set DRUM_DEFAULT u64 [41] :the drum a note outside the map falls to
call synth_init > clobber a0 [46:85] :every voice free, every channel at program 0 in bank 0 with its controllers at their defaults, the instruments the General MIDI table, no SoundFont loaded
call synth_live [86:91] :the notes from here on are the calls' own
call synth_from_file [92:98] :the notes from here on are the file's
call synth_sounding > sounding a0 bool [99:111]
 sounding :1 while any voice sounds, the chip's or the font's
call local synth_reset_channel channel addr [113:122] :the channel record back to its default controllers, the program kept
call local synth_channel channel u64 > record a0 addr [124:130]
ecall sys_midi_program channel u64,program u64 > status a0 u64 [131:141] :the channel's instrument becomes that program for the notes after, each masked to its range
 status :0, or sound_open's code
j local midi_refused [143:147] :a MIDI call answering with sound_open's code, in a0
ecall sys_midi_note channel u64,note u64,velocity u64,on u64 > status a0 u64 [148:169] :starts the note on a voice with on set and a velocity, else releases every voice of the calls sounding it on the channel
 status :0, or sound_open's code
ecall sys_midi_control channel u64,control u64,value u64 > status a0 u64 [170:181] :synth_control's, for the calls
 status :0, or sound_open's code
call synth_control channel u64,control u64,value u64 > clobber a0-a3 [182:248] :the channel's controller takes the value, each masked to its range
call synth_program channel u64,program u64 > clobber a0-a1 [249:258] :the channel's program becomes that one, each masked
call synth_bend channel u64,bend u64 > clobber a0-a1 [259:271] :the channel's bend becomes that one, 14 bits with JAB_MIDI_BEND_CENTER for none, each masked
ecall sys_midi_bend channel u64,value u64 > status a0 u64 [272:281]
 status :0, or sound_open's code
ecall sys_midi_instrument program u64,spec addr > status a0 u64 [282:300] :that program plays the instrument the spec describes for the notes after
 spec :JAB_MIDI_INSTRUMENT_ENTRY bytes, ending the run unless inside the program's window
 status :0, or sound_open's code
ecall sys_midi_silence > status a0 u64 [301:319] :the piece stopped, every voice free at once, and every channel's controllers back to their defaults, the programs kept
 status :0, or sound_open's code
call synth_all_off now bool,source i64 > clobber a0 [320:351] :every voice of the source, or every voice with SOURCE_ANY, freed at once with now set, else released, the chip's and the font's
call synth_note_on channel u64,note u64,velocity u64 > clobber a0-a3 [352:466] :starts the note on a voice, or on the font's with a SoundFont loaded
call local synth_take > voice a0 addr [468:494]
 voice :a free one, else the oldest releasing, else the oldest of all
call local synth_pitch note u64 > step a0 u32 [496:507]
 step :the note's phase step a frame, 2^32 a cycle
call local synth_drum note u64 > spec a0 addr,sounds a1 u64 [509:527]
 note :in a1, a note on the percussion channel
 sounds :the note the drum sounds at
call synth_note_off channel u64,note u64 > clobber a0 [528:570] :releases every voice of the current source sounding the note on the channel, or marks it held while the pedal is down, the chip's and the font's
call local synth_release voice addr [572:590] :the voice goes to its release, falling to silence over its release time, or gone next frame with none
call local synth_pedal_up channel u64 > clobber a0 [592:617] :releases every voice of the channel held under the pedal, the chip's and the font's
call local synth_channel_off channel u64,now bool > clobber a0 [619:653] :every voice of the channel from the current source freed at once with now set, else released, the chip's and the font's
call synth_render accumulator addr,frames u64 > mix 0(accumulator),clobber a0,a2-a7 [654:672] :adds every sounding voice into the accumulator, two 32-bit samples a frame, the font's voices after the chip's
j local voice [673:736] :synth_render's loop over the voices
j local frame [737:843] :synth_render's loop over a voice's frames
j local next_voice [844:865] :synth_render's step to the next voice
rodata local synth_octave 12 u32 [870:884] :the top octave's steps, notes 120 to 131
macro instrument wave imm,duty imm,attack imm,decay imm,release imm,sustain imm,depth=0 imm,rate=0 imm [878:882] :assembles a JAB_MIDI_INSTRUMENT_ENTRY spec
rodata local synth_defaults [885:953] :the General MIDI defaults, a spec a program
macro drum wave imm,duty imm,decay imm,release imm,note imm [947:951] :assembles a drum's spec, which dies away and sounds at its own note
rodata local synth_drums [954:965] :the kit's specs
rodata local synth_drum_map 47 u8 [967:973] :each note of General MIDI's kit to a drum
bss local synth_age u64 [977:979] :the note-on counter
bss synth_channels [980:981] :the channel records
bss local synth_voices [982:983] :the voices
bss local synth_instruments [984:986] :a spec a program
bss synth_source u8 [987:988] :whose notes the next note on, note off, and channel off are
