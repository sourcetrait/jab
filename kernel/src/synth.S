.include "jab.inc"
.include "synth.inc"

.set VOICES, JAB_MIDI_VOICES
.set CHANNELS, JAB_MIDI_CHANNELS
.set PERCUSSION, JAB_MIDI_PERCUSSION
.set TOP, (65535 << 16)
.set FRAMES_PER_MS, (JAB_SOUND_RATE / 1000)
.set LFO_HZ, 89478
.set BEND_SCALE, 8028

.set VOICE_STAGE, 0             # 0 free, 1 attack, 2 decay, 3 sustain, 4 release
.set VOICE_CHANNEL, 1
.set VOICE_NOTE, 2              # the MIDI note, for identity; a drum sounds elsewhere
.set VOICE_VELOCITY, 3
.set VOICE_WAVE, 4
.set VOICE_DUTY, 5
.set VOICE_HELD, 6              # released under the pedal; waits for it
.set VOICE_DEPTH, 7             # the vibrato's
.set VOICE_PHASE, 8             # u32
.set VOICE_STEP, 12             # u32, the note's own
.set VOICE_DECAY, 16            # u32 a frame, once the top is reached
.set VOICE_SUSTAIN, 20          # u32, the level the decay settles at
.set VOICE_RELEASE_MS, 24       # u32
.set VOICE_LFO_PHASE, 28        # u32
.set VOICE_LFO_STEP, 32         # u32 a frame
.set VOICE_AGE, 36              # u32, from the note-on counter
.set VOICE_LFSR, 40             # u32, the noise
.set VOICE_SOURCE, 44           # SOURCE_LIVE or SOURCE_FILE
.set VOICE_LEVEL, 48            # i64, 0 to TOP
.set VOICE_DELTA, 56            # i64 a frame
.set VOICE_SIZE, 64
.set STAGE_ATTACK, 1
.set STAGE_DECAY, 2
.set STAGE_SUSTAIN, 3
.set STAGE_RELEASE, 4

.set DRUM_NOTE, 11
.set DRUM_FIRST, 35
.set DRUM_LAST, 81
.set DRUM_DEFAULT, 9

.section .text

.global synth_init
synth_init:
    addi sp, sp, -16
    sd ra, 8(sp)
    call soundfont_init
    la t0, synth_instruments
    la t1, synth_defaults
    li t2, 128 * JAB_MIDI_INSTRUMENT_ENTRY
1:
    lbu t3, 0(t1)
    sb t3, 0(t0)
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, 1b
    la t0, synth_voices
    li t1, VOICES * VOICE_SIZE
2:
    sb zero, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, 2b
    la t4, synth_channels
    li t5, CHANNELS
3:
    sb zero, CHANNEL_PROGRAM(t4)
    sb zero, CHANNEL_BANK(t4)
    mv a0, t4
    call synth_reset_channel
    addi t4, t4, CHANNEL_SIZE
    addi t5, t5, -1
    bnez t5, 3b
    la t0, synth_age
    sd zero, 0(t0)
    la t0, synth_source
    sb zero, 0(t0)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.global synth_live
synth_live:
    la t0, synth_source
    sb zero, 0(t0)
    ret

.global synth_from_file
synth_from_file:
    la t0, synth_source
    li t1, SOURCE_FILE
    sb t1, 0(t0)
    ret

.global synth_sounding
synth_sounding:
    la t0, synth_voices
    li t1, VOICES
    li a0, 1
1:
    lbu t2, VOICE_STAGE(t0)
    bnez t2, 2f
    addi t0, t0, VOICE_SIZE
    addi t1, t1, -1
    bnez t1, 1b
    j soundfont_sounding
2:
    ret

synth_reset_channel:
    li t0, 100
    sb t0, CHANNEL_VOLUME(a0)
    li t0, 64
    sb t0, CHANNEL_PAN(a0)
    li t0, 127
    sb t0, CHANNEL_EXPRESSION(a0)
    sb zero, CHANNEL_PEDAL(a0)
    sh zero, CHANNEL_BEND(a0)
    ret

synth_channel:
    slli a0, a0, CHANNEL_SHIFT
    la t0, synth_channels
    add a0, a0, t0
    ret

