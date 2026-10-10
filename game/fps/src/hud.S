.set CROSSHAIR_RADIUS, 5
.set CROSSHAIR_X, (SCREEN_W / 2)
.set CROSSHAIR_Y, (SCREEN_H / 2)
.set STAMP_BITS, 16
.set STAMP_CELL, 4
.set STAMP_WHITE, 0x00ffffff

.section .text

hud_draw:
.ifdef DEBUG
    la t0, hud_stamp
    lbu t0, 0(t0)
    beqz t0, 8f
    li t0, JAB_DISPLAY_BASE         # the cell's top-left pixel
    li t1, 0                        # the bit
5:
    srl t2, a0, t1
    andi t2, t2, 1
    neg t2, t2
    li t3, STAMP_WHITE
    and t2, t2, t3                  # white for a one, black for a zero
    mv t3, t0
    li t4, STAMP_CELL               # its rows
6:
    mv t5, t3
    li t6, STAMP_CELL               # the row's pixels
7:
    sw t2, 0(t5)
    addi t5, t5, 4
    addi t6, t6, -1
    bnez t6, 7b
    li t5, SCREEN_PITCH
    add t3, t3, t5
    addi t4, t4, -1
    bnez t4, 6b
    addi t0, t0, (STAMP_CELL * 4)   # the next cell, to the right
    addi t1, t1, 1
    li t2, STAMP_BITS
    bltu t1, t2, 5b
8:
.endif
    li t0, -CROSSHAIR_RADIUS        # the row, from the top
1:
    li t1, CROSSHAIR_RADIUS
    bgt t0, t1, 9f
    mul t2, t0, t0
    li t3, (CROSSHAIR_RADIUS * CROSSHAIR_RADIUS)
    sub t2, t3, t2
    li t4, 0
2:
    addi t5, t4, 1
    mul t6, t5, t5
    bgt t6, t2, 3f
    mv t4, t5
    j 2b
3:
    li t5, SCREEN_PITCH
    addi t6, t0, CROSSHAIR_Y
    mul t5, t5, t6
    li t6, JAB_DISPLAY_BASE
    add t5, t5, t6
    li t6, CROSSHAIR_X
    sub t6, t6, t4
    slli t6, t6, 2
    add t5, t5, t6                  # the row's first pixel
    slli t6, t4, 1
    addi t6, t6, 1                  # its pixels
.balign 64
4:
    lw a0, 0(t5)
    srli a0, a0, 1
    li a1, 0x7f7f7f
    and a0, a0, a1
    li a1, 0x808080
    add a0, a0, a1                  # half the pixel and half of white
    sw a0, 0(t5)
    addi t5, t5, 4
    addi t6, t6, -1
    bnez t6, 4b
    addi t0, t0, 1
    j 1b
9:
    ret

.ifdef DEBUG
.section .bss
hud_stamp:
    .skip 1
.endif
