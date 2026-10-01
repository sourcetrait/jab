# The map's lights, without shadows: the brightness at a world point of a
# surface, the ambient plus each light of a list by cosine and falloff; a
# lumel map baked over every textured surface at load, which the lit spans
# read, and a sprite's one lumel taken at its centre a frame.

.section .rodata
.balign 8
k_lumel_d:
    .double 0.5
k_two32_d:
    .double 4294967296.0
.balign 4
k_light_ambient:
    .float 0.15
k_light_none:
    .float -2.0
k_light_minus_one:
    .float -1.0
k_depth_scale:
    .float 67108864.0
msg_lumels:
    .asciz "fps: lumel maps "
word_baked_in:
    .asciz " baked in "
word_lumels:
    .asciz " lumels, "
word_unmapped:
    .asciz " unmapped"

.section .text

# The light entities into the light table, then each sector's list of light
# indices from the file's.
lights_gather:
    addi sp, sp, -80
    sd ra, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    fsd fs0, 24(sp)
    fsd fs1, 16(sp)
    la t0, light_count
    sw zero, 0(t0)
    section_count KIND_ENTITIES, s2
    section_at KIND_ENTITIES, s3    # the entity
    li s4, 0                        # its index
1:
    bgeu s4, s2, 6f
    li t0, -1
    la t1, entity_light
    slli t2, s4, 2
    add t1, t1, t2
    sw t0, 0(t1)
    lwu t0, ENTITY_CLASS(s3)
    li t1, CLASS_LIGHT
    bne t0, t1, 5f
    la t0, light_count
    lwu t1, 0(t0)
    li t2, MAX_LIGHTS
    bgeu t1, t2, 5f
    li t2, LIGHT_SIZE
    mul t2, t1, t2
    la s5, lights
    add s5, s5, t2                  # the light
    la t2, entity_light
    slli t3, s4, 2
    add t2, t2, t3
    sw t1, 0(t2)
    addi t1, t1, 1
    sw t1, 0(t0)
    lw t2, ENTITY_X(s3)
    sw t2, LIGHT_X(s5)
    lw t2, ENTITY_Y(s3)
    sw t2, LIGHT_Y(s5)
    lw t2, ENTITY_Z(s3)
    sw t2, LIGHT_Z(s5)
    lw t2, ENTITY_R(s3)
    sw t2, LIGHT_R(s5)
    lw t2, ENTITY_G(s3)
    sw t2, LIGHT_G(s5)
    lw t2, ENTITY_B(s3)
    sw t2, LIGHT_B(s5)
    flw ft0, ENTITY_RADIUS(s3)
    fmul.s ft1, ft0, ft0
    fsw ft1, LIGHT_RADIUS2(s5)
    la t0, k_one
    flw ft1, 0(t0)
    fdiv.s ft1, ft1, ft0
    fsw ft1, LIGHT_OVER_RADIUS(s5)
    # the axis from the yaw and pitch, and the cosine of the spread; a
    # spread of none makes a point light
    flw fa0, ENTITY_YAW(s3)
    jab.f32.rad fa0, fa0
    jab.f32.sin fs0, fa0            # sin yaw
    jab.f32.cos fs1, fa0            # cos yaw
    flw fa0, ENTITY_PITCH(s3)
    jab.f32.rad fa0, fa0
    jab.f32.sin fa1, fa0
    fsw fa1, (LIGHT_AXIS + 8)(s5)   # sin pitch
    jab.f32.cos fa1, fa0            # cos pitch
    fmul.s ft8, fs1, fa1
    fsw ft8, (LIGHT_AXIS + 0)(s5)   # cos pitch cos yaw
    fmul.s ft8, fs0, fa1
    fsw ft8, (LIGHT_AXIS + 4)(s5)   # cos pitch sin yaw
    flw fa0, ENTITY_SPREAD(s3)
    la t0, k_zero
    flw ft1, 0(t0)
    flt.s t1, ft1, fa0
    bnez t1, 2f
    la t0, k_light_none
    flw ft1, 0(t0)
    fsw ft1, LIGHT_COS(s5)
    j 5f
2:
    jab.f32.rad fa0, fa0
    jab.f32.cos fa1, fa0
    fsw fa1, LIGHT_COS(s5)
5:
    addi s3, s3, ENTITY_SIZE
    addi s4, s4, 1
    j 1b
6:
    # each sector's list: the file's light entities as light indices
    section_count KIND_SECTORS, s2
    li s3, 0
7:
    bgeu s3, s2, 9f
    mv a0, s3
    call sector_at
    mv s4, a0
    la s5, sector_lights
    slli t0, s3, 5
    add s5, s5, t0                  # the list
    sb zero, 0(s5)
    lwu t1, SECTOR_FIRST_LIGHT(s4)
    lwu s6, SECTOR_LIGHT_COUNT(s4)  # the entries left
    section_at KIND_SECTOR_LIGHTS, t2
    slli t1, t1, 2
    add t2, t2, t1                  # the entry
8:
    beqz s6, 85f
    lbu t3, 0(s5)                   # the list's count
    li t4, SECTOR_LIGHTS_MAX
    bgeu t3, t4, 85f
    lwu t5, 0(t2)                   # the light entity
    la t6, entity_light
    slli t5, t5, 2
    add t6, t6, t5
    lw t5, 0(t6)                    # its light
    bltz t5, 84f
    addi t3, t3, 1
    sb t3, 0(s5)
    add t6, s5, t3
    sb t5, 0(t6)