.global sys_midi_program
sys_midi_program:
    call sound_open
    bnez a0, midi_refused
    ld a0, 80(sp)
    ld a1, 88(sp)
    andi a0, a0, CHANNELS - 1
    andi a1, a1, 127
    call synth_channel
    sb a1, CHANNEL_PROGRAM(a0)
    sd zero, 80(sp)
    j trap_return

midi_refused:
    sd a0, 80(sp)
    j trap_return

.global sys_midi_note
sys_midi_note:
    call sound_open
    bnez a0, midi_refused
    call synth_live
    ld a0, 80(sp)
    ld a1, 88(sp)
    ld a2, 96(sp)
    ld a3, 104(sp)
    andi a0, a0, CHANNELS - 1
    andi a1, a1, 127
    andi a2, a2, 127
    beqz a3, 1f
    beqz a2, 1f
    call synth_note_on
    j 2f
1:
    call synth_note_off
2:
    sd zero, 80(sp)
    j trap_return

.global sys_midi_control
sys_midi_control:
    call sound_open
    bnez a0, midi_refused
    call synth_live
    ld a0, 80(sp)
    ld a1, 88(sp)
    ld a2, 96(sp)
    call synth_control
    sd zero, 80(sp)
    j trap_return

.global synth_control
synth_control:
    addi sp, sp, -16
    sd ra, 8(sp)
    andi a0, a0, CHANNELS - 1
    andi a1, a1, 127
    andi a2, a2, 127
    mv a3, a0
    call synth_channel
    li t0, JAB_MIDI_CC_BANK
    bne a1, t0, 10f
    sb a2, CHANNEL_BANK(a0)
    j 9f
10:
    li t0, JAB_MIDI_CC_VOLUME
    bne a1, t0, 1f
    sb a2, CHANNEL_VOLUME(a0)
    j 9f
1:
    li t0, JAB_MIDI_CC_PAN
    bne a1, t0, 2f
    sb a2, CHANNEL_PAN(a0)
    j 9f
2:
    li t0, JAB_MIDI_CC_EXPRESSION
    bne a1, t0, 3f
    sb a2, CHANNEL_EXPRESSION(a0)
    j 9f
3:
    li t0, JAB_MIDI_CC_PEDAL
    bne a1, t0, 4f
    sltiu t1, a2, 64
    xori t1, t1, 1              # down from 64 up
    lbu t2, CHANNEL_PEDAL(a0)
    sb t1, CHANNEL_PEDAL(a0)
    beqz t2, 9f
    bnez t1, 9f
    mv a0, a3
    call synth_pedal_up
    j 9f
4:
    li t0, JAB_MIDI_CC_ALL_SOUND_OFF
    bne a1, t0, 5f
    mv a0, a3
    li a1, 1
    call synth_channel_off
    j 9f
5:
    li t0, JAB_MIDI_CC_RESET
    bne a1, t0, 6f
    mv a0, a3
    call synth_pedal_up
    mv a0, a3
    call synth_channel
    call synth_reset_channel
    j 9f
6:
    li t0, JAB_MIDI_CC_ALL_NOTES_OFF
    bne a1, t0, 9f
    mv a0, a3
    li a1, 0
    call synth_channel_off
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.global synth_program
synth_program:
    andi a0, a0, CHANNELS - 1
    andi a1, a1, 127
    slli a0, a0, CHANNEL_SHIFT
    la t0, synth_channels
    add a0, a0, t0
    sb a1, CHANNEL_PROGRAM(a0)
    ret

.global synth_bend
synth_bend:
    andi a0, a0, CHANNELS - 1
    li t0, 16383
    and a1, a1, t0
    li t0, JAB_MIDI_BEND_CENTER
    sub a1, a1, t0
    slli a0, a0, CHANNEL_SHIFT
    la t0, synth_channels
    add a0, a0, t0
    sh a1, CHANNEL_BEND(a0)
    ret

.global sys_midi_bend
sys_midi_bend:
    call sound_open
    bnez a0, midi_refused
    ld a0, 80(sp)
    ld a1, 88(sp)
    call synth_bend
    sd zero, 80(sp)
    j trap_return

.global sys_midi_instrument
sys_midi_instrument:
    call sound_open
    bnez a0, midi_refused
    ld a0, 88(sp)
    li a1, JAB_MIDI_INSTRUMENT_ENTRY
    call buffer_bounds
    ld t0, 80(sp)
    andi t0, t0, 127
    li t1, JAB_MIDI_INSTRUMENT_ENTRY
    mul t0, t0, t1
    la a0, synth_instruments
    add a0, a0, t0
    ld a1, 88(sp)
    li a2, JAB_MIDI_INSTRUMENT_ENTRY
    call copy_bytes
    sd zero, 80(sp)
    j trap_return

