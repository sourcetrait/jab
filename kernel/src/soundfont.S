.include "riscv.inc"
.include "jab.inc"
.include "synth.inc"

# The SoundFont: an SF2 file the program holds, read in place by
# jab.sys.midi.soundfont, and the sampled voices that play through it in
# place of the chip-tune voices of synth.S once it is loaded. The file
# is the SoundFont 2.04 specification's RIFF form: an INFO list, an
# sdta list holding the 16-bit sample data, and a pdta list holding
# the nine hydra chunks, the presets with their zones and generators,
# the instruments with theirs, and the sample headers. Loading keeps
# only where each chunk sits and how many records it holds. A note on
# finds the channel's preset by bank and program (bank 128 for the
# percussion channel; a bank with no such preset falls back to bank 0,
# a kit to kit 0), walks the preset's zones for the ones holding the
# key and velocity, and for each instrument zone under them that does
# too starts a voice: the sample's start, end, and loop from its header
# with the zone's offsets; the pitch from the root key, the tuning, and
# the sample's rate as a 16.16 step a frame through the data; the
# volume envelope in the specification's timecents and centibels; the
# pan, the attenuation, an exclusive class. A zone's generators are a
# table the specification's defaults fill first, the instrument level
# replacing and the preset level adding, so one more generator honoured
# is one more row read. Modulators, the filter, and the LFOs are not
# read; the default modulators the specification names for velocity,
# volume, expression, pan, and the bend are applied by rule. Each voice
# renders a period at a time into the mixer's accumulator (sound.S): the
# sample linearly interpolated at its position, the envelope's level
# in 16.16 stepping a frame, the gains and the bent step recomputed a
# period. Every routine here keeps the s registers unless it says
# otherwise, since the note calls run inside the stream's refill.
.set VOICES, JAB_MIDI_FONT_VOICES
# A note starts at most this many voices, however many zones fit it
.set NOTE_VOICES, 8
.set GENERATORS, 61
# The envelope's level runs 0 to TOP in 16.16, as synth.S's does
.set TOP, (65535 << 16)
# Attenuation in centibels times 256: full silence, the most a
# generator asks for, and how much a period adds at the rate of 100 dB
# a second, the rate a decay or release time of 0 timecents names
.set SILENCE_CB256, (1000 * 256)
.set ATTENUATION_MAX, 1440
.set PERIOD_CB256, ((1000 * 256 * JAB_SOUND_PERIOD) / JAB_SOUND_RATE)
# An exclusive class cuts a voice within a period
.set CUT_CB256, (1000 * 256)
# cents = -(cB * CB_TO_CENTS) >> 6, since a centibel is 19.9375 cents of
# amplitude: 20 log10(2) = 6.0206 dB an octave
.set CB_TO_CENTS, 1276
# 127 to the sixth: velocity, volume, and expression each squared over
# the full scale, the specification's concave default modulators
.set FULL_SCALE_SIXTH, 4195872914689

# The chunk tags as the little-endian words a read sees
.set TAG_RIFF, 0x46464952
.set TAG_SFBK, 0x6b626673
.set TAG_LIST, 0x5453494c
.set TAG_INFO, 0x4f464e49
.set TAG_SDTA, 0x61746473
.set TAG_SMPL, 0x6c706d73
.set TAG_PDTA, 0x61746470
.set TAG_PHDR, 0x72646870
.set TAG_PBAG, 0x67616270
.set TAG_PMOD, 0x646f6d70
.set TAG_PGEN, 0x6e656770
.set TAG_INST, 0x74736e69
.set TAG_IBAG, 0x67616269
.set TAG_IMOD, 0x646f6d69
.set TAG_IGEN, 0x6e656769
.set TAG_SHDR, 0x72646873

# The hydra, in the order the file holds them
.set HYDRA_PHDR, 0
.set HYDRA_PBAG, 1
.set HYDRA_PMOD, 2
.set HYDRA_PGEN, 3
.set HYDRA_INST, 4
.set HYDRA_IBAG, 5
.set HYDRA_IMOD, 6
.set HYDRA_IGEN, 7
.set HYDRA_SHDR, 8
.set HYDRA_COUNT, 9

# The records: a preset header, a bag (a zone), a generator, an
# instrument, a sample header
.set PHDR_SIZE, 38
.set PHDR_PRESET, 20
.set PHDR_BANK, 22
.set PHDR_BAG, 24
.set BAG_SIZE, 4
.set BAG_GEN, 0
.set GEN_SIZE, 4
.set GEN_OP, 0
.set GEN_AMOUNT, 2
.set INST_SIZE, 22
.set INST_BAG, 20
.set SHDR_SIZE, 46
.set SHDR_START, 20
.set SHDR_END, 24
.set SHDR_LOOP_START, 28
.set SHDR_LOOP_END, 32
.set SHDR_RATE, 36
.set SHDR_KEY, 40
.set SHDR_CORRECTION, 41
.set SHDR_TYPE, 44

# The generators read, by the specification's numbers
.set GEN_START_OFFSET, 0
.set GEN_END_OFFSET, 1
.set GEN_LOOP_START_OFFSET, 2
.set GEN_LOOP_END_OFFSET, 3
.set GEN_START_COARSE, 4
.set GEN_END_COARSE, 12
.set GEN_PAN, 17
.set GEN_DELAY, 33
.set GEN_ATTACK, 34
.set GEN_HOLD, 35
.set GEN_DECAY, 36
.set GEN_SUSTAIN, 37
.set GEN_RELEASE, 38
.set GEN_INSTRUMENT, 41
.set GEN_KEY_RANGE, 43
.set GEN_VEL_RANGE, 44
.set GEN_LOOP_START_COARSE, 45
.set GEN_KEYNUM, 46
.set GEN_VELOCITY, 47
.set GEN_ATTENUATION, 48
.set GEN_LOOP_END_COARSE, 50
.set GEN_COARSE_TUNE, 51
.set GEN_FINE_TUNE, 52
.set GEN_SAMPLE, 53
.set GEN_SAMPLE_MODES, 54
.set GEN_SCALE_TUNING, 56
.set GEN_EXCLUSIVE, 57
.set GEN_ROOT_KEY, 58

# A voice
.set FV_STAGE, 0                # a STAGE_*
.set FV_CHANNEL, 1
.set FV_NOTE, 2                 # the MIDI note, for identity
.set FV_VELOCITY, 3
.set FV_SOURCE, 4               # SOURCE_LIVE or SOURCE_FILE
.set FV_HELD, 5                 # released under the pedal; waits for it
.set FV_LOOP, 6                 # 0 none, 1 continuous, 3 until released
.set FV_EXCLUSIVE, 7
.set FV_AGE, 8                  # u32, from the note-on counter
.set FV_PAN, 12                 # i16, in 0.1%
.set FV_SUSTAIN, 14             # u16, cB
.set FV_ATTENUATION, 16         # u32, 16.16, the zone's attenuation as an amplitude
.set FV_DECAY_RATE, 20          # u32, cB times 256 a period
.set FV_RELEASE_RATE, 24        # u32
.set FV_ENV, 28                 # i32, the envelope's attenuation, cB times 256
.set FV_HOLD, 32                # u32 frames
.set FV_ATTACK_DELTA, 36        # u32, the level's step a frame in the attack
.set FV_COUNTDOWN, 40           # u32, frames left in the delay or the hold
.set FV_BASE_STEP, 44           # u32, 16.16, unbent
.set FV_POS, 48                 # u64, the sample index above the 16-bit fraction
.set FV_END, 56                 # u64, the end as a position
.set FV_LOOP_END, 64            # u64
.set FV_LOOP_LENGTH, 72         # u64, 0 with no loop
.set FV_LEVEL, 80               # i64, 0 to TOP
.set FV_DELTA, 88               # i64 a frame
.set FV_STEP, 96                # u32, 16.16, bent
.set FV_GAIN_LEFT, 100          # u32, 16.16
.set FV_GAIN_RIGHT, 104         # u32
.set FV_SIZE, 112
.set STAGE_FREE, 0
.set STAGE_DELAY, 1
.set STAGE_ATTACK, 2
.set STAGE_HOLD, 3
.set STAGE_DECAY, 4
.set STAGE_SUSTAIN, 5
.set STAGE_RELEASE, 6
.set STAGE_ENDING, 7

