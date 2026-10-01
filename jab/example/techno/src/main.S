# techno: technojab.mid, the piece shipped on the program's romfs,
# played through the kernel's synthesizer on its own, with TECHNOJAB in
# the middle of the screen while it plays; when the piece ends, so does
# the program, its last release played out by the exit.
.include "jab.inc"

.set DISK, 1
.set PIECE_BYTES, 98304
# The title: bold at four times the console's cell, centred on the
# screen; bold adds a pixel to the width
.set TITLE_CELLS, 9
.set TITLE_SCALE, (JAB_TEXT_SCALE_ONE * 4)
.set TITLE_WIDTH, (JAB_TEXT_WIDTH * 4 * TITLE_CELLS + 1)
.set TITLE_HEIGHT, (JAB_TEXT_HEIGHT * 4)
.set TITLE_X, ((JAB_DISPLAY_WIDTH - TITLE_WIDTH) / 2)
.set TITLE_Y, ((JAB_DISPLAY_HEIGHT - TITLE_HEIGHT) / 2)
.set TITLE_COLOR, 0x00ebe6dc

.section .text
.global _start
_start:
    jab.sys.display.open
    bnez a0, no_display
    jab.sys.sound.open
    bnez a0, no_sound
    call read_piece
    la t0, piece_length
    ld t1, 0(t0)
    beqz t1, no_piece
    li t1, TITLE_X
    li t2, TITLE_Y
    li t3, TITLE_COLOR
    li t4, JAB_TEXT_BOLD
    li t5, TITLE_SCALE
    jab.sys.display.text title, t1, t2, t3, t4, t5
    jab.sys.display.await
    jab.sys.display.flip
    la t0, piece
    la t1, piece_length
    ld t1, 0(t1)
    jab.sys.midi.play t0, t1
    bnez a0, refused
playing:
    jab.sys.display.await
    jab.sys.midi.playing
    bnez a0, playing
    jab.sys.exit 0

no_display:
    jab.sys.uart.print msg_no_display
    jab.sys.exit 1

no_sound:
    jab.sys.uart.print msg_no_sound
    jab.sys.exit 2

no_piece:
    jab.sys.uart.print msg_no_piece
    jab.sys.exit 3

refused:
    jab.sys.uart.print msg_refused
    jab.sys.exit 4

# read_piece: the piece off the romfs into memory, its length kept; a
# missing file leaves the length 0.
read_piece:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, rec
    li t1, DISK
    li t2, JAB_ROMFS_ROOT
    jab.sys.romfs.find t0, t1, t2, piece_path
    bnez a0, 9f
    la t0, rec
    lwu s0, JAB_ROMFS_OFFSET(t0)
    li s1, 0                    # where in the file
    li s2, 0                    # how much is here
1:
    la t0, piece
    add t0, t0, s2
    li t1, DISK
    mv t2, s0
    mv t3, s1
    li t4, PIECE_BYTES
    sub t4, t4, s2
    jab.sys.romfs.read t0, t1, t2, t3, t4
    beqz a0, 2f
    add s2, s2, a0
    mv s1, a1
    bnez s1, 1b
2:
    la t0, piece_length
    sd s2, 0(t0)
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.section .bss
.balign 8
piece_length:
    .skip 8
rec:
    .skip JAB_ROMFS_ENTRY
piece:
    .skip PIECE_BYTES

.section .rodata
piece_path:
    .asciz "/technojab.mid"
title:
    .asciz "TECHNOJAB"
msg_no_display:
    .asciz "techno: no display\n"
msg_no_sound:
    .asciz "techno: no sound\n"
msg_no_piece:
    .asciz "techno: the piece is not on the disk\n"
msg_refused:
    .asciz "techno: the piece was refused\n"
