.include "jab.inc"

.set CHANNEL, 0
.set TONE_NOTE, 69
.set TONE_VELOCITY, 127
.set TONE_VOLUME, 127
.set TONE_HOLD, JAB_TIME_HZ
.set TAIL, (JAB_TIME_HZ / 2)
.set PIANO_PROGRAM, 0
.set PIANO_NOTE, 60
.set PIANO_VELOCITY, 100
.set PIANO_HOLD, (JAB_TIME_HZ * 8 / 10)
.set TONE_BYTES, 4096
.set FONT_BYTES, (160 * 1024 * 1024)
.set PAGE_BYTES, (1024 * 1024)
.set LINE_BYTES, 128
.set DIGITS_BYTES, 24

.section .text
.global _start
_start:
    jab.sys.sound.open
    bnez a0, no_sound
    jab.sys.block.find serial_tone
    beqz a0, fluid
    mv s0, a0
    la a0, tone
    li a1, TONE_BYTES
    mv a2, s0
    la a3, path_tone
    call read_file
    beqz a0, no_tone
    la t0, tone
    mv t1, a0
    jab.sys.midi.soundfont t0, t1
    bnez a0, tone_refused
    la a0, label_tone
    call print_counts
    li t0, CHANNEL
    li t1, JAB_MIDI_CC_VOLUME
    li t2, TONE_VOLUME
    jab.sys.midi.control t0, t1, t2
    li t0, CHANNEL
    li t1, TONE_NOTE
    li t2, TONE_VELOCITY
    jab.sys.midi.note.on t0, t1, t2
    li a0, TONE_HOLD
    call spin
    li t0, CHANNEL
    li t1, TONE_NOTE
    jab.sys.midi.note.off t0, t1
    li a0, TAIL
    call spin
fluid:
    jab.sys.block.find serial_mix
    beqz a0, no_mix
    mv s0, a0
    la a0, font
    li a1, FONT_BYTES
    mv a2, s0
    la a3, path_fluid
    call read_file
    beqz a0, no_fluid
    la t0, font
    mv t1, a0
    jab.sys.midi.soundfont t0, t1
    bnez a0, fluid_refused
    la a0, label_fluid
    call print_counts
    li t0, CHANNEL
    li t1, PIANO_PROGRAM
    jab.sys.midi.program t0, t1
    li t0, CHANNEL
    li t1, PIANO_NOTE
    li t2, PIANO_VELOCITY
    jab.sys.midi.note.on t0, t1, t2
    li a0, PIANO_HOLD
    call spin
    li t0, CHANNEL
    li t1, PIANO_NOTE
    jab.sys.midi.note.off t0, t1
    li a0, TAIL
    call spin
    jab.sys.exit 0

no_sound:
    jab.sys.uart.print msg_no_sound
    jab.sys.exit 2

no_tone:
    jab.sys.uart.print msg_no_tone
    jab.sys.exit 3

tone_refused:
    mv s1, a0
    la a0, msg_tone_refused
    call print_code
    jab.sys.exit 4

no_mix:
    jab.sys.uart.print msg_no_mix
    jab.sys.exit 5

no_fluid:
    jab.sys.uart.print msg_no_fluid
    jab.sys.exit 6

fluid_refused:
    mv s1, a0
    la a0, msg_fluid_refused
    call print_code
    jab.sys.exit 7

read_file:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    mv s0, a0                   # the buffer
    mv s1, a1                   # its room
    mv s2, a2                   # the disk
    la a0, rec
    mv a1, s2
    li a2, JAB_ROMFS_ROOT
    li a7, JAB_SYS_ROMFS_FIND
    ecall
    bnez a0, 8f
    la t0, rec
    lwu s3, JAB_ROMFS_OFFSET(t0)
    li s4, 0                    # the byte of the file to read from
    li a4, 0                    # how much is here
1:
    sub t4, s1, a4
    li t5, PAGE_BYTES
    bleu t4, t5, 2f
    mv t4, t5
2:
    beqz t4, 3f
    add t0, s0, a4
    mv t1, s2
    mv t2, s3
    mv t3, s4
    sd a4, 8(sp)
    jab.sys.romfs.read t0, t1, t2, t3, t4
    ld a4, 8(sp)
    beqz a0, 3f
    add a4, a4, a0
    mv s4, a1
    bnez s4, 1b
3:
    mv a0, a4
    j 9f
8:
    li a0, 0
9:
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 64
    ret

print_counts:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd a1, 0(sp)
    sd a2, 8(sp)
    sd a3, 16(sp)
    mv a1, a0
    la a0, line
    call append_str
    la a1, word_presets
    call append_str
    ld a1, 0(sp)
    call append_dec
    la a1, word_instruments
    call append_str
    ld a1, 8(sp)
    call append_dec
    la a1, word_samples
    call append_str
    ld a1, 16(sp)
    call append_dec
    li t0, '\n'
    sb t0, 0(a0)
    sb zero, 1(a0)
    jab.sys.uart.print line
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

print_code:
    addi sp, sp, -16
    sd ra, 8(sp)
    mv a1, a0
    la a0, line
    call append_str
    mv a1, s1
    call append_dec
    li t0, '\n'
    sb t0, 0(a0)
    sb zero, 1(a0)
    jab.sys.uart.print line
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

append_str:
1:
    lbu t0, 0(a1)
    beqz t0, 2f
    sb t0, 0(a0)
    addi a0, a0, 1
    addi a1, a1, 1
    j 1b
2:
    ret

append_dec:
    la t0, digits
    addi t0, t0, DIGITS_BYTES
    li t1, 10
1:
    remu t2, a1, t1
    divu a1, a1, t1
    addi t2, t2, '0'
    addi t0, t0, -1
    sb t2, 0(t0)
    bnez a1, 1b
    la t3, digits
    addi t3, t3, DIGITS_BYTES
2:
    lbu t2, 0(t0)
    sb t2, 0(a0)
    addi a0, a0, 1
    addi t0, t0, 1
    bltu t0, t3, 2b
    ret

spin:
    rdtime t0
    add t1, t0, a0
1:
    rdtime t0
    bltu t0, t1, 1b
    ret

.section .bss
.balign 8
rec:
    .skip JAB_ROMFS_ENTRY
digits:
    .skip DIGITS_BYTES
line:
    .skip LINE_BYTES
.balign 4
tone:
    .skip TONE_BYTES
.balign 4
font:
    .skip FONT_BYTES

.section .rodata
serial_tone:
    .asciz "tone"
serial_mix:
    .asciz "mix"
path_tone:
    .asciz "/tone.sf2"
path_fluid:
    .asciz "/mix/snd/font/FluidR3_GM.sf2"
label_tone:
    .asciz "soundfont: tone"
label_fluid:
    .asciz "soundfont: fluid"
word_presets:
    .asciz " presets="
word_instruments:
    .asciz " instruments="
word_samples:
    .asciz " samples="
msg_no_sound:
    .asciz "soundfont: no sound\n"
msg_no_tone:
    .asciz "soundfont: the tone font is not on its disk\n"
msg_tone_refused:
    .asciz "soundfont: the tone font was refused "
msg_no_mix:
    .asciz "soundfont: no mix disk\n"
msg_no_fluid:
    .asciz "soundfont: FluidR3 is not on the mix disk\n"
msg_fluid_refused:
    .asciz "soundfont: FluidR3 was refused "