.section .text

# sys_midi_soundfont (jab.sys.midi.soundfont): a0 is the file inside the
# program's window on a 4-byte boundary, a1 its length; a length of 0
# unloads. a0 becomes 0 with a1, a2, a3 the presets, instruments, and
# samples; or sound_open's code, 3 for a file that is not a SoundFont,
# 4 for one that is unsound, the counts 0 then.
.global sys_midi_soundfont
sys_midi_soundfont:
    call sound_open
    bnez a0, 8f
    ld a1, 88(sp)
    bnez a1, 1f
    call soundfont_unload
    li a0, 0
    j 8f
1:
    ld a0, 80(sp)
    call buffer_bounds
    ld a0, 80(sp)
    ld a1, 88(sp)
    call soundfont_load
    sd a0, 80(sp)
    sd a1, 88(sp)
    sd a2, 96(sp)
    sd a3, 104(sp)
    j trap_return
8:
    sd a0, 80(sp)
    sd zero, 88(sp)
    sd zero, 96(sp)
    sd zero, 104(sp)
    j trap_return

# soundfont_init: nothing loaded, every voice free. Clobbers t registers.
.global soundfont_init
soundfont_init:
    la t0, sf_age
    sd zero, 0(t0)
# soundfont_unload: the file forgotten and every voice free at once.
.global soundfont_unload
soundfont_unload:
    la t0, soundfont_loaded
    sd zero, 0(t0)
    la t0, sf_voices
    li t1, VOICES
1:
    sb zero, FV_STAGE(t0)
    addi t0, t0, FV_SIZE
    addi t1, t1, -1
    bnez t1, 1b
    ret

# soundfont_load: a0 is the file and a1 its length. The RIFF form and
# its three lists are walked, the sample data and the nine hydra chunks
# found and kept by address and record count. a0 becomes 0 with the
# counts in a1 to a3, else 3 or 4 as sys_midi_soundfont says.
soundfont_load:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    mv s0, a0
    add s1, a0, a1              # the buffer's end
    call soundfont_unload
    andi t0, s0, 3
    bnez t0, unsound
    li t0, 12
    sub t1, s1, s0
    bltu t1, t0, notfont
    mv a0, s0
    call sf_u32
    li t0, TAG_RIFF
    bne a0, t0, notfont
    addi a0, s0, 8
    call sf_u32
    li t0, TAG_SFBK
    bne a0, t0, notfont
    addi a0, s0, 4
    call sf_u32
    addi s3, s0, 8
    add s3, s3, a0              # the form's end
    bgtu s3, s1, unsound
    addi s2, s0, 12             # the cursor
    # the INFO list, read for its shape only
    mv a0, s2
    mv a1, s3
    call sf_chunk
    beqz a0, unsound
    li t0, TAG_LIST
    bne a0, t0, notfont
    li t0, 4
    bltu a2, t0, notfont
    mv s4, a3
    mv a0, a1
    call sf_u32
    li t0, TAG_INFO
    bne a0, t0, notfont
    mv s2, s4
    # the sdta list: the smpl chunk inside it is the sample data
    mv a0, s2
    mv a1, s3
    call sf_chunk
    beqz a0, unsound
    li t0, TAG_LIST
    bne a0, t0, notfont
    li t0, 4
    bltu a2, t0, notfont
    sd a3, 0(sp)                # the list after it
    add s4, a1, a2              # the list's end
    sd a1, 8(sp)
    mv a0, a1
    call sf_u32
    li t0, TAG_SDTA
    bne a0, t0, notfont
    la t0, sf_samples
    sd zero, 0(t0)
    ld a0, 8(sp)
    addi a0, a0, 4
1:
    mv a1, s4
    call sf_chunk
    beqz a0, 2f
    li t0, TAG_SMPL
    bne a0, t0, 3f
    la t0, sf_samples
    sd a1, 0(t0)
    srli a2, a2, 1
    la t0, sf_sample_count
    sd a2, 0(t0)
3:
    mv a0, a3
    j 1b
2:
    la t0, sf_samples
    ld t0, 0(t0)
    beqz t0, notfont
    ld s2, 0(sp)
    # the pdta list: the nine hydra chunks in their order, each a whole
    # number of its records and at least its terminal
    mv a0, s2
    mv a1, s3
    call sf_chunk
    beqz a0, unsound
    li t0, TAG_LIST
    bne a0, t0, notfont
    li t0, 4
    bltu a2, t0, notfont
    add s4, a1, a2
    sd a1, 8(sp)
    mv a0, a1
    call sf_u32
    li t0, TAG_PDTA
    bne a0, t0, notfont
    ld s2, 8(sp)
    addi s2, s2, 4
    li s0, 0                    # the hydra row
4:
    li t0, HYDRA_COUNT
    bgeu s0, t0, 5f
    mv a0, s2
    mv a1, s4
    call sf_chunk
    beqz a0, unsound
    slli t1, s0, 3
    la t2, sf_hydra
    add t2, t2, t1
    lwu t3, 0(t2)
    bne a0, t3, notfont
    lhu t4, 4(t2)               # the record's size
    lhu t5, 6(t2)               # the least records
    remu t6, a2, t4
    bnez t6, unsound
    divu t6, a2, t4
    bltu t6, t5, unsound
    la t2, sf_hydra_ptr
    add t2, t2, t1
    sd a1, 0(t2)
    la t2, sf_hydra_count
    add t2, t2, t1
    sd t6, 0(t2)
    mv s2, a3
    addi s0, s0, 1
    j 4b
5:
    la t0, soundfont_loaded
    li t1, 1
    sd t1, 0(t0)
    la t0, sf_hydra_count
    ld a1, (HYDRA_PHDR * 8)(t0)
    addi a1, a1, -1
    ld a2, (HYDRA_INST * 8)(t0)
    addi a2, a2, -1
    ld a3, (HYDRA_SHDR * 8)(t0)
    addi a3, a3, -1
    li a0, 0
    j 9f
notfont:
    li a0, 3
    j 8f
unsound:
    li a0, 4
8:
    li a1, 0
    li a2, 0
    li a3, 0
9:
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 64
    ret

# sf_u32: a0 is a 2-aligned address in the file; a0 becomes the
# little-endian longword there, read as two halves since a chunk sits
# on a 2-byte boundary only. Clobbers t0.
sf_u32:
    lhu t0, 0(a0)
    lhu a0, 2(a0)
    slli a0, a0, 16
    or a0, a0, t0
    ret

# sf_chunk: a0 is a cursor and a1 a limit. a0 becomes the chunk's tag
# with a1 its data, a2 its size, and a3 the cursor after it, padded to
# even; or 0 when no whole chunk lies before the limit. Clobbers t0 to
# t2.
sf_chunk:
    addi t1, a0, 8
    bgtu t1, a1, 8f
    lhu t0, 0(a0)
    lhu t2, 2(a0)
    slli t2, t2, 16
    or t0, t0, t2
    lhu t2, 4(a0)
    lhu a2, 6(a0)
    slli a2, a2, 16
    or a2, a2, t2
    add a3, t1, a2
    bgtu a3, a1, 8f
    andi t2, a2, 1
    add a3, a3, t2
    mv a1, t1
    mv a0, t0
    ret
