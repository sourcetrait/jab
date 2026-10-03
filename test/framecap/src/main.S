.include "jab.inc"

.set FLIPS, 64

.section .text
.global _start
_start:
    jab.sys.display.open
    bnez a0, no_display
    li s0, 0
    li s1, FLIPS
1:
    jab.sys.display.flip
    li t0, 1
    bne a0, t0, 2f
    addi s0, s0, 1
2:
    addi s1, s1, -1
    bnez s1, 1b
    mv a0, s0
    la a1, refused_digits
    call two_digits
    jab.sys.uart.print refused
    li s1, FLIPS / 2
3:
    jab.sys.display.await
    jab.sys.display.flip
    bnez a0, flip_failed
    addi s1, s1, -1
    bnez s1, 3b
    li s1, FLIPS / 2
4:
    jab.sys.display.await
    li a0, 100
    li a1, 100
    li a2, 50
    li a3, 50
    jab.sys.display.flip.rect
    bnez a0, flip_failed
    addi s1, s1, -1
    bnez s1, 4b
    jab.sys.display.await
    li a0, 1900
    li a1, 0
    li a2, 100
    li a3, 10
    jab.sys.display.flip.rect
    la a1, badrect_digits
    call two_digits
    jab.sys.uart.print badrect
    jab.sys.display.await
    la t0, two_rects
    li t1, 2
    jab.sys.display.flip.rects t0, t1
    la a1, rects_digits
    call two_digits
    jab.sys.uart.print rects
    jab.sys.display.await
    la t0, bad_rects
    li t1, 2
    jab.sys.display.flip.rects t0, t1
    la a1, badrects_digits
    call two_digits
    jab.sys.uart.print badrects
    la t0, two_rects
    li t1, 0
    jab.sys.display.flip.rects t0, t1
    la a1, norects_digits
    call two_digits
    jab.sys.uart.print norects
    jab.sys.kernel.flags
    la a1, flags_digits
    call two_digits
    jab.sys.uart.print flags
    jab.sys.uart.print paced
    jab.sys.exit 0

no_display:
    jab.sys.uart.print msg_no_display
    jab.sys.exit 1

flip_failed:
    jab.sys.uart.print msg_flip_failed
    jab.sys.exit 2

two_digits:
    li t1, 10
    divu t2, a0, t1
    remu t3, a0, t1
    addi t2, t2, '0'
    addi t3, t3, '0'
    sb t2, 0(a1)
    sb t3, 1(a1)
    ret

.section .data
refused:
    .ascii "refused="
refused_digits:
    .asciz "00\n"
badrect:
    .ascii "badrect="
badrect_digits:
    .asciz "00\n"
rects:
    .ascii "rects="
rects_digits:
    .asciz "00\n"
badrects:
    .ascii "badrects="
badrects_digits:
    .asciz "00\n"
norects:
    .ascii "norects="
norects_digits:
    .asciz "00\n"
flags:
    .ascii "flags="
flags_digits:
    .asciz "00\n"

.section .rodata
.balign 4
two_rects:
    .word 100, 100, 50, 50
    .word 1000, 800, 200, 100
bad_rects:
    .word 100, 100, 50, 50
    .word 1000, 1070, 200, 100
paced:
    .asciz "paced\n"
msg_no_display:
    .asciz "framecap: no display\n"
msg_flip_failed:
    .asciz "framecap: a flip after await failed\n"
