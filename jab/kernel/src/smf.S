.include "jab.inc"
.include "synth.inc"

# The Standard MIDI File player: a sequencer over the synthesizer
# (synth.S) stepped by the sound clock, one step a period as the
# stream refills (sound.S), so a file's events land on the same
# calls a program makes live and within a period of their time. The
# file stays in the program's memory where jab.midi.play found it,
# read in place: the header's format, track count, and division, then
# every MTrk chunk as a track with a cursor, its running status, and
# the absolute tick of its next event. A step moves the position by
# the period's ticks, 20000 times the division over the tempo in
# microseconds a quarter note, kept in 32.32 fixed point, and fires
# every track's events up to it: notes on and off, controllers,
# program changes, and bends to the synthesizer, the tempo meta event
# to the clock, the end-of-track meta event ending the track; every
# other event is skipped by its length. The piece ends when every
# track has. Every read is bounded by its track's chunk, so a
# malformed file ends its track rather than reading past it.
.set TRACKS, JAB_MIDI_TRACKS
.set TRACK_AT, 0                # the next byte to read
.set TRACK_END, 8               # the chunk's end
.set TRACK_TICK, 16             # the next event's absolute tick
.set TRACK_STATUS, 24           # the running status
.set TRACK_DONE, 25
.set TRACK_SIZE, 32
.set HEADER_BYTES, 14
.set CHUNK_HEADER_BYTES, 8
.set FORMAT_MOST, 1
.set META, 0xff
.set SYSEX, 0xf0
.set SYSEX_ESCAPE, 0xf7
.set META_TEMPO, 0x51
.set META_END, 0x2f
.set TEMPO_DEFAULT, 500000
# One period, JAB_SOUND_PERIOD frames at JAB_SOUND_RATE, in microseconds
.set PERIOD_MICROS, (JAB_SOUND_PERIOD * 1000000 / JAB_SOUND_RATE)

.section .text

# sys_midi_play (jab.midi.play): a0 is a Standard MIDI File inside the
# program's window, a1 its length. Whatever was playing stops, its
# notes released; the file's tracks are read and the piece starts at
# the next period. a0 becomes 0, or jab.sound.open's code, or 3 when
# the file is not one the player takes: no MThd header, a format past
# 1, a SMPTE division, no track or more than JAB_MIDI_TRACKS, or a
# chunk past the end.
.global sys_midi_play
sys_midi_play:
    call sound_open
    bnez a0, 9f
    ld a0, 80(sp)
    ld a1, 88(sp)
    call buffer_bounds
    call smf_stop
    ld a0, 80(sp)
    ld a1, 88(sp)
    call smf_load
9:
    sd a0, 80(sp)
    j trap_return

# sys_midi_stop (jab.midi.stop): the piece stops where it is, its
# notes released. a0 becomes 0, or jab.sound.open's code.
.global sys_midi_stop
sys_midi_stop:
    call sound_open
    bnez a0, 9f
    call smf_stop
    li a0, 0
9:
    sd a0, 80(sp)
    j trap_return

# sys_midi_playing (jab.midi.playing): a0 becomes 1 while a piece
# plays, else 0.
.global sys_midi_playing
sys_midi_playing:
    la t0, smf_playing
    ld a0, 0(t0)
    sd a0, 80(sp)
    j trap_return

# smf_stop: the sequencer stopped and the file's own voices released,
# the calls' left sounding. Keeps the s registers.
.global smf_stop
smf_stop:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, smf_playing
    ld t1, 0(t0)
    beqz t1, 1f
    sd zero, 0(t0)
    li a0, 0
    li a1, SOURCE_FILE
    call synth_all_off
1:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# smf_load: the file at a0 of a1 bytes read into the tracks and the
# clock, and the piece started. a0 becomes 0, or 3 when the file is
# refused.
smf_load:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    mv s0, a0                   # the file
    add s1, a0, a1              # its end
    li t0, HEADER_BYTES
    bltu a1, t0, 8f
    # "MThd", a length of 6, a format of 0 or 1, 1 to TRACKS tracks, a
    # division in ticks a quarter note
    lbu t0, 0(s0)
    li t1, 'M'
    bne t0, t1, 8f
    lbu t0, 1(s0)
    li t1, 'T'
    bne t0, t1, 8f
    lbu t0, 2(s0)
    li t1, 'h'
    bne t0, t1, 8f
    lbu t0, 3(s0)
    li t1, 'd'
    bne t0, t1, 8f
    addi a0, s0, 4
    call smf_be32
    li t0, 6
    bne a0, t0, 8f
    addi a0, s0, 8
    call smf_be16
    li t0, FORMAT_MOST
    bgtu a0, t0, 8f
    addi a0, s0, 10
    call smf_be16
    beqz a0, 8f
    li t0, TRACKS
    bgtu a0, t0, 8f
    mv s2, a0                   # the track count
    addi a0, s0, 12
    call smf_be16
    beqz a0, 8f
    li t0, 0x8000
    and t1, a0, t0
    bnez t1, 8f
    la t0, smf_division
    sd a0, 0(t0)
    # the tracks: each MTrk chunk in turn, a chunk of any other kind
    # skipped by its length, the file's end ending the count early
    la t0, smf_track_count
    sd zero, 0(t0)
    addi s3, s0, HEADER_BYTES   # the next chunk
1:
    la t0, smf_track_count
    ld t0, 0(t0)
    bgeu t0, s2, 5f
    addi t0, s3, CHUNK_HEADER_BYTES
    bgtu t0, s1, 5f
    addi a0, s3, 4
    call smf_be32
    addi s4, s3, CHUNK_HEADER_BYTES
    add s4, s4, a0              # the chunk's end
    bltu s4, s3, 8f
    bgtu s4, s1, 8f
    lbu t0, 0(s3)
    li t2, 'M'
    bne t0, t2, 4f
    lbu t0, 1(s3)
    li t2, 'T'
    bne t0, t2, 4f
    lbu t0, 2(s3)
    li t2, 'r'
    bne t0, t2, 4f
    lbu t0, 3(s3)
    li t2, 'k'
    bne t0, t2, 4f
    # a track: its record, and its first delta
    la t0, smf_track_count
    ld t2, 0(t0)
    li t3, TRACK_SIZE
    mul t2, t2, t3
    la t3, smf_tracks
    add t2, t2, t3
    addi t0, s3, CHUNK_HEADER_BYTES
    sd t0, TRACK_AT(t2)
    sd s4, TRACK_END(t2)
    sd zero, TRACK_TICK(t2)
    sb zero, TRACK_STATUS(t2)
    sb zero, TRACK_DONE(t2)
    mv a0, t2
    call smf_delta
    la t0, smf_track_count
    ld t2, 0(t0)
    addi t2, t2, 1
    sd t2, 0(t0)
4:
    mv s3, s4
    j 1b
5:
    la t0, smf_track_count
    ld t0, 0(t0)
    beqz t0, 8f
    li t0, TEMPO_DEFAULT
    la t1, smf_tempo
    sd t0, 0(t1)
    call smf_clock
    la t0, smf_position
    sd zero, 0(t0)
    la t0, smf_playing
    li t1, 1
    sd t1, 0(t0)
    li a0, 0
    j 9f
8:
    li a0, 3
9:
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 64
    ret

# smf_clock: the position's step a period from the tempo and the
# division, 32.32 ticks. Clobbers t registers.
smf_clock:
    la t0, smf_division
    ld t0, 0(t0)
    li t1, PERIOD_MICROS
    mul t0, t0, t1
    slli t0, t0, 32
    la t1, smf_tempo
    ld t1, 0(t1)
    divu t0, t0, t1
    la t1, smf_increment
    sd t0, 0(t1)
    ret

# smf_be32, smf_be16: the big-endian value at a0, into a0. Clobbers t0
# and t1.
smf_be32:
    mv t1, a0
    lbu a0, 0(t1)
    slli a0, a0, 8
    lbu t0, 1(t1)
    or a0, a0, t0
    slli a0, a0, 8
    lbu t0, 2(t1)
    or a0, a0, t0
    slli a0, a0, 8
    lbu t0, 3(t1)
    or a0, a0, t0
    ret