8:
    li a0, 0
    ret

# sf_find_preset: a0 is a bank and a1 a program; a0 becomes the index
# of the first preset carrying both, or -1. Clobbers t0 to t4.
sf_find_preset:
    la t0, sf_hydra_ptr
    ld t1, (HYDRA_PHDR * 8)(t0)
    la t0, sf_hydra_count
    ld t2, (HYDRA_PHDR * 8)(t0)
    addi t2, t2, -1
    li t3, 0
1:
    bgeu t3, t2, 8f
    lhu t4, PHDR_PRESET(t1)
    bne t4, a1, 2f
    lhu t4, PHDR_BANK(t1)
    bne t4, a0, 2f
    mv a0, t3
    ret
2:
    addi t1, t1, PHDR_SIZE
    addi t3, t3, 1
    j 1b
8:
    li a0, -1
    ret

# sf_zone_gens: a0 is a bag chunk's hydra index, a1 its generator
# chunk's, a2 a zone; a0 becomes the zone's first generator and a1 the
# one past its last, or a0 0 when the zone or its indices lie outside
# the chunks. Clobbers t0 to t6.
sf_zone_gens:
    slli t0, a0, 3
    la t1, sf_hydra_ptr
    add t2, t1, t0
    ld t2, 0(t2)                # the bags
    la t3, sf_hydra_count
    add t4, t3, t0
    ld t4, 0(t4)
    addi t5, a2, 1
    bgeu t5, t4, 8f             # the zone after it must exist
    slli t5, a2, 2
    add t5, t5, t2
    lhu t6, BAG_GEN(t5)
    lhu t5, (BAG_GEN + BAG_SIZE)(t5)
    bgtu t6, t5, 8f
    slli t0, a1, 3
    add t4, t3, t0
    ld t4, 0(t4)
    addi t4, t4, -1
    bgtu t5, t4, 8f
    add t1, t1, t0
    ld t1, 0(t1)                # the generators
    slli t6, t6, 2
    add a0, t1, t6
    slli t5, t5, 2
    add a1, t1, t5
    ret
8:
    li a0, 0
    ret

# sf_zone_fits: a0 is a zone's first generator and a1 the one past its
# last, a2 a key, a3 a velocity; a0 becomes 1 when the zone's key and
# velocity ranges, where it has them, hold both. Clobbers t0 to t4.
sf_zone_fits:
1:
    bgeu a0, a1, 9f
    lhu t0, GEN_OP(a0)
    lhu t1, GEN_AMOUNT(a0)
    addi a0, a0, GEN_SIZE
    li t2, GEN_KEY_RANGE
    bne t0, t2, 2f
    mv t3, a2
    j 3f
2:
    li t2, GEN_VEL_RANGE
    bne t0, t2, 1b
    mv t3, a3
3:
    andi t4, t1, 0xff
    bltu t3, t4, 8f
    srli t4, t1, 8
    andi t4, t4, 0xff
    bgtu t3, t4, 8f
    j 1b
9:
    li a0, 1
    ret
8:
    li a0, 0
    ret

# sf_apply: the generators from a0 up to a1 each set their row of the
# table at a2, a halfword a generator; an operator past the table is
# ignored. Clobbers t0 to t2.
sf_apply:
1:
    bgeu a0, a1, 9f
    lhu t0, GEN_OP(a0)
    lhu t1, GEN_AMOUNT(a0)
    addi a0, a0, GEN_SIZE
    li t2, GENERATORS
    bgeu t0, t2, 1b
    slli t0, t0, 1
    add t0, t0, a2
    sh t1, 0(t0)
    j 1b
9:
    ret

# sf_add_preset: the preset table at a1 added to the zone table at a0,
# row by row, for the value generators alone: a range, an index, a
# substitution, or a sample generator at the preset level is a filter
# or ignored, never a sum. Clobbers t0 to t4.
sf_add_preset:
    li t0, 0
1:
    li t1, GENERATORS
    bgeu t0, t1, 9f
    la t1, sf_value
    add t1, t1, t0
    lbu t1, 0(t1)
    beqz t1, 2f
    slli t1, t0, 1
    add t2, a0, t1
    add t3, a1, t1
    lh t4, 0(t2)
    lh t3, 0(t3)
    add t4, t4, t3
    sh t4, 0(t2)
2:
    addi t0, t0, 1
    j 1b
9:
    ret

# soundfont_note_on: the note a1 at velocity a2 starts on channel a0
# through the font: the channel's preset by bank and program, a zone of
# it holding the key and velocity, and under each such zone every
# instrument zone that does too starts a voice, up to NOTE_VOICES. The
# instrument's generators replace the defaults and the preset's add to
# them. Keeps the s registers.
.global soundfont_note_on
soundfont_note_on:
    addi sp, sp, -128
    sd ra, 120(sp)
    sd s0, 112(sp)
    sd s1, 104(sp)
    sd s2, 96(sp)
    sd s3, 88(sp)
    mv s0, a0                   # the channel
    mv s1, a1                   # the key
    mv s2, a2                   # the velocity
    li s3, 0                    # voices started
    # the channel's bank and program; the percussion channel is bank 128
    slli t0, s0, CHANNEL_SHIFT
    la t1, synth_channels
    add t1, t1, t0
    lbu a1, CHANNEL_PROGRAM(t1)
    lbu a0, CHANNEL_BANK(t1)
    li t0, JAB_MIDI_PERCUSSION
    bne s0, t0, 1f
    li a0, 128
1:
    sd a0, 0(sp)
    sd a1, 8(sp)
    call sf_find_preset
    bgez a0, 2f
    # nothing there: bank 0's program, or the kit at 0
    ld a0, 0(sp)
    ld a1, 8(sp)
    li t0, 128
    beq a0, t0, 11f
    li a0, 0
    j 12f
11:
    li a1, 0
12:
    call sf_find_preset
    bltz a0, 9f
2:
    # the preset's zones
    la t0, sf_hydra_ptr
    ld t1, (HYDRA_PHDR * 8)(t0)
    li t2, PHDR_SIZE
    mul t2, t2, a0
    add t1, t1, t2
    lhu t3, PHDR_BAG(t1)
    lhu t4, (PHDR_BAG + PHDR_SIZE)(t1)
    bgeu t3, t4, 9f
    sd t3, 16(sp)               # the first zone
    sd t4, 24(sp)               # past the last
    sd zero, 32(sp)             # the global zone's generators, none
    sd zero, 40(sp)
    # a global zone: the first, when its last generator is not the
    # instrument; its generators go under every zone's
    li a0, HYDRA_PBAG
    li a1, HYDRA_PGEN
    mv a2, t3
    call sf_zone_gens
    beqz a0, 9f
    bgeu a0, a1, 3f
    lhu t2, -4(a1)
    li t3, GEN_INSTRUMENT
    beq t2, t3, 4f
3:
    sd a0, 32(sp)
    sd a1, 40(sp)
    ld t3, 16(sp)
    addi t3, t3, 1
    sd t3, 16(sp)
4:
    ld t0, 16(sp)
    sd t0, 48(sp)               # the zone in hand