84:
    addi t2, t2, SECTOR_LIGHT_SIZE
    addi s6, s6, -1
    j 8b
85:
    addi s3, s3, 1
    j 7b
9:
    ld ra, 72(sp)
    ld s2, 64(sp)
    ld s3, 56(sp)
    ld s4, 48(sp)
    ld s5, 40(sp)
    ld s6, 32(sp)
    fld fs0, 24(sp)
    fld fs1, 16(sp)
    addi sp, sp, 80
    ret

# The world box of the polygon in hand's points
# returns Clobbers t0, t1, ft0
#   fa0 f32 min x
#   fa1 f32 max x
#   fa2 f32 min y
#   fa3 f32 max y
#   fa4 f32 min z
#   fa5 f32 max z
verts_bounds:
    la t0, verts
    la t1, vert_count
    ld t1, 0(t1)
    flw fa0, 0(t0)
    fmv.s fa1, fa0
    flw fa2, 4(t0)
    fmv.s fa3, fa2
    flw fa4, 8(t0)
    fmv.s fa5, fa4
1:
    beqz t1, 9f
    flw ft0, 0(t0)
    fmin.s fa0, fa0, ft0
    fmax.s fa1, fa1, ft0
    flw ft0, 4(t0)
    fmin.s fa2, fa2, ft0
    fmax.s fa3, fa3, ft0
    flw ft0, 8(t0)
    fmin.s fa4, fa4, ft0
    fmax.s fa5, fa5, ft0
    addi t0, t0, VERT_SIZE
    addi t1, t1, -1
    j 1b
9:
    ret

# The world box of a sector's plane: its bounds in the plan and the plane's
# height at their corners
# a0 address The sector
# a1 address Its plane, a, b, c
# returns Clobbers ft0 to ft6
#   fa0 f32 min x
#   fa1 f32 max x
#   fa2 f32 min y
#   fa3 f32 max y
#   fa4 f32 min z
#   fa5 f32 max z
plane_box:
    flw fa0, SECTOR_MIN_X(a0)
    flw fa1, SECTOR_MAX_X(a0)
    flw fa2, SECTOR_MIN_Y(a0)
    flw fa3, SECTOR_MAX_Y(a0)
    flw ft0, PLANE_A(a1)
    flw ft1, PLANE_B(a1)
    flw ft2, PLANE_C(a1)
    fmul.s ft3, ft0, fa0
    fmadd.s ft3, ft1, fa2, ft3
    fadd.s ft3, ft3, ft2
    fmul.s ft4, ft0, fa1
    fmadd.s ft4, ft1, fa2, ft4
    fadd.s ft4, ft4, ft2
    fmul.s ft5, ft0, fa0
    fmadd.s ft5, ft1, fa3, ft5
    fadd.s ft5, ft5, ft2
    fmul.s ft6, ft0, fa1
    fmadd.s ft6, ft1, fa3, ft6
    fadd.s ft6, ft6, ft2
    fmin.s fa4, ft3, ft4
    fmin.s fa4, fa4, ft5
    fmin.s fa4, fa4, ft6
    fmax.s fa5, ft3, ft4
    fmax.s fa5, fa5, ft5
    fmax.s fa5, fa5, ft6
    ret

# The surface's sector's lights culled into the polygon's own list: a light
# stays when its sphere meets the box and, unless the surface is lit at no
# angle, it lies ahead of the plane's normal facing the camera
# fa0 f32 min x
# fa1 f32 max x
# fa2 f32 min y
# fa3 f32 max y
# fa4 f32 min z
# fa5 f32 max z
# returns Clobbers t0 to t6, a5, ft0 to ft7
lights_cull:
    la t0, poly
    lw t1, POLY_SECTOR(t0)
    la t2, sector_lights
    slli t1, t1, 5
    add t2, t2, t1                  # the sector's list
    lbu t3, 0(t2)                   # its count
    addi t2, t2, 1
    addi t5, t0, (POLY_LIGHTS + 1)  # the polygon's next index
    ld a5, POLY_FLAT_LIT(t0)
    fmv.w.x ft3, zero
1:
    beqz t3, 9f
    lbu t6, 0(t2)
    li t1, LIGHT_SIZE
    mul t1, t6, t1
    la t4, lights
    add t4, t4, t1                  # the light
    # the box's gap to the light on each axis, none inside, squared
    flw ft0, LIGHT_X(t4)
    fsub.s ft1, fa0, ft0
    fsub.s ft2, ft0, fa1
    fmax.s ft1, ft1, ft2
    fmax.s ft1, ft1, ft3
    flw ft0, LIGHT_Y(t4)
    fsub.s ft2, fa2, ft0
    fsub.s ft4, ft0, fa3
    fmax.s ft2, ft2, ft4
    fmax.s ft2, ft2, ft3
    flw ft0, LIGHT_Z(t4)
    fsub.s ft4, fa4, ft0
    fsub.s ft5, ft0, fa5
    fmax.s ft4, ft4, ft5
    fmax.s ft4, ft4, ft3
    jab.f32.vec3.reg.sqrlen ft6, ft1, ft2, ft4
    flw ft7, LIGHT_RADIUS2(t4)
    flt.s t1, ft7, ft6
    bnez t1, 7f                     # out of reach
    bnez a5, 6f                     # lit at no angle: kept
    # ahead of the plane: n . (light - q) > 0
    la t1, plane
    flw ft0, LIGHT_X(t4)
    flw ft1, (PLANE_Q + 0)(t1)
    fsub.s ft0, ft0, ft1
    flw ft1, LIGHT_Y(t4)
    flw ft2, (PLANE_Q + 4)(t1)
    fsub.s ft1, ft1, ft2
    flw ft2, LIGHT_Z(t4)
    flw ft4, (PLANE_Q + 8)(t1)
    fsub.s ft2, ft2, ft4
    la t1, poly
    flw ft4, POLY_LNX(t1)
    flw ft5, POLY_LNY(t1)
    flw ft6, POLY_LNZ(t1)
    jab.f32.vec3.reg.dot ft7, ft0, ft1, ft2, ft4, ft5, ft6
    fle.s t1, ft7, ft3
    bnez t1, 7f                     # behind the surface
