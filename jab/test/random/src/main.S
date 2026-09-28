# random: the kernel's entropy call under test. Asks jab.random for 64
# bytes twice, into two buffers, and prints each answer as `bytes
# <given>` and then the bytes in decimal on one line, so the test can
# see that they came, that the two draws differ, and that they look
# like entropy. A machine with no rng device says so and exits 2.
.include "jab.inc"

.set BYTES, 64
.set LINE_BYTES, 320
.set DIGITS_BYTES, 24

.section .text
.global _start
_start:
    la s0, first
    call draw
    la s0, second
    call draw
    jab.exit 0

no_rng:
    jab.uart.print msg_no_rng
    jab.exit 2

# draw: fill the buffer at s0 from the device and print it.
draw:
    addi sp, sp, -16
    sd ra, 8(sp)
    li t1, BYTES
    jab.random s0, t1
    bnez a0, no_rng
    mv s1, a1
    call line_begin
    la a0, msg_bytes
    call line_str
    mv a0, s1
    call line_int
    call line_end
    call line_begin
    li s2, 0
1:
    bgeu s2, s1, 2f
    add t0, s0, s2
    lbu a0, 0(t0)
    call line_int
    la a0, msg_space
    call line_str
    addi s2, s2, 1
    j 1b
2:
    call line_end
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# The line: begun empty, strings and signed decimals appended, ended
# with a newline and sent to the UART.
line_begin:
    la t0, line_len
    sd zero, 0(t0)
    ret

# line_str: a0 is a NUL-terminated string.
line_str:
    la t0, line_len
    ld t1, 0(t0)
    la t2, line
1:
    lbu t3, 0(a0)
    beqz t3, 2f
    add t4, t2, t1
    sb t3, 0(t4)
    addi t1, t1, 1
    addi a0, a0, 1
    j 1b
2:
    sd t1, 0(t0)
    ret

# line_int: a0 is a signed value, appended in decimal.
line_int:
    la t0, line_len
    ld t1, 0(t0)
    la t2, line
    bgez a0, 1f
    add t4, t2, t1
    li t3, '-'
    sb t3, 0(t4)
    addi t1, t1, 1
    neg a0, a0
1:
    la t3, digits
    addi t3, t3, DIGITS_BYTES
    li t4, 10
2:
    remu t5, a0, t4
    divu a0, a0, t4
    addi t5, t5, '0'
    addi t3, t3, -1
    sb t5, 0(t3)
    bnez a0, 2b
    la t5, digits
    addi t5, t5, DIGITS_BYTES
3:
    bgeu t3, t5, 4f
    lbu t6, 0(t3)
    add t4, t2, t1
    sb t6, 0(t4)
    addi t1, t1, 1
    addi t3, t3, 1
    j 3b
4:
    sd t1, 0(t0)
    ret

# line_end: the newline and the terminator, then the line to the UART.
line_end:
    la t0, line_len
    ld t1, 0(t0)
    la t2, line
    add t2, t2, t1
    li t3, '\n'
    sb t3, 0(t2)
    sb zero, 1(t2)
    sd zero, 0(t0)
    jab.uart.print line
    ret

.section .bss
.balign 8
line_len:
    .skip 8
line:
    .skip LINE_BYTES
digits:
    .skip DIGITS_BYTES
first:
    .skip BYTES
second:
    .skip BYTES

.section .rodata
msg_no_rng:
    .asciz "random: no rng\n"
msg_bytes:
    .asciz "bytes "
msg_space:
    .asciz " "