5:
    ld t0, 48(sp)
    ld t1, 24(sp)
    bgeu t0, t1, 9f
    li a0, HYDRA_PBAG
    li a1, HYDRA_PGEN
    mv a2, t0
    call sf_zone_gens
    beqz a0, 6f
    bgeu a0, a1, 6f
    lhu t2, -4(a1)
    li t3, GEN_INSTRUMENT
    bne t2, t3, 6f
    sd a0, 56(sp)
    sd a1, 64(sp)
    mv a2, s1
    mv a3, s2
    call sf_zone_fits
    beqz a0, 6f
    ld a1, 64(sp)
    lhu t0, -2(a1)              # the instrument
    la t1, sf_hydra_count
    ld t1, (HYDRA_INST * 8)(t1)
    addi t1, t1, -1
    bgeu t0, t1, 6f
    sd t0, 72(sp)
    # the preset's sum: the global zone's generators, then this zone's
    la a0, sf_preset_gen
    li a1, GENERATORS * 2
    call zero_bytes
    ld a0, 32(sp)
    ld a1, 40(sp)
    beqz a0, 51f
    la a2, sf_preset_gen
    call sf_apply
51:
    ld a0, 56(sp)
    ld a1, 64(sp)
    la a2, sf_preset_gen
    call sf_apply
    ld a0, 72(sp)
    call sf_instrument
    li t0, NOTE_VOICES
    bgeu s3, t0, 9f
6:
    ld t0, 48(sp)
    addi t0, t0, 1
    sd t0, 48(sp)
    j 5b
9:
    ld ra, 120(sp)
    ld s0, 112(sp)
    ld s1, 104(sp)
    ld s2, 96(sp)
    ld s3, 88(sp)
    addi sp, sp, 128
    ret

# sf_instrument: every zone of instrument a0 holding the key s1 and the
# velocity s2 starts a voice on channel s0, s3 counting them: its table
# is the defaults, the instrument's global zone, the zone itself, then
# the preset's sum added. Keeps the s registers.
sf_instrument:
    addi sp, sp, -80
    sd ra, 72(sp)
    la t0, sf_hydra_ptr
    ld t1, (HYDRA_INST * 8)(t0)
    li t2, INST_SIZE
    mul t2, t2, a0
    add t1, t1, t2
    lhu t3, INST_BAG(t1)
    lhu t4, (INST_BAG + INST_SIZE)(t1)
    bgeu t3, t4, 9f
    sd t3, 0(sp)                # the first zone
    sd t4, 8(sp)                # past the last
    sd zero, 16(sp)             # the global zone's generators, none
    sd zero, 24(sp)
    li a0, HYDRA_IBAG
    li a1, HYDRA_IGEN
    mv a2, t3
    call sf_zone_gens
    beqz a0, 9f
    bgeu a0, a1, 1f
    lhu t2, -4(a1)
    li t3, GEN_SAMPLE
    beq t2, t3, 2f
1:
    sd a0, 16(sp)
    sd a1, 24(sp)
    ld t3, 0(sp)
    addi t3, t3, 1
    sd t3, 0(sp)
2:
    ld t0, 0(sp)
    sd t0, 32(sp)               # the zone in hand
3:
    ld t0, 32(sp)
    ld t1, 8(sp)
    bgeu t0, t1, 9f
    li a0, HYDRA_IBAG
    li a1, HYDRA_IGEN
    mv a2, t0
    call sf_zone_gens
    beqz a0, 4f
    bgeu a0, a1, 4f
    lhu t2, -4(a1)
    li t3, GEN_SAMPLE
    bne t2, t3, 4f
    sd a0, 40(sp)
    sd a1, 48(sp)
    mv a2, s1
    mv a3, s2
    call sf_zone_fits
    beqz a0, 4f
    la a0, sf_gen
    la a1, sf_defaults
    li a2, GENERATORS * 2
    call copy_bytes
    ld a0, 16(sp)
    ld a1, 24(sp)
    beqz a0, 31f
    la a2, sf_gen
    call sf_apply
31:
    ld a0, 40(sp)
    ld a1, 48(sp)
    la a2, sf_gen
    call sf_apply
    la a0, sf_gen
    la a1, sf_preset_gen
    call sf_add_preset
    la a0, sf_gen
    mv a1, s0
    mv a2, s1
    mv a3, s2
    call sf_voice_start
    add s3, s3, a0
    li t0, NOTE_VOICES
    bgeu s3, t0, 9f
4:
    ld t0, 32(sp)
    addi t0, t0, 1
    sd t0, 32(sp)
    j 3b
9:
    ld ra, 72(sp)
    addi sp, sp, 80
    ret

# sf_voice_start: a voice from the generator table at a0 on channel a1,
# note a2, velocity a3: the sample header the table names, the
# positions from it and the table's offsets, the pitch, the envelope,
# the pan, the attenuation, the exclusive class. a0 becomes 1 with a
# voice started, or 0 when the sample is not one the kernel plays (a
# ROM sample, one past the data, an empty range). Keeps s0 to s3.
sf_voice_start:
    addi sp, sp, -128
    sd ra, 120(sp)
    sd s4, 112(sp)
    sd s5, 104(sp)
    sd s6, 96(sp)
    sd s7, 88(sp)
    sd s8, 80(sp)
    sd s9, 72(sp)
    mv s4, a0                   # the table
    mv s5, a1                   # the channel
    mv s6, a2                   # the note
    mv s7, a3                   # the velocity
    # the sample header
    lhu t0, (GEN_SAMPLE * 2)(s4)
    la t1, sf_hydra_count
    ld t1, (HYDRA_SHDR * 8)(t1)
    addi t1, t1, -1
    bgeu t0, t1, 8f
    la t1, sf_hydra_ptr
    ld t1, (HYDRA_SHDR * 8)(t1)
    li t2, SHDR_SIZE
    mul t2, t2, t0
    add s8, t1, t2
    lhu t0, SHDR_TYPE(s8)
    srli t0, t0, 15
    bnez t0, 8f                 # a ROM sample
    # the start, the end, the loop's start and end: the header's, plus
    # the zone's fine and coarse offsets
    addi a0, s8, SHDR_START
    call sf_u32
    lh t0, (GEN_START_OFFSET * 2)(s4)
    add a0, a0, t0
    lh t0, (GEN_START_COARSE * 2)(s4)
    slli t0, t0, 15
    add a0, a0, t0
    sd a0, 0(sp)
    addi a0, s8, SHDR_END
    call sf_u32
    lh t0, (GEN_END_OFFSET * 2)(s4)
    add a0, a0, t0
    lh t0, (GEN_END_COARSE * 2)(s4)
    slli t0, t0, 15
    add a0, a0, t0
    sd a0, 8(sp)
    addi a0, s8, SHDR_LOOP_START
    call sf_u32
    lh t0, (GEN_LOOP_START_OFFSET * 2)(s4)
    add a0, a0, t0
    lh t0, (GEN_LOOP_START_COARSE * 2)(s4)
    slli t0, t0, 15
    add a0, a0, t0
    sd a0, 16(sp)
    addi a0, s8, SHDR_LOOP_END
    call sf_u32
    lh t0, (GEN_LOOP_END_OFFSET * 2)(s4)
    add a0, a0, t0
    lh t0, (GEN_LOOP_END_COARSE * 2)(s4)
    slli t0, t0, 15
    add a0, a0, t0
    sd a0, 24(sp)
    # inside the data, the start before the end
    ld t0, 0(sp)
    ld t1, 8(sp)
    bltz t0, 8f
    bge t0, t1, 8f
    la t2, sf_sample_count
    ld t2, 0(t2)
    bgt t1, t2, 8f
    # the loop: the mode's low two bits, 2 meaning none, and the points
    # inside the sound in order, else none
    lhu t3, (GEN_SAMPLE_MODES * 2)(s4)
    andi t3, t3, 3
    li t4, 2
    bne t3, t4, 1f
    li t3, 0