6:
    sb t6, 0(t5)
    addi t5, t5, 1
7:
    addi t2, t2, 1
    addi t3, t3, -1
    j 1b
9:
    la t0, poly
    addi t1, t0, (POLY_LIGHTS + 1)
    sub t1, t5, t1
    sb t1, POLY_LIGHTS(t0)          # the count
    ret

# The brightness at a pixel of the surface in hand over the polygon's list,
# for a dynamic light: the world point down the pixel's ray, then point_light
# under the surface's normal facing the camera.
# a0 int The pixel.
# a1 int The row.
# a2 int 1/z there, 6.26.
# returns A leaf; clobbers t0 to t5 and every temporary float register.
#   a0 The packed brightness.
.balign CODE_PAGE
span_light:
    li t0, IZ_MIN
    bge a2, t0, 1f
    mv a2, t0
1:
    fcvt.s.l ft0, a2
    la t0, k_depth_scale
    flw ft1, 0(t0)
    fdiv.s ft0, ft1, ft0            # z
    la t0, k_hz
    flw ft1, 0(t0)
    fdiv.s ft0, ft0, ft1            # z over hz
    fcvt.s.w ft1, a0
    la t0, k_half
    flw ft2, 0(t0)
    fadd.s ft1, ft1, ft2
    la t0, k_hx
    flw ft3, 0(t0)
    fsub.s ft1, ft1, ft3            # x + 1/2 - hx
    fcvt.s.w ft2, a1
    la t0, k_half
    flw ft3, 0(t0)
    fadd.s ft2, ft2, ft3
    la t0, k_hy
    flw ft3, 0(t0)
    fsub.s ft2, ft2, ft3
    fneg.s ft2, ft2                 # hy - y - 1/2: the ray's share of up
    la t0, k_hz
    flw ft3, 0(t0)                  # hz
    # the point: the camera plus (right sx + up sy + forward hz) z/hz
    la t0, camera
    flw ft4, (CAM_RIGHT + 0)(t0)
    fmul.s ft4, ft4, ft1
    flw ft5, (CAM_UP + 0)(t0)
    fmadd.s ft4, ft5, ft2, ft4
    flw ft5, (CAM_FORWARD + 0)(t0)
    fmadd.s ft4, ft5, ft3, ft4
    flw ft5, CAM_X(t0)
    fmadd.s fa0, ft4, ft0, ft5      # the point's x
    flw ft4, (CAM_RIGHT + 4)(t0)
    fmul.s ft4, ft4, ft1
    flw ft5, (CAM_UP + 4)(t0)
    fmadd.s ft4, ft5, ft2, ft4
    flw ft5, (CAM_FORWARD + 4)(t0)
    fmadd.s ft4, ft5, ft3, ft4
    flw ft5, CAM_Y(t0)
    fmadd.s fa1, ft4, ft0, ft5      # y
    flw ft4, (CAM_RIGHT + 8)(t0)
    fmul.s ft4, ft4, ft1
    flw ft5, (CAM_UP + 8)(t0)
    fmadd.s ft4, ft5, ft2, ft4
    flw ft5, (CAM_FORWARD + 8)(t0)
    fmadd.s ft4, ft5, ft3, ft4
    flw ft5, CAM_Z(t0)
    fmadd.s fa2, ft4, ft0, ft5      # z
    la t0, poly
    flw fa3, POLY_LNX(t0)
    flw fa4, POLY_LNY(t0)
    flw fa5, POLY_LNZ(t0)
    ld t6, POLY_FLAT_LIT(t0)
    addi t2, t0, POLY_LIGHTS
    # falls into point_light

# The brightness at a world point of a surface: the three channels in 16.16
# packed CHANNEL_BITS apart, the ambient plus each light of a list in reach,
# in single precision throughout.
# fa0 f32 The point's x; fa1 y; fa2 z.
# fa3 f32 The unit normal's x; fa4 y; fa5 z.
# t6 int 1 lit at no angle, every light in reach by its falloff alone.
# t2 address The list, a count byte then that many light indices.
# returns A leaf; clobbers t0 to t5 and every temporary float register.
#   a0 The packed brightness.
point_light:
    la t1, k_light_ambient
    flw fa6, 0(t1)                  # red
    fmv.s fa7, fa6                  # green
    fmv.s ft11, fa6                 # blue
    la t1, k_one
    flw ft10, 0(t1)                 # one
    lbu t3, 0(t2)                   # the list's count
    addi t2, t2, 1
