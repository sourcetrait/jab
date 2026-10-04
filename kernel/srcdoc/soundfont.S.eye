ecall sys_midi_soundfont buffer addr,length u64 > status a0 u64,presets a1 u64,instruments a2 u64,samples a3 u64 [135:161] :plays the notes after through the SoundFont 2 file at the buffer, read in place, or unloads it with a length of 0
 buffer :ends the run unless the whole file lies inside the program's window
 status :0, sound_open's code, 3 for a file that is not a SoundFont, 4 for one that is unsound
 presets :0 unless the status is 0, as are the other counts
call soundfont_init > age sf_age u64 [162:165] :nothing loaded and every voice free, falling into soundfont_unload
call soundfont_unload > loaded soundfont_loaded u64 [166:176] :the file forgotten and every voice free at once
call local soundfont_load file addr,length u64 > status a0 u64,presets a1 u64,instruments a2 u64,samples a3 u64 [178:316] :walks the RIFF form's three lists, keeping the sample data and the nine hydra chunks by address and record count
 status :0, or sys_midi_soundfont's 3 or 4
j local notfont [317:319] :soundfont_load's answer for a file that is not a SoundFont
j local unsound [320:334] :soundfont_load's answer for one that is unsound
call local sf_u32 at addr > word a0 u32 [336:341]
 at :2-aligned, read as two halves
call local sf_chunk cursor addr,limit addr > tag a0 u32,data a1 addr,size a2 u32,next a3 addr [343:363]
 tag :0 when no whole chunk lies before the limit
 next :past the chunk, padded to even
call local sf_find_preset bank u64,program u64 > preset a0 i64 [365:386]
 preset :the first carrying both, -1 when none does
call local sf_zone_gens bags u64,gens u64,zone u64 > first a0 addr,end a1 addr [388:417]
 bags :the bag chunk's hydra row, as gens is the generator chunk's
 first :the zone's first generator, 0 when the zone or its indices lie outside the chunks
call local sf_zone_fits first addr,end addr,key u8,velocity u8 > fits a0 bool [419:445]
 fits :1 when the zone's key and velocity ranges, where it has them, hold both
call local sf_apply first addr,end addr,table addr > rows 0(table) i16,clobber a0 [447:460] :each generator sets its row of the table, an operator past it ignored
call local sf_add_preset zone addr,preset addr > rows 0(zone) i16 [462:484] :adds the preset table to the zone table, row by row, for the value generators alone
call soundfont_note_on channel u64,key u64,velocity u64 > clobber a0-a3 [485:606] :starts the note through the font: the channel's preset, its zones holding the key and velocity, and under each every instrument zone that does too, up to NOTE_VOICES
call local sf_instrument instrument u64 > count s3 u64,clobber a0-a3 [608:693] :starts a voice for every zone of the instrument holding the key and velocity
 instrument :with the channel in s0, the key in s1, and the velocity in s2
 count :on by each voice started
call local sf_voice_start table addr,channel u8,note u8,velocity u8 > started a0 bool,clobber a1 [695:985] :starts a voice from the generator table
 started :0 when the sample is not one the kernel plays, a ROM sample, one past the data, an empty range
call local sf_ratio cents i64 > ratio a0 u64 [987:1023]
 ratio :2 to the cents over 1200 in 16.16, 0 below the tables' reach and held at 31 octaves up
call local sf_frames timecents i64 > frames a0 u64 [1025:1038]
 frames :held below 2^31
call local sf_period_rate timecents i64 > rate a0 u64 [1040:1057]
 timecents :a decay or release time, that of a 100 dB change
 rate :the change a period makes, centibels times 256, at least 1 and held below 2^31
call local sf_take > voice a0 addr [1059:1085]
 voice :a free one, else the oldest releasing, else the oldest of all
call local sf_exclusive channel u8,class u8 [1087:1109] :every sounding voice of the class on the channel goes to a release gone within a period
call local sf_release voice addr [1111:1137] :the voice goes to its release unless there already, a loop lasting until the key's release ending
call local sf_level_cb level i64 > attenuation a0 u64 [1139:1177]
 attenuation :the level's, centibels times 256
call soundfont_note_off channel u64,note u64 > clobber a0 [1178:1227] :releases every voice of the current source sounding the note on the channel, or marks it held while the pedal is down
call soundfont_pedal_up channel u64 > clobber a0 [1228:1257] :releases every voice of the channel held under the pedal
call soundfont_channel_off channel u64,now bool > clobber a0 [1258:1296] :every voice of the channel from the current source freed at once with now set, else released
call soundfont_all_off now bool,source i64 > clobber a0 [1297:1333] :every voice of the source, or every voice with SOURCE_ANY, freed at once with now set, else released
call soundfont_sounding > sounding a0 bool [1334:1348]
 sounding :1 while any font voice sounds
call soundfont_render accumulator addr,frames u64 > mix 0(accumulator),clobber a0,a2-a7 [1349:1370] :adds every sounding font voice into the accumulator, two 32-bit samples a frame; nothing with no font loaded
j local voice [1371:1428] :soundfont_render's loop over the voices
j local gains [1429:1504] :the step and the gains, past the envelope's period
j local frame [1505:1517] :the loop over a voice's frames
j local env_attack [1518:1528] :a frame of the attack
j local env_hold [1529:1533] :a frame of the hold
j local env_run [1534:1540] :a frame of the decay, sustain, or release
j local sample [1541:1576] :a frame's sample into the accumulator
j local advance_silent [1577:1581] :a frame of the delay, nothing added
j local voice_ends [1582:1583] :the voice is done, its sample or its release ended
j local voice_done [1584:1590] :the voice's state kept for the next period
j local free_voice [1591:1592] :an ending voice reached silence
j local next_voice [1593:1610] :the step to the next voice
j local done [1611:1612] :soundfont_render's return
