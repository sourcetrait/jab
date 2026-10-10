.section .rodata
.balign 8
k_near_sq_d:
    .double 0.003906640625
k_zero_d:
    .double 0.0
k_flow_near_sq_d:
    .double 0.00905
.balign 4
k_facing_slack_sq:
    .float 0.000001

.section .text

world_draw:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    la t0, workers_active
    lwu t2, 0(t0)
    la t0, round_workers
    sw t2, 0(t0)                    # the frame's workers, every render's
    la t0, band_grain
    lwu t1, 0(t0)
    la t0, round_grain
    sw t1, 0(t0)                    # and its grain
    beqz t2, 10f
    li t1, 1
    la t0, round_first
    sb t1, 0(t0)                    # the first round clears each band before its spans
    la t1, stats
    sd zero, STAT_CLEAR_TICKS(t1)
    j 12f
10:
    rdtime s2
    la t0, zbuf
    li t1, ZBUF_BYTES
    add t1, t1, t0
.balign 32
1:
    sd zero, 0(t0)
    sd zero, 8(t0)
    sd zero, 16(t0)
    sd zero, 24(t0)
    addi t0, t0, 32
    bltu t0, t1, 1b
.ifdef DEBUG
    li t0, JAB_DISPLAY_BASE
    li t1, SCREEN_PITCH
    li t2, SCREEN_H
    mul t1, t1, t2
    add t1, t1, t0
    li t2, 0xff00ff
    slli t3, t2, 32
    or t2, t2, t3
11:
    sd t2, 0(t0)
    sd t2, 8(t0)
    sd t2, 16(t0)
    sd t2, 24(t0)
    addi t0, t0, 32
    bltu t0, t1, 11b
.endif
    rdtime t0
    sub t0, t0, s2
    la t1, stats
    sd t0, STAT_CLEAR_TICKS(t1)
12:
    sd zero, STAT_SECTORS(t1)
    sd zero, STAT_WALLS(t1)
    sd zero, STAT_PIECES(t1)
    sd zero, STAT_PLANES(t1)
    sd zero, STAT_OPENINGS(t1)
    sd zero, STAT_PLANE_TICKS(t1)
    sd zero, STAT_WALL_TICKS(t1)
    sd zero, STAT_PORTAL_TICKS(t1)
    sd zero, STAT_SPRITES(t1)
    sd zero, STAT_SPRITE_TICKS(t1)
    sd zero, STAT_SPANS(t1)
    sd zero, STAT_PIXELS(t1)
    sd zero, STAT_LIT_SPANS(t1)
    sd zero, STAT_LIT_PIXELS(t1)
    sd zero, STAT_LIGHT_TICKS(t1)
    sd zero, STAT_REJECTED(t1)
    sd zero, STAT_SAMPLES(t1)
    sd zero, STAT_TILES_BUILT(t1)
    sd zero, STAT_TILED_PIXELS(t1)
    sd zero, STAT_TILE_TICKS(t1)
    sd zero, STAT_RASTER_TICKS(t1)
    sd zero, STAT_COMMANDS(t1)
    sd zero, STAT_FLUSHES(t1)
    sd zero, STAT_DISPATCH(t1)
    sd zero, STAT_BARRIER(t1)
    sd zero, STAT_SLOWEST(t1)
    sd zero, STAT_BUSY(t1)
    sd zero, STAT_ROUNDS(t1)
    sd zero, STAT_CANCELLED(t1)
    sd zero, STAT_TILE_ADMITTED(t1)
    sd zero, STAT_TILE_DROPPED(t1)
    sd zero, STAT_TILE_FILTERED(t1)
    sd zero, STAT_TILE_HITS(t1)
    sd zero, STAT_TILE_STRADDLING(t1)
    sd zero, STAT_TILE_MISSES(t1)
    sd zero, STAT_TILE_BUILD_TICKS(t1)
    sd zero, STAT_TILE_OVERRUN(t1)
    sd zero, STAT_TILE_EVICTED(t1)
    sd zero, STAT_TILE_MERGED(t1)
    sd zero, STAT_TILE_UNPROCESSED(t1)
    sd zero, STAT_BANDS(t1)
    sd zero, (STAT_BANDS + 8)(t1)
.ifdef COUNT
    la t1, count_stats
    sd zero, COUNT_DIVIDES(t1)
    sd zero, COUNT_AVOIDED(t1)
    sd zero, COUNT_SHIFTED(t1)
    sd zero, COUNT_SHORT(t1)
    sd zero, COUNT_NEGATIVE_U(t1)
    sd zero, COUNT_NEGATIVE_V(t1)
    sd zero, COUNT_FLAT(t1)
    sd zero, COUNT_MISMATCHES(t1)
    sd zero, COUNT_REENTRY_TWO(t1)
    sd zero, COUNT_REENTRY_FOUR(t1)
    sd zero, COUNT_REENTRY_CUT(t1)
.endif
    call tile_boundary              # the pool's one change a frame, before any bind
.ifdef DEBUG
    la t0, tile_writes
    ld t1, 0(t0)
    la t0, tile_writes_frozen
    sd t1, 0(t0)                    # the pool frozen from here to the last join
.endif
    call sky_setup
    la t0, span_count
    sd zero, 0(t0)
    la t0, command_count
    sd zero, 0(t0)                  # the frame's first packet empty
    rdtime s2
    call world_flow
    rdtime t0
    sub t0, t0, s2
    la t1, stats
    sd t0, STAT_PORTAL_TICKS(t1)
    la s3, walk_fifo
    li s4, 0                        # the fifo's read