2:
    beqz t3, 8f
    lbu t4, 0(t2)
    li t5, LIGHT_SIZE
    mul t4, t4, t5
    la t5, lights
    add t4, t4, t5                  # the light
    flw ft0, LIGHT_X(t4)
    fsub.s ft0, ft0, fa0            # d, from the point to the light
    flw ft1, LIGHT_Y(t4)
    fsub.s ft1, ft1, fa1
    flw ft2, LIGHT_Z(t4)
    fsub.s ft2, ft2, fa2
    jab.f32.vec3.reg.sqrlen ft3, ft0, ft1, ft2  # the distance squared
    flw ft4, LIGHT_RADIUS2(t4)
    flt.s t5, ft4, ft3
    bnez t5, 7f                     # out of reach
    fsqrt.s ft6, ft3                # the distance
    beqz t6, 3f
    fmv.s ft5, ft10                 # lit at no angle: the cosine one
    j 4f
3:
    jab.f32.vec3.reg.dot ft5, ft0, ft1, ft2, fa3, fa4, fa5  # n . d
    fmv.w.x ft7, zero
    fle.s t5, ft5, ft7
    bnez t5, 7f                     # behind the surface
    fdiv.s ft5, ft5, ft6            # the cosine at the surface
4:
    # the falloff: one at the light, straight to nothing at the radius
    flw ft7, LIGHT_OVER_RADIUS(t4)
    fmul.s ft7, ft7, ft6            # the distance over the radius
    fsub.s ft7, ft10, ft7
    fmul.s ft5, ft5, ft7            # the cosine times the falloff
    flw ft7, LIGHT_COS(t4)
    la t5, k_light_minus_one
    flw ft9, 0(t5)
    flt.s t5, ft7, ft9
    bnez t5, 6f                     # a point light
    # the spotlight: the cosine from the light's axis to the point,
    # from the spread's edge scaled to one on the axis
    flw ft8, (LIGHT_AXIS + 0)(t4)
    flw ft9, (LIGHT_AXIS + 4)(t4)
    flw ft4, (LIGHT_AXIS + 8)(t4)
    jab.f32.vec3.reg.dot ft3, ft0, ft1, ft2, ft8, ft9, ft4  # d . axis
    fneg.s ft3, ft3
    fdiv.s ft3, ft3, ft6            # the cosine from the axis
    fsub.s ft3, ft3, ft7
    fsub.s ft9, ft10, ft7           # 1 - cos spread
    fdiv.s ft3, ft3, ft9
    fmv.w.x ft9, zero
    fle.s t5, ft3, ft9
    bnez t5, 7f                     # outside the cone
    fmul.s ft5, ft5, ft3
6:
    flw ft9, LIGHT_R(t4)
    fmadd.s fa6, ft9, ft5, fa6
    flw ft9, LIGHT_G(t4)
    fmadd.s fa7, ft9, ft5, fa7
    flw ft9, LIGHT_B(t4)
    fmadd.s ft11, ft9, ft5, ft11
7:
    addi t2, t2, 1
    addi t3, t3, -1
    j 2b
8:
    # each channel clamped to one, in 16.16, packed
    la t0, k_sixty_four_k
    flw ft1, 0(t0)
    fmin.s fa6, fa6, ft10
    fmul.s fa6, fa6, ft1
    fcvt.l.s a0, fa6, rne
    fmin.s fa7, fa7, ft10
    fmul.s fa7, fa7, ft1
    fcvt.l.s t1, fa7, rne
    slli t1, t1, CHANNEL_BITS
    or a0, a0, t1
    fmin.s ft11, ft11, ft10
    fmul.s ft11, ft11, ft1
    fcvt.l.s t1, ft11, rne
    slli t1, t1, (2 * CHANNEL_BITS)
    or a0, a0, t1
    ret

# A brightness word's channels as a lumel's: each lane's 16.16 to 256ths.
# a0 int The brightness, packed.
# returns Clobbers t0, t1.
#   a0 The lumel.
lumel_pack:
    slli t0, a0, (64 - CHANNEL_BITS)
    srli t0, t0, (64 - CHANNEL_BITS + 8)
    slli t1, a0, (64 - 2 * CHANNEL_BITS)
    srli t1, t1, (64 - CHANNEL_BITS + 8)
    slli t1, t1, CHANNEL_BITS
    or t0, t0, t1
    slli t1, a0, (64 - 3 * CHANNEL_BITS)
    srli t1, t1, (64 - CHANNEL_BITS + 8)
    slli t1, t1, (2 * CHANNEL_BITS)
    or a0, t0, t1
    ret

