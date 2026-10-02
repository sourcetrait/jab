# The sprite entities drawn after the walk, each a flat quad facing the
# camera, fixed along its yaw, or flat on the floor, masked by alpha.

.section .rodata
.balign 8
k_pull_d:
    .double 0.99
k_tiny_d:
    .double 0.000000001

.section .text

# Every sprite entity in a sector the walk reached drawn.
sprites_draw:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    section_count KIND_ENTITIES, s2
    section_at KIND_ENTITIES, s3
1:
    beqz s2, 9f
    lwu t0, ENTITY_CLASS(s3)
    li t1, CLASS_SPRITE
    bne t0, t1, 8f
    lw t0, ENTITY_SECTOR(s3)
    la t1, walk_seen
    add t1, t1, t0
    lbu t1, 0(t1)
    beqz t1, 8f
    # its surface index: the map sprites after every map, by entity
    section_at KIND_ENTITIES, t0
    sub t0, s3, t0
    li t1, ENTITY_SIZE
    divu t0, t0, t1
    li t1, SURFACE_SPRITES
    add t0, t0, t1
    la t1, sprite_surface
    sd t0, 0(t1)
    mv a0, s3
    call sprite_draw
8:
    addi s3, s3, ENTITY_SIZE
    addi s2, s2, -1
    j 1b
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

# A sprite entity drawn when it has a texture and faces the camera or is
# two-sided; lit flat by one brightness at its centre.
# a0 address The entity.
sprite_draw:
    addi sp, sp, -128
    sd ra, 120(sp)
    sd s2, 112(sp)
    sd s3, 104(sp)
    fsd fs0, 96(sp)
    fsd fs1, 88(sp)
    fsd fs2, 80(sp)
    fsd fs3, 72(sp)
    fsd fs4, 64(sp)
    fsd fs5, 56(sp)
    fsd fs6, 48(sp)
    fsd fs7, 40(sp)
    fsd fs8, 32(sp)
    fsd fs9, 24(sp)
    fsd fs10, 16(sp)
    fsd fs11, 8(sp)
    mv s2, a0                       # the entity
    lw a0, ENTITY_MATERIAL(s2)
    call material_bind
    beqz a0, 90f
    lwu s3, ENTITY_FLAGS(s2)
    # the feet and the half extents, doubles
    flw ft0, ENTITY_X(s2)
    fcvt.d.s fs0, ft0
    flw ft0, ENTITY_Y(s2)
    fcvt.d.s fs1, ft0
    flw ft0, ENTITY_Z(s2)
    fcvt.d.s fs2, ft0
    la t0, k_half_d
    fld ft1, 0(t0)
    flw ft0, ENTITY_WIDTH(s2)
    fcvt.d.s ft0, ft0
    fmul.d fs9, ft0, ft1            # half the width
    flw ft0, ENTITY_HEIGHT(s2)
    fcvt.d.s ft0, ft0
    fmul.d fs10, ft0, ft1           # half the height
    # the yaw's sine and cosine, doubles
    flw fa0, ENTITY_YAW(s2)
    jab.f32.rad fa0, fa0
    jab.f32.sin fa1, fa0
    fcvt.d.s fs11, fa1              # sin yaw
    jab.f32.cos fa1, fa0
    fcvt.d.s ft9, fa1               # cos yaw
    andi t0, s3, ENTITY_FLAT
    bnez t0, 2f
    # standing: the centre half the height up, d straight down
    fadd.d fs2, fs2, fs10
    fcvt.d.w fs6, zero
    fcvt.d.w fs7, zero
    fneg.d fs8, fs10
    andi t0, s3, ENTITY_CAMERA
    bnez t0, 1f
    # fixed: facing its yaw, r to the right of a viewer in front
    fneg.d fs3, fs11
    fmul.d fs3, fs3, fs9
    fmul.d fs4, ft9, fs9
    fcvt.d.w fs5, zero
    j 3f