1:
    beqz t3, 2f
    ld t4, 16(sp)
    ld t5, 24(sp)
    blt t4, t0, 11f
    bgt t5, t1, 11f
    bge t4, t5, 11f
    j 2f
11:
    li t3, 0
2:
    sd t3, 32(sp)               # the loop mode
    # the rate, the root key, the key and velocity that sound
    addi a0, s8, SHDR_RATE
    call sf_u32
    bnez a0, 3f
    li a0, 44100
3:
    sd a0, 40(sp)
    lh t0, (GEN_ROOT_KEY * 2)(s4)
    bltz t0, 31f
    li t1, 127
    ble t0, t1, 32f
31:
    lbu t0, SHDR_KEY(s8)
    li t1, 127
    bleu t0, t1, 32f
    li t0, 60
32:
    lh t1, (GEN_KEYNUM * 2)(s4)
    bltz t1, 33f
    li t2, 127
    ble t1, t2, 34f
33:
    mv t1, s6
34:
    lh t2, (GEN_VELOCITY * 2)(s4)
    blez t2, 35f
    li t4, 127
    ble t2, t4, 36f
35:
    mv t2, s7
36:
    sd t2, 48(sp)               # the velocity that sounds
    # the pitch, in cents: the key's distance from the root at the scale
    # tuning, the coarse and fine tuning, the header's correction
    sub t1, t1, t0
    lh t3, (GEN_SCALE_TUNING * 2)(s4)
    mul t1, t1, t3
    lh t3, (GEN_COARSE_TUNE * 2)(s4)
    li t4, 100
    mul t3, t3, t4
    add t1, t1, t3
    lh t3, (GEN_FINE_TUNE * 2)(s4)
    add t1, t1, t3
    lb t3, SHDR_CORRECTION(s8)
    add t1, t1, t3
    mv a0, t1
    call sf_ratio
    ld t0, 40(sp)
    slli t0, t0, 16
    li t1, JAB_SOUND_RATE
    divu t0, t0, t1             # the rate's own step, 16.16
    mul a0, a0, t0
    srli a0, a0, 16
    li t1, 0xffffffff
    bleu a0, t1, 4f
    mv a0, t1
4:
    sd a0, 56(sp)               # the base step
    beqz a0, 8f
    # an exclusive class cuts the class's other voices on the channel
    lh t0, (GEN_EXCLUSIVE * 2)(s4)
    beqz t0, 5f
    mv a0, s5
    mv a1, t0
    call sf_exclusive
5:
    call sf_take
    mv s9, a0
    sb s5, FV_CHANNEL(s9)
    sb s6, FV_NOTE(s9)
    ld t0, 48(sp)
    sb t0, FV_VELOCITY(s9)
    la t0, synth_source
    lbu t0, 0(t0)
    sb t0, FV_SOURCE(s9)
    sb zero, FV_HELD(s9)
    ld t0, 32(sp)
    sb t0, FV_LOOP(s9)
    lh t0, (GEN_EXCLUSIVE * 2)(s4)
    sb t0, FV_EXCLUSIVE(s9)
    la t0, sf_age
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
    sw t1, FV_AGE(s9)
    # the pan, held to the specification's range
    lh t0, (GEN_PAN * 2)(s4)
    li t1, 500
    ble t0, t1, 51f
    mv t0, t1
51:
    li t1, -500
    bge t0, t1, 52f
    mv t0, t1
52:
    sh t0, FV_PAN(s9)
    # the sustain, in cB, and the attenuation as an amplitude
    lh t0, (GEN_SUSTAIN * 2)(s4)
    bgez t0, 53f
    li t0, 0
53:
    li t1, ATTENUATION_MAX
    ble t0, t1, 54f
    mv t0, t1
54:
    sh t0, FV_SUSTAIN(s9)
    lh t0, (GEN_ATTENUATION * 2)(s4)
    bgez t0, 55f
    li t0, 0
55:
    li t1, ATTENUATION_MAX
    ble t0, t1, 56f
    mv t0, t1
56:
    li t1, CB_TO_CENTS
    mul t0, t0, t1
    srai t0, t0, 6
    neg a0, t0
    call sf_ratio
    li t1, 65536
    bleu a0, t1, 57f
    mv a0, t1
57:
    sw a0, FV_ATTENUATION(s9)
    # the decay and the release, as cB times 256 a period, at least 1
    lh a0, (GEN_DECAY * 2)(s4)
    call sf_period_rate
    sw a0, FV_DECAY_RATE(s9)
    lh a0, (GEN_RELEASE * 2)(s4)
    call sf_period_rate
    sw a0, FV_RELEASE_RATE(s9)
    sw zero, FV_ENV(s9)
    # the positions
    ld t0, 0(sp)
    slli t0, t0, 16
    sd t0, FV_POS(s9)
    ld t0, 8(sp)
    slli t0, t0, 16
    sd t0, FV_END(s9)
    ld t1, 32(sp)
    beqz t1, 58f
    ld t0, 24(sp)
    slli t0, t0, 16
    sd t0, FV_LOOP_END(s9)
    ld t2, 16(sp)
    slli t2, t2, 16
    sub t0, t0, t2
    sd t0, FV_LOOP_LENGTH(s9)
    j 59f
58:
    sd zero, FV_LOOP_END(s9)
    sd zero, FV_LOOP_LENGTH(s9)
59:
    ld t0, 56(sp)
    sw t0, FV_BASE_STEP(s9)
    sw t0, FV_STEP(s9)
    sw zero, FV_GAIN_LEFT(s9)
    sw zero, FV_GAIN_RIGHT(s9)
    # the envelope's delay, attack, and hold in frames, and the attack's
    # step a frame, TOP over its frames
    lh a0, (GEN_HOLD * 2)(s4)
    call sf_frames
    sw a0, FV_HOLD(s9)
    lh a0, (GEN_ATTACK * 2)(s4)
    call sf_frames
    sd a0, 64(sp)
    lh a0, (GEN_DELAY * 2)(s4)
    call sf_frames
    sd zero, FV_LEVEL(s9)
    sd zero, FV_DELTA(s9)
    sw zero, FV_COUNTDOWN(s9)
    ld t0, 64(sp)
    li t1, TOP
    beqz t0, 60f
    divu t1, t1, t0
    bnez t1, 60f
    li t1, 1
60:
    sw t1, FV_ATTACK_DELTA(s9)
    # the stage: a delay counts down first; an attack climbs; without
    # either the level starts at the top, holding or decaying
    beqz a0, 61f
    sw a0, FV_COUNTDOWN(s9)
    li t0, STAGE_DELAY
    sb t0, FV_STAGE(s9)
    j 70f
61:
    ld t0, 64(sp)
    beqz t0, 62f
    lwu t1, FV_ATTACK_DELTA(s9)
    sd t1, FV_DELTA(s9)
    li t0, STAGE_ATTACK
    sb t0, FV_STAGE(s9)
    j 70f
62:
    li t0, TOP
    sd t0, FV_LEVEL(s9)
    lwu t0, FV_HOLD(s9)
    beqz t0, 63f
    sw t0, FV_COUNTDOWN(s9)
    li t0, STAGE_HOLD
    sb t0, FV_STAGE(s9)
    j 70f
63:
    li t0, STAGE_DECAY
    sb t0, FV_STAGE(s9)
70:
    li a0, 1
    j 9f
8:
    li a0, 0
9:
    ld ra, 120(sp)
    ld s4, 112(sp)
    ld s5, 104(sp)
    ld s6, 96(sp)
    ld s7, 88(sp)
    ld s8, 80(sp)
    ld s9, 72(sp)
    addi sp, sp, 128
    ret