.global sys_midi_silence
sys_midi_silence:
    call sound_open
    bnez a0, midi_refused
    call smf_stop
    li a0, 1
    li a1, SOURCE_ANY
    call synth_all_off
    la t4, synth_channels
    li t5, CHANNELS
2:
    mv a0, t4
    call synth_reset_channel
    addi t4, t4, CHANNEL_SIZE
    addi t5, t5, -1
    bnez t5, 2b
    sd zero, 80(sp)
    j trap_return

.global synth_all_off
synth_all_off:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t4, synth_voices
    li t5, VOICES
1:
    lbu t0, VOICE_STAGE(t4)
    beqz t0, 2f
    bltz a1, 11f
    lbu t1, VOICE_SOURCE(t4)
    bne t1, a1, 2f
11:
    beqz a0, 3f
    sb zero, VOICE_STAGE(t4)
    j 2f
3:
    li t1, STAGE_RELEASE
    beq t0, t1, 2f
    mv t6, a0
    mv a0, t4
    call synth_release
    mv a0, t6
2:
    addi t4, t4, VOICE_SIZE
    addi t5, t5, -1
    bnez t5, 1b
    call soundfont_all_off
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.global synth_note_on
synth_note_on:
    la t0, soundfont_loaded
    ld t0, 0(t0)
    beqz t0, 0f
    j soundfont_note_on
0:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    sd s4, 0(sp)
    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s4, a1                   # the note that sounds
    li t0, PERCUSSION
    bne s0, t0, 1f
    call synth_drum
    mv s3, a0
    mv s4, a1
    j 2f
1:
    call synth_channel
    lbu t0, CHANNEL_PROGRAM(a0)
    li t1, JAB_MIDI_INSTRUMENT_ENTRY
    mul t0, t0, t1
    la s3, synth_instruments
    add s3, s3, t0
2:
    call synth_take
    li t0, STAGE_ATTACK
    sb t0, VOICE_STAGE(a0)
    sb s0, VOICE_CHANNEL(a0)
    sb s1, VOICE_NOTE(a0)
    sb s2, VOICE_VELOCITY(a0)
    la t0, synth_source
    lbu t0, 0(t0)
    sb t0, VOICE_SOURCE(a0)
    lbu t0, JAB_MIDI_WAVE(s3)
    sb t0, VOICE_WAVE(a0)
    lbu t0, JAB_MIDI_DUTY(s3)
    sb t0, VOICE_DUTY(a0)
    sb zero, VOICE_HELD(a0)
    lbu t0, JAB_MIDI_VIBRATO(s3)
    sb t0, VOICE_DEPTH(a0)
    sw zero, VOICE_PHASE(a0)
    mv t6, a0
    mv a0, s4
    call synth_pitch
    sw a0, VOICE_STEP(t6)
    mv a0, t6
    lbu t0, JAB_MIDI_SUSTAIN(s3)
    li t1, 257
    mul t0, t0, t1
    slli t0, t0, 16
    sw t0, VOICE_SUSTAIN(a0)
    lhu t1, JAB_MIDI_DECAY(s3)
    li t2, FRAMES_PER_MS
    mul t1, t1, t2
    li t2, TOP
    sub t2, t2, t0
    beqz t1, 3f
    divu t2, t2, t1
3:
    bnez t2, 4f
    li t2, 1
4:
    sw t2, VOICE_DECAY(a0)
    lhu t1, JAB_MIDI_RELEASE(s3)
    sw t1, VOICE_RELEASE_MS(a0)
    lhu t1, JAB_MIDI_ATTACK(s3)
    li t2, FRAMES_PER_MS
    mul t1, t1, t2
    beqz t1, 5f
    li t2, TOP
    divu t2, t2, t1
    bnez t2, 41f
    li t2, 1
41:
    sd zero, VOICE_LEVEL(a0)
    sd t2, VOICE_DELTA(a0)
    j 6f