1:
    # facing the camera: r along the camera's right kept level; a
    # right that stands on end leaves the sprite facing its yaw
    la t3, camera_d
    addi t3, t3, CAMD_RIGHT
    jab.f64.vec2.len ft8, t3        # the level length of right
    la t0, k_tiny_d
    fld ft5, 0(t0)
    flt.d t1, ft8, ft5
    beqz t1, 11f
    fneg.d fs3, fs11
    fmul.d fs3, fs3, fs9
    fmul.d fs4, ft9, fs9
    fcvt.d.w fs5, zero
    j 3f
11:
    fdiv.d ft4, fs9, ft8
    fld ft2, 0(t3)
    fmul.d fs3, ft2, ft4
    fld ft3, 8(t3)
    fmul.d fs4, ft3, ft4
    fcvt.d.w fs5, zero
    j 3f
2:
    # flat: along its yaw with its face up
    fmul.d fs3, ft9, fs9
    fmul.d fs4, fs11, fs9
    fcvt.d.w fs5, zero
    fmul.d fs6, fs11, fs10
    fneg.d fs7, ft9
    fmul.d fs7, fs7, fs10
    fcvt.d.w fs8, zero
3:
    # the normal, d x r, the side the texture faces
    fmul.d ft6, fs7, fs5
    fnmsub.d ft6, fs8, fs4, ft6     # d.y r.z - d.z r.y
    fmul.d ft7, fs8, fs3
    fnmsub.d ft7, fs6, fs5, ft7     # d.z r.x - d.x r.z
    fmul.d ft8, fs6, fs4
    fnmsub.d ft8, fs7, fs3, ft8     # d.x r.y - d.y r.x
    andi t0, s3, ENTITY_TWO_SIDED
    bnez t0, 4f
    la t0, camera
    flw ft0, CAM_X(t0)
    fcvt.d.s ft0, ft0
    fsub.d ft0, ft0, fs0
    flw ft1, CAM_Y(t0)
    fcvt.d.s ft1, ft1
    fsub.d ft1, ft1, fs1
    flw ft2, CAM_Z(t0)
    fcvt.d.s ft2, ft2
    fsub.d ft2, ft2, fs2
    fmul.d ft3, ft0, ft6
    fmadd.d ft3, ft1, ft7, ft3
    fmadd.d ft3, ft2, ft8, ft3      # n . (camera - c)
    fcvt.d.w ft4, zero
    fle.d t1, ft3, ft4
    bnez t1, 90f                    # the camera behind it