# sf_ratio: a0 is a count of cents, signed; a0 becomes 2 to the
# cents over 1200 in 16.16, the semitone's entry times the cent's
# entry shifted by the octave, 0 below the tables' reach and capped at
# 31 octaves up. Clobbers t0 to t4.
sf_ratio:
    li t0, 1200
    div t1, a0, t0              # the octave, toward zero
    rem t2, a0, t0
    bgez t2, 1f
    add t2, t2, t0
    addi t1, t1, -1
1:
    li t0, 100
    divu t3, t2, t0             # the semitone
    remu t4, t2, t0             # the cent
    la t0, soundfont_semitones
    slli t3, t3, 2
    add t3, t3, t0
    lwu t3, 0(t3)
    la t0, soundfont_cents
    slli t4, t4, 2
    add t4, t4, t0
    lwu t4, 0(t4)
    mul a0, t3, t4
    srli a0, a0, 16
    bgez t1, 2f
    neg t1, t1
    li t0, 63
    bleu t1, t0, 11f
    li a0, 0
    ret
11:
    srl a0, a0, t1
    ret
2:
    li t0, 31
    bleu t1, t0, 21f
    mv t1, t0
21:
    sll a0, a0, t1
    ret

# sf_frames: a0 is a time in timecents; a0 becomes that many seconds
# of frames, capped below 2^31. Clobbers t registers.
sf_frames:
    addi sp, sp, -16
    sd ra, 8(sp)
    call sf_ratio
    li t0, JAB_SOUND_RATE
    mul a0, a0, t0
    srli a0, a0, 16
    li t0, 0x7fffffff
    bleu a0, t0, 1f
    mv a0, t0
1:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# sf_period_rate: a0 is a decay or release time in timecents, the time
# of a 100 dB change; a0 becomes the change a period makes, cB times
# 256, at least 1 and capped below 2^31. Clobbers t registers.
sf_period_rate:
    addi sp, sp, -16
    sd ra, 8(sp)
    neg a0, a0
    call sf_ratio
    li t0, PERIOD_CB256
    mul a0, a0, t0
    srli a0, a0, 16
    bnez a0, 1f
    li a0, 1
1:
    li t0, 0x7fffffff
    bleu a0, t0, 2f
    mv a0, t0
2:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# sf_take: a0 becomes the voice for a new note: a free one, else the
# oldest releasing one, else the oldest of all. Clobbers t0 to t6.
sf_take:
    la t0, sf_voices
    li t1, VOICES
    li t2, 0
    li t3, -1
1:
    lbu t4, FV_STAGE(t0)
    beqz t4, 3f
    lwu t5, FV_AGE(t0)
    li t6, STAGE_RELEASE
    bgeu t4, t6, 2f
    li t6, 1
    slli t6, t6, 32
    add t5, t5, t6              # still held: after every releasing one
2:
    bgeu t5, t3, 4f
    mv t3, t5
    mv t2, t0
4:
    addi t0, t0, FV_SIZE
    addi t1, t1, -1
    bnez t1, 1b
    mv a0, t2
    ret
3:
    mv a0, t0
    ret

# sf_exclusive: every sounding voice on channel a0 of exclusive class
# a1 goes to a release fast enough to be gone within a period.
# Clobbers t0 to t4.
sf_exclusive:
    la t0, sf_voices
    li t1, VOICES
1:
    lbu t2, FV_STAGE(t0)
    beqz t2, 2f
    li t3, STAGE_RELEASE
    bgeu t2, t3, 2f
    lbu t2, FV_CHANNEL(t0)
    bne t2, a0, 2f
    lbu t2, FV_EXCLUSIVE(t0)
    bne t2, a1, 2f
    li t2, STAGE_RELEASE
    sb t2, FV_STAGE(t0)
    sb zero, FV_HELD(t0)
    li t2, CUT_CB256
    sw t2, FV_RELEASE_RATE(t0)
    sd zero, FV_LOOP_LENGTH(t0)
2:
    addi t0, t0, FV_SIZE
    addi t1, t1, -1
    bnez t1, 1b
    ret

# sf_release: the voice at a0 goes to its release, unless it is there
# already: from the attack or the hold the envelope's attenuation is
# read off its level, since the release falls in decibels from
# wherever the voice is; a loop that lasts until the key is released
# ends. Clobbers t0 to t4 and a0.
sf_release:
    lbu t0, FV_STAGE(a0)
    beqz t0, 9f
    li t1, STAGE_RELEASE
    bgeu t0, t1, 9f
    li t1, STAGE_DECAY
    bgeu t0, t1, 1f
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
    ld a0, FV_LEVEL(a0)
    call sf_level_cb
    ld t4, 0(sp)
    sw a0, FV_ENV(t4)
    mv a0, t4
    ld ra, 8(sp)
    addi sp, sp, 16
1:
    li t0, STAGE_RELEASE
    sb t0, FV_STAGE(a0)
    sb zero, FV_HELD(a0)
    lbu t0, FV_LOOP(a0)
    li t1, 3
    bne t0, t1, 9f
    sd zero, FV_LOOP_LENGTH(a0)
9:
    ret

# sf_level_cb: a0 is a level, 0 to TOP; a0 becomes the attenuation it
# stands for, cB times 256, from its logarithm: the leading bit found
# by a walk, the next four bits through a table. Clobbers t0 to t3.
sf_level_cb:
    bnez a0, 1f
    li a0, SILENCE_CB256
    ret
1:
    li t0, TOP
    bltu a0, t0, 2f
    li a0, 0
    ret
2:
    li t1, 31
21:
    srl t2, a0, t1
    bnez t2, 3f
    addi t1, t1, -1
    bnez t1, 21b
3:
    addi t3, t1, -4
    bgez t3, 4f
    neg t3, t3
    sll t2, a0, t3
    j 5f
4:
    srl t2, a0, t3
5:
    andi t2, t2, 15
    la t3, sf_log2
    add t3, t3, t2
    lbu t2, 0(t3)
    slli t1, t1, 8
    add t1, t1, t2              # the logarithm, times 256
    li t2, 32 * 256
    sub t2, t2, t1              # octaves below the top, times 256
    li t3, 15413
    mul t2, t2, t3
    srli a0, t2, 8
    ret

# soundfont_note_off: every voice of the current source still sounding
# note a1 on channel a0 is released, or marked held while the channel's
# pedal is down. Keeps the s registers.
.global soundfont_note_off
soundfont_note_off:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    sd s4, 0(sp)
    mv s0, a0
    mv s1, a1
    slli t0, s0, CHANNEL_SHIFT
    la t1, synth_channels
    add t1, t1, t0
    lbu s4, CHANNEL_PEDAL(t1)
    la s2, sf_voices
    li s3, VOICES
1:
    lbu t0, FV_STAGE(s2)
    beqz t0, 2f
    li t1, STAGE_RELEASE
    bgeu t0, t1, 2f
    lbu t0, FV_CHANNEL(s2)
    bne t0, s0, 2f
    lbu t0, FV_NOTE(s2)
    bne t0, s1, 2f
    lbu t0, FV_SOURCE(s2)
    la t1, synth_source
    lbu t1, 0(t1)
    bne t0, t1, 2f
    beqz s4, 3f
    li t0, 1
    sb t0, FV_HELD(s2)
    j 2f
3:
    mv a0, s2
    call sf_release
2:
    addi s2, s2, FV_SIZE
    addi s3, s3, -1
    bnez s3, 1b
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    ld s4, 0(sp)
    addi sp, sp, 48
    ret

# soundfont_pedal_up: every voice of channel a0 held under the pedal is
# released. Keeps the s registers.
.global soundfont_pedal_up
soundfont_pedal_up:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    sd s2, 0(sp)
    mv s0, a0
    la s1, sf_voices
    li s2, VOICES