8:
    la t0, walk_tail
    ld t1, 0(t0)
    bgeu s4, t1, 9f
    slli t2, s4, 2
    add t2, t2, s3
    lwu a0, 0(t2)
    addi s4, s4, 1
    call sector_draw
    j 8b
9:
    call phase_mark
    mv s2, a0
    call sprites_draw
    call actors_draw
    call phase_mark
    sub t0, a0, s2
    la t1, stats
    sd t0, STAT_SPRITE_TICKS(t1)
.ifdef DEBUG
    call scratch_poison             # nothing reads the producer's scratch once the packet is published
.endif
    call packet_render              # the frame's last packet, every polygon prepared
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 48
    ret

world_flow:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    section_count KIND_SECTORS, s2
    la t0, sector_rect
    li t1, SCREEN_W
    li t2, SCREEN_H
    mv t3, s2
1:
    beqz t3, 2f
    sw t1, RECT_X0(t0)
    sw zero, RECT_X1(t0)
    sw t2, RECT_Y0(t0)
    sw zero, RECT_Y1(t0)
    addi t0, t0, RECT_SIZE
    addi t3, t3, -1
    j 1b
2:
    la t0, walk_seen
    la t1, flow_pending
    mv t3, s2
3:
    beqz t3, 4f
    sb zero, 0(t0)
    sb zero, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    addi t3, t3, -1
    j 3b
4:
    la t0, walk_tail
    sd zero, 0(t0)
    la t0, flow_head
    sd zero, 0(t0)
    la t0, flow_tail
    sd zero, 0(t0)
    la t0, cam_sector
    lw a0, 0(t0)
    bgeu a0, s2, 6f
    call flow_screen
    j 8f
6:
    li s3, 0
7:
    bgeu s3, s2, 8f
    mv a0, s3
    call flow_screen
    addi s3, s3, 1
    j 7b
8:
    la t0, flow_head
    ld t1, 0(t0)
    la t2, flow_tail
    ld t2, 0(t2)
    beq t1, t2, 9f
    andi t3, t1, FLOW_RING_MASK
    la t4, flow_ring
    slli t3, t3, 2
    add t4, t4, t3
    lwu s3, 0(t4)
    addi t1, t1, 1
    sd t1, 0(t0)
    la t0, flow_pending
    add t0, t0, s3
    sb zero, 0(t0)
    la t0, walk_seen
    add t0, t0, s3
    lbu t1, 0(t0)
    bnez t1, 81f
    li t1, 1
    sb t1, 0(t0)
    la t0, walk_tail
    ld t1, 0(t0)
    la t2, walk_fifo
    slli t3, t1, 2
    add t2, t2, t3
    sw s3, 0(t2)
    addi t1, t1, 1
    sd t1, 0(t0)
81:
    mv a0, s3
    call sector_flow
    j 8b
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

flow_screen:
    la t0, sector_rect
    slli t1, a0, 4
    add t0, t0, t1
    sw zero, RECT_X0(t0)
    li t1, SCREEN_W
    sw t1, RECT_X1(t0)
    sw zero, RECT_Y0(t0)
    li t1, SCREEN_H
    sw t1, RECT_Y1(t0)

flow_queue:
    la t0, flow_pending
    add t0, t0, a0
    lbu t1, 0(t0)
    bnez t1, 9f
    li t1, 1
    sb t1, 0(t0)
    la t0, flow_tail
    ld t1, 0(t0)
    andi t2, t1, FLOW_RING_MASK
    la t3, flow_ring
    slli t2, t2, 2
    add t3, t3, t2
    sw a0, 0(t3)
    addi t1, t1, 1
    sd t1, 0(t0)
9:
    ret

rect_grow:
    la t0, sector_rect
    slli t1, a4, 4
    add t0, t0, t1
    lw t2, RECT_X0(t0)
    lw t3, RECT_X1(t0)
    lw t4, RECT_Y0(t0)
    lw t5, RECT_Y1(t0)
    blt a0, t2, 1f
    bgt a1, t3, 1f
    blt a2, t4, 1f
    bgt a3, t5, 1f
    ret
1:
    bge a0, t2, 2f
    mv t2, a0
2:
    ble a1, t3, 3f
    mv t3, a1
3:
    bge a2, t4, 4f
    mv t4, a2
4:
    ble a3, t5, 5f
    mv t5, a3
5:
    sw t2, RECT_X0(t0)
    sw t3, RECT_X1(t0)
    sw t4, RECT_Y0(t0)
    sw t5, RECT_Y1(t0)
    mv a0, a4
    j flow_queue

sector_flow:
    addi sp, sp, -208
    sd ra, 184(sp)
    sd s2, 176(sp)
    sd s3, 168(sp)
    sd s4, 160(sp)
    sd s5, 152(sp)
    sd s6, 144(sp)
    sd s7, 136(sp)
    sd s8, 128(sp)
    sd s9, 120(sp)
    sd s10, 112(sp)
    sd s11, 104(sp)
    fsd fs0, 96(sp)
    fsd fs1, 88(sp)
    fsd fs2, 80(sp)
    fsd fs3, 72(sp)
    fsd fs4, 64(sp)
    fsd fs5, 56(sp)
    fsd fs6, 48(sp)
    fsd fs7, 40(sp)
    mv s2, a0
    la t0, sector_rect
    slli t1, s2, 4
    add t0, t0, t1
    lw s8, RECT_X0(t0)
    lw s9, RECT_X1(t0)
    lw s10, RECT_Y0(t0)
    lw s11, RECT_Y1(t0)
    mv a0, s2
    call sector_at
    lwu s4, SECTOR_FIRST_LOOP(a0)
    lwu s5, SECTOR_LOOP_COUNT(a0)
    add s5, s5, s4                  # past the last loop