4:
    # pulled a hundredth toward the camera
    la t0, k_pull_d
    fld ft5, 0(t0)
    la t0, camera
    flw ft0, CAM_X(t0)
    fcvt.d.s ft0, ft0
    fsub.d fs0, fs0, ft0
    fmadd.d fs0, fs0, ft5, ft0
    flw ft0, CAM_Y(t0)
    fcvt.d.s ft0, ft0
    fsub.d fs1, fs1, ft0
    fmadd.d fs1, fs1, ft5, ft0
    flw ft0, CAM_Z(t0)
    fcvt.d.s ft0, ft0
    fsub.d fs2, fs2, ft0
    fmadd.d fs2, fs2, ft5, ft0
    fmul.d fs3, fs3, ft5
    fmul.d fs4, fs4, ft5
    fmul.d fs5, fs5, ft5
    fmul.d fs6, fs6, ft5
    fmul.d fs7, fs7, ft5
    fmul.d fs8, fs8, ft5
    # the plane: the normal, the centre, u across r and v across d,
    # each 0 at the near edge and 1 at the far
    la t0, plane
    fcvt.s.d ft0, ft6
    fsw ft0, (PLANE_N + 0)(t0)
    fcvt.s.d ft0, ft7
    fsw ft0, (PLANE_N + 4)(t0)
    fcvt.s.d ft0, ft8
    fsw ft0, (PLANE_N + 8)(t0)
    fcvt.s.d ft0, fs0
    fsw ft0, (PLANE_Q + 0)(t0)
    fcvt.s.d ft0, fs1
    fsw ft0, (PLANE_Q + 4)(t0)
    fcvt.s.d ft0, fs2
    fsw ft0, (PLANE_Q + 8)(t0)
    fmul.d ft1, fs3, fs3
    fmadd.d ft1, fs4, fs4, ft1
    fmadd.d ft1, fs5, fs5, ft1
    fadd.d ft1, ft1, ft1
    la t1, k_one_d
    fld ft2, 0(t1)
    fdiv.d ft1, ft2, ft1            # 1 / (2 |r|^2)
    fmul.d ft2, fs3, ft1
    fmul.d ft3, fs4, ft1
    fmul.d ft4, fs5, ft1
    fcvt.s.d ft0, ft2
    fsw ft0, (PLANE_AU + 0)(t0)
    fcvt.s.d ft0, ft3
    fsw ft0, (PLANE_AU + 4)(t0)
    fcvt.s.d ft0, ft4
    fsw ft0, (PLANE_AU + 8)(t0)
    la t1, k_half_d
    fld ft6, 0(t1)
    fnmsub.d ft6, ft2, fs0, ft6
    fnmsub.d ft6, ft3, fs1, ft6
    fnmsub.d ft6, ft4, fs2, ft6     # 1/2 - c . a_u
    fcvt.s.d ft0, ft6
    fsw ft0, PLANE_U0(t0)
    fmul.d ft1, fs6, fs6
    fmadd.d ft1, fs7, fs7, ft1
    fmadd.d ft1, fs8, fs8, ft1
    fadd.d ft1, ft1, ft1
    la t1, k_one_d
    fld ft2, 0(t1)
    fdiv.d ft1, ft2, ft1            # 1 / (2 |d|^2)
    fmul.d ft2, fs6, ft1
    fmul.d ft3, fs7, ft1
    fmul.d ft4, fs8, ft1
    fcvt.s.d ft0, ft2
    fsw ft0, (PLANE_AV + 0)(t0)
    fcvt.s.d ft0, ft3
    fsw ft0, (PLANE_AV + 4)(t0)
    fcvt.s.d ft0, ft4
    fsw ft0, (PLANE_AV + 8)(t0)
    la t1, k_half_d
    fld ft6, 0(t1)
    fnmsub.d ft6, ft2, fs0, ft6
    fnmsub.d ft6, ft3, fs1, ft6
    fnmsub.d ft6, ft4, fs2, ft6
    fcvt.s.d ft0, ft6
    fsw ft0, PLANE_V0(t0)
    # no lumel map: a sprite moves, so it is lit flat by one brightness
    # taken below once the lights are culled; the surface index the
    # caller named
    la t0, poly
    sd zero, POLY_LUMAP(t0)
    lw t1, ENTITY_SECTOR(s2)
    sw t1, POLY_SECTOR(t0)
    la t1, sprite_surface
    ld t1, 0(t1)
    sd t1, POLY_SURFACE(t0)
    # its sector's rectangle clips the quad only when the quad is proven
    # within the sector; a flat quad, or one unproven, draws over the
    # whole screen, depth-tested as before
    andi t0, s3, ENTITY_FLAT
    bnez t0, 480f
    lw a0, ENTITY_SECTOR(s2)
    call sprite_within
    beqz a0, 480f
    lw t1, ENTITY_SECTOR(s2)
    la t2, sector_rect
    slli t1, t1, 4
    add t2, t2, t1
    la t1, clip_rect
    ld t3, 0(t2)
    sd t3, 0(t1)
    ld t3, 8(t2)
    sd t3, 8(t1)
    j 481f
480:
    la t1, clip_rect
    sw zero, RECT_X0(t1)
    li t2, SCREEN_W
    sw t2, RECT_X1(t1)
    sw zero, RECT_Y0(t1)
    li t2, SCREEN_H
    sw t2, RECT_Y1(t1)