5:
    li t2, TOP
    sd t2, VOICE_LEVEL(a0)
    lwu t2, VOICE_DECAY(a0)
    neg t2, t2
    sd t2, VOICE_DELTA(a0)
    li t2, STAGE_DECAY
    sb t2, VOICE_STAGE(a0)
6:
    sw zero, VOICE_LFO_PHASE(a0)
    lbu t1, JAB_MIDI_VIBRATO_RATE(s3)
    li t2, LFO_HZ
    mul t1, t1, t2
    sw t1, VOICE_LFO_STEP(a0)
    la t0, synth_age
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
    sw t1, VOICE_AGE(a0)
    li t2, 0xace1
    xor t2, t2, t1
    ori t2, t2, 1
    sw t2, VOICE_LFSR(a0)
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    ld s4, 0(sp)
    addi sp, sp, 48
    ret

synth_take:
    la t0, synth_voices
    li t1, VOICES
    li t2, 0
    li t3, -1                   # the best candidate's rank, lower is older
1:
    lbu t4, VOICE_STAGE(t0)
    beqz t4, 3f
    lwu t5, VOICE_AGE(t0)
    li t6, STAGE_RELEASE
    beq t4, t6, 2f
    li t6, 1
    slli t6, t6, 32
    add t5, t5, t6              # still held: after every releasing one
2:
    bgeu t5, t3, 4f
    mv t3, t5
    mv t2, t0
4:
    addi t0, t0, VOICE_SIZE
    addi t1, t1, -1
    bnez t1, 1b
    mv a0, t2
    ret
3:
    mv a0, t0
    ret

synth_pitch:
    li t0, 12
    divu t1, a0, t0
    remu t2, a0, t0
    slli t2, t2, 2
    la t0, synth_octave
    add t0, t0, t2
    lwu a0, 0(t0)
    li t2, 10
    sub t2, t2, t1
    srl a0, a0, t2
    ret

synth_drum:
    li a0, DRUM_DEFAULT
    li t0, DRUM_FIRST
    bltu a1, t0, 1f
    li t0, DRUM_LAST
    bgtu a1, t0, 1f
    addi t0, a1, -DRUM_FIRST
    la t1, synth_drum_map
    add t0, t0, t1
    lbu a0, 0(t0)
1:
    li t0, JAB_MIDI_INSTRUMENT_ENTRY
    mul a0, a0, t0
    la t0, synth_drums
    add a0, a0, t0
    lbu a1, DRUM_NOTE(a0)
    ret

.global synth_note_off
synth_note_off:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, a0
    mv s1, a1
    call synth_channel
    lbu t6, CHANNEL_PEDAL(a0)
    la t3, synth_source
    lbu t3, 0(t3)
    la t4, synth_voices
    li t5, VOICES
1:
    lbu t0, VOICE_STAGE(t4)
    beqz t0, 2f
    li t1, STAGE_RELEASE
    beq t0, t1, 2f
    lbu t0, VOICE_CHANNEL(t4)
    bne t0, s0, 2f
    lbu t0, VOICE_NOTE(t4)
    bne t0, s1, 2f
    lbu t0, VOICE_SOURCE(t4)
    bne t0, t3, 2f
    beqz t6, 3f
    li t0, 1
    sb t0, VOICE_HELD(t4)
    j 2f
3:
    mv a0, t4
    call synth_release
2:
    addi t4, t4, VOICE_SIZE
    addi t5, t5, -1
    bnez t5, 1b
    mv a0, s0
    mv a1, s1
    call soundfont_note_off
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
    ret

synth_release:
    li t0, STAGE_RELEASE
    sb t0, VOICE_STAGE(a0)
    sb zero, VOICE_HELD(a0)
    ld t0, VOICE_LEVEL(a0)
    lwu t1, VOICE_RELEASE_MS(a0)
    li t2, FRAMES_PER_MS
    mul t1, t1, t2
    bnez t1, 1f
    li t0, TOP
    j 2f
1:
    divu t0, t0, t1
    bnez t0, 2f
    li t0, 1
2:
    neg t0, t0
    sd t0, VOICE_DELTA(a0)
    ret

synth_pedal_up:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
    la t4, synth_voices
    li t5, VOICES
1:
    lbu t0, VOICE_STAGE(t4)
    beqz t0, 2f
    lbu t0, VOICE_HELD(t4)
    beqz t0, 2f
    lbu t0, VOICE_CHANNEL(t4)
    bne t0, a0, 2f
    mv t6, a0
    mv a0, t4
    call synth_release
    mv a0, t6
