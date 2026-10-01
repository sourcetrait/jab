# The world drawn from the camera: the portal walk breadth-first through the
# compiler's portals, each sector's planes and wall pieces, the openings
# sampled against the depth buffer.

.section .rodata
.balign 8
k_near_sq_d:
    .double 0.003906640625
k_zero_d:
    .double 0.0

.section .text

# The frame drawn: the depth buffer cleared, the walk from the camera's
# sector or from every sector, then the sprites and the actors.
world_draw:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
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
    # the frame painted magenta first, so a pixel no surface reaches
    # shows in a capture; the release build leaves the frame before
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
    call sky_setup
    # the walk's start
    section_count KIND_SECTORS, s2
    la t0, walk_seen
    add t1, t0, s2
2:
    beq t0, t1, 3f
    sb zero, 0(t0)
    addi t0, t0, 1
    j 2b
3:
    la t0, cam_sector
    lw t1, 0(t0)
    la s3, walk_fifo
    li s4, 0                        # the fifo's write
    bgeu t1, s2, 5f
    sw t1, 0(s3)
    li s4, 1
    la t0, walk_seen
    add t0, t0, t1
    li t2, 1
    sb t2, 0(t0)
    j 7f
5:
    # in no sector: every sector
    mv s4, s2                       # the fifo holds them all
    li t1, 0
6:
    bgeu t1, s2, 7f
    slli t2, t1, 2
    add t2, t2, s3
    sw t1, 0(t2)
    la t0, walk_seen
    add t0, t0, t1
    li t2, 1
    sb t2, 0(t0)
    addi t1, t1, 1
    j 6b
7:
    la t0, walk_tail
    sd s4, 0(t0)
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
    # the sprites and the actors of the sectors drawn
    rdtime s2
    call sprites_draw
    call actors_draw
    rdtime t0
    sub t0, t0, s2
    la t1, stats
    sd t0, STAT_SPRITE_TICKS(t1)
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 48
    ret

# Queues a sector and marks it reached.
# a0 int The sector.
# returns Clobbers t0 to t2.
walk_push:
    la t0, walk_seen
    add t0, t0, a0
    li t1, 1
    sb t1, 0(t0)
    la t0, walk_tail
    ld t1, 0(t0)
    la t2, walk_fifo
    slli t1, t1, 2
    add t2, t2, t1
    sw a0, 0(t2)
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
    ret

# A sector's planes facing the camera, then its walls facing the camera.
# a0 int The sector.
sector_draw:
    addi sp, sp, -80
    sd ra, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    sd s7, 24(sp)
    mv s2, a0
    la t0, stats
    ld t1, STAT_SECTORS(t0)
    addi t1, t1, 1
    sd t1, STAT_SECTORS(t0)
    rdtime t0
    sd t0, 0(sp)
    # the planes: the floor unless the camera is below it, the ceiling
    # unless the camera is above it, judged at the plane's height under
    # the camera
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
    rdtime t0
    ld t1, 0(sp)
    sub t0, t0, t1
    la t1, stats
    ld t2, STAT_PLANE_TICKS(t1)
    add t2, t2, t0
    sd t2, STAT_PLANE_TICKS(t1)
    rdtime t0
    sd t0, 0(sp)
    # the walls facing the camera: the camera on the sector's side of
    # the wall's line, its left from a to b
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
    mv a0, s2
    mv a1, s5
    call wall_draw
61:
    addi s5, s5, 1
    j 6b
7:
    addi s3, s3, 1
    j 5b
8:
    rdtime t0
    ld t1, 0(sp)
    sub t0, t0, t1
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
    addi sp, sp, 80
    ret

# A material's texture into the surface in hand: pixels, size, and wraps.
# a0 int The material.
# returns Clobbers t0 to t4, a1.
#   a0 1, or 0 with the sizes 1 when the material is none or has no texture.
material_bind:
    la t1, poly
    bltz a0, 8f
    la t0, material_record
    slli t2, a0, 3
    add t0, t0, t2
    ld t0, 0(t0)
    beqz t0, 8f
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
    # the width's power of two below it, its mask, and the row shift
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

# POLY_MODE from a surface's flags: the sky, else textured, lit with lights.
# a0 u32 The flags.
# returns Clobbers t0, t1.
surface_mode:
    andi t0, a0, SURFACE_SKY
    li a0, POLY_TEXTURED
    beqz t0, poly_mode
    li a0, POLY_SKY
    la t0, poly
    sd a0, POLY_MODE(t0)
    ret

# POLY_MODE set, the lit flag added when the map has lights.
# a0 int The mode.
# returns Clobbers t0, t1.
poly_mode:
    la t0, light_count
    lwu t0, 0(t0)
    beqz t0, 1f
    ori a0, a0, POLY_LIT
1:
    la t0, poly
    sd a0, POLY_MODE(t0)
    ret

# A sector's plane when its surface has a material: every loop's points at
# the plane's height into one edge list and one even-odd fill.
# a0 int The sector.
# a1 int 0 the floor, 1 the ceiling.
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
    call sector_at
    mv s4, a0                       # the sector
    li t0, SURFACE_SIZE
    mul t0, s3, t0
    addi s5, s4, SECTOR_FLOOR_SURFACE
    add s5, s5, t0                  # the surface
    lw a0, SURFACE_MATERIAL(s5)
    call material_bind
    beqz a0, 90f
    lwu a0, SURFACE_FLAGS(s5)
    call surface_mode
    la t0, poly
    sw s2, POLY_SECTOR(t0)
    # the plane: the normal (-a, -b, 1) and the point (0, 0, c)
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
    # u along x and v along y, by the surface's scales and offsets
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
    # the loops' edges, each loop a polygon of its walls' first
    # vertices at the plane's height
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