481:
    call surface_setup
    # facing the camera, its face is the eye's, so it is lit at no
    # angle, else a light behind it would leave it black; the mode
    # after the setup, which clears the flag
    andi t0, s3, ENTITY_CAMERA
    beqz t0, 45f
    la t0, poly
    li t1, 1
    sd t1, POLY_FLAT_LIT(t0)
45:
    li a0, POLY_MASKED
    call poly_mode
    # the quad, from the corner at u 0, v 0 around
    call edges_reset
    call poly_reset
    fsub.d ft0, fs0, fs3
    fsub.d ft0, ft0, fs6
    fcvt.s.d fa0, ft0
    fsub.d ft1, fs1, fs4
    fsub.d ft1, ft1, fs7
    fcvt.s.d fa1, ft1
    fsub.d ft2, fs2, fs5
    fsub.d ft2, ft2, fs8
    fcvt.s.d fa2, ft2
    call poly_point
    fadd.d ft0, fs0, fs3
    fsub.d ft0, ft0, fs6
    fcvt.s.d fa0, ft0
    fadd.d ft1, fs1, fs4
    fsub.d ft1, ft1, fs7
    fcvt.s.d fa1, ft1
    fadd.d ft2, fs2, fs5
    fsub.d ft2, ft2, fs8
    fcvt.s.d fa2, ft2
    call poly_point
    fadd.d ft0, fs0, fs3
    fadd.d ft0, ft0, fs6
    fcvt.s.d fa0, ft0
    fadd.d ft1, fs1, fs4
    fadd.d ft1, ft1, fs7
    fcvt.s.d fa1, ft1
    fadd.d ft2, fs2, fs5
    fadd.d ft2, ft2, fs8
    fcvt.s.d fa2, ft2
    call poly_point
    fsub.d ft0, fs0, fs3
    fadd.d ft0, ft0, fs6
    fcvt.s.d fa0, ft0
    fsub.d ft1, fs1, fs4
    fadd.d ft1, ft1, fs7
    fcvt.s.d fa1, ft1
    fsub.d ft2, fs2, fs5
    fadd.d ft2, ft2, fs8
    fcvt.s.d fa2, ft2
    call poly_point
    call poly_project
    li t0, 3
    bltu a0, t0, 90f
    call verts_bounds
    call lights_cull
    # lit: the brightness at the quad's centre over the polygon's list,
    # at no angle for a face the eye's, as the polygon's one brightness,
    # which the fill takes over the whole quad; its ticks are the
    # frame's light
    la t0, poly
    ld t1, POLY_MODE(t0)
    andi t1, t1, POLY_LIT
    beqz t1, 46f
    rdtime t1
    sd t1, 0(sp)
    fcvt.s.d fa0, fs0
    fcvt.s.d fa1, fs1
    fcvt.s.d fa2, fs2
    flw fa3, POLY_LNX(t0)
    flw fa4, POLY_LNY(t0)
    flw fa5, POLY_LNZ(t0)
    ld t6, POLY_FLAT_LIT(t0)
    addi t2, t0, POLY_LIGHTS
    call point_light
    la t1, poly
    sd a0, POLY_FLAT_BRIGHT(t1)
    rdtime t0
    ld t1, 0(sp)
    sub t0, t0, t1
    la t1, stats
    ld t2, STAT_LIGHT_TICKS(t1)
    add t2, t2, t0
    sd t2, STAT_LIGHT_TICKS(t1)
46:
    call poly_fill
    la t0, stats
    ld t1, STAT_SPRITES(t0)
    addi t1, t1, 1
    sd t1, STAT_SPRITES(t0)
90:
    ld ra, 120(sp)
    ld s2, 112(sp)
    ld s3, 104(sp)
    fld fs0, 96(sp)
    fld fs1, 88(sp)
    fld fs2, 80(sp)
    fld fs3, 72(sp)
    fld fs4, 64(sp)
    fld fs5, 56(sp)
    fld fs6, 48(sp)
    fld fs7, 40(sp)
    fld fs8, 32(sp)
    fld fs9, 24(sp)
    fld fs10, 16(sp)
    fld fs11, 8(sp)
    addi sp, sp, 128
    ret