1:
    lbu t0, FV_STAGE(s1)
    beqz t0, 2f
    lbu t0, FV_HELD(s1)
    beqz t0, 2f
    lbu t0, FV_CHANNEL(s1)
    bne t0, s0, 2f
    mv a0, s1
    call sf_release
2:
    addi s1, s1, FV_SIZE
    addi s2, s2, -1
    bnez s2, 1b
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 32
    ret

# soundfont_channel_off: every voice of channel a0 from the current
# source is freed at once when a1 is set, else released. Keeps the s
# registers.
.global soundfont_channel_off
soundfont_channel_off:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s0, a0
    mv s1, a1
    la s2, sf_voices
    li s3, VOICES
1:
    lbu t0, FV_STAGE(s2)
    beqz t0, 2f
    lbu t0, FV_CHANNEL(s2)
    bne t0, s0, 2f
    lbu t0, FV_SOURCE(s2)
    la t1, synth_source
    lbu t1, 0(t1)
    bne t0, t1, 2f
    beqz s1, 3f
    sb zero, FV_STAGE(s2)
    j 2f
3:
    mv a0, s2
    call sf_release
2:
    addi s2, s2, FV_SIZE
    addi s3, s3, -1
    bnez s3, 1b
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 48
    ret

# soundfont_all_off: every voice of source a1, or every voice with
# SOURCE_ANY, freed at once when a0 is set, else released. Keeps the s
# registers.
.global soundfont_all_off
soundfont_all_off:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s0, a0
    mv s1, a1
    la s2, sf_voices
    li s3, VOICES
1:
    lbu t0, FV_STAGE(s2)
    beqz t0, 2f
    bltz s1, 11f
    lbu t1, FV_SOURCE(s2)
    bne t1, s1, 2f
11:
    beqz s0, 3f
    sb zero, FV_STAGE(s2)
    j 2f
3:
    mv a0, s2
    call sf_release
2:
    addi s2, s2, FV_SIZE
    addi s3, s3, -1
    bnez s3, 1b
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 48
    ret

# soundfont_sounding: a0 becomes 1 while any voice sounds, else 0.
# Clobbers t0 to t2.
.global soundfont_sounding
soundfont_sounding:
    la t0, sf_voices
    li t1, VOICES
    li a0, 1
1:
    lbu t2, FV_STAGE(t0)
    bnez t2, 2f
    addi t0, t0, FV_SIZE
    addi t1, t1, -1
    bnez t1, 1b
    li a0, 0
2:
    ret

# soundfont_render: every sounding voice added into the accumulator at
# a0, a1 frames of two 32-bit samples, left then right, a period. Per
# voice and period: the envelope's attenuation moved on through its
# decay or release and the level's step a frame toward the amplitude
# it names; the step bent by the channel; the gains from the velocity,
# the volume, and the expression each squared, the zone's attenuation,
# and the pan with the channel's. Then per frame: the envelope on,
# through its delay, attack, and hold by the frame, else by the step;
# the sample interpolated between its two points at the position,
# scaled by the level and the gains into both sides; the position on
# by the step, wrapped at the loop's end or ended at the sample's.
# Keeps the s registers.
.global soundfont_render
soundfont_render:
    la t0, soundfont_loaded
    ld t0, 0(t0)
    beqz t0, done
    addi sp, sp, -128
    sd ra, 120(sp)
    sd s0, 112(sp)
    sd s1, 104(sp)
    sd s2, 96(sp)
    sd s3, 88(sp)
    sd s4, 80(sp)
    sd s5, 72(sp)
    sd s6, 64(sp)
    sd s7, 56(sp)
    sd s8, 48(sp)
    sd s9, 40(sp)
    sd s10, 32(sp)
    sd s11, 24(sp)
    mv s0, a0
    mv s1, a1
    la s2, sf_voices
    li s3, VOICES
voice:
    lbu t0, FV_STAGE(s2)
    beqz t0, next_voice
    lbu t1, FV_CHANNEL(s2)
    slli t1, t1, CHANNEL_SHIFT
    la t2, synth_channels
    add s4, t2, t1              # the channel
    # the envelope's period, past the hold: the attenuation on by the
    # decay's rate to the sustain, or by the release's to silence
    li t1, STAGE_DECAY
    bltu t0, t1, gains
    lw t2, FV_ENV(s2)
    li t1, STAGE_DECAY
    bne t0, t1, 1f
    lwu t3, FV_DECAY_RATE(s2)
    add t2, t2, t3
    lhu t3, FV_SUSTAIN(s2)
    slli t3, t3, 8
    blt t2, t3, 2f
    mv t2, t3
    li t0, STAGE_SUSTAIN
    j 2f
1:
    li t1, STAGE_RELEASE
    bne t0, t1, 2f
    lwu t3, FV_RELEASE_RATE(s2)
    add t2, t2, t3
2:
    li t3, SILENCE_CB256
    blt t2, t3, 3f
    mv t2, t3
    li t0, STAGE_ENDING
3:
    sw t2, FV_ENV(s2)
    sb t0, FV_STAGE(s2)
    # the level the attenuation names, and the step a frame to it
    li t1, STAGE_ENDING
    bne t0, t1, 4f
    ld t3, FV_LEVEL(s2)
    beqz t3, free_voice
    li a0, 0
    j 5f
4:
    li t3, CB_TO_CENTS
    mul a0, t2, t3
    srai a0, a0, 14
    neg a0, a0
    call sf_ratio
    li t0, 65536
    bleu a0, t0, 41f
    mv a0, t0
41:
    slli a0, a0, 16
    li t0, TOP
    bleu a0, t0, 5f
    mv a0, t0
5:
    ld t1, FV_LEVEL(s2)
    sub a0, a0, t1
    div a0, a0, s1
    sd a0, FV_DELTA(s2)
gains:
    # the step: the note's, bent by the channel over two semitones
    lwu t0, FV_BASE_STEP(s2)
    lh t1, CHANNEL_BEND(s4)
    beqz t1, 6f
    sd t0, 0(sp)
    li t2, 200
    mul a0, t1, t2
    srai a0, a0, 13
    call sf_ratio
    ld t0, 0(sp)
    mul t0, t0, a0
    srli t0, t0, 16
6:
    sw t0, FV_STEP(s2)
    # the gains: the velocity, volume, and expression each squared over
    # full scale, the zone's attenuation, then each side's share of the
    # pan summed with the channel's
    lbu t0, FV_VELOCITY(s2)
    lbu t1, CHANNEL_VOLUME(s4)
    mul t0, t0, t1
    lbu t1, CHANNEL_EXPRESSION(s4)
    mul t0, t0, t1
    mul t0, t0, t0
    slli t0, t0, 16
    li t1, FULL_SCALE_SIXTH
    divu t0, t0, t1
    lwu t1, FV_ATTENUATION(s2)
    mul t0, t0, t1
    srli t0, t0, 16
    lh t1, FV_PAN(s2)
    lbu t2, CHANNEL_PAN(s4)
    addi t2, t2, -64
    li t3, 1000
    mul t2, t2, t3
    srai t2, t2, 6
    add t1, t1, t2
    li t2, 500
    ble t1, t2, 61f
    mv t1, t2
61:
    li t2, -500
    bge t1, t2, 62f
    mv t1, t2
62:
    li t2, 500
    li t4, 65536
    sub t3, t2, t1
    slli t3, t3, 16
    divu t3, t3, t2
    bleu t3, t4, 63f
    mv t3, t4
63:
    mul t3, t3, t0
    srli t3, t3, 16
    sw t3, FV_GAIN_LEFT(s2)
    add t3, t2, t1
    slli t3, t3, 16
    divu t3, t3, t2
    bleu t3, t4, 64f
    mv t3, t4