2:
    addi t4, t4, VOICE_SIZE
    addi t5, t5, -1
    bnez t5, 1b
    ld a0, 0(sp)
    call soundfont_pedal_up
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

synth_channel_off:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t3, synth_source
    lbu t3, 0(t3)
    la t4, synth_voices
    li t5, VOICES
1:
    lbu t0, VOICE_STAGE(t4)
    beqz t0, 2f
    lbu t0, VOICE_CHANNEL(t4)
    bne t0, a0, 2f
    lbu t0, VOICE_SOURCE(t4)
    bne t0, t3, 2f
    beqz a1, 3f
    sb zero, VOICE_STAGE(t4)
    j 2f
3:
    lbu t0, VOICE_STAGE(t4)
    li t1, STAGE_RELEASE
    beq t0, t1, 2f
    mv t6, a0
    mv a0, t4
    call synth_release
    mv a0, t6
2:
    addi t4, t4, VOICE_SIZE
    addi t5, t5, -1
    bnez t5, 1b
    call soundfont_channel_off
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.global synth_render
synth_render:
    addi sp, sp, -112
    sd ra, 104(sp)
    sd s0, 96(sp)
    sd s1, 88(sp)
    sd s2, 80(sp)
    sd s3, 72(sp)
    sd s4, 64(sp)
    sd s5, 56(sp)
    sd s6, 48(sp)
    sd s7, 40(sp)
    sd s8, 32(sp)
    sd s9, 24(sp)
    sd s10, 16(sp)
    sd s11, 8(sp)
    mv s0, a0
    mv s1, a1
    la s2, synth_voices
    li s3, VOICES
voice:
    lbu a5, VOICE_STAGE(s2)
    beqz a5, next_voice
    lbu a0, VOICE_CHANNEL(s2)
    slli a0, a0, CHANNEL_SHIFT
    la t0, synth_channels
    add a0, a0, t0
    lwu s4, VOICE_STEP(s2)
    lh t0, CHANNEL_BEND(a0)
    beqz t0, 1f
    mul t1, s4, t0
    li t2, BEND_SCALE
    mul t1, t1, t2
    srai t1, t1, 29
    add s4, s4, t1
1:
    lbu t0, VOICE_DEPTH(s2)
    beqz t0, 2f
    lwu t1, VOICE_LFO_PHASE(s2)
    lwu t2, VOICE_LFO_STEP(s2)
    mul t2, t2, s1
    add t1, t1, t2
    sw t1, VOICE_LFO_PHASE(s2)
    srliw t1, t1, 24
    slli t1, t1, 1
    la t2, synth_sine
    add t2, t2, t1
    lh t1, 0(t2)
    mul t1, t1, t0
    mul t1, t1, s4
    srai t1, t1, 27
    add s4, s4, t1
2:
    lbu t0, VOICE_VELOCITY(s2)
    lbu t1, CHANNEL_VOLUME(a0)
    mul t0, t0, t1
    lbu t1, CHANNEL_EXPRESSION(a0)
    mul t0, t0, t1
    srli t0, t0, 14
    lbu t1, CHANNEL_PAN(a0)
    li t2, 127
    sub t3, t2, t1
    slli t3, t3, 1
    bleu t3, t2, 3f
    mv t3, t2
3:
    slli t1, t1, 1
    bleu t1, t2, 4f
    mv t1, t2
4:
    mul s5, t0, t3
    srli s5, s5, 7
    mul s6, t0, t1
    srli s6, s6, 7
    lbu s7, VOICE_WAVE(s2)
    lbu s8, VOICE_DUTY(s2)
    lwu s9, VOICE_PHASE(s2)
    ld s10, VOICE_LEVEL(s2)
    ld s11, VOICE_DELTA(s2)
    lwu a2, VOICE_DECAY(s2)
    lwu a3, VOICE_SUSTAIN(s2)
    lwu a4, VOICE_LFSR(s2)
    mv a6, s0
    mv a7, s1
frame:
    li t0, JAB_WAVE_SQUARE
    bne s7, t0, 10f
    srliw t0, s9, 24
    li t2, 32767
    bltu t0, s8, 20f
    li t2, -32768
    j 20f