# Whether a standing sprite's quad is proven within a sector: its pulled
# centre inside the sector in the plan, its level segment crossing no
# wall of the sector's loops, a touch or a collinear overlap counting as
# a crossing, and its bottom and top within the floor and the ceiling at
# both ends of the segment, a millimetre's slack throughout; anything
# short of that is not proven
# a0 int The sector
# fs0 f64 The pulled centre's x; fs1 y; fs2 z
# fs3 f64 The pulled half width's x; fs4 y, level
# fs8 f64 The pulled half height's z, the quad from the centre less it to the centre plus it
# returns
#   a0 1 proven within, else 0
sprite_within:
    addi sp, sp, -112
    sd ra, 104(sp)
    sd s4, 96(sp)
    sd s5, 88(sp)
    sd s6, 80(sp)
    sd s7, 72(sp)
    sd s8, 64(sp)
    fsd fs9, 56(sp)
    fsd fs10, 48(sp)
    fsd fs11, 40(sp)
    mv s4, a0
    # the centre inside
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call sector_holds_plan
    beqz a0, 8f
    # the segment's ends a and b, the centre less and plus the half
    # width, and its run d, twice the half width
    fsub.d ft0, fs0, fs3
    fsd ft0, 0(sp)                  # ax
    fsub.d ft0, fs1, fs4
    fsd ft0, 8(sp)                  # ay
    fadd.d ft0, fs0, fs3
    fsd ft0, 16(sp)                 # bx
    fadd.d ft0, fs1, fs4
    fsd ft0, 24(sp)                 # by
    fadd.d fs9, fs3, fs3            # dx
    fadd.d fs10, fs4, fs4           # dy
    mv a0, s4
    call sector_at
    lwu s5, SECTOR_FIRST_LOOP(a0)
    lwu s6, SECTOR_LOOP_COUNT(a0)
    add s6, s6, s5                  # past the last loop
1:
    bgeu s5, s6, 5f
    mv a0, s5
    call loop_at
    lwu s7, LOOP_FIRST_WALL(a0)
    lwu s8, LOOP_WALL_COUNT(a0)
    add s8, s8, s7                  # past the last wall
2:
    bgeu s7, s8, 4f
    mv a0, s7
    call wall_at
    sd a0, 32(sp)                   # the wall
    lwu a0, WALL_A(a0)
    call vertex_at
    flw ft0, VERTEX_X(a0)
    fcvt.d.s ft8, ft0               # p, the wall's start
    flw ft0, VERTEX_Y(a0)
    fcvt.d.s ft9, ft0
    ld t0, 32(sp)
    lwu a0, WALL_B(t0)
    call vertex_at
    flw ft0, VERTEX_X(a0)
    fcvt.d.s ft10, ft0              # q, its end
    flw ft0, VERTEX_Y(a0)
    fcvt.d.s ft11, ft0
    fsub.d ft4, ft10, ft8           # e, the wall's run
    fsub.d ft5, ft11, ft9
    fld ft6, 0(sp)
    fld ft7, 8(sp)
    fsub.d ft0, ft8, ft6            # p - a
    fsub.d ft1, ft9, ft7
    fmul.d ft2, fs9, ft5
    fnmsub.d ft2, fs10, ft4, ft2    # cross(d, e)
    fabs.d ft3, ft2
    la t0, k_within_den_d
    fld ft10, 0(t0)
    flt.d t1, ft3, ft10
    beqz t1, 3f
    # parallel: a crossing when the segment's start lies within the
    # slack of the wall's line, the cross with the run over its length
    fmul.d ft3, ft0, ft5
    fnmsub.d ft3, ft1, ft4, ft3     # cross(p - a, e)
    fmul.d ft3, ft3, ft3
    fmul.d ft10, ft4, ft4
    fmadd.d ft10, ft5, ft5, ft10    # the run squared
    la t0, k_within_slack_sq_d
    fld ft11, 0(t0)
    fmul.d ft10, ft10, ft11
    fle.d t1, ft3, ft10
    bnez t1, 8f                     # on the line: not proven
    j 7f