# Every textured surface's lumel map baked, the sector planes then the
# walls, each over the sector's lights culled to the surface; the sprite's
# own map of four lumels alike set up; a line on the UART. A map with no
# lights bakes none and draws unlit.
lumaps_bake:
    addi sp, sp, -192
    sd ra, 184(sp)
    sd s2, 176(sp)
    sd s3, 168(sp)
    sd s4, 160(sp)
    sd s5, 152(sp)
    sd s6, 144(sp)
    sd s7, 136(sp)
    sd s8, 128(sp)
    sd s9, 120(sp)
    fsd fs0, 112(sp)
    fsd fs1, 104(sp)
    fsd fs2, 96(sp)
    fsd fs3, 88(sp)
    fsd fs4, 80(sp)
    fsd fs5, 72(sp)
    fsd fs6, 64(sp)
    fsd fs7, 56(sp)
    fsd fs8, 48(sp)
    fsd fs9, 40(sp)
    rdtime s9
    la t0, lumel_cursor
    la t1, lumel_arena
    sd t1, 0(t0)
    la t0, lumap_count
    sd zero, 0(t0)
    la t0, lumel_count
    sd zero, 0(t0)
    la t0, lumap_missing
    sd zero, 0(t0)
    # every map none
    la t0, lumaps
    li t1, (LUMAP_COUNT * LUMAP_SIZE)
    add t1, t1, t0
1:
    sd zero, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 1b
    # the sprite's map: two lumels a side, every sample the first
    la t0, sprite_lumap
    la t1, sprite_cells
    sd t1, LUMAP_BASE(t0)
    li t1, 2
    sd t1, LUMAP_W(t0)
    sd t1, LUMAP_H(t0)
    sd zero, LUMAP_RU(t0)
    sd zero, LUMAP_OU(t0)
    sd zero, LUMAP_RV(t0)
    sd zero, LUMAP_OV(t0)
    li t1, 0xffff
    sd t1, LUMAP_UMAX(t0)
    sd t1, LUMAP_VMAX(t0)
    la t0, light_count
    lwu t0, 0(t0)
    beqz t0, 90f
    # the planes
    section_count KIND_SECTORS, s2
    li s3, 0                        # the sector
10:
    bgeu s3, s2, 30f
    li s4, 0                        # 0 the floor, 1 the ceiling
11:
    li t0, 2
    bge s4, t0, 19f
    mv a0, s3
    call sector_at
    mv s5, a0
    li t0, SURFACE_SIZE
    mul t0, s4, t0
    addi s6, s5, SECTOR_FLOOR_SURFACE
    add s6, s6, t0                  # the surface
    slli t0, s3, 1
    add t0, t0, s4
    li t1, LUMAP_SIZE
    mul t0, t0, t1
    la s7, lumaps
    add s7, s7, t0                  # its map
    lwu t0, SURFACE_FLAGS(s6)
    andi t0, t0, SURFACE_SKY
    bnez t0, 18f
    lw a0, SURFACE_MATERIAL(s6)
    call material_bind
    beqz a0, 18f
    li t0, SECTOR_CEILING
    mul t0, s4, t0
    add s8, s5, t0                  # the plane's a, b, c
    # the grid: from the bounds' corner at the plane's height there, a
    # lumel along x with the plane's rise, the same along y
    flw ft0, SECTOR_MIN_X(s5)
    fcvt.d.s fs0, ft0
    flw ft0, SECTOR_MIN_Y(s5)
    fcvt.d.s fs1, ft0
    flw ft0, PLANE_A(s8)
    fcvt.d.s fs2, ft0
    flw ft0, PLANE_B(s8)
    fcvt.d.s fs3, ft0
    flw ft0, PLANE_C(s8)
    fcvt.d.s fs4, ft0
    la t0, k_lumel_d
    fld fs5, 0(t0)
    la t1, bake_grid
    fsd fs0, (GRID_O + 0)(t1)
    fsd fs1, (GRID_O + 8)(t1)
    fmul.d ft0, fs2, fs0
    fmadd.d ft0, fs3, fs1, ft0
    fadd.d ft0, ft0, fs4
    fsd ft0, (GRID_O + 16)(t1)
    fsd fs5, (GRID_U + 0)(t1)
    sd zero, (GRID_U + 8)(t1)
    fmul.d ft0, fs2, fs5
    fsd ft0, (GRID_U + 16)(t1)
    sd zero, (GRID_V + 0)(t1)
    fsd fs5, (GRID_V + 8)(t1)
    fmul.d ft0, fs3, fs5
    fsd ft0, (GRID_V + 16)(t1)
    # the unit normal into the room: (-a, -b, 1) for the floor, its
    # negative for the ceiling
    fneg.d ft6, fs2
    fneg.d ft7, fs3
    la t0, k_one_d
    fld ft8, 0(t0)
    beqz s4, 12f
    fneg.d ft6, ft6
    fneg.d ft7, ft7
    fneg.d ft8, ft8
