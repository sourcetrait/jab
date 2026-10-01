# The map's lights, without shadows: a span's brightness in three channels,
# the ambient plus each light of the sector's list by cosine and falloff.

.section .rodata
.balign 4
k_light_ambient:
    .float 0.15
k_light_none:
    .float -2.0
k_light_minus_one:
    .float -1.0
k_depth_scale:
    .float 67108864.0

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

# The brightness at a pixel of the surface in hand: the three channels in
# 16.16 packed CHANNEL_BITS apart, the ambient plus each light in reach, in
# single precision throughout.
# a0 int The pixel.
# a1 int The row.
# a2 int 1/z there, 6.26.
# returns A leaf; clobbers t0 to t6 and every temporary float register.
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
    # the normal, the ambient, and the sector's list
    la t0, poly
    flw fa3, POLY_LNX(t0)
    flw fa4, POLY_LNY(t0)
    flw fa5, POLY_LNZ(t0)
    la t1, k_light_ambient
    flw fa6, 0(t1)                  # red
    fmv.s fa7, fa6                  # green
    fmv.s ft11, fa6                 # blue
    la t1, k_one
    flw ft10, 0(t1)                 # one
    ld t6, POLY_FLAT_LIT(t0)        # lit at no angle
    lw t1, POLY_SECTOR(t0)
    la t2, sector_lights
    slli t1, t1, 5
    add t2, t2, t1                  # the list
    lbu t3, 0(t2)                   # its count
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