1:
    bgeu s4, s5, 90f
    mv a0, s4
    call loop_at
    lwu s6, LOOP_FIRST_WALL(a0)
    lwu s7, LOOP_WALL_COUNT(a0)
    add s7, s7, s6                  # past the last wall
2:
    bgeu s6, s7, 8f
    mv a0, s6
    call wall_at
    sd a0, 0(sp)                    # the wall
    lwu t0, WALL_PORTAL_COUNT(a0)
    beqz t0, 7f                     # solid
    lwu a0, WALL_A(a0)
    call vertex_at
    flw ft2, VERTEX_X(a0)
    flw ft3, VERTEX_Y(a0)
    fcvt.d.s fs0, ft2
    fcvt.d.s fs1, ft3
    ld t0, 0(sp)
    lwu a0, WALL_B(t0)
    call vertex_at
    flw ft4, VERTEX_X(a0)
    flw ft5, VERTEX_Y(a0)
    fcvt.d.s fs2, ft4
    fcvt.d.s fs3, ft5
    la t0, camera
    flw ft0, CAM_X(t0)
    flw ft1, CAM_Y(t0)
    fsub.s ft0, ft0, ft2            # px - ax
    fsub.s ft1, ft1, ft3            # py - ay
    fsub.s ft4, ft4, ft2            # bx - ax
    fsub.s ft5, ft5, ft3            # by - ay
    fmul.s ft6, ft4, ft1
    fmul.s ft7, ft5, ft0
    fsub.s ft6, ft6, ft7            # (bx - ax)(py - ay) - (by - ay)(px - ax): the run times the eye's distance from the line, signed
    la t0, k_zero
    flw ft7, 0(t0)
    flt.s t1, ft7, ft6
    bnez t1, 25f                    # ahead of the line
    fmul.s ft6, ft6, ft6
    fmul.s ft7, ft4, ft4
    fmadd.s ft7, ft5, ft5, ft7      # the run squared
    la t0, k_facing_slack_sq
    flw ft0, 0(t0)
    fmul.s ft7, ft7, ft0
    flt.s t1, ft7, ft6
    bnez t1, 7f                     # behind
25:
    mv a0, s2
    li a1, 1
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs4, fa0                  # the ceiling at the start
    mv a0, s2
    li a1, 1
    fmv.d fa0, fs2
    fmv.d fa1, fs3
    call plane_height
    fmv.d fs5, fa0                  # and at the end
    mv a0, s2
    li a1, 0
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs6, fa0                  # the floor at the start
    mv a0, s2
    li a1, 0
    fmv.d fa0, fs2
    fmv.d fa1, fs3
    call plane_height
    fmv.d fs7, fa0                  # and at the end
    la t0, k_flow_near_sq_d
    fld fa0, 0(t0)
    call wall_within
    sd a0, 8(sp)
    ld t0, 0(sp)
    lwu t1, WALL_FIRST_PORTAL(t0)
    lwu t2, WALL_PORTAL_COUNT(t0)
    add t2, t2, t1
    sd t1, 16(sp)                   # the portal
    sd t2, 24(sp)                   # past the last
3:
    ld t1, 16(sp)
    ld t2, 24(sp)
    bgeu t1, t2, 7f
    mv a0, t1
    call portal_at
    lwu a0, PORTAL_SECTOR(a0)
    sd a0, 32(sp)                   # the neighbour
    ld t0, 8(sp)
    beqz t0, 4f
    mv a0, s8
    mv a1, s9
    mv a2, s10
    mv a3, s11
    j 5f
4:
    ld a0, 32(sp)
    call opening_cut
    li t0, 3
    bltu a0, t0, 6f
    call poly_rect
    bge a0, s8, 41f
    mv a0, s8
41:
    ble a1, s9, 42f
    mv a1, s9
42:
    bge a2, s10, 43f
    mv a2, s10
43:
    ble a3, s11, 44f
    mv a3, s11
44:
    bge a0, a1, 6f                  # empty
    bge a2, a3, 6f
5:
    la t0, stats
    ld t1, STAT_OPENINGS(t0)
    addi t1, t1, 1
    sd t1, STAT_OPENINGS(t0)
    ld a4, 32(sp)
    call rect_grow
6:
    ld t1, 16(sp)
    addi t1, t1, 1
    sd t1, 16(sp)
    j 3b
7:
    addi s6, s6, 1
    j 2b
8:
    addi s4, s4, 1
    j 1b
90:
    ld ra, 184(sp)
    ld s2, 176(sp)
    ld s3, 168(sp)
    ld s4, 160(sp)
    ld s5, 152(sp)
    ld s6, 144(sp)
    ld s7, 136(sp)
    ld s8, 128(sp)
    ld s9, 120(sp)
    ld s10, 112(sp)
    ld s11, 104(sp)
    fld fs0, 96(sp)
    fld fs1, 88(sp)
    fld fs2, 80(sp)
    fld fs3, 72(sp)
    fld fs4, 64(sp)
    fld fs5, 56(sp)
    fld fs6, 48(sp)
    fld fs7, 40(sp)
    addi sp, sp, 208
    ret

opening_cut:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    fsd fs8, 24(sp)
    fsd fs9, 16(sp)
    fsd fs10, 8(sp)
    fsd fs11, 0(sp)
    mv s2, a0
    mv a0, s2
    li a1, 1
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs8, fa0                  # the neighbour's ceiling at the start
    mv a0, s2
    li a1, 1
    fmv.d fa0, fs2
    fmv.d fa1, fs3
    call plane_height
    fmv.d fs9, fa0                  # and at the end
    flt.d t1, fs4, fs8
    flt.d t2, fs5, fs9
    and t1, t1, t2
    beqz t1, 1f
    fmv.d fs8, fs4                  # clamped to the sector's ceiling
    fmv.d fs9, fs5