smf_be16:
    lbu t0, 0(a0)
    lbu t1, 1(a0)
    slli a0, t0, 8
    or a0, a0, t1
    ret

# smf_step: one period of the piece: the position moved on by the
# clock's step and every track's events up to it fired; the piece
# ends once every track has. Called as the stream refills (sound.S),
# so it keeps every register but the t registers and a0.
.global smf_step
smf_step:
    la t0, smf_playing
    ld t0, 0(t0)
    beqz t0, 9f
    addi sp, sp, -96
    sd ra, 88(sp)
    sd s0, 80(sp)
    sd s1, 72(sp)
    sd s2, 64(sp)
    sd a1, 56(sp)
    sd a2, 48(sp)
    sd a3, 40(sp)
    sd a4, 32(sp)
    sd a5, 24(sp)
    sd a6, 16(sp)
    sd a7, 8(sp)
    la t0, smf_position
    ld t1, 0(t0)
    la t2, smf_increment
    ld t2, 0(t2)
    add t1, t1, t2
    sd t1, 0(t0)
    # the events fired from here are the file's own notes
    call synth_from_file
    la s0, smf_tracks
    la t0, smf_track_count
    ld s1, 0(t0)
    li s2, 0                    # tracks still going
1:
    lbu t0, TRACK_DONE(s0)
    bnez t0, 3f
2:
    la t0, smf_position
    ld t0, 0(t0)
    srli t0, t0, 32
    ld t1, TRACK_TICK(s0)
    bltu t0, t1, 4f
    mv a0, s0
    call smf_event
    lbu t0, TRACK_DONE(s0)
    beqz t0, 2b
    j 3f
4:
    addi s2, s2, 1
3:
    addi s0, s0, TRACK_SIZE
    addi s1, s1, -1
    bnez s1, 1b
    bnez s2, 5f
    la t0, smf_playing
    sd zero, 0(t0)
    # a note the file left held, ending without its off, goes to its
    # release with the piece
    li a0, 0
    li a1, SOURCE_FILE
    call synth_all_off
5:
    # and the calls' again, the file having taken its turn inside a
    # call or the vector
    call synth_live
    ld ra, 88(sp)
    ld s0, 80(sp)
    ld s1, 72(sp)
    ld s2, 64(sp)
    ld a1, 56(sp)
    ld a2, 48(sp)
    ld a3, 40(sp)
    ld a4, 32(sp)
    ld a5, 24(sp)
    ld a6, 16(sp)
    ld a7, 8(sp)
    addi sp, sp, 96
9:
    ret

# smf_event: the event at the cursor of the track record at a0 fired
# and the cursor moved past it and its next delta; a read past the
# chunk, a running status with none set, or the end-of-track event
# ends the track. Keeps the s registers.
smf_event:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s0, a0
    ld s1, TRACK_AT(s0)
    ld s2, TRACK_END(s0)
    bgeu s1, s2, 8f
    lbu s3, 0(s1)               # the status, or a data byte
    li t0, 0x80
    bgeu s3, t0, 1f
    lbu s3, TRACK_STATUS(s0)
    beqz s3, 8f
    j 2f
1:
    addi s1, s1, 1
    li t0, META
    beq s3, t0, 3f
    li t0, SYSEX
    beq s3, t0, 4f
    li t0, SYSEX_ESCAPE
    beq s3, t0, 4f
    sb s3, TRACK_STATUS(s0)
2:
    # a channel message
    srli t0, s3, 4
    andi a0, s3, 15
    li t1, 0xc
    beq t0, t1, 20f
    li t1, 0xd
    beq t0, t1, 21f
    li t1, 0xf
    beq t0, t1, 8f
    # two data bytes
    addi t2, s1, 2
    bgtu t2, s2, 8f
    lbu a1, 0(s1)
    lbu a2, 1(s1)
    addi s1, s1, 2
    li t1, 0x8
    beq t0, t1, 10f
    li t1, 0x9
    beq t0, t1, 11f
    li t1, 0xb
    beq t0, t1, 12f
    li t1, 0xe
    beq t0, t1, 13f
    j 7f                        # aftertouch: nothing