10:
    li t0, JAB_WAVE_TRIANGLE
    bne s7, t0, 11f
    srliw t0, s9, 16
    li t1, 32768
    bltu t0, t1, 12f
    li t1, 65535
    sub t0, t1, t0
12:
    slli t2, t0, 1
    li t1, 32768
    sub t2, t2, t1
    j 20f
11:
    li t0, JAB_WAVE_SAW
    bne s7, t0, 13f
    srliw t2, s9, 16
    li t1, 32768
    sub t2, t2, t1
    j 20f
13:
    li t0, JAB_WAVE_SINE
    bne s7, t0, 14f
    srliw t0, s9, 24
    slli t0, t0, 1
    la t1, synth_sine
    add t1, t1, t0
    lh t2, 0(t1)
    j 20f
14:
    andi t2, a4, 1
    li t0, 32767
    bnez t2, 15f
    li t0, -32768
15:
    mv t2, t0
    srliw t0, s9, 27
    addw t1, s9, s4
    srliw t1, t1, 27
    beq t0, t1, 20f
    srli t0, a4, 1
    xor t0, t0, a4
    srli t1, a4, 3
    xor t0, t0, t1
    srli t1, a4, 12
    xor t0, t0, t1
    andi t0, t0, 1
    slli t0, t0, 15
    srli a4, a4, 1
    or a4, a4, t0
20:
    addw s9, s9, s4
    mul t2, t2, s10
    srai t2, t2, 32
    lw t0, 0(a6)
    mul t1, t2, s5
    srai t1, t1, 7
    add t0, t0, t1
    sw t0, 0(a6)
    lw t0, 4(a6)
    mul t1, t2, s6
    srai t1, t1, 7
    add t0, t0, t1
    sw t0, 4(a6)
    addi a6, a6, 8
    beqz s11, 30f
    add s10, s10, s11
    li t0, STAGE_ATTACK
    bne a5, t0, 21f
    li t0, TOP
    blt s10, t0, 30f
    mv s10, t0
    li a5, STAGE_DECAY
    neg s11, a2
    j 30f
21:
    li t0, STAGE_DECAY
    bne a5, t0, 22f
    bgt s10, a3, 30f
    mv s10, a3
    li a5, STAGE_SUSTAIN
    li s11, 0
    bnez s10, 30f
    li a5, 0
    j 31f
22:
    bgtz s10, 30f
    li s10, 0
    li a5, 0
    j 31f
30:
    addi a7, a7, -1
    bnez a7, frame
31:
    sw s9, VOICE_PHASE(s2)
    sd s10, VOICE_LEVEL(s2)
    sd s11, VOICE_DELTA(s2)
    sw a4, VOICE_LFSR(s2)
    sb a5, VOICE_STAGE(s2)
next_voice:
    addi s2, s2, VOICE_SIZE
    addi s3, s3, -1
    bnez s3, voice
    mv a0, s0
    mv a1, s1
    call soundfont_render
    ld ra, 104(sp)
    ld s0, 96(sp)
    ld s1, 88(sp)
    ld s2, 80(sp)
    ld s3, 72(sp)
    ld s4, 64(sp)
    ld s5, 56(sp)
    ld s6, 48(sp)
    ld s7, 40(sp)
    ld s8, 32(sp)
    ld s9, 24(sp)
    ld s10, 16(sp)
    ld s11, 8(sp)
    addi sp, sp, 112
    ret

.section .rodata

.balign 4
synth_octave:
    .4byte 749115498, 793660223, 840853716, 890853480
    .4byte 943826385, 999949222, 1059409297, 1122405052
    .4byte 1189146729, 1259857073, 1334772074, 1414141751

.balign 2
.include "sine.inc"

.macro instrument wave, duty, attack, decay, release, sustain, depth=0, rate=0
    .byte \wave, \duty
    .2byte \attack, \decay, \release
    .byte \sustain, \depth, \rate, 0
.endm