1:
    mv a0, s2
    li a1, 0
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs10, fa0                 # the neighbour's floor at the start
    mv a0, s2
    li a1, 0
    fmv.d fa0, fs2
    fmv.d fa1, fs3
    call plane_height
    fmv.d fs11, fa0                 # and at the end
    flt.d t1, fs10, fs6
    flt.d t2, fs11, fs7
    and t1, t1, t2
    beqz t1, 2f
    fmv.d fs10, fs6                 # clamped to the sector's floor
    fmv.d fs11, fs7
2:
    fmv.d fa0, fs8
    fmv.d fa1, fs9
    fmv.d fa2, fs10
    fmv.d fa3, fs11
    call piece_polygon
    ld ra, 40(sp)
    ld s2, 32(sp)
    fld fs8, 24(sp)
    fld fs9, 16(sp)
    fld fs10, 8(sp)
    fld fs11, 0(sp)
    addi sp, sp, 48
    ret

sector_draw:
    addi sp, sp, -80
    sd ra, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    sd s7, 24(sp)
    sd s8, 16(sp)
    mv s2, a0
    li s8, 0                        # the facing walls gathered
    la t0, sector_rect
    slli t1, s2, 4
    add t0, t0, t1
    la t1, clip_rect
    ld t2, 0(t0)
    sd t2, 0(t1)
    ld t2, 8(t0)
    sd t2, 8(t1)
    la t0, stats
    ld t1, STAT_SECTORS(t0)
    addi t1, t1, 1
    sd t1, STAT_SECTORS(t0)
    call phase_mark
    sd a0, 0(sp)
    li s3, 0
1:
    li t0, 2
    bge s3, t0, 4f
    la t0, camera
    flw fa0, CAM_X(t0)
    fcvt.d.s fa0, fa0
    flw fa1, CAM_Y(t0)
    fcvt.d.s fa1, fa1
    mv a0, s2
    mv a1, s3
    call plane_height
    la t0, camera
    flw ft0, CAM_Z(t0)
    fcvt.d.s ft0, ft0               # the camera's z
    bnez s3, 2f
    flt.d t1, ft0, fa0              # below the floor
    bnez t1, 3f
    j 21f
2:
    flt.d t1, fa0, ft0              # above the ceiling
    bnez t1, 3f
21:
    mv a0, s2
    mv a1, s3
    call plane_draw
3:
    addi s3, s3, 1
    j 1b
4:
    call phase_mark
    ld t1, 0(sp)
    sub t0, a0, t1
    la t1, stats
    ld t2, STAT_PLANE_TICKS(t1)
    add t2, t2, t0
    sd t2, STAT_PLANE_TICKS(t1)
    call phase_mark
    sd a0, 0(sp)
    mv a0, s2
    call sector_at
    lwu s3, SECTOR_FIRST_LOOP(a0)
    lwu s4, SECTOR_LOOP_COUNT(a0)
    add s4, s4, s3                  # past the last loop
5:
    bgeu s3, s4, 8f
    mv a0, s3
    call loop_at
    lwu s5, LOOP_FIRST_WALL(a0)
    lwu s6, LOOP_WALL_COUNT(a0)
    add s6, s6, s5                  # past the last wall
6:
    bgeu s5, s6, 7f
    mv a0, s5
    call wall_at
    mv s7, a0
    lwu a0, WALL_A(s7)
    call vertex_at
    flw ft2, VERTEX_X(a0)
    flw ft3, VERTEX_Y(a0)
    lwu a0, WALL_B(s7)
    call vertex_at
    flw ft4, VERTEX_X(a0)
    flw ft5, VERTEX_Y(a0)
    la t0, camera
    flw ft0, CAM_X(t0)
    flw ft1, CAM_Y(t0)
    fsub.s ft0, ft0, ft2            # px - ax
    fsub.s ft1, ft1, ft3            # py - ay
    fsub.s ft4, ft4, ft2            # bx - ax
    fsub.s ft5, ft5, ft3            # by - ay
    fmul.s ft6, ft4, ft1
    fmul.s ft7, ft5, ft0
    flt.s t1, ft7, ft6              # (bx - ax)(py - ay) > (by - ay)(px - ax): in front
    beqz t1, 61f
    fmul.s ft6, ft0, ft4
    fmadd.s ft6, ft1, ft5, ft6      # along the run
    fmul.s ft7, ft4, ft4
    fmadd.s ft7, ft5, ft5, ft7      # the run squared
    fdiv.s ft6, ft6, ft7
    la t0, k_zero
    flw ft7, 0(t0)
    fmax.s ft6, ft6, ft7
    la t0, k_one
    flw ft7, 0(t0)
    fmin.s ft6, ft6, ft7            # the nearest point's share
    fnmsub.s ft0, ft6, ft4, ft0     # from the nearest point to the eye
    fnmsub.s ft1, ft6, ft5, ft1
    fmul.s ft6, ft0, ft0
    fmadd.s ft6, ft1, ft1, ft6
    la t0, wall_order
    slli t1, s8, 3
    add t1, t1, t0                  # past the last entry
62:
    beq t1, t0, 63f
    flw ft7, -8(t1)
    fle.s t2, ft7, ft6
    bnez t2, 63f
    fsw ft7, 0(t1)
    lwu t2, -4(t1)
    sw t2, 4(t1)
    addi t1, t1, -8
    j 62b