12:
    jab.f64.vec3.reg.norm ft6, ft7, ft8
    la t1, bake_grid
    fcvt.s.d ft6, ft6
    fsw ft6, (GRID_N + 0)(t1)
    fcvt.s.d ft7, ft7
    fsw ft7, (GRID_N + 4)(t1)
    fcvt.s.d ft8, ft8
    fsw ft8, (GRID_N + 8)(t1)
    # the columns and rows: the bounds in lumels
    flw ft0, SECTOR_MAX_X(s5)
    fcvt.d.s ft0, ft0
    fsub.d ft0, ft0, fs0
    flw ft1, SECTOR_MAX_Y(s5)
    fcvt.d.s ft1, ft1
    fsub.d ft1, ft1, fs1
    mv a0, s7
    call map_extent
    # the texel coordinates to lumel coordinates, from the bounds' corner
    mv a0, s6
    mv a1, s7
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call map_params
    beqz a0, 17f
    # the lights culled to the plane: its point and normal, its box
    la t0, plane
    fcvt.s.d ft0, fs0
    fsw ft0, (PLANE_Q + 0)(t0)
    fcvt.s.d ft0, fs1
    fsw ft0, (PLANE_Q + 4)(t0)
    la t1, bake_grid
    fld ft0, (GRID_O + 16)(t1)
    fcvt.s.d ft0, ft0
    fsw ft0, (PLANE_Q + 8)(t0)
    la t0, poly
    flw ft0, (GRID_N + 0)(t1)
    fsw ft0, POLY_LNX(t0)
    flw ft0, (GRID_N + 4)(t1)
    fsw ft0, POLY_LNY(t0)
    flw ft0, (GRID_N + 8)(t1)
    fsw ft0, POLY_LNZ(t0)
    sw s3, POLY_SECTOR(t0)
    sd zero, POLY_FLAT_LIT(t0)
    mv a0, s5
    mv a1, s8
    call plane_box
    call lights_cull
    mv a0, s7
    call lumap_fill
    j 18f
17:
    la t0, lumap_missing
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
18:
    addi s4, s4, 1
    j 11b
19:
    addi s3, s3, 1
    j 10b
30:
    # the walls
    section_count KIND_WALLS, s2
    li s3, 0                        # the wall
31:
    bgeu s3, s2, 50f
    mv a0, s3
    call wall_at
    mv s5, a0
    li t0, LUMAP_PLANES
    add t0, t0, s3
    li t1, LUMAP_SIZE
    mul t0, t0, t1
    la s7, lumaps
    add s7, s7, t0                  # its map
    lwu t0, (WALL_SURFACE + SURFACE_FLAGS)(s5)
    andi t0, t0, SURFACE_SKY
    bnez t0, 48f
    lw a0, (WALL_SURFACE + SURFACE_MATERIAL)(s5)
    call material_bind
    beqz a0, 48f
    lwu s4, WALL_SECTOR(s5)
    lwu a0, WALL_A(s5)
    call vertex_at
    flw ft0, VERTEX_X(a0)
    fcvt.d.s fs0, ft0
    flw ft0, VERTEX_Y(a0)
    fcvt.d.s fs1, ft0               # a
    lwu a0, WALL_B(s5)
    call vertex_at
    flw ft0, VERTEX_X(a0)
    fcvt.d.s fs2, ft0
    flw ft0, VERTEX_Y(a0)
    fcvt.d.s fs3, ft0               # b
    # the wall's extent: from the higher ceiling end down to the lower
    # floor end
    mv a0, s4
    li a1, 1
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs4, fa0
    mv a0, s4
    li a1, 1
    fmv.d fa0, fs2
    fmv.d fa1, fs3
    call plane_height
    fmax.d fs4, fs4, fa0            # the top
    mv a0, s4
    li a1, 0
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs5, fa0
    mv a0, s4
    li a1, 0
    fmv.d fa0, fs2
    fmv.d fa1, fs3
    call plane_height
    fmin.d fs5, fs5, fa0            # the bottom
    # the run, unit, and its length; a wall of no length has no map
    fsub.d fs6, fs2, fs0
    fsub.d fs7, fs3, fs1
    jab.f64.vec2.reg.len fs8, fs6, fs7
    fcvt.d.w ft0, zero
    feq.d t0, fs8, ft0
    bnez t0, 47f
    fdiv.d fs6, fs6, fs8
    fdiv.d fs7, fs7, fs8
    la t0, k_lumel_d
    fld fs9, 0(t0)
    # the grid: from a at the top, a lumel along the wall, a lumel down
    la t1, bake_grid
    fsd fs0, (GRID_O + 0)(t1)
    fsd fs1, (GRID_O + 8)(t1)
    fsd fs4, (GRID_O + 16)(t1)
    fmul.d ft0, fs6, fs9
    fsd ft0, (GRID_U + 0)(t1)
    fmul.d ft0, fs7, fs9
    fsd ft0, (GRID_U + 8)(t1)
    sd zero, (GRID_U + 16)(t1)
    sd zero, (GRID_V + 0)(t1)
    sd zero, (GRID_V + 8)(t1)
    fneg.d ft0, fs9
    fsd ft0, (GRID_V + 16)(t1)
    # the unit normal into the sector, the run turned a quarter left
    fneg.d ft0, fs7
    fcvt.s.d ft0, ft0
    fsw ft0, (GRID_N + 0)(t1)
    fcvt.s.d ft0, fs6
    fsw ft0, (GRID_N + 4)(t1)
    sw zero, (GRID_N + 8)(t1)
    # the columns and rows: the length and the height in lumels
    fmv.d ft0, fs8
    fsub.d ft1, fs4, fs5
    mv a0, s7
    call map_extent
    # the texel coordinates to lumel coordinates: u from a, v from the
    # anchor against the top
    flw ft0, WALL_ANCHOR(s5)
    fcvt.d.s fa1, ft0
    fsub.d fa1, fa1, fs4
    fcvt.d.w fa0, zero
    addi a0, s5, WALL_SURFACE
    mv a1, s7
    call map_params
    beqz a0, 47f
    # the lights culled to the wall: its point and normal, its box
    la t0, plane
    fcvt.s.d ft0, fs0
    fsw ft0, (PLANE_Q + 0)(t0)
    fcvt.s.d ft0, fs1
    fsw ft0, (PLANE_Q + 4)(t0)
    fcvt.s.d ft0, fs4
    fsw ft0, (PLANE_Q + 8)(t0)
    la t1, bake_grid
    la t0, poly
    flw ft0, (GRID_N + 0)(t1)
    fsw ft0, POLY_LNX(t0)
    flw ft0, (GRID_N + 4)(t1)
    fsw ft0, POLY_LNY(t0)
    sw zero, POLY_LNZ(t0)
    sw s4, POLY_SECTOR(t0)
    sd zero, POLY_FLAT_LIT(t0)
    fmin.d ft0, fs0, fs2
    fcvt.s.d fa0, ft0
    fmax.d ft0, fs0, fs2
    fcvt.s.d fa1, ft0
    fmin.d ft0, fs1, fs3
    fcvt.s.d fa2, ft0
    fmax.d ft0, fs1, fs3
    fcvt.s.d fa3, ft0
    fcvt.s.d fa4, fs5
    fcvt.s.d fa5, fs4
    call lights_cull
    mv a0, s7
    call lumap_fill
    j 48f
