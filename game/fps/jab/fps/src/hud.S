# hud.S: what the player sees over the world. The crosshair: a
# semi-translucent white dot at the screen's centre, CROSSHAIR_RADIUS
# pixels in radius, each pixel of the frame under it blended half with
# white after the world is drawn, so the aim's mark is read against
# anything. The rounds and the magazines to come.

.set CROSSHAIR_RADIUS, 5
.set CROSSHAIR_X, (SCREEN_W / 2)
.set CROSSHAIR_Y, (SCREEN_H / 2)

.section .text

# hud_draw: the crosshair over the frame. Clobbers t0 to t6, a0, a1.
hud_draw:
    li t0, -CROSSHAIR_RADIUS        # the row, from the top
1:
    li t1, CROSSHAIR_RADIUS
    bgt t0, t1, 9f
    # the row's half width: the greatest w with w * w within the
    # radius's square less the row's
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
