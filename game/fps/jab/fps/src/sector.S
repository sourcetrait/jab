# sector.S: the world's geometry asked about a point. A sector's plane
# is z = a x + b y + c, so its height at a point is two multiplies and
# two adds. A sector holds a point in the plan by the even-odd rule over
# the walls of its loops, and holds it outright when the point's z lies
# between its floor and its ceiling there, with a thousandth's slack
# either way, the same rule the host's reader applies. The sector
# holding a point is found from the sector it was last in: itself, else
# a breadth-first walk through the portals of its walls, then every
# sector not reached, from the top.

.section .rodata
.balign 8
k_hold_slack_d:
    .double 0.001

.section .text

# plane_height: fa0 becomes the height of the sector a0's plane a1, 0
# the floor and 1 the ceiling, at the point fa0, fa1, doubles.
# Clobbers t0 to t2, ft0 to ft2.
plane_height:
    li t0, SECTOR_SIZE
    mul t0, a0, t0
    section_at KIND_SECTORS, t1
    add t0, t0, t1                  # the sector
    li t1, SECTOR_CEILING
    mul t1, a1, t1
    add t0, t0, t1                  # its plane
    flw ft0, PLANE_A(t0)
    fcvt.d.s ft0, ft0
    flw ft1, PLANE_B(t0)
    fcvt.d.s ft1, ft1
    flw ft2, PLANE_C(t0)
    fcvt.d.s ft2, ft2
    fmul.d fa0, fa0, ft0
    fmadd.d fa0, fa1, ft1, fa0
    fadd.d fa0, fa0, ft2
    ret

# sector_holds_plan: a0 becomes 1 when the sector a0 holds the point
# fa0, fa1 (doubles) in the plan by the even-odd rule over the walls of
# its loops, else 0: a wall whose ends straddle the point's y crosses
# when the wall's x at that y lies past the point's. Clobbers t0 to t6,
# a1 to a5, ft0 to ft7.
sector_holds_plan:
    li t0, SECTOR_SIZE
    mul t0, a0, t0
    section_at KIND_SECTORS, t1
    add t0, t0, t1                  # the sector
    lwu t1, SECTOR_FIRST_LOOP(t0)
    lwu t2, SECTOR_LOOP_COUNT(t0)
    li t3, LOOP_SIZE
    mul t1, t1, t3
    section_at KIND_LOOPS, t3
    add t1, t1, t3                  # the loop
    section_at KIND_WALLS, a3
    section_at KIND_VERTICES, a4
    li a0, 0                        # the crossings
1:
    beqz t2, 9f
    lwu t3, LOOP_FIRST_WALL(t1)
    lwu t4, LOOP_WALL_COUNT(t1)
    li t5, WALL_SIZE
    mul t3, t3, t5
    add t3, t3, a3                  # the wall
2:
    beqz t4, 8f
    lwu t5, WALL_A(t3)
    slli t5, t5, 3
    add t5, t5, a4
    flw ft0, VERTEX_X(t5)
    fcvt.d.s ft0, ft0               # ax
    flw ft1, VERTEX_Y(t5)
    fcvt.d.s ft1, ft1               # ay
    lwu t5, WALL_B(t3)
    slli t5, t5, 3
    add t5, t5, a4
    flw ft2, VERTEX_X(t5)
    fcvt.d.s ft2, ft2               # bx
    flw ft3, VERTEX_Y(t5)
    fcvt.d.s ft3, ft3               # by
    flt.d a1, fa1, ft1              # ay > y
    flt.d a2, fa1, ft3              # by > y
    beq a1, a2, 3f
    # the wall's x at y past the point's: (y - ay)(bx - ax) against
    # (x - ax)(by - ay), the sense by the sign of by - ay
    fsub.d ft4, fa1, ft1
    fsub.d ft5, ft2, ft0
    fmul.d ft4, ft4, ft5            # (y - ay)(bx - ax)
    fsub.d ft5, fa0, ft0
    fsub.d ft6, ft3, ft1
    fmul.d ft5, ft5, ft6            # (x - ax)(by - ay)
    flt.d a5, ft1, ft3              # by > ay
    beqz a5, 21f
    flt.d a5, ft5, ft4              # xi > x
    j 22f
21:
    flt.d a5, ft4, ft5
22:
    add a0, a0, a5
3:
    addi t3, t3, WALL_SIZE
    addi t4, t4, -1
    j 2b
8:
    addi t1, t1, LOOP_SIZE
    addi t2, t2, -1
    j 1b
9:
    andi a0, a0, 1
    ret

# sector_holds: a0 becomes 1 when the sector a0 holds the point fs0,
# fs1, fs2 (doubles): inside its loops in the plan and between its
# floor and its ceiling there, a thousandth's slack either way; else 0.
sector_holds:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call sector_holds_plan
    beqz a0, 8f
    mv a0, s2
    li a1, 0
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    la t0, k_hold_slack_d
    fld ft0, 0(t0)
    fsub.d fa0, fa0, ft0
    flt.d t0, fs2, fa0              # below the floor
    bnez t0, 8f
    mv a0, s2
    li a1, 1
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    la t0, k_hold_slack_d
    fld ft0, 0(t0)
    fadd.d fa0, fa0, ft0
    flt.d t0, fa0, fs2              # above the ceiling
    bnez t0, 8f
    li a0, 1
    j 9f