3:
    # the crossing's share along the segment and along the wall, each
    # within the unit range widened by the slack
    fmul.d ft3, ft0, ft5
    fnmsub.d ft3, ft1, ft4, ft3     # cross(p - a, e)
    fdiv.d ft3, ft3, ft2            # t, along the segment
    fmul.d ft10, ft0, fs10
    fnmsub.d ft10, ft1, fs9, ft10   # cross(p - a, d)
    fdiv.d ft10, ft10, ft2          # u, along the wall
    la t0, k_within_low_d
    fld ft11, 0(t0)
    flt.d t1, ft3, ft11
    bnez t1, 7f
    flt.d t1, ft10, ft11
    bnez t1, 7f
    la t0, k_within_high_d
    fld ft11, 0(t0)
    flt.d t1, ft11, ft3
    bnez t1, 7f
    flt.d t1, ft11, ft10
    bnez t1, 7f
    j 8f                            # crossed: not proven
7:
    addi s7, s7, 1
    j 2b
4:
    addi s5, s5, 1
    j 1b
5:
    # the quad's bottom and top within the planes at both ends
    fabs.d ft11, fs8
    fsub.d fs11, fs2, ft11          # the bottom
    fadd.d fs10, fs2, ft11          # the top
    mv a0, s4
    li a1, 0
    fld fa0, 0(sp)
    fld fa1, 8(sp)
    call plane_height               # the floor at a
    la t0, k_thousandth_d
    fld ft0, 0(t0)
    fsub.d fa0, fa0, ft0
    flt.d t1, fs11, fa0
    bnez t1, 8f                     # the bottom under the floor
    mv a0, s4
    li a1, 1
    fld fa0, 0(sp)
    fld fa1, 8(sp)
    call plane_height               # the ceiling at a
    la t0, k_thousandth_d
    fld ft0, 0(t0)
    fadd.d fa0, fa0, ft0
    flt.d t1, fa0, fs10
    bnez t1, 8f                     # the top over the ceiling
    mv a0, s4
    li a1, 0
    fld fa0, 16(sp)
    fld fa1, 24(sp)
    call plane_height               # the floor at b
    la t0, k_thousandth_d
    fld ft0, 0(t0)
    fsub.d fa0, fa0, ft0
    flt.d t1, fs11, fa0
    bnez t1, 8f
    mv a0, s4
    li a1, 1
    fld fa0, 16(sp)
    fld fa1, 24(sp)
    call plane_height               # the ceiling at b
    la t0, k_thousandth_d
    fld ft0, 0(t0)
    fadd.d fa0, fa0, ft0
    flt.d t1, fa0, fs10
    bnez t1, 8f
    li a0, 1
    j 9f
8:
    li a0, 0
9:
    ld ra, 104(sp)
    ld s4, 96(sp)
    ld s5, 88(sp)
    ld s6, 80(sp)
    ld s7, 72(sp)
    ld s8, 64(sp)
    fld fs9, 56(sp)
    fld fs10, 48(sp)
    fld fs11, 40(sp)
    addi sp, sp, 112
    ret

.section .rodata
.balign 8
# The containment's slacks: a cross product under which a wall runs
# parallel to the quad's segment, a millimetre squared for a start on
# such a wall's line, and the crossing's shares widened by a thousandth
# past the unit range either way
k_within_den_d:
    .double 0.000000000001
k_within_slack_sq_d:
    .double 0.000001
k_within_low_d:
    .double -0.001
k_within_high_d:
    .double 1.001

.section .bss
.balign 8
# The surface index the next sprite draws as, a map sprite's by its
# entity or an actor's by its index, named by the caller
sprite_surface:
    .skip 8