.balign 2
synth_defaults:
    .rept 8
    instrument JAB_WAVE_SQUARE, 64, 0, 900, 120, 0
    .endr
    .rept 8
    instrument JAB_WAVE_SINE, 128, 0, 700, 150, 0
    .endr
    .rept 8
    instrument JAB_WAVE_SQUARE, 128, 10, 0, 40, 255, 20, 6
    .endr
    .rept 4
    instrument JAB_WAVE_TRIANGLE, 128, 0, 700, 100, 0
    .endr
    .rept 4
    instrument JAB_WAVE_SAW, 128, 0, 500, 100, 60
    .endr
    .rept 6
    instrument JAB_WAVE_TRIANGLE, 128, 0, 400, 80, 180
    .endr
    .rept 2
    instrument JAB_WAVE_SQUARE, 128, 0, 300, 60, 200
    .endr
    .rept 8
    instrument JAB_WAVE_SAW, 128, 120, 200, 300, 200, 40, 5
    .endr
    .rept 8
    instrument JAB_WAVE_SAW, 128, 250, 300, 400, 210, 30, 5
    .endr
    .rept 8
    instrument JAB_WAVE_SQUARE, 96, 40, 150, 80, 200, 20, 5
    .endr
    .rept 8
    instrument JAB_WAVE_SQUARE, 128, 30, 100, 80, 210, 30, 5
    .endr
    .rept 8
    instrument JAB_WAVE_SINE, 128, 60, 100, 100, 210, 30, 5
    .endr
    instrument JAB_WAVE_SQUARE, 128, 5, 100, 60, 220
    instrument JAB_WAVE_SAW, 128, 5, 100, 60, 220
    instrument JAB_WAVE_SINE, 128, 20, 100, 80, 220, 20, 5
    instrument JAB_WAVE_TRIANGLE, 128, 5, 150, 60, 200
    instrument JAB_WAVE_SAW, 128, 5, 100, 60, 220, 20, 6
    instrument JAB_WAVE_SINE, 128, 60, 150, 150, 220, 30, 5
    instrument JAB_WAVE_SAW, 128, 5, 100, 60, 220
    instrument JAB_WAVE_SQUARE, 128, 5, 100, 60, 220
    .rept 8
    instrument JAB_WAVE_SAW, 128, 400, 300, 600, 200, 20, 4
    .endr
    .rept 8
    instrument JAB_WAVE_TRIANGLE, 128, 200, 400, 500, 150, 60, 3
    .endr
    .rept 8
    instrument JAB_WAVE_TRIANGLE, 128, 0, 500, 100, 0
    .endr
    .rept 7
    instrument JAB_WAVE_TRIANGLE, 128, 0, 250, 60, 0
    .endr
    instrument JAB_WAVE_NOISE, 0, 800, 100, 100, 0
    .rept 8
    instrument JAB_WAVE_NOISE, 0, 0, 400, 200, 0
    .endr

.macro drum wave, duty, decay, release, note
    .byte \wave, \duty
    .2byte 0, \decay, \release
    .byte 0, 0, 0, \note
.endm

.balign 2
synth_drums:
    drum JAB_WAVE_TRIANGLE, 128, 180, 40, 33
    drum JAB_WAVE_NOISE, 0, 160, 40, 90
    drum JAB_WAVE_NOISE, 0, 45, 15, 110
    drum JAB_WAVE_NOISE, 0, 260, 60, 110
    drum JAB_WAVE_TRIANGLE, 128, 250, 60, 43
    drum JAB_WAVE_TRIANGLE, 128, 220, 60, 48
    drum JAB_WAVE_TRIANGLE, 128, 200, 60, 53
    drum JAB_WAVE_NOISE, 0, 700, 200, 100
    drum JAB_WAVE_NOISE, 0, 350, 100, 115
    drum JAB_WAVE_NOISE, 0, 120, 30, 95
    drum JAB_WAVE_SQUARE, 128, 40, 10, 84

synth_drum_map:
    .byte 0, 0, 10, 1, 9, 1, 4, 2        # 35-42
    .byte 4, 2, 5, 3, 5, 6, 7, 6         # 43-50
    .byte 8, 7, 8, 2, 7, 10, 7, 9        # 51-58
    .byte 8, 6, 6, 5, 5, 4, 5, 4         # 59-66
    .byte 10, 10, 2, 2, 10, 10, 9, 9     # 67-74
    .byte 10, 10, 10, 9, 9, 2, 3         # 75-81

.section .bss
.balign 8
synth_age:
    .skip 8
.global synth_channels
synth_channels:
    .skip CHANNELS * CHANNEL_SIZE
synth_voices:
    .skip VOICES * VOICE_SIZE
synth_instruments:
    .skip 128 * JAB_MIDI_INSTRUMENT_ENTRY
.global synth_source
synth_source:
    .skip 1