47:
    la t0, lumap_missing
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
48:
    addi s3, s3, 1
    j 31b
50:
    # the line: the maps baked, the time, the lumels, and the textured
    # surfaces left without a map
    rdtime t0
    sub t0, t0, s9
    li t1, MS_TICKS
    divu s9, t0, t1
    la a0, line
    la a1, msg_lumels
    call append_str
    la t0, lumap_count
    ld a1, 0(t0)
    call append_dec
    la a1, word_baked_in
    call append_str
    mv a1, s9
    call append_dec
    la a1, word_ms
    call append_str
    la t0, lumel_count
    ld a1, 0(t0)
    call append_dec
    la a1, word_lumels
    call append_str
    la t0, lumap_missing
    ld a1, 0(t0)
    call append_dec
    la a1, word_unmapped
    call append_str
    call line_end
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
    fld fs0, 112(sp)
    fld fs1, 104(sp)
    fld fs2, 96(sp)
    fld fs3, 88(sp)
    fld fs4, 80(sp)
    fld fs5, 72(sp)
    fld fs6, 64(sp)
    fld fs7, 56(sp)
    fld fs8, 48(sp)
    fld fs9, 40(sp)
    addi sp, sp, 192
    ret

# A map's columns and rows from its extents, a node past each end and two
# at the least, and the clamps a sample stays within.
# a0 address The record.
# ft0 f64 The extent along u, metres.
# ft1 f64 The extent along v.
# returns Clobbers t0 to t2, ft0 to ft2.
map_extent:
    la t0, k_lumel_d
    fld ft2, 0(t0)
    fdiv.d ft0, ft0, ft2
    fcvt.l.d t0, ft0, rup
    addi t0, t0, 2
    li t2, 2
    bge t0, t2, 1f
    mv t0, t2
1:
    sd t0, LUMAP_W(a0)
    addi t0, t0, -1
    slli t0, t0, 16
    addi t0, t0, -1
    sd t0, LUMAP_UMAX(a0)
    fdiv.d ft1, ft1, ft2
    fcvt.l.d t1, ft1, rup
    addi t1, t1, 2
    bge t1, t2, 2f
    mv t1, t2
2:
    sd t1, LUMAP_H(a0)
    addi t1, t1, -1
    slli t1, t1, 16
    addi t1, t1, -1
    sd t1, LUMAP_VMAX(a0)
    ret

# A map's texel coordinates to lumel coordinates from a surface's mapping:
# lu = u RU >> 32 - OU, RU being 2^32 over texw u_scale L and OU (u_offset /
# u_scale + du) / L in 16.16, and v the same over texh.
# a0 address The surface.
# a1 address The record.
# fa0 f64 du, the u term beyond the mapping: a plane's origin, nothing for a wall.
# fa1 f64 dv: a plane's origin, a wall's anchor less its top.
# returns Clobbers t0, ft0 to ft5.
#   a0 1, or 0 for a mapping of no scale, which has no map.
map_params:
    la t0, k_lumel_d
    fld ft5, 0(t0)
    la t0, k_two32_d
    fld ft4, 0(t0)
    la t0, poly
    flw ft0, POLY_TEXW(t0)
    fcvt.d.s ft0, ft0
    flw ft1, SURFACE_U_SCALE(a0)
    fcvt.d.s ft1, ft1
    fcvt.d.w ft2, zero
    feq.d t0, ft1, ft2
    bnez t0, 8f
    fmul.d ft0, ft0, ft1
    fmul.d ft0, ft0, ft5
    fdiv.d ft0, ft4, ft0
    fcvt.l.d t0, ft0, rne
    sd t0, LUMAP_RU(a1)
    flw ft0, SURFACE_U_OFFSET(a0)
    fcvt.d.s ft0, ft0
    fdiv.d ft0, ft0, ft1
    fadd.d ft0, ft0, fa0
    fdiv.d ft0, ft0, ft5
    la t0, k_uv_scale_d
    fld ft3, 0(t0)
    fmul.d ft0, ft0, ft3
    fcvt.l.d t0, ft0, rne
    sd t0, LUMAP_OU(a1)
    la t0, poly
    flw ft0, POLY_TEXH(t0)
    fcvt.d.s ft0, ft0
    flw ft1, SURFACE_V_SCALE(a0)
    fcvt.d.s ft1, ft1
    feq.d t0, ft1, ft2
    bnez t0, 8f
    fmul.d ft0, ft0, ft1
    fmul.d ft0, ft0, ft5
    fdiv.d ft0, ft4, ft0
    fcvt.l.d t0, ft0, rne
    sd t0, LUMAP_RV(a1)
    flw ft0, SURFACE_V_OFFSET(a0)
    fcvt.d.s ft0, ft0
    fdiv.d ft0, ft0, ft1
    fadd.d ft0, ft0, fa1
    fdiv.d ft0, ft0, ft5
    fmul.d ft0, ft0, ft3
    fcvt.l.d t0, ft0, rne
    sd t0, LUMAP_OV(a1)
    li a0, 1
    ret
