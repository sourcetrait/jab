.include "jab.inc"

.set RADIUS, 90
.set BACKGROUND, 0x00000000
.set BALL, 0x008f00ff
.set LEFT, RADIUS
.set RIGHT, (JAB_DISPLAY_WIDTH - 1 - RADIUS)
.set TOP, RADIUS
.set BOTTOM, (JAB_DISPLAY_HEIGHT - 1 - RADIUS)
.set FIX, 8
.set ONE, (1 << FIX)
.set SPEED_X, (210 * ONE)
.set SPEED_Y, (150 * ONE)
.set DT_MAX, (JAB_TIME_HZ / 10)

.section .text
.global _start
_start:
    jab.sys.display.open
    bnez a0, no_display
    li s0, 200 * ONE
    li s1, 200 * ONE
    li s2, SPEED_X
    li s3, SPEED_Y
    rdtime t0
    la t1, last_time
    sd t0, 0(t1)
frame:
    jab.sys.display.await
    call elapsed
    srai s4, s0, FIX
    srai s5, s1, FIX
    mv a0, s4
    mv a1, s5
    li a2, BACKGROUND
    call fill_square
    mv a0, s0
    mv a1, s2
    call advance
    mv s0, a0
    mv a0, s1
    mv a1, s3
    call advance
    mv s1, a0
    srai t1, s0, FIX
    li t0, LEFT
    bge t1, t0, 1f
    li s0, LEFT * ONE
    neg s2, s2
1:
    li t0, RIGHT
    ble t1, t0, 2f
    li s0, RIGHT * ONE
    neg s2, s2
2:
    srai t1, s1, FIX
    li t0, TOP
    bge t1, t0, 3f
    li s1, TOP * ONE
    neg s3, s3
3:
    li t0, BOTTOM
    ble t1, t0, 4f
    li s1, BOTTOM * ONE
    neg s3, s3
4:
    srai a0, s0, FIX
    srai a1, s1, FIX
    call draw_ball
    srai t4, s0, FIX
    srai t5, s1, FIX
    mv a0, t4
    bge s4, t4, 5f
    mv a0, s4
5:
    addi a0, a0, -RADIUS
    mv a2, t4
    ble s4, t4, 6f
    mv a2, s4
6:
    addi a2, a2, RADIUS + 1
    sub a2, a2, a0
    mv a1, t5
    bge s5, t5, 7f
    mv a1, s5
7:
    addi a1, a1, -RADIUS
    mv a3, t5
    ble s5, t5, 8f
    mv a3, s5
8:
    addi a3, a3, RADIUS + 1
    sub a3, a3, a1
    jab.sys.display.flip.rect
    j frame

no_display:
    jab.sys.uart.print msg_no_display
    jab.sys.exit 1

elapsed:
    rdtime t0
    la t1, last_time
    ld t2, 0(t1)
    sd t0, 0(t1)
    sub t0, t0, t2
    li t1, DT_MAX
    bleu t0, t1, 1f
    mv t0, t1
1:
    la t1, dt
    sd t0, 0(t1)
    ret

advance:
    la t0, dt
    ld t0, 0(t0)
    mul t1, a1, t0
    li t2, JAB_TIME_HZ
    div t1, t1, t2
    add a0, a0, t1
    ret

fill_square:
    li t0, -RADIUS
    li t6, RADIUS
1:
    add t1, a1, t0
    li t2, JAB_DISPLAY_PITCH
    mul t1, t1, t2
    addi t2, a0, -RADIUS
    slli t2, t2, 2
    add t1, t1, t2
    li t2, JAB_DISPLAY_BASE
    add t1, t1, t2
    li t3, 2 * RADIUS + 1
2:
    sw a2, 0(t1)
    addi t1, t1, 4
    addi t3, t3, -1
    bnez t3, 2b
    addi t0, t0, 1
    ble t0, t6, 1b
    ret

draw_ball:
    li t0, -RADIUS
    li t6, RADIUS
    li t5, BALL
    li a3, RADIUS * RADIUS
1:
    add t1, a1, t0
    li t2, JAB_DISPLAY_PITCH
    mul t1, t1, t2
    li t2, JAB_DISPLAY_BASE
    add t1, t1, t2
    slli t2, a0, 2
    add t1, t1, t2
    mul t4, t0, t0
    li t2, -RADIUS
2:
    mul t3, t2, t2
    add t3, t3, t4
    bgt t3, a3, 3f
    slli a4, t2, 2
    add a4, a4, t1
    sw t5, 0(a4)
3:
    addi t2, t2, 1
    ble t2, t6, 2b
    addi t0, t0, 1
    ble t0, t6, 1b
    ret

.section .bss
.balign 8
last_time:
    .skip 8
dt:
    .skip 8

.section .rodata
msg_no_display:
    .asciz "bounce: no display\n"
