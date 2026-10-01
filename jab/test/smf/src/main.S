# smf: the Standard MIDI File player under test. Reads /piece.mid off
# the first disk, a file the test wrote, plays it, spins on the clock
# until the piece has ended so the stream's refills come through the
# trap vector, lingers a moment for the last release, and exits, which
# plays the stream out; the host records what played and the test
# holds it against the file. With no sound device it says so and exits
# 2; with no file, 1; with a file the player refuses, 3.
.include "jab.inc"

.set DISK, 1
.set PIECE_BYTES, 4096
.set LINGER, (JAB_TIME_HZ / 5)

.section .text
.global _start
_start:
    jab.sys.sound.open
    bnez a0, no_sound
    # the file, out of the romfs and into memory
    la t0, rec
    li t1, DISK
    li t2, JAB_ROMFS_ROOT
    jab.sys.romfs.find t0, t1, t2, path
    bnez a0, no_file
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
    la t0, piece
    jab.sys.midi.play t0, s2
    bnez a0, refused
3:
    jab.sys.midi.playing
    bnez a0, 3b
    rdtime t0
    li t1, LINGER
    add t1, t0, t1
4:
    rdtime t0
    bltu t0, t1, 4b
    jab.sys.exit 0

no_sound:
    jab.sys.uart.print msg_no_sound
    jab.sys.exit 2
no_file:
    jab.sys.uart.print msg_no_file
    jab.sys.exit 1
refused:
    jab.sys.uart.print msg_refused
    jab.sys.exit 3

.section .rodata
path:
    .asciz "/piece.mid"
msg_no_sound:
    .asciz "smf: no sound\n"
msg_no_file:
    .asciz "smf: the piece is not on the disk\n"
msg_refused:
    .asciz "smf: the player refused the piece\n"

.section .bss
.balign 8
rec:
    .skip JAB_ROMFS_ENTRY
piece:
    .skip PIECE_BYTES