8:
    li a0, 0
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

# sector_find: a0 becomes the sector holding the point fa0, fa1, fa2
# (doubles), starting from the sector a0: the sector itself, else a
# breadth-first walk from it through the portals of its walls, the
# sectors left unreached taken from the top down; a start outside the
# map is a search from the top; -1 when no sector holds the point.
sector_find:
    addi sp, sp, -112
    sd ra, 104(sp)
    sd s2, 96(sp)
    sd s3, 88(sp)
    sd s4, 80(sp)
    sd s5, 72(sp)
    sd s6, 64(sp)
    sd s7, 56(sp)
    sd s8, 48(sp)
    fsd fs0, 40(sp)
    fsd fs1, 32(sp)
    fsd fs2, 24(sp)
    fmv.d fs0, fa0
    fmv.d fs1, fa1
    fmv.d fs2, fa2
    section_count KIND_SECTORS, s2
    mv s3, a0
    bltu s3, s2, 2f
    # from the top
    addi s4, s2, -1
1:
    bltz s4, 8f
    mv a0, s4
    call sector_holds
    bnez a0, 7f
    addi s4, s4, -1
    j 1b
2:
    mv a0, s3
    call sector_holds
    mv s4, s3
    bnez a0, 7f
    # the walk: nothing seen but the start, the fifo empty
    la t0, sector_seen
    add t1, t0, s2
3:
    beq t0, t1, 4f
    sb zero, 0(t0)
    addi t0, t0, 1
    j 3b
4:
    la t0, sector_seen
    add t0, t0, s3
    li t1, 1
    sb t1, 0(t0)
    li s5, 0                        # the fifo's read
    li s6, 0                        # and write
    addi s7, s2, -1                 # the unreached sector from the top
    addi s8, s2, -1                 # the sectors left to try
5:
    blez s8, 8f
    # every portal of every wall of the sector in hand, its sector
    # queued
    mv a0, s3
    call sector_at
    lwu t1, SECTOR_FIRST_LOOP(a0)
    lwu t2, SECTOR_LOOP_COUNT(a0)
    li t3, LOOP_SIZE
    mul t1, t1, t3
    section_at KIND_LOOPS, t3
    add t1, t1, t3                  # the loop
    section_at KIND_WALLS, a3
    section_at KIND_PORTALS, a4
51:
    beqz t2, 55f
    lwu t3, LOOP_FIRST_WALL(t1)
    lwu t4, LOOP_WALL_COUNT(t1)
    li t5, WALL_SIZE
    mul t3, t3, t5
    add t3, t3, a3                  # the wall
52:
    beqz t4, 54f
    lwu t5, WALL_FIRST_PORTAL(t3)
    lwu t6, WALL_PORTAL_COUNT(t3)
    slli t5, t5, 3
    add t5, t5, a4                  # the portal
53:
    beqz t6, 531f
    lwu a1, PORTAL_SECTOR(t5)
    la a2, sector_seen
    add a2, a2, a1
    lbu a5, 0(a2)
    bnez a5, 530f
    li a5, 1
    sb a5, 0(a2)
    la a2, sector_fifo
    slli a5, s6, 2
    add a2, a2, a5
    sw a1, 0(a2)
    addi s6, s6, 1
530:
    addi t5, t5, PORTAL_SIZE
    addi t6, t6, -1
    j 53b
531:
    addi t3, t3, WALL_SIZE
    addi t4, t4, -1
    j 52b
54:
    addi t1, t1, LOOP_SIZE
    addi t2, t2, -1
    j 51b
55:
    # the next sector: the fifo's, else one not yet reached
    bgeu s5, s6, 56f
    la t0, sector_fifo
    slli t1, s5, 2
    add t0, t0, t1
    lwu s3, 0(t0)
    addi s5, s5, 1
    j 58f
56:
    bltz s7, 8f
    la t0, sector_seen
    add t0, t0, s7
    lbu t1, 0(t0)
    beqz t1, 57f
    addi s7, s7, -1
    j 56b
57:
    li t1, 1
    sb t1, 0(t0)
    mv s3, s7
58:
    mv a0, s3
    call sector_holds
    mv s4, s3
    bnez a0, 7f
    addi s8, s8, -1
    j 5b
7:
    mv a0, s4
    j 9f
8:
    li a0, -1
9:
    ld ra, 104(sp)
    ld s2, 96(sp)
    ld s3, 88(sp)
    ld s4, 80(sp)
    ld s5, 72(sp)
    ld s6, 64(sp)
    ld s7, 56(sp)
    ld s8, 48(sp)
    fld fs0, 40(sp)
    fld fs1, 32(sp)
    fld fs2, 24(sp)
    addi sp, sp, 112
    ret

.section .bss
.balign 8
sector_fifo:
    .skip (MAX_SECTORS * 4)
sector_seen:
    .skip MAX_SECTORS
