# soundfont.S

The SoundFont: an SF2 file the program holds, read in place by
jab.sys.midi.soundfont, and the sampled voices that play through it in
place of the chip-tune voices of synth.S once it is loaded. The file is the
SoundFont 2.04 specification's RIFF form: an INFO list, an sdta list holding
the 16-bit sample data, and a pdta list holding the nine hydra chunks, the
presets with their zones and generators, the instruments with theirs, and
the sample headers. Loading keeps only where each chunk sits and how many
records it holds. A note on finds the channel's preset by bank and program
(bank 128 for the percussion channel; a bank with no such preset falls back
to bank 0, a kit to kit 0), walks the preset's zones for the ones holding
the key and velocity, and for each instrument zone under them that does too
starts a voice: the sample's start, end, and loop from its header with the
zone's offsets; the pitch from the root key, the tuning, and the sample's
rate as a 16.16 step a frame through the data; the volume envelope in the
specification's timecents and centibels; the pan, the attenuation, an
exclusive class. A zone's generators are a table the specification's
defaults fill first, the instrument level replacing and the preset level
adding, so one more generator honoured is one more row read. Modulators,
the filter, and the LFOs are not read; the default modulators the
specification names for velocity, volume, expression, pan, and the bend are
applied by rule. Each voice renders a period at a time into the mixer's
accumulator (sound.S): the sample linearly interpolated at its position,
the envelope's level in 16.16 stepping a frame, the gains and the bent step
recomputed a period. Every routine keeps the s registers unless its
signature says otherwise, since the note calls run inside the stream's
refill.

## .set VOICES

`u64`: the font's voices.

## .set NOTE_VOICES

`u64`: the most voices a note starts, however many zones fit it.

## .set GENERATORS

`u64`: the rows of a generator table.

## .set TOP

`u64`: the envelope's full level, 16.16, as synth.S's.

## .set SILENCE_CB256

`u64`: full silence, centibels times 256.

## .set ATTENUATION_MAX

`u64`: the most attenuation a generator asks for, centibels.

## .set PERIOD_CB256

`u64`: what a period adds at 100 dB a second, the rate of 0 timecents.

## .set CUT_CB256

`u64`: a release rate that ends a voice within a period, for an exclusive class.

## .set CB_TO_CENTS

`u64`: cents = -(cB * CB_TO_CENTS) >> 6.

A centibel is 19.9375 cents of amplitude: 20 log10(2) = 6.0206 dB an
octave.

## .set FULL_SCALE_SIXTH

`u64`: 127 to the sixth.

Velocity, volume, and expression are each squared over the full scale, the
specification's concave default modulators.

## .set TAG_RIFF

`u32`: the chunk tags as the little-endian words a read sees.

## .set TAG_SFBK

`u32`.

## .set TAG_LIST

`u32`.

## .set TAG_INFO

`u32`.

## .set TAG_SDTA

`u32`.

## .set TAG_SMPL

`u32`.

## .set TAG_PDTA

`u32`.

## .set TAG_PHDR

`u32`.

## .set TAG_PBAG

`u32`.

## .set TAG_PMOD

`u32`.

## .set TAG_PGEN

`u32`.

## .set TAG_INST

`u32`.

## .set TAG_IBAG

`u32`.

## .set TAG_IMOD

`u32`.

## .set TAG_IGEN

`u32`.

## .set TAG_SHDR

`u32`.

## .set HYDRA_PHDR

`u64`: the hydra chunks' rows, in the order the file holds them.

## .set HYDRA_PBAG

`u64`.

## .set HYDRA_PMOD

`u64`.

## .set HYDRA_PGEN

`u64`.

## .set HYDRA_INST

`u64`.

## .set HYDRA_IBAG

`u64`.

## .set HYDRA_IMOD

`u64`.

## .set HYDRA_IGEN

`u64`.

## .set HYDRA_SHDR

`u64`.

## .set HYDRA_COUNT

`u64`.

## .set PHDR_SIZE

`u64`: bytes in a preset header.

## .set PHDR_PRESET

`u16`.

## .set PHDR_BANK

`u16`.

## .set PHDR_BAG

`u16`.

## .set BAG_SIZE

`u64`: bytes in a bag, a zone.

