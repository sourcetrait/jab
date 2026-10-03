set VOICES u64 [5] :the font's voices
set NOTE_VOICES u64 [6] :the most voices a note starts, however many zones fit it
set GENERATORS u64 [7] :the rows of a generator table
set TOP u64 [8] :the envelope's full level, 16.16, as synth.S's
set SILENCE_CB256 u64 [9] :full silence, centibels times 256
set ATTENUATION_MAX u64 [10] :the most attenuation a generator asks for, centibels
set PERIOD_CB256 u64 [11] :what a period adds at 100 dB a second, the rate of 0 timecents
set CUT_CB256 u64 [12] :a release rate that ends a voice within a period, for an exclusive class
set CB_TO_CENTS u64 [13] :cents = -(cB * CB_TO_CENTS) >> 6
set FULL_SCALE_SIXTH u64 [14] :127 to the sixth
set TAG_RIFF u32 [16] :the chunk tags as the little-endian words a read sees
set TAG_SFBK u32 [17]
set TAG_LIST u32 [18]
set TAG_INFO u32 [19]
set TAG_SDTA u32 [20]
set TAG_SMPL u32 [21]
set TAG_PDTA u32 [22]
set TAG_PHDR u32 [23]
set TAG_PBAG u32 [24]
set TAG_PMOD u32 [25]
set TAG_PGEN u32 [26]
set TAG_INST u32 [27]
set TAG_IBAG u32 [28]
set TAG_IMOD u32 [29]
set TAG_IGEN u32 [30]
set TAG_SHDR u32 [31]
set HYDRA_PHDR u64 [33] :the hydra chunks' rows, in the order the file holds them
set HYDRA_PBAG u64 [34]
set HYDRA_PMOD u64 [35]
set HYDRA_PGEN u64 [36]
set HYDRA_INST u64 [37]
set HYDRA_IBAG u64 [38]
set HYDRA_IMOD u64 [39]
set HYDRA_IGEN u64 [40]
set HYDRA_SHDR u64 [41]
set HYDRA_COUNT u64 [42]
set PHDR_SIZE u64 [44] :bytes in a preset header
set PHDR_PRESET u16 [45]
set PHDR_BANK u16 [46]
set PHDR_BAG u16 [47]
set BAG_SIZE u64 [48] :bytes in a bag, a zone
set BAG_GEN u16 [49]
set GEN_SIZE u64 [50] :bytes in a generator
set GEN_OP u16 [51]
set GEN_AMOUNT i16 [52]
set INST_SIZE u64 [53] :bytes in an instrument
set INST_BAG u16 [54]
set SHDR_SIZE u64 [55] :bytes in a sample header
set SHDR_START u32 [56]
set SHDR_END u32 [57]
set SHDR_LOOP_START u32 [58]
set SHDR_LOOP_END u32 [59]
set SHDR_RATE u32 [60]
set SHDR_KEY u8 [61]
set SHDR_CORRECTION i8 [62]
set SHDR_TYPE u16 [63]
set GEN_START_OFFSET u16 [65] :the generators read, by the specification's numbers
set GEN_END_OFFSET u16 [66]
set GEN_LOOP_START_OFFSET u16 [67]
set GEN_LOOP_END_OFFSET u16 [68]
set GEN_START_COARSE u16 [69]
set GEN_END_COARSE u16 [70]
set GEN_PAN u16 [71]
set GEN_DELAY u16 [72]
set GEN_ATTACK u16 [73]
set GEN_HOLD u16 [74]
set GEN_DECAY u16 [75]
set GEN_SUSTAIN u16 [76]
set GEN_RELEASE u16 [77]
set GEN_INSTRUMENT u16 [78]
set GEN_KEY_RANGE u16 [79]
set GEN_VEL_RANGE u16 [80]
set GEN_LOOP_START_COARSE u16 [81]
set GEN_KEYNUM u16 [82]
set GEN_VELOCITY u16 [83]
set GEN_ATTENUATION u16 [84]
set GEN_LOOP_END_COARSE u16 [85]
set GEN_COARSE_TUNE u16 [86]
set GEN_FINE_TUNE u16 [87]
set GEN_SAMPLE u16 [88]
set GEN_SAMPLE_MODES u16 [89]
set GEN_SCALE_TUNING u16 [90]
set GEN_EXCLUSIVE u16 [91]
set GEN_ROOT_KEY u16 [92]
set FV_STAGE u8 [94] :a font voice's fields, a STAGE_*
set FV_CHANNEL u8 [95]
set FV_NOTE u8 [96] :the MIDI note, for identity
set FV_VELOCITY u8 [97]
set FV_SOURCE u8 [98] :whose note, SOURCE_LIVE or SOURCE_FILE
set FV_HELD u8 [99] :released under the pedal and waiting for it
set FV_LOOP u8 [100] :0 none, 1 continuous, 3 until released
set FV_EXCLUSIVE u8 [101]
set FV_AGE u32 [102] :from the note-on counter
set FV_PAN i16 [103] :in 0.1%
set FV_SUSTAIN u16 [104] :centibels
set FV_ATTENUATION u32 [105] :the zone's attenuation as an amplitude, 16.16
set FV_DECAY_RATE u32 [106] :centibels times 256 a period
set FV_RELEASE_RATE u32 [107]
set FV_ENV i32 [108] :the envelope's attenuation, centibels times 256
set FV_HOLD u32 [109] :frames
set FV_ATTACK_DELTA u32 [110] :the level's step a frame in the attack
set FV_COUNTDOWN u32 [111] :frames left in the delay or the hold
set FV_BASE_STEP u32 [112] :16.16, unbent
set FV_POS u64 [113] :the sample index above a 16-bit fraction
set FV_END u64 [114] :the end as a position
set FV_LOOP_END u64 [115]
set FV_LOOP_LENGTH u64 [116] :0 with no loop
set FV_LEVEL i64 [117] :0 to TOP
set FV_DELTA i64 [118] :a frame
set FV_STEP u32 [119] :16.16, bent
set FV_GAIN_LEFT u32 [120] :16.16
set FV_GAIN_RIGHT u32 [121]
set FV_SIZE u64 [122] :bytes in a voice
set STAGE_FREE u8 [123]
set STAGE_DELAY u8 [124]
set STAGE_ATTACK u8 [125]
set STAGE_HOLD u8 [126]
set STAGE_DECAY u8 [127]
set STAGE_SUSTAIN u8 [128]
set STAGE_RELEASE u8 [129]
set STAGE_ENDING u8 [130]
ecall sys_midi_soundfont buffer address,length u64 > status a0 u64,presets a1 u64,instruments a2 u64,samples a3 u64 [135:161] :plays the notes after through the SoundFont 2 file at the buffer, read in place, or unloads it with a length of 0
 buffer :ends the run unless the whole file lies inside the program's window
 status :0, sound_open's code, 3 for a file that is not a SoundFont, 4 for one that is unsound
 presets :0 unless the status is 0, as are the other counts