# The polygon in hand set to the wall piece between two heights at each
# end: the quad, the triangle where the planes cross, or nothing.
# fa0 f64 The top at the start.
# fa1 f64 The top at the end.
# fa2 f64 The bottom at the start.
# fa3 f64 The bottom at the end.
# fs0 f64 The wall's start x; fs1 y; fs2 the end x; fs3 y.
# returns
#   a0 The clipped point count, 0 for nothing.
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
    # the quad
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
    # the triangle at the start: the start's top and bottom and the
    # crossing along the top
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
    # the triangle at the end
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

# The point a fraction along the wall from its start, at the top's height
# there.
# ft3 f64 The fraction.
# returns Clobbers ft4.
#   fa0 f32 x.
#   fa1 f32 y.
#   fa2 f32 z.
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

# The plane and surface in hand set for a wall: the normal into the sector,
# u along the wall from its first vertex, v down from its anchor height.
# a0 int The sector.
# a1 int The wall.
# fs0 f64 The wall's start x; fs1 y; fs2 the end x; fs3 y.
# returns
#   a0 1 when the wall's material has a texture, else 0.
wall_surface:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s4, 32(sp)
    sd s5, 24(sp)
    sd s6, 16(sp)
    mv s4, a0
    mv s5, a1
    mv a0, s5
    call wall_at
    mv s6, a0                       # the wall
    la t0, plane
    # the normal and a point
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
    # e, the unit direction along the wall, and the start's distance
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
    # u: the scale along e from the start
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
    # v: the scale down from the anchor height
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
    lwu a0, (WALL_SURFACE + SURFACE_FLAGS)(s6)
    call surface_mode
    la t0, poly
    sw s4, POLY_SECTOR(t0)
    call surface_setup
    mv a0, s5
    ld ra, 40(sp)
    ld s4, 32(sp)
    ld s5, 24(sp)
    ld s6, 16(sp)
    addi sp, sp, 48
    ret

# Whether the camera is within the near distance of the wall in hand, in
# the plan.
# returns Clobbers t0, ft0 to ft7.
#   a0 1 or 0.
wall_near:
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
    la t0, k_near_sq_d
    fld ft7, 0(t0)
    fle.d a0, ft4, ft7
    ret

# A wall of a sector facing the camera: its portals from the top down, the
# solid pieces between them and, at each, the opening into its neighbour.
# a0 int The sector.
# a1 int The wall.
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
    # the sector's planes at the two ends
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
    # the neighbour above this piece: its floor is the piece's top
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
    # the opening into it, when it is not yet reached or the wall is
    # masked
    la t0, walk_seen
    add t0, t0, s7
    lbu t1, 0(t0)
    andi t2, s8, SURFACE_MASKED
    beqz t1, 10f
    beqz t2, 20f
10:
    call wall_near
    beqz a0, 11f
    la t0, walk_seen
    add t0, t0, s7
    lbu t1, 0(t0)
    bnez t1, 20f
    mv a0, s7
    call walk_push
    j 20f
11:
    mv a0, s7
    li a1, 1
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs10, fa0                 # the opening's top at the start
    mv a0, s7
    li a1, 1
    fmv.d fa0, fs2
    fmv.d fa1, fs3
    call plane_height
    fmv.d fs11, fa0                 # and at the end
    flt.d t1, fs4, fs10
    flt.d t2, fs5, fs11
    and t1, t1, t2
    beqz t1, 12f
    fmv.d fs10, fs4                 # clamped to the sector's ceiling
    fmv.d fs11, fs5
12:
    fmv.d fa2, fs8                  # the opening's bottom, the floor
    fmv.d fa3, fs9
    flt.d t1, fa2, fs6
    flt.d t2, fa3, fs7
    and t1, t1, t2
    beqz t1, 13f
    fmv.d fa2, fs6                  # clamped to the sector's floor
    fmv.d fa3, fs7
13:
    fmv.d fa0, fs10
    fmv.d fa1, fs11
    call piece_polygon
    li t0, 3
    bltu a0, t0, 20f
    mv a0, s2
    mv a1, s3
    call wall_surface
    sd a0, 0(sp)
    la t0, walk_seen
    add t0, t0, s7
    lbu t1, 0(t0)
    bnez t1, 15f
    rdtime t0
    sd t0, 176(sp)
    call poly_shows
    la t0, stats
    ld t1, STAT_OPENINGS(t0)
    addi t1, t1, 1
    sd t1, STAT_OPENINGS(t0)
    rdtime t1
    ld t2, 176(sp)
    sub t1, t1, t2
    ld t2, STAT_PORTAL_TICKS(t0)
    add t2, t2, t1
    sd t2, STAT_PORTAL_TICKS(t0)
    beqz a0, 15f
    mv a0, s7
    call walk_push
15:
    andi t2, s8, SURFACE_MASKED
    beqz t2, 20f
    ld t0, 0(sp)
    beqz t0, 20f
    li a0, POLY_MASKED
    call poly_mode
    call poly_fill
20:
    # the piece's bottom: the next neighbour's ceiling, or the floor
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

# How many pixels no surface reached this frame, the depth buffer's zeros.
# returns Clobbers t0 to t2.
#   a0 The count.
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
