# piano: the kernel's synthesizer on the keyboard. One octave from
# middle C is drawn as twelve keys across the screen, every one white,
# C4 to B4 a semitone apart, and each carries the key that plays it: A
# S D F G H J K L ; V N, the home row and then V and N. A key pressed
# starts its note on the piano and letting go releases it.
.include "jab.inc"

.set CHANNEL, 0
.set PROGRAM, 0
.set VELOCITY, 100
.set KEYS, 12
.set NOTE_FIRST, 60
# The keys: KEY_WIDTH by KEY_HEIGHT, KEY_GAP apart, the row centred
.set KEY_WIDTH, 140
.set KEY_HEIGHT, 560
.set KEY_GAP, 8
.set KEY_STRIDE, (KEY_WIDTH + KEY_GAP)
.set ROW_WIDTH, (KEYS * KEY_STRIDE - KEY_GAP)
.set ROW_X, ((JAB_DISPLAY_WIDTH - ROW_WIDTH) / 2)
.set ROW_Y, ((JAB_DISPLAY_HEIGHT - KEY_HEIGHT) / 2)
.set KEY_COLOR, 0x00ffffff
# The labels: bold black at three times the console's cell, centred
# in the key; bold adds a pixel to the width
.set LABEL_SCALE, (JAB_TEXT_SCALE_ONE * 3)
.set LABEL_WIDTH, (JAB_TEXT_WIDTH * 3 + 1)
.set LABEL_HEIGHT, (JAB_TEXT_HEIGHT * 3)
.set LABEL_X, ((KEY_WIDTH - LABEL_WIDTH) / 2)
.set LABEL_Y, ((KEY_HEIGHT - LABEL_HEIGHT) / 2)
.set LABEL_COLOR, 0x00000000
.set LABEL_ENTRY, 2

.section .text
.global _start
_start:
    jab.display.open
    bnez a0, no_display
    jab.sound.open
    bnez a0, no_sound
    li t0, CHANNEL
    li t1, PROGRAM
    jab.midi.program t0, t1
    call draw_keys
    jab.display.await
    jab.display.flip
loop:
    jab.keyboard.await
1:
    jab.keyboard.input
    beqz a0, loop
    call apply_key
    j 1b

no_display:
    jab.uart.print msg_no_display
    jab.exit 1

no_sound:
    jab.uart.print msg_no_sound
    jab.exit 2

# draw_keys: every key a white rectangle with its label in it.
draw_keys:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    li s0, 0                    # the key
1:
    li t0, KEY_STRIDE
    mul s1, s0, t0
    addi s1, s1, ROW_X          # its left
    # the rectangle, a row at a time
    li t0, JAB_DISPLAY_BASE + ROW_Y * JAB_DISPLAY_PITCH
    slli t1, s1, 2
    add t0, t0, t1              # its first pixel
    li t2, KEY_HEIGHT
    li t5, KEY_COLOR
2:
    mv t3, t0
    li t4, KEY_WIDTH
3:
    sw t5, 0(t3)
    addi t3, t3, 4
    addi t4, t4, -1
    bnez t4, 3b
    li t3, JAB_DISPLAY_PITCH
    add t0, t0, t3
    addi t2, t2, -1
    bnez t2, 2b
    # the label, its address computed, so the plain call
    la a0, labels
    slli t0, s0, 1
    add a0, a0, t0
    addi a1, s1, LABEL_X
    li a2, ROW_Y + LABEL_Y
    li a3, LABEL_COLOR
    li a4, JAB_TEXT_BOLD
    li a5, LABEL_SCALE
    li a7, JAB_SYS_DISPLAY_TEXT
    ecall
    addi s0, s0, 1
    li t0, KEYS
    bltu s0, t0, 1b
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
    ret

# apply_key: a0 is a key's code and a1 its value; a repeat is ignored,
# a press starts the key's note and a release ends it.
apply_key:
    addi sp, sp, -16
    sd ra, 8(sp)
    li t0, JAB_KEY_HELD
    beq a1, t0, 9f
    mv t3, a1
    # the key's place in the table, or none
    la t0, key_codes
    li t1, 0
1:
    lbu t2, 0(t0)
    beq t2, a0, 2f
    addi t0, t0, 1
    addi t1, t1, 1
    li t2, KEYS
    bltu t1, t2, 1b
    j 9f
2:
    addi t1, t1, NOTE_FIRST     # its note
    li t0, CHANNEL
    li t2, JAB_KEY_PRESSED
    bne t3, t2, 3f
    li t2, VELOCITY
    jab.midi.note.on t0, t1, t2
    j 9f
3:
    jab.midi.note.off t0, t1
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.section .rodata
# The keys that play, C4 up a semitone each
key_codes:
    .byte JAB_KEY_A, JAB_KEY_S, JAB_KEY_D, JAB_KEY_F, JAB_KEY_G, JAB_KEY_H
    .byte JAB_KEY_J, JAB_KEY_K, JAB_KEY_L, JAB_KEY_SEMICOLON, JAB_KEY_V, JAB_KEY_N
# Each key's label, LABEL_ENTRY bytes, terminated
labels:
    .byte 'A', 0, 'S', 0, 'D', 0, 'F', 0, 'G', 0, 'H', 0
    .byte 'J', 0, 'K', 0, 'L', 0, ';', 0, 'V', 0, 'N', 0
msg_no_display:
    .asciz "piano: no display\n"
msg_no_sound:
    .asciz "piano: no sound\n"