call soundfont_init > age sf_age u64 [162:165] :nothing loaded and every voice free, falling into soundfont_unload
call soundfont_unload > loaded soundfont_loaded u64 [166:176] :the file forgotten and every voice free at once
call local soundfont_load file address,length u64 > status a0 u64,presets a1 u64,instruments a2 u64,samples a3 u64 [178:316] :walks the RIFF form's three lists, keeping the sample data and the nine hydra chunks by address and record count
 status :0, or sys_midi_soundfont's 3 or 4
j local notfont [317:319] :soundfont_load's answer for a file that is not a SoundFont
j local unsound [320:334] :soundfont_load's answer for one that is unsound
call local sf_u32 at address > word a0 u32 [336:341]
 at :2-aligned, read as two halves
call local sf_chunk cursor address,limit address > tag a0 u32,data a1 address,size a2 u32,next a3 address [343:363]
 tag :0 when no whole chunk lies before the limit
 next :past the chunk, padded to even
call local sf_find_preset bank u64,program u64 > preset a0 i64 [365:386]
 preset :the first carrying both, -1 when none does
call local sf_zone_gens bags u64,gens u64,zone u64 > first a0 address,end a1 address [388:417]
 bags :the bag chunk's hydra row, as gens is the generator chunk's
 first :the zone's first generator, 0 when the zone or its indices lie outside the chunks