63:
    fsw ft6, 0(t1)
    sw s5, 4(t1)
    addi s8, s8, 1
61:
    addi s5, s5, 1
    j 6b
7:
    addi s3, s3, 1
    j 5b
8:
    li s3, 0
81:
    bgeu s3, s8, 82f
    la t0, wall_order
    slli t1, s3, 3
    add t0, t0, t1
    lwu a1, 4(t0)
    mv a0, s2
    call wall_draw
    addi s3, s3, 1
    j 81b
82:
    call phase_mark
    ld t1, 0(sp)
    sub t0, a0, t1
    la t1, stats
    ld t2, STAT_WALL_TICKS(t1)
    add t2, t2, t0
    sd t2, STAT_WALL_TICKS(t1)
    ld ra, 72(sp)
    ld s2, 64(sp)
    ld s3, 56(sp)
    ld s4, 48(sp)
    ld s5, 40(sp)
    ld s6, 32(sp)
    ld s7, 24(sp)
    ld s8, 16(sp)
    addi sp, sp, 80
    ret

material_bind:
    la t1, poly
    bltz a0, 8f
    la t0, material_record
    slli t2, a0, 3
    add t0, t0, t2
    ld t0, 0(t0)
    beqz t0, 8f
    la t4, material_mips
    li t2, MIP_ENTRY
    mul t2, a0, t2
    add t4, t4, t2
    sd t4, POLY_MIPS(t1)
    la t4, material_mip_count
    slli t2, a0, 3
    add t4, t4, t2
    ld t4, 0(t4)
    sd t4, POLY_MIP_COUNT(t1)
    lwu t2, JAB_SPRITE_WIDTH(t0)
    lwu t3, JAB_SPRITE_HEIGHT(t0)
    addi t4, t0, JAB_SPRITE_PIXELS
    sd t4, POLY_TEX(t1)
    sw t2, POLY_TEXWI(t1)
    sw t3, POLY_TEXHI(t1)
    fcvt.s.wu ft0, t2
    fsw ft0, POLY_TEXW(t1)
    fcvt.s.wu ft0, t3
    fsw ft0, POLY_TEXH(t1)
    li t4, 1
    li t0, 0
1:
    slli a1, t4, 1
    bgtu a1, t2, 2f
    mv t4, a1
    addi t0, t0, 1
    j 1b
2:
    addi t4, t4, -1
    sd t4, POLY_UMASK(t1)
    addi t0, t0, 2
    sd t0, POLY_WSHIFT(t1)
    li t4, 1
3:
    slli a1, t4, 1
    bgtu a1, t3, 4f
    mv t4, a1
    j 3b
4:
    addi t4, t4, -1
    sd t4, POLY_VMASK(t1)
    li a0, 1
    ret
8:
    li t2, 1
    sw t2, POLY_TEXWI(t1)
    sw t2, POLY_TEXHI(t1)
    fcvt.s.w ft0, t2
    fsw ft0, POLY_TEXW(t1)
    fsw ft0, POLY_TEXH(t1)
    li a0, 0
    ret

surface_mode:
    andi t0, a0, SURFACE_SKY
    li a0, POLY_TEXTURED
    beqz t0, poly_mode
    li a0, POLY_SKY
    la t0, poly
    sd a0, POLY_MODE(t0)
    ret

poly_mode:
    la t0, light_count
    lwu t0, 0(t0)
    beqz t0, 1f
    la t0, poly
    ld t1, POLY_LUMAP(t0)
    beqz t1, 2f
    ld t1, LUMAP_BASE(t1)
    beqz t1, 1f
2:
    ori a0, a0, POLY_LIT
1:
    la t0, poly
    sd a0, POLY_MODE(t0)
    ret

plane_draw:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s2, 48(sp)
    sd s3, 40(sp)
    sd s4, 32(sp)
    sd s5, 24(sp)
    sd s6, 16(sp)
    sd s7, 8(sp)
    mv s2, a0
    mv s3, a1
    slli t0, s2, 1
    add t0, t0, s3
    la t1, poly
    sd t0, POLY_SURFACE(t1)
    li t1, LUMAP_SIZE
    mul t0, t0, t1
    la t1, lumaps
    add t0, t0, t1
    la t1, poly
    sd t0, POLY_LUMAP(t1)
    call sector_at
    mv s4, a0                       # the sector
    li t0, SURFACE_SIZE
    mul t0, s3, t0
    addi s5, s4, SECTOR_FLOOR_SURFACE
    add s5, s5, t0                  # the surface
    lw a0, SURFACE_MATERIAL(s5)
    call material_bind
    beqz a0, 90f
    la t0, plane
    li t1, SECTOR_CEILING
    mul t1, s3, t1
    add t1, t1, s4
    flw ft0, PLANE_A(t1)
    fneg.s ft0, ft0
    fsw ft0, (PLANE_N + 0)(t0)
    flw ft0, PLANE_B(t1)
    fneg.s ft0, ft0
    fsw ft0, (PLANE_N + 4)(t0)
    la t2, k_one
    flw ft0, 0(t2)
    fsw ft0, (PLANE_N + 8)(t0)
    sw zero, (PLANE_Q + 0)(t0)
    sw zero, (PLANE_Q + 4)(t0)
    flw ft0, PLANE_C(t1)
    fsw ft0, (PLANE_Q + 8)(t0)
    flw ft0, SURFACE_U_SCALE(s5)
    fsw ft0, (PLANE_AU + 0)(t0)
    sw zero, (PLANE_AU + 4)(t0)
    sw zero, (PLANE_AU + 8)(t0)
    flw ft0, SURFACE_U_OFFSET(s5)
    fsw ft0, PLANE_U0(t0)
    sw zero, (PLANE_AV + 0)(t0)
    flw ft0, SURFACE_V_SCALE(s5)
    fsw ft0, (PLANE_AV + 4)(t0)
    sw zero, (PLANE_AV + 8)(t0)
    flw ft0, SURFACE_V_OFFSET(s5)
    fsw ft0, PLANE_V0(t0)
    call surface_setup
    lwu a0, SURFACE_FLAGS(s5)
    call surface_mode
    la t0, poly
    sw s2, POLY_SECTOR(t0)
    call lumap_bind
    call edges_reset
    lwu s6, SECTOR_FIRST_LOOP(s4)
    lwu s7, SECTOR_LOOP_COUNT(s4)
    add s7, s7, s6
