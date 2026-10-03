.include "jab.inc"

.set CHANNEL, 0
.set PROGRAM, 80
.set NOTE, 69
.set VELOCITY, 127
.set HOLD, JAB_TIME_HZ
.set TAIL, (JAB_TIME_HZ / 2)

.section .text
.global _start
_start:
    jab.sys.sound.open
    bnez a0, no_sound
    li t0, CHANNEL
    li t1, PROGRAM
    jab.sys.midi.program t0, t1
    li t0, CHANNEL
    li t1, NOTE
    li t2, VELOCITY
    jab.sys.midi.note.on t0, t1, t2
    li a0, HOLD
    call spin
    li t0, CHANNEL
    li t1, NOTE
    jab.sys.midi.note.off t0, t1
    li a0, TAIL
    call spin
    jab.sys.exit 0

spin:
    rdtime t0
    add t1, t0, a0
1:
    rdtime t0
    bltu t0, t1, 1b
    ret

no_sound:
    jab.sys.uart.print msg_no_sound
    jab.sys.exit 2

.section .rodata
msg_no_sound:
    .asciz "midi: no sound\n"
