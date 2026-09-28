# sound: the kernel's sound device under test. Opens the stream and
# plays a second of a 440 Hz square wave at AMPLITUDE either side of
# silence, one period at a time, waiting whenever the ring is full,
# then exits, which plays the ring out; the host records what played
# and the test measures it. With no sound device it says so and
# exits 2.
.include "jab.inc"

.set PERIODS_TO_PLAY, 50
.set AMPLITUDE, 16000
# 440 Hz as a phase step in 1/2^32 cycles a frame at 48 kHz
.set STEP, 39370534

.section .text
.global _start
_start:
    jab.sound.open
    bnez a0, no_sound
    li s0, PERIODS_TO_PLAY
    li s1, 0                    # the phase, 32 bits
next:
    beqz s0, done
    # one period of the wave
    la t0, period
    li t1, JAB_SOUND_PERIOD
1:
    li t2, AMPLITUDE
    srli t3, s1, 31
    andi t3, t3, 1
    beqz t3, 2f
    neg t2, t2
2:
    sh t2, 0(t0)
    sh t2, 2(t0)
    addi t0, t0, 4
    li t3, STEP
    add s1, s1, t3
    slli s1, s1, 32
    srli s1, s1, 32
    addi t1, t1, -1
    bnez t1, 1b
    # into the stream, whole, waiting for room as needed
    la s2, period
    li s3, JAB_SOUND_PERIOD
3:
    jab.sound.write s2, s3
    bnez a0, no_sound
    sub s3, s3, a1
    slli t0, a1, 2
    add s2, s2, t0
    beqz s3, 4f
    jab.sound.await
    j 3b
4:
    addi s0, s0, -1
    j next
done:
    jab.exit 0

no_sound:
    jab.uart.print msg_no_sound
    jab.exit 2

.section .bss
.balign 4
period:
    .skip JAB_SOUND_PERIOD * JAB_SOUND_FRAME_BYTES

.section .rodata
msg_no_sound:
    .asciz "sound: no sound\n"
