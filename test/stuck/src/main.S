.include "jab.inc"

.set WAIT_TICKS, 270
.set DRAW_BYTES, 8

.section .text
.global _start
_start:
    la s4, buffer
    li s5, DRAW_BYTES
    jab.sys.random s4, s5
    mv s0, a0                               # the first draw's status
    jab.sys.display.open
    li s6, WAIT_TICKS
1:
    jab.sys.await JAB_AWAIT_DISPLAY
    jab.sys.display.flip
    addi s6, s6, -1
    bnez s6, 1b
    jab.sys.random s4, s5
    mv s1, a0                               # the second draw's status
    jab.sys.await JAB_AWAIT_DISPLAY
    jab.sys.display.flip
    mv s2, a0                               # a flip's status after it
    la s3, line
    la a1, word_stuck
    call put_str
    mv a0, s0
    call put_dec
    la a1, word_then
    call put_str
    mv a0, s1
    call put_dec
    la a1, word_flip
    call put_str
    mv a0, s2
    call put_dec
    li a0, '\n'
    call put_char
    sb zero, 0(s3)
    jab.sys.uart.print line
    jab.sys.exit 0

put_char:
    sb a0, 0(s3)
    addi s3, s3, 1
    ret

put_str:
    lbu t0, 0(a1)
    beqz t0, 1f
    sb t0, 0(s3)
    addi s3, s3, 1
    addi a1, a1, 1
    j put_str
1:
    ret

put_dec:
    la t1, digits
    addi t1, t1, 31
    sb zero, 0(t1)
    li t2, 10
1:
    remu t3, a0, t2
    divu a0, a0, t2
    addi t3, t3, '0'
    addi t1, t1, -1
    sb t3, 0(t1)
    bnez a0, 1b
2:
    lbu t3, 0(t1)
    beqz t3, 3f
    sb t3, 0(s3)
    addi s3, s3, 1
    addi t1, t1, 1
    j 2b
3:
    ret

.section .rodata
word_stuck:
    .asciz "stuck random "
word_then:
    .asciz " then "
word_flip:
    .asciz ", flip "

.section .bss
buffer:
    .skip DRAW_BYTES
line:
    .skip 128
digits:
    .skip 32
