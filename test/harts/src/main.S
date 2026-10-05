.include "jab.inc"

.set HOLD_TICKS, 120

.section .text
.global _start
_start:
    li s4, HOLD_TICKS
1:
    jab.sys.display.await
    addi s4, s4, -1
    bnez s4, 1b
    jab.sys.harts
    mv s0, a0                               # discovered
    mv s1, a1                               # online
    mv s2, a2                               # failed
    la s3, line
    la a1, word_harts
    call put_str
    mv a0, s0
    call put_dec
    li a0, ' '
    call put_char
    mv a0, s1
    call put_dec
    li a0, ' '
    call put_char
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
word_harts:
    .asciz "harts "

.section .bss
line:
    .skip 128
digits:
    .skip 32