## .set BAG_GEN

`u16`.

## .set GEN_SIZE

`u64`: bytes in a generator.

## .set GEN_OP

`u16`.

## .set GEN_AMOUNT

`i16`.

## .set INST_SIZE

`u64`: bytes in an instrument.

## .set INST_BAG

`u16`.

## .set SHDR_SIZE

`u64`: bytes in a sample header.

## .set SHDR_START

`u32`.

## .set SHDR_END

`u32`.

## .set SHDR_LOOP_START

`u32`.

## .set SHDR_LOOP_END

`u32`.

## .set SHDR_RATE

`u32`.

## .set SHDR_KEY

`u8`.

## .set SHDR_CORRECTION

`i8`.

## .set SHDR_TYPE

`u16`.

## .set GEN_START_OFFSET

`u16`: the generators read, by the specification's numbers.

## .set GEN_END_OFFSET

`u16`.

## .set GEN_LOOP_START_OFFSET

`u16`.

## .set GEN_LOOP_END_OFFSET

`u16`.

## .set GEN_START_COARSE

`u16`.

## .set GEN_END_COARSE

`u16`.

## .set GEN_PAN

`u16`.

## .set GEN_DELAY

`u16`.

## .set GEN_ATTACK

`u16`.

## .set GEN_HOLD

`u16`.

## .set GEN_DECAY

`u16`.

## .set GEN_SUSTAIN

`u16`.

## .set GEN_RELEASE

`u16`.

## .set GEN_INSTRUMENT

`u16`.

## .set GEN_KEY_RANGE

`u16`.

## .set GEN_VEL_RANGE

`u16`.

## .set GEN_LOOP_START_COARSE

`u16`.

## .set GEN_KEYNUM

`u16`.

## .set GEN_VELOCITY

`u16`.

## .set GEN_ATTENUATION

`u16`.

## .set GEN_LOOP_END_COARSE

`u16`.

## .set GEN_COARSE_TUNE

`u16`.

## .set GEN_FINE_TUNE

`u16`.

## .set GEN_SAMPLE

`u16`.

## .set GEN_SAMPLE_MODES

`u16`.

## .set GEN_SCALE_TUNING

`u16`.

## .set GEN_EXCLUSIVE

`u16`.

## .set GEN_ROOT_KEY

`u16`.

## .set FV_STAGE

`u8`: a font voice's fields, a STAGE_*.

## .set FV_CHANNEL

`u8`.

## .set FV_NOTE

`u8`: the MIDI note, for identity.

## .set FV_VELOCITY

`u8`.

## .set FV_SOURCE

`u8`: whose note, SOURCE_LIVE or SOURCE_FILE.

## .set FV_HELD

`u8`: released under the pedal and waiting for it.

## .set FV_LOOP

`u8`: 0 none, 1 continuous, 3 until released.

## .set FV_EXCLUSIVE

`u8`.

## .set FV_AGE

`u32`: from the note-on counter.

## .set FV_PAN

`i16`: in 0.1%.

## .set FV_SUSTAIN

`u16`: centibels.

## .set FV_ATTENUATION

`u32`: the zone's attenuation as an amplitude, 16.16.

## .set FV_DECAY_RATE

`u32`: centibels times 256 a period.

## .set FV_RELEASE_RATE

`u32`.

## .set FV_ENV

`i32`: the envelope's attenuation, centibels times 256.

## .set FV_HOLD

`u32`: frames.

## .set FV_ATTACK_DELTA

`u32`: the level's step a frame in the attack.

## .set FV_COUNTDOWN

`u32`: frames left in the delay or the hold.

## .set FV_BASE_STEP

`u32`: 16.16, unbent.

## .set FV_POS

`u64`: the sample index above a 16-bit fraction.

## .set FV_END

`u64`: the end as a position.

## .set FV_LOOP_END

`u64`.

## .set FV_LOOP_LENGTH

`u64`: 0 with no loop.

## .set FV_LEVEL

`i64`: 0 to TOP.

## .set FV_DELTA

`i64`: a frame.

## .set FV_STEP

`u32`: 16.16, bent.

## .set FV_GAIN_LEFT

`u32`: 16.16.

## .set FV_GAIN_RIGHT

`u32`.