10:
    call synth_note_off
    j 7f
11:
    beqz a2, 10b
    call synth_note_on
    j 7f
12:
    call synth_control
    j 7f
13:
    slli a2, a2, 7
    or a1, a1, a2
    call synth_bend
    j 7f
20:
    # one data byte: the program
    bgeu s1, s2, 8f
    lbu a1, 0(s1)
    addi s1, s1, 1
    call synth_program
    j 7f
21:
    # one data byte: channel pressure, nothing
    bgeu s1, s2, 8f
    addi s1, s1, 1
    j 7f
3:
    # a meta event: its kind, its length, its bytes
    bgeu s1, s2, 8f
    lbu s3, 0(s1)
    addi s1, s1, 1
    mv a0, s1
    mv a1, s2
    call smf_varint
    beqz a2, 8f
    mv s1, a1
    add t0, s1, a0
    bltu t0, s1, 8f
    bgtu t0, s2, 8f
    sd t0, 0(sp)                # the bytes' end
    li t1, META_END
    beq s3, t1, 8f
    li t1, META_TEMPO
    bne s3, t1, 5f
    li t1, 3
    bne a0, t1, 5f
    lbu t1, 0(s1)
    slli t1, t1, 8
    lbu t2, 1(s1)
    or t1, t1, t2
    slli t1, t1, 8
    lbu t2, 2(s1)
    or t1, t1, t2
    beqz t1, 5f
    la t2, smf_tempo
    sd t1, 0(t2)
    call smf_clock
5:
    ld s1, 0(sp)
    j 7f
4:
    # a system exclusive event: skipped by its length
    mv a0, s1
    mv a1, s2
    call smf_varint
    beqz a2, 8f
    add s1, a1, a0
    bltu s1, a1, 8f
    bgtu s1, s2, 8f
7:
    # the next delta
    sd s1, TRACK_AT(s0)
    mv a0, s0
    call smf_delta
    j 9f
8:
    li t0, 1
    sb t0, TRACK_DONE(s0)
9:
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 48
    ret

# smf_delta: the delta at the cursor of the track record at a0 added
# to its tick and the cursor moved past it; a track with no delta left
# is done. Clobbers t registers and a0 to a2.
smf_delta:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
    ld a1, TRACK_END(a0)
    ld a0, TRACK_AT(a0)
    call smf_varint
    ld t0, 0(sp)
    beqz a2, 1f
    ld t1, TRACK_TICK(t0)
    add t1, t1, a0
    sd t1, TRACK_TICK(t0)
    sd a1, TRACK_AT(t0)
    j 2f
1:
    li t1, 1
    sb t1, TRACK_DONE(t0)
2:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# smf_varint: the variable-length quantity at a0, read no further than
# a1: a0 becomes its value, a1 the byte after it, a2 1, or a2 0 when
# it runs past a1 or past four bytes. Clobbers t0 to t2.
smf_varint:
    li t2, 0                    # the value
    li t1, 4                    # bytes left to take
1:
    bgeu a0, a1, 3f
    beqz t1, 3f
    lbu t0, 0(a0)
    addi a0, a0, 1
    addi t1, t1, -1
    andi a2, t0, 0x7f
    slli t2, t2, 7
    or t2, t2, a2
    andi t0, t0, 0x80
    bnez t0, 1b
    mv a1, a0
    mv a0, t2
    li a2, 1
    ret
3:
    li a2, 0
    ret

.section .bss
.balign 8
smf_playing:
    .skip 8
smf_division:
    .skip 8
smf_tempo:
    .skip 8
smf_position:
    .skip 8
smf_increment:
    .skip 8
smf_track_count:
    .skip 8
smf_tracks:
    .skip TRACKS * TRACK_SIZE