64:
    mul t3, t3, t0
    srli t3, t3, 16
    sw t3, FV_GAIN_RIGHT(s2)
    # the frame loop's state: s5 the position, s6 the step, s7 the end,
    # s8 the loop's end, s9 its length, s10 the level, s11 its step, a2
    # and a3 the gains, a4 the stage, a5 the countdown, t6 the samples,
    # a6 the accumulator, a7 the frames left
    ld s5, FV_POS(s2)
    lwu s6, FV_STEP(s2)
    ld s7, FV_END(s2)
    ld s8, FV_LOOP_END(s2)
    ld s9, FV_LOOP_LENGTH(s2)
    ld s10, FV_LEVEL(s2)
    ld s11, FV_DELTA(s2)
    lwu a2, FV_GAIN_LEFT(s2)
    lwu a3, FV_GAIN_RIGHT(s2)
    lbu a4, FV_STAGE(s2)
    lwu a5, FV_COUNTDOWN(s2)
    la t0, sf_samples
    ld t6, 0(t0)
    mv a6, s0
    mv a7, s1
frame:
    li t0, STAGE_DECAY
    bgeu a4, t0, env_run
    li t0, STAGE_ATTACK
    beq a4, t0, env_attack
    li t0, STAGE_HOLD
    beq a4, t0, env_hold
    # the delay: silence, then the attack begins
    addi a5, a5, -1
    bnez a5, advance_silent
    li a4, STAGE_ATTACK
    lwu s11, FV_ATTACK_DELTA(s2)
    li s10, 0
    j advance_silent
env_attack:
    add s10, s10, s11
    li t0, TOP
    blt s10, t0, sample
    mv s10, t0
    li s11, 0
    lwu a5, FV_HOLD(s2)
    li a4, STAGE_HOLD
    bnez a5, sample
    li a4, STAGE_DECAY
    j sample
env_hold:
    addi a5, a5, -1
    bnez a5, sample
    li a4, STAGE_DECAY
    j sample
env_run:
    add s10, s10, s11
    bgtz s10, sample
    li s10, 0
    li t0, STAGE_RELEASE
    bltu a4, t0, sample
    j voice_ends
sample:
    # the two points about the position, interpolated by its fraction
    srli t0, s5, 16
    slli t0, t0, 1
    add t0, t0, t6
    lh t1, 0(t0)
    lh t2, 2(t0)
    sub t2, t2, t1
    li t3, 0xffff
    and t3, s5, t3
    mul t2, t2, t3
    srai t2, t2, 16
    add t1, t1, t2
    # at the level, into both sides at their gains
    mul t1, t1, s10
    srai t1, t1, 32
    lw t2, 0(a6)
    mul t3, t1, a2
    srai t3, t3, 16
    add t2, t2, t3
    sw t2, 0(a6)
    lw t2, 4(a6)
    mul t3, t1, a3
    srai t3, t3, 16
    add t2, t2, t3
    sw t2, 4(a6)
    addi a6, a6, 8
    # the position on, around the loop or to the end
    add s5, s5, s6
    beqz s9, 7f
    bltu s5, s8, 8f
    sub s5, s5, s9
    j 8f
7:
    bgeu s5, s7, voice_ends
8:
    addi a7, a7, -1
    bnez a7, frame
    j voice_done
advance_silent:
    addi a6, a6, 8
    addi a7, a7, -1
    bnez a7, frame
    j voice_done
voice_ends:
    li a4, STAGE_FREE
voice_done:
    sd s5, FV_POS(s2)
    sd s10, FV_LEVEL(s2)
    sd s11, FV_DELTA(s2)
    sb a4, FV_STAGE(s2)
    sw a5, FV_COUNTDOWN(s2)
    j next_voice
free_voice:
    sb zero, FV_STAGE(s2)
next_voice:
    addi s2, s2, FV_SIZE
    addi s3, s3, -1
    bnez s3, voice
    ld ra, 120(sp)
    ld s0, 112(sp)
    ld s1, 104(sp)
    ld s2, 96(sp)
    ld s3, 88(sp)
    ld s4, 80(sp)
    ld s5, 72(sp)
    ld s6, 64(sp)
    ld s7, 56(sp)
    ld s8, 48(sp)
    ld s9, 40(sp)
    ld s10, 32(sp)
    ld s11, 24(sp)
    addi sp, sp, 128
done:
    ret

.section .rodata

# The hydra: each chunk's tag, its record's size, and the least records
# it holds, its terminal counted
.balign 4
sf_hydra:
    .4byte TAG_PHDR
    .2byte PHDR_SIZE, 2
    .4byte TAG_PBAG
    .2byte BAG_SIZE, 1
    .4byte TAG_PMOD
    .2byte 10, 1
    .4byte TAG_PGEN
    .2byte GEN_SIZE, 1
    .4byte TAG_INST
    .2byte INST_SIZE, 2
    .4byte TAG_IBAG
    .2byte BAG_SIZE, 1
    .4byte TAG_IMOD
    .2byte 10, 1
    .4byte TAG_IGEN
    .2byte GEN_SIZE, 1
    .4byte TAG_SHDR
    .2byte SHDR_SIZE, 2

# The generators' defaults, one row a generator in the specification's
# order: the filter open, every time the least, the ranges the whole
# keyboard and every velocity, the scale tuning a semitone a key, the
# substitutions and the root key unset
.balign 2
sf_defaults:
    .2byte 0, 0, 0, 0, 0, 0, 0, 0, 13500, 0             # 0 to 9
    .2byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0                 # 10 to 19
    .2byte 0, -12000, 0, -12000, 0, -12000, -12000, -12000, -12000, 0   # 20 to 29
    .2byte -12000, 0, 0, -12000, -12000, -12000, -12000, 0, -12000, 0   # 30 to 39
    .2byte 0, 0, 0, 0x7f00, 0x7f00, 0, -1, -1, 0, 0     # 40 to 49
    .2byte 0, 0, 0, 0, 0, 0, 100, 0, -1, 0              # 50 to 59
    .2byte 0                                            # 60

# Whether a generator is a value the preset level adds to, one row a
# generator: the ranges, the indices, the substitutions, and the sample
# generators are not
sf_value:
    .byte 0, 0, 0, 0, 0, 1, 1, 1, 1, 1                  # 0 to 9
    .byte 1, 1, 0, 1, 1, 1, 1, 1, 1, 1                  # 10 to 19
    .byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1                  # 20 to 29
    .byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1                  # 30 to 39
    .byte 1, 0, 1, 0, 0, 0, 0, 0, 1, 1                  # 40 to 49
    .byte 0, 1, 1, 0, 0, 1, 1, 0, 0, 1                  # 50 to 59
    .byte 1                                             # 60

# The logarithm of 1 + m/16 for m of 0 to 15, times 256
sf_log2:
    .byte 0, 22, 44, 63, 82, 100, 118, 134
    .byte 150, 165, 179, 193, 207, 220, 232, 244

# The ratios 2^(n/12) and 2^(c/1200) in 16.16
.balign 4
.include "cents.inc"

.section .bss
.balign 8
.global soundfont_loaded
soundfont_loaded:
    .skip 8
sf_samples:
    .skip 8
sf_sample_count:
    .skip 8
sf_hydra_ptr:
    .skip HYDRA_COUNT * 8
sf_hydra_count:
    .skip HYDRA_COUNT * 8
sf_age:
    .skip 8
sf_voices:
    .skip VOICES * FV_SIZE
.balign 2
sf_gen:
    .skip GENERATORS * 2
sf_preset_gen:
    .skip GENERATORS * 2