## .set FV_SIZE

`u64`: bytes in a voice.

## .set STAGE_FREE

`u8`.

## .set STAGE_DELAY

`u8`.

## .set STAGE_ATTACK

`u8`.

## .set STAGE_HOLD

`u8`.

## .set STAGE_DECAY

`u8`.

## .set STAGE_SUSTAIN

`u8`.

## .set STAGE_RELEASE

`u8`.

## .set STAGE_ENDING

`u8`.

## soundfont_load

The INFO list is read for its shape only; the smpl chunk inside the sdta
list is the sample data; the pdta list's nine hydra chunks come in their
order, each a whole number of its records and at least its terminal.

## sf_chunk

A chunk sits on a 2-byte boundary only, which is why sf_u32 reads halves.

## sf_add_preset

A range, an index, a substitution, or a sample generator at the preset
level is a filter or ignored, never a sum.

## soundfont_note_on

A global zone is the first, when its last generator is not the instrument;
its generators go under every zone's. The preset's sum is the global zone's
generators, then this zone's. The instrument's generators replace the
defaults and the preset's add to them.

## sf_instrument

Its table is the defaults, the instrument's global zone, the zone itself,
then the preset's sum added.

## sf_voice_start

Keeps s0 to s3, the note's context. The start, the end, and the loop's start
and end are the header's plus the zone's fine and coarse offsets, the start
inside the data and before the end. The loop is the mode's low two bits, 2
meaning none, with its points inside the sound in order, else none. The
pitch in cents is the key's distance from the root at the scale tuning, the
coarse and fine tuning, and the header's correction. An exclusive class cuts
the class's other voices on the channel. The pan is held to the
specification's range; the sustain is in centibels and the attenuation an
amplitude. The decay and release are centibels times 256 a period, at least
1. The envelope's delay, attack, and hold are in frames, the attack's step a
frame TOP over its frames; a delay counts down first, an attack climbs, and
without either the level starts at the top, holding or decaying.

## sf_ratio

The semitone's entry times the cent's entry, shifted by the octave
(cents.inc).

## sf_release

From the attack or the hold the envelope's attenuation is read off its
level, since the release falls in decibels from wherever the voice is.

## sf_level_cb

From the level's logarithm: the leading bit found by a walk, the next four
bits through sf_log2.

## soundfont_render

Per voice and period: the envelope's attenuation moved on through its decay
or release, past the hold, to the sustain or to silence, and the level's
step a frame toward the amplitude it names; the step bent by the channel
over two semitones; the gains from the velocity, the volume, and the
expression each squared over full scale, the zone's attenuation, and each
side's share of the pan summed with the channel's. The frame loop holds s5
the position, s6 the step, s7 the end, s8 the loop's end, s9 its length,
s10 the level, s11 its step, a2 and a3 the gains, a4 the stage, a5 the
countdown, t6 the samples, a6 the accumulator, a7 the frames left. Per
frame: the envelope on, the delay silent and then the attack begun, through
the attack and hold by the frame, else by the step; the sample interpolated
between the two points about the position by its fraction, scaled by the
level and the gains into both sides; the position on by the step, around
the loop or to the end.

## sf_hydra

Each hydra chunk's tag, record size, and least records, its terminal counted.

## sf_defaults

`61 i16`: the generators' defaults, a row a generator.

The filter open, every time the least, the ranges the whole keyboard and
every velocity, the scale tuning a semitone a key, the substitutions and
the root key unset.

## sf_value

`61 u8`: 1 for a generator the preset level adds to.

The ranges, the indices, the substitutions, and the sample generators are
not values the preset level adds to.

## sf_log2

`16 u8`: the logarithm of 1 + m/16, times 256.

## soundfont_loaded

`u64`: 1 while a font is loaded.

## sf_samples

`addr`: the sample data.

## sf_sample_count

`u64`: its 16-bit samples.

## sf_hydra_ptr

`9 addr`: each hydra chunk's records.

## sf_hydra_count

`9 u64`: each hydra chunk's record count.

## sf_age

`u64`: the note-on counter.

## sf_voices

The font's voices.

## sf_gen

`61 i16`: the zone's generator table.

## sf_preset_gen

`61 i16`: the preset's sum.
