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
# two-sided.
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
    li a0, POLY_MASKED
    call poly_mode
    la t0, poly
    lw t1, ENTITY_SECTOR(s2)
    sw t1, POLY_SECTOR(t0)
    call surface_setup
    # facing the camera, its face is the eye's, so it is lit at no
    # angle, else a light behind it would leave it black
    andi t0, s3, ENTITY_CAMERA
    beqz t0, 45f
    la t0, poly
    li t1, 1
    sd t1, POLY_FLAT_LIT(t0)
45:
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
