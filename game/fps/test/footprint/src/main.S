.include "jab.inc"
.include "jab_jobs.inc"
.include "map.inc"
.include "render.inc"

.set CASES, 12
.set CASE_SIZE, 32
.set LINE_BYTES, 256

.section .text
.global _start
_start:
    call cases_run
    jab.sys.exit 0

cases_run:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    li s2, 0                        # the case
    la s3, cases
1:
    call line_reset
    la a0, word_derivative
    call line_str
    mv a0, s2
    call line_signed
    li a0, ' '
    call line_char
    ld a0, 0(s3)
    call line_signed
    li a0, ' '
    call line_char
    ld a0, 8(s3)
    call line_signed
    li a0, ' '
    call line_char
    ld a0, 16(s3)
    call line_signed
    li a0, ' '
    call line_char
    ld a0, 24(s3)
    call line_signed
    li a0, ' '
    call line_char
    ld a1, 0(s3)
    ld a2, 8(s3)
    ld a3, 16(s3)
    ld a4, 24(s3)
    row_derivative a0, a1, a2, a3, a4, a5, a6, 2f
    call line_signed
    j 3f
2:
    la a0, word_saturated
    call line_str
3:
    call line_nl
    jab.sys.uart.print line
    addi s2, s2, 1
    addi s3, s3, CASE_SIZE
    li t0, CASES
    bltu s2, t0, 1b
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

line_reset:
    la t0, line
    la t1, lineptr
    sd t0, 0(t1)
    ret

line_char:
    la t1, lineptr
    ld t0, 0(t1)
    sb a0, 0(t0)
    addi t0, t0, 1
    sd t0, 0(t1)
    ret

line_nl:
    la t1, lineptr
    ld t0, 0(t1)
    li t2, '\n'
    sb t2, 0(t0)
    addi t0, t0, 1
    sb zero, 0(t0)
    sd t0, 0(t1)
    ret

line_str:
    mv t2, a0
    la t1, lineptr
    ld t0, 0(t1)
1:
    lbu t3, 0(t2)
    beqz t3, 2f
    sb t3, 0(t0)
    addi t0, t0, 1
    addi t2, t2, 1
    j 1b
2:
    sd t0, 0(t1)
    ret

line_signed:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    mv s2, a0
    bgez s2, 1f
    li a0, '-'
    call line_char
    neg s2, s2                      # the most negative stays itself, read unsigned below
1:
    addi s3, sp, 24
    li t1, 10
2:
    remu t2, s2, t1
    addi t2, t2, '0'
    addi s3, s3, -1
    sb t2, 0(s3)
    divu s2, s2, t1
    bnez s2, 2b
3:
    lbu a0, 0(s3)
    call line_char
    addi s3, s3, 1
    addi t0, sp, 24
    bltu s3, t0, 3b
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    addi sp, sp, 48
    ret

.section .rodata
.balign 8
cases:
    .dword (10 << 16), (1 << 20), (1 << 16), (2 << 16)
    .dword (3 << 40), (5 << 30), (1 << 50), (1 << 20)
    .dword (1 << 60), (1 << 40), 0, (1 << 16)
    .dword 0, 0, (1 << 62), (1 << 20)
    .dword (1 << 26), (1 << 26), 0x8000000000000000, (1 << 16)
    .dword 0, 0, -(1 << 47), (1 << 32)
    .dword (1 << 20), (1 << 26), 0, (1 << 16)
    .dword (1 << 40), 0, (5 << 16), (1 << 30)
    .dword -3, (1 << 25), 0, (1 << 16)
    .dword 1234567, 98765, 4567890, 345678
    .dword 0, 0, ((1 << 47) - 1), (1 << 32)
    .dword 0, 0, (1 << 47), (1 << 32)
word_derivative:
    .asciz "footprint: derivative "
word_saturated:
    .asciz "saturated"

.section .bss
.balign 8
line:
    .skip LINE_BYTES
lineptr:
    .skip 8