8:
    li a0, 0
    ret

# A map's lumels baked over bake_grid: each node's point under the normal
# over the polygon's list through point_light, its channels to 256ths, into
# the arena from the cursor; the record's base, or none when the arena is
# full, which counts the map unmapped.
# a0 address The record, its columns and rows set.
lumap_fill:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s2, 48(sp)
    sd s3, 40(sp)
    sd s4, 32(sp)
    sd s5, 24(sp)
    sd s6, 16(sp)
    sd s7, 8(sp)
    mv s2, a0
    ld s6, LUMAP_W(s2)
    ld s7, LUMAP_H(s2)
    mul t2, s6, s7                  # the lumels
    la t0, lumel_cursor
    ld s3, 0(t0)                    # the first
    slli t3, t2, 3
    add t3, t3, s3                  # past the last
    la t1, lumel_arena
    li t4, LUMEL_ARENA_BYTES
    add t1, t1, t4
    bgtu t3, t1, 8f
    sd t3, 0(t0)
    sd s3, LUMAP_BASE(s2)
    la t0, lumap_count
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
    la t0, lumel_count
    ld t1, 0(t0)
    add t1, t1, t2
    sd t1, 0(t0)
    li s5, 0                        # the row
1:
    bgeu s5, s7, 9f
    li s4, 0                        # the column
2:
    bgeu s4, s6, 7f
    # the node: the origin along u by the column and along v by the row
    la t0, bake_grid
    fcvt.d.l ft8, s4
    fcvt.d.l ft9, s5
    fld ft0, (GRID_O + 0)(t0)
    fld ft1, (GRID_U + 0)(t0)
    fmadd.d ft0, ft1, ft8, ft0
    fld ft1, (GRID_V + 0)(t0)
    fmadd.d ft0, ft1, ft9, ft0
    fcvt.s.d fa0, ft0
    fld ft0, (GRID_O + 8)(t0)
    fld ft1, (GRID_U + 8)(t0)
    fmadd.d ft0, ft1, ft8, ft0
    fld ft1, (GRID_V + 8)(t0)
    fmadd.d ft0, ft1, ft9, ft0
    fcvt.s.d fa1, ft0
    fld ft0, (GRID_O + 16)(t0)
    fld ft1, (GRID_U + 16)(t0)
    fmadd.d ft0, ft1, ft8, ft0
    fld ft1, (GRID_V + 16)(t0)
    fmadd.d ft0, ft1, ft9, ft0
    fcvt.s.d fa2, ft0
    flw fa3, (GRID_N + 0)(t0)
    flw fa4, (GRID_N + 4)(t0)
    flw fa5, (GRID_N + 8)(t0)
    li t6, 0
    la t2, poly
    addi t2, t2, POLY_LIGHTS
    call point_light
    call lumel_pack
    sd a0, 0(s3)
    addi s3, s3, LUMEL_BYTES
    addi s4, s4, 1
    j 2b
7:
    addi s5, s5, 1
    j 1b
8:
    sd zero, LUMAP_BASE(s2)
    la t0, lumap_missing
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
9:
    ld ra, 56(sp)
    ld s2, 48(sp)
    ld s3, 40(sp)
    ld s4, 32(sp)
    ld s5, 24(sp)
    ld s6, 16(sp)
    ld s7, 8(sp)
    addi sp, sp, 64
    ret

.section .bss
.balign 8
light_count:
    .skip 4
.balign 8
lights:
    .skip (MAX_LIGHTS * LIGHT_SIZE)
sector_lights:
    .skip (MAX_SECTORS * SECTOR_LIGHTS_SIZE)
# Each entity's light index, -1 for an entity that is no light
entity_light:
    .skip (MAX_ENTITIES * 4)
.balign 8
# The arena's next free lumel; the maps baked, the lumels in them, and the
# textured surfaces left without a map
lumel_cursor:
    .skip 8
lumap_count:
    .skip 8
lumel_count:
    .skip 8
lumap_missing:
    .skip 8
# The grid the map in hand is baked over
bake_grid:
    .skip GRID_SIZE
.balign 8
# A sprite's map: four lumels alike, written a frame at its centre
sprite_lumap:
    .skip LUMAP_SIZE
sprite_cells:
    .skip (4 * LUMEL_BYTES)
# Every surface's map
lumaps:
    .skip (LUMAP_COUNT * LUMAP_SIZE)
.balign 8
lumel_arena:
    .skip LUMEL_ARENA_BYTES