4:
    bgeu s6, s7, 6f
    call poly_reset
    mv a0, s6
    call loop_at
    lwu t1, LOOP_FIRST_WALL(a0)
    lwu t2, LOOP_WALL_COUNT(a0)
    sd t1, 0(sp)
    add t2, t2, t1
    sd t2, 8(sp)
5:
    ld t1, 0(sp)
    ld t2, 8(sp)
    bgeu t1, t2, 55f
    mv a0, t1
    call wall_at
    lwu a0, WALL_A(a0)
    call vertex_at
    flw ft2, VERTEX_X(a0)
    flw ft3, VERTEX_Y(a0)
    fsw ft2, 16(sp)
    fsw ft3, 20(sp)
    fcvt.d.s fa0, ft2
    fcvt.d.s fa1, ft3
    mv a0, s2
    mv a1, s3
    call plane_height
    fcvt.s.d fa2, fa0
    flw fa0, 16(sp)
    flw fa1, 20(sp)
    call poly_point
    ld t1, 0(sp)
    addi t1, t1, 1
    sd t1, 0(sp)
    j 5b
55:
    call poly_project
    addi s6, s6, 1
    j 4b
6:
    la t0, stats
    ld t1, STAT_PLANES(t0)
    addi t1, t1, 1
    sd t1, STAT_PLANES(t0)
    call poly_fill
90:
    ld ra, 56(sp)
    ld s2, 48(sp)
    ld s3, 40(sp)
    ld s4, 32(sp)
    ld s5, 24(sp)
    ld s6, 16(sp)
    ld s7, 8(sp)
    addi sp, sp, 64
    ret

piece_polygon:
    addi sp, sp, -64
    sd ra, 56(sp)
    fsd fs4, 48(sp)
    fsd fs5, 40(sp)
    fsd fs6, 32(sp)
    fsd fs7, 24(sp)
    fmv.d fs4, fa0                  # top0
    fmv.d fs5, fa1                  # top1
    fmv.d fs6, fa2                  # bot0
    fmv.d fs7, fa3                  # bot1
    call edges_reset
    call poly_reset
    fsub.d ft0, fs4, fs6            # dz0
    fsub.d ft1, fs5, fs7            # dz1
    la t0, k_zero_d
    fld ft2, 0(t0)
    flt.d t1, ft2, ft0              # dz0 > 0
    flt.d t2, ft2, ft1              # dz1 > 0
    beqz t1, 3f
    beqz t2, 2f
    fcvt.s.d fa0, fs0
    fcvt.s.d fa1, fs1
    fcvt.s.d fa2, fs4
    call poly_point
    fcvt.s.d fa0, fs2
    fcvt.s.d fa1, fs3
    fcvt.s.d fa2, fs5
    call poly_point
    fcvt.s.d fa0, fs2
    fcvt.s.d fa1, fs3
    fcvt.s.d fa2, fs7
    call poly_point
    fcvt.s.d fa0, fs0
    fcvt.s.d fa1, fs1
    fcvt.s.d fa2, fs6
    call poly_point
    j 5f
2:
    fsub.d ft3, ft0, ft1
    fdiv.d ft3, ft0, ft3            # f
    fcvt.s.d fa0, fs0
    fcvt.s.d fa1, fs1
    fcvt.s.d fa2, fs4
    call poly_point
    call piece_cross
    call poly_point
    fcvt.s.d fa0, fs0
    fcvt.s.d fa1, fs1
    fcvt.s.d fa2, fs6
    call poly_point
    j 5f
3:
    beqz t2, 9f
    fsub.d ft3, ft0, ft1
    fdiv.d ft3, ft0, ft3
    call piece_cross
    call poly_point
    fcvt.s.d fa0, fs2
    fcvt.s.d fa1, fs3
    fcvt.s.d fa2, fs5
    call poly_point
    fcvt.s.d fa0, fs2
    fcvt.s.d fa1, fs3
    fcvt.s.d fa2, fs7
    call poly_point
5:
    call poly_project
    j 10f
9:
    li a0, 0
10:
    ld ra, 56(sp)
    fld fs4, 48(sp)
    fld fs5, 40(sp)
    fld fs6, 32(sp)
    fld fs7, 24(sp)
    addi sp, sp, 64
    ret

piece_cross:
    fsub.d ft4, fs2, fs0
    fmadd.d ft4, ft4, ft3, fs0
    fcvt.s.d fa0, ft4
    fsub.d ft4, fs3, fs1
    fmadd.d ft4, ft4, ft3, fs1
    fcvt.s.d fa1, ft4
    fsub.d ft4, fs5, fs4
    fmadd.d ft4, ft4, ft3, fs4
    fcvt.s.d fa2, ft4
    ret