call local sf_zone_fits first address,end address,key u8,velocity u8 > fits a0 bool [419:445]
 fits :1 when the zone's key and velocity ranges, where it has them, hold both
call local sf_apply first address,end address,table address > rows 0(table) i16,clobber a0 [447:460] :each generator sets its row of the table, an operator past it ignored
call local sf_add_preset zone address,preset address > rows 0(zone) i16 [462:484] :adds the preset table to the zone table, row by row, for the value generators alone
call soundfont_note_on channel u64,key u64,velocity u64 > clobber a0-a3 [485:606] :starts the note through the font: the channel's preset, its zones holding the key and velocity, and under each every instrument zone that does too, up to NOTE_VOICES
call local sf_instrument instrument u64 > count s3 u64,clobber a0-a3 [608:693] :starts a voice for every zone of the instrument holding the key and velocity
 instrument :with the channel in s0, the key in s1, and the velocity in s2
 count :on by each voice started
call local sf_voice_start table address,channel u8,note u8,velocity u8 > started a0 bool,clobber a1 [695:985] :starts a voice from the generator table
 started :0 when the sample is not one the kernel plays, a ROM sample, one past the data, an empty range
call local sf_ratio cents i64 > ratio a0 u64 [987:1023]
 ratio :2 to the cents over 1200 in 16.16, 0 below the tables' reach and held at 31 octaves up
call local sf_frames timecents i64 > frames a0 u64 [1025:1038]
 frames :held below 2^31
call local sf_period_rate timecents i64 > rate a0 u64 [1040:1057]
 timecents :a decay or release time, that of a 100 dB change
 rate :the change a period makes, centibels times 256, at least 1 and held below 2^31
call local sf_take > voice a0 address [1059:1085]
 voice :a free one, else the oldest releasing, else the oldest of all
call local sf_exclusive channel u8,class u8 [1087:1109] :every sounding voice of the class on the channel goes to a release gone within a period
call local sf_release voice address [1111:1137] :the voice goes to its release unless there already, a loop lasting until the key's release ending
call local sf_level_cb level i64 > attenuation a0 u64 [1139:1177]
 attenuation :the level's, centibels times 256
call soundfont_note_off channel u64,note u64 > clobber a0 [1178:1227] :releases every voice of the current source sounding the note on the channel, or marks it held while the pedal is down
call soundfont_pedal_up channel u64 > clobber a0 [1228:1257] :releases every voice of the channel held under the pedal
call soundfont_channel_off channel u64,now bool > clobber a0 [1258:1296] :every voice of the channel from the current source freed at once with now set, else released
call soundfont_all_off now bool,source i64 > clobber a0 [1297:1333] :every voice of the source, or every voice with SOURCE_ANY, freed at once with now set, else released
call soundfont_sounding > sounding a0 bool [1334:1348]
 sounding :1 while any font voice sounds
call soundfont_render accumulator address,frames u64 > mix 0(accumulator),clobber a0,a2-a7 [1349:1370] :adds every sounding font voice into the accumulator, two 32-bit samples a frame; nothing with no font loaded
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
rodata local sf_hydra [1617:1637] :each hydra chunk's tag, record size, and least records, its terminal counted
rodata local sf_defaults 61 i16 [1638:1645] :the generators' defaults, a row a generator
rodata local sf_value 61 u8 [1647:1654] :1 for a generator the preset level adds to
rodata local sf_log2 16 u8 [1656:1661] :the logarithm of 1 + m/16, times 256
bss soundfont_loaded u64 [1666:1667] :1 while a font is loaded
bss local sf_samples address [1668:1669] :the sample data
bss local sf_sample_count u64 [1670:1671] :its 16-bit samples
bss local sf_hydra_ptr 9 address [1672:1673] :each hydra chunk's records
bss local sf_hydra_count 9 u64 [1674:1675] :each hydra chunk's record count
bss local sf_age u64 [1676:1677] :the note-on counter
bss local sf_voices [1678:1680] :the font's voices
bss local sf_gen 61 i16 [1681:1682] :the zone's generator table
bss local sf_preset_gen 61 i16 [1683:1684] :the preset's sum
