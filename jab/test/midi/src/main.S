# midi: the kernel's synthesizer under test. Sets channel 0 to the
# square lead, plays the A at 440 Hz for a second at full velocity,
# releases it, and spins on the clock for half a second more, never
# waiting in the kernel, so every refill of the stream comes through
# the trap vector while the program runs; then exits. The host
# records what played and the test measures it. With no sound device
# it says so and exits 2.
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

# spin: a0 ticks of the clock go by with the hart busy the whole time.
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