wall_surface:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s4, 32(sp)
    sd s5, 24(sp)
    sd s6, 16(sp)
    mv s4, a0
    mv s5, a1
    li t0, LUMAP_PLANES
    add t0, t0, s5
    la t1, poly
    sd t0, POLY_SURFACE(t1)
    li t1, LUMAP_SIZE
    mul t0, t0, t1
    la t1, lumaps
    add t0, t0, t1
    la t1, poly
    sd t0, POLY_LUMAP(t1)
    mv a0, s5
    call wall_at
    mv s6, a0                       # the wall
    la t0, plane
    fcvt.s.d ft0, fs1
    fcvt.s.d ft1, fs3
    fsub.s ft2, ft0, ft1            # ay - by
    fsw ft2, (PLANE_N + 0)(t0)
    fcvt.s.d ft0, fs2
    fcvt.s.d ft1, fs0
    fsub.s ft2, ft0, ft1            # bx - ax
    fsw ft2, (PLANE_N + 4)(t0)
    sw zero, (PLANE_N + 8)(t0)
    fsw ft1, (PLANE_Q + 0)(t0)
    fcvt.s.d ft0, fs1
    fsw ft0, (PLANE_Q + 4)(t0)
    sw zero, (PLANE_Q + 8)(t0)
    fsub.d ft0, fs2, fs0
    fsub.d ft1, fs3, fs1
    jab.f64.vec2.reg.len ft8, ft0, ft1
    la t1, k_one_d
    fld ft3, 0(t1)
    fdiv.d ft2, ft3, ft8
    fmul.d ft0, ft0, ft2            # ex
    fmul.d ft1, ft1, ft2            # ey
    fmul.d ft4, ft0, fs0
    fmadd.d ft4, ft1, fs1, ft4      # e . a
    flw ft5, (WALL_SURFACE + SURFACE_U_SCALE)(s6)
    fcvt.d.s ft5, ft5
    fmul.d ft6, ft5, ft0
    fcvt.s.d ft7, ft6
    fsw ft7, (PLANE_AU + 0)(t0)
    fmul.d ft6, ft5, ft1
    fcvt.s.d ft7, ft6
    fsw ft7, (PLANE_AU + 4)(t0)
    sw zero, (PLANE_AU + 8)(t0)
    flw ft6, (WALL_SURFACE + SURFACE_U_OFFSET)(s6)
    fcvt.d.s ft6, ft6
    fnmsub.d ft6, ft5, ft4, ft6     # u_offset - u_scale e.a
    fcvt.s.d ft7, ft6
    fsw ft7, PLANE_U0(t0)
    flw ft5, (WALL_SURFACE + SURFACE_V_SCALE)(s6)
    fcvt.d.s ft5, ft5
    sw zero, (PLANE_AV + 0)(t0)
    sw zero, (PLANE_AV + 4)(t0)
    fneg.d ft6, ft5
    fcvt.s.d ft7, ft6
    fsw ft7, (PLANE_AV + 8)(t0)
    flw ft6, WALL_ANCHOR(s6)
    fcvt.d.s ft6, ft6
    flw ft7, (WALL_SURFACE + SURFACE_V_OFFSET)(s6)
    fcvt.d.s ft7, ft7
    fmadd.d ft7, ft5, ft6, ft7      # v_offset + v_scale anchor
    fcvt.s.d ft7, ft7
    fsw ft7, PLANE_V0(t0)
    lw a0, (WALL_SURFACE + SURFACE_MATERIAL)(s6)
    call material_bind
    mv s5, a0
    call surface_setup
    lwu a0, (WALL_SURFACE + SURFACE_FLAGS)(s6)
    call surface_mode
    la t0, poly
    sw s4, POLY_SECTOR(t0)
    call lumap_bind
    mv a0, s5
    ld ra, 40(sp)
    ld s4, 32(sp)
    ld s5, 24(sp)
    ld s6, 16(sp)
    addi sp, sp, 48
    ret

wall_within:
    la t0, camera
    flw ft0, CAM_X(t0)
    fcvt.d.s ft0, ft0
    flw ft1, CAM_Y(t0)
    fcvt.d.s ft1, ft1
    fsub.d ft2, fs2, fs0            # the wall's run
    fsub.d ft3, fs3, fs1
    fsub.d ft4, ft0, fs0            # from the start to the camera
    fsub.d ft5, ft1, fs1
    fmul.d ft6, ft4, ft2
    fmadd.d ft6, ft5, ft3, ft6      # along
    fmul.d ft7, ft2, ft2
    fmadd.d ft7, ft3, ft3, ft7      # the length squared
    fdiv.d ft6, ft6, ft7
    la t0, k_zero_d
    fld ft7, 0(t0)
    fmax.d ft6, ft6, ft7
    la t0, k_one_d
    fld ft7, 0(t0)
    fmin.d ft6, ft6, ft7            # clamped to the segment
    fnmsub.d ft4, ft6, ft2, ft4     # from the closest point to the camera
    fnmsub.d ft5, ft6, ft3, ft5
    fmul.d ft4, ft4, ft4
    fmadd.d ft4, ft5, ft5, ft4
    fle.d a0, ft4, fa0
    ret

