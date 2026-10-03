.include "jab.inc"

.set BLOCK_BYTES, 64
.set FILL, 0xa5
.set SPIN, 100000
.set LINE_BYTES, 160
.set DIGITS_BYTES, 24

.section .text
.global _start
_start:
    call fill
    la a0, blocks
    addi a0, a0, 8
    cbo.zero (a0)                   # the whole block a0 falls in
    la a0, blocks
    li a1, 0
    call count
    mv s0, a0
    la a0, blocks
    addi a0, a0, BLOCK_BYTES
    li a1, FILL
    call count
    mv s1, a0
    call line_begin
    la a0, msg_zero
    call line_str
    mv a0, s0
    call line_int
    la a0, msg_untouched
    call line_str
    mv a0, s1
    call line_int
    call line_end
    la a0, blocks
    addi a0, a0, BLOCK_BYTES
    cbo.clean (a0)
    cbo.flush (a0)
    cbo.inval (a0)
    li a1, FILL
    call count
    mv s0, a0
    call line_begin
    la a0, msg_kept
    call line_str
    mv a0, s0
    call line_int
    call line_end
    rdtime s2
    rdcycle s3
    rdinstret s4
    li t0, SPIN
1:
    addi t0, t0, -1
    bnez t0, 1b
    rdtime s5
    rdcycle s6
    rdinstret s7
    call line_begin
    la a0, msg_rising
    call line_str
    sltu a0, s2, s5
    call line_int
    la a0, msg_space
    call line_str
    sltu a0, s3, s6
    call line_int
    la a0, msg_space
    call line_str
    sltu a0, s4, s7
    call line_int
    call line_end
    csrr s0, hpmcounter3
    csrr s1, hpmcounter18
    call line_begin
    la a0, msg_hpm3
    call line_str
    mv a0, s0
    call line_int
    la a0, msg_hpm18
    call line_str
    mv a0, s1
    call line_int
    call line_end
    jab.sys.exit 0

fill:
    la t0, blocks
    li t1, (BLOCK_BYTES * 2)
    li t2, FILL
1:
    sb t2, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, 1b
    ret

count:
    li t0, BLOCK_BYTES
    li t1, 0
1:
    lbu t2, 0(a0)
    bne t2, a1, 2f
    addi t1, t1, 1
2:
    addi a0, a0, 1
    addi t0, t0, -1
    bnez t0, 1b
    mv a0, t1
    ret

line_begin:
    la t0, line_len
    sd zero, 0(t0)
    ret

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

line_end:
    la t0, line_len
    ld t1, 0(t0)
    la t2, line
    add t2, t2, t1
    li t3, '\n'
    sb t3, 0(t2)
    sb zero, 1(t2)
    sd zero, 0(t0)
    jab.sys.uart.print line
    ret

.section .bss
.balign 64
blocks:
    .skip (BLOCK_BYTES * 2)
.balign 8
line_len:
    .skip 8
line:
    .skip LINE_BYTES
digits:
    .skip DIGITS_BYTES

.section .rodata
msg_zero:
    .asciz "zero "
msg_untouched:
    .asciz " untouched "
msg_kept:
    .asciz "kept "
msg_rising:
    .asciz "rising "
msg_space:
    .asciz " "
msg_hpm3:
    .asciz "hpm3 "
msg_hpm18:
    .asciz " hpm18 "