wall_draw:
    addi sp, sp, -192
    sd ra, 168(sp)
    sd s2, 160(sp)
    sd s3, 152(sp)
    sd s4, 144(sp)
    sd s5, 136(sp)
    sd s6, 128(sp)
    sd s7, 120(sp)
    sd s8, 112(sp)
    sd s9, 24(sp)
    fsd fs0, 104(sp)
    fsd fs1, 96(sp)
    fsd fs2, 88(sp)
    fsd fs3, 80(sp)
    fsd fs4, 72(sp)
    fsd fs5, 64(sp)
    fsd fs6, 56(sp)
    fsd fs7, 48(sp)
    fsd fs8, 40(sp)
    fsd fs9, 32(sp)
    fsd fs10, 16(sp)
    fsd fs11, 8(sp)
    mv s2, a0                       # the sector
    mv s3, a1                       # the wall
    la t0, stats
    ld t1, STAT_WALLS(t0)
    addi t1, t1, 1
    sd t1, STAT_WALLS(t0)
    mv a0, s3
    call wall_at
    mv s4, a0
    lwu s8, (WALL_SURFACE + SURFACE_FLAGS)(s4)
    lwu s9, WALL_FIRST_PORTAL(s4)
    lwu s5, WALL_PORTAL_COUNT(s4)
    lwu a0, WALL_A(s4)
    call vertex_at
    flw ft0, VERTEX_X(a0)
    fcvt.d.s fs0, ft0
    flw ft0, VERTEX_Y(a0)
    fcvt.d.s fs1, ft0               # the start
    lwu a0, WALL_B(s4)
    call vertex_at
    flw ft0, VERTEX_X(a0)
    fcvt.d.s fs2, ft0
    flw ft0, VERTEX_Y(a0)
    fcvt.d.s fs3, ft0               # the end
    mv a0, s2
    li a1, 1
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs4, fa0                  # the ceiling at the start
    mv a0, s2
    li a1, 1
    fmv.d fa0, fs2
    fmv.d fa1, fs3
    call plane_height
    fmv.d fs5, fa0                  # and at the end
    mv a0, s2
    li a1, 0
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs6, fa0                  # the floor at the start
    mv a0, s2
    li a1, 0
    fmv.d fa0, fs2
    fmv.d fa1, fs3
    call plane_height
    fmv.d fs7, fa0                  # and at the end
    fmv.d fs8, fs4                  # the piece's top
    fmv.d fs9, fs5
    li s6, 0                        # k, the piece
1:
    bgt s6, s5, 90f
    beqz s6, 20f
    add a0, s9, s6
    addi a0, a0, -1
    call portal_at
    lwu s7, PORTAL_SECTOR(a0)
    mv a0, s7
    li a1, 0
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs8, fa0
    mv a0, s7
    li a1, 0
    fmv.d fa0, fs2
    fmv.d fa1, fs3
    call plane_height
    fmv.d fs9, fa0
    andi t2, s8, SURFACE_MASKED
    beqz t2, 20f
    la t0, k_near_sq_d
    fld fa0, 0(t0)
    call wall_within
    bnez a0, 20f
    mv a0, s7
    call opening_cut
    li t0, 3
    bltu a0, t0, 20f
    mv a0, s2
    mv a1, s3
    call wall_surface
    beqz a0, 20f
    li a0, POLY_MASKED
    call poly_mode
    call poly_fill
20:
    bge s6, s5, 21f
    add a0, s9, s6
    call portal_at
    lwu s7, PORTAL_SECTOR(a0)
    mv a0, s7
    li a1, 1
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs10, fa0
    mv a0, s7
    li a1, 1
    fmv.d fa0, fs2
    fmv.d fa1, fs3
    call plane_height
    fmv.d fs11, fa0
    j 22f
21:
    fmv.d fs10, fs6
    fmv.d fs11, fs7
22:
    fmv.d fa0, fs8
    fmv.d fa1, fs9
    fmv.d fa2, fs10
    fmv.d fa3, fs11
    call piece_polygon
    li t0, 3
    bltu a0, t0, 30f
    mv a0, s2
    mv a1, s3
    call wall_surface
    beqz a0, 30f
    la t0, stats
    ld t1, STAT_PIECES(t0)
    addi t1, t1, 1
    sd t1, STAT_PIECES(t0)
    call poly_fill
30:
    addi s6, s6, 1
    j 1b
90:
    ld ra, 168(sp)
    ld s2, 160(sp)
    ld s3, 152(sp)
    ld s4, 144(sp)
    ld s5, 136(sp)
    ld s6, 128(sp)
    ld s7, 120(sp)
    ld s8, 112(sp)
    ld s9, 24(sp)
    fld fs0, 104(sp)
    fld fs1, 96(sp)
    fld fs2, 88(sp)
    fld fs3, 80(sp)
    fld fs4, 72(sp)
    fld fs5, 64(sp)
    fld fs6, 56(sp)
    fld fs7, 48(sp)
    fld fs8, 40(sp)
    fld fs9, 32(sp)
    fld fs10, 16(sp)
    fld fs11, 8(sp)
    addi sp, sp, 192
    ret

phase_mark:
    rdtime a0
    la t0, stats
    ld t0, STAT_RASTER_TICKS(t0)
    sub a0, a0, t0                  # the clock less the raster's ticks, so a flush's render is no phase's
    ret

uncovered:
    la t0, zbuf
    li t1, ZBUF_BYTES
    add t1, t1, t0
    li a0, 0
.balign 32
1:
    lw t2, 0(t0)
    snez t2, t2
    xori t2, t2, 1
    add a0, a0, t2
    addi t0, t0, 4
    bltu t0, t1, 1b
    ret

.section .bss
.balign 8
walk_tail:
    .skip 8
stats:
    .skip STAT_SIZE
walk_fifo:
    .skip (MAX_SECTORS * 4)
walk_seen:
    .skip MAX_SECTORS
.balign 8
wall_order:
    .skip (MAX_WALLS * 8)
.balign 16
sector_rect:
    .skip (MAX_SECTORS * RECT_SIZE)
flow_pending:
    .skip MAX_SECTORS
.balign 8
flow_ring:
    .skip (FLOW_RING * 4)
flow_head:
    .skip 8
flow_tail:
    .skip 8
clip_rect:
    .skip RECT_SIZE
