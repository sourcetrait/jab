.section .rodata
.balign 8
k_body_radius_d:
    .double 0.35
k_body_radius_sq_d:
    .double 0.1225
k_body_height_d:
    .double 1.8
k_body_eye_d:
    .double 1.6
k_body_step_d:
    .double 0.501                   # a step, and a hair for a floor set exactly one step up
k_body_gravity_d:
    .double 9.8
k_thousandth_d:
    .double 0.001
.balign 4
k_walk_speed:
    .float 4.0

.section .text

body_move:
    addi sp, sp, -112
    sd ra, 104(sp)
    sd s2, 96(sp)
    sd s3, 88(sp)
    sd s4, 80(sp)
    sd s5, 72(sp)
    fsd fs0, 64(sp)
    fsd fs1, 56(sp)
    fsd fs2, 48(sp)
    fsd fs3, 40(sp)
    fsd fs4, 32(sp)
    fsd fs5, 24(sp)
    fsd fs6, 16(sp)
    fsd fs7, 8(sp)
    fmv.s fs4, fa0                  # the seconds, single
    fsw fa1, 0(sp)
    fsw fa2, 4(sp)
    la t0, camera
    flw fa0, CAM_YAW(t0)
    jab.f32.cos ft8, fa0
    jab.f32.sin ft9, fa0
    fmv.s ft0, ft8                  # forward x
    fmv.s ft1, ft9                  # forward y
    fmv.s ft4, ft1                  # right: forward turned a quarter to the right
    fneg.s ft5, ft0
    flw fa1, 0(sp)
    flw fa2, 4(sp)
    la t1, k_walk_speed
    flw ft6, 0(t1)
    fmul.s ft6, ft6, fs4            # the units this frame at full throw
    fmul.s fa1, fa1, ft6
    fmul.s fa2, fa2, ft6
    la t0, camera
    flw ft7, CAM_X(t0)
    fmadd.s ft7, ft0, fa2, ft7
    fmadd.s ft7, ft4, fa1, ft7
    fcvt.d.s fs0, ft7               # the feet's x after the move
    flw ft7, CAM_Y(t0)
    fmadd.s ft7, ft1, fa2, ft7
    fmadd.s ft7, ft5, fa1, ft7
    fcvt.d.s fs1, ft7               # y
    flw ft7, CAM_Z(t0)
    fcvt.d.s fs2, ft7
    la t1, k_body_eye_d
    fld ft8, 0(t1)
    fsub.d fs2, fs2, ft8            # the feet's z, the eye's less the height
    la t0, cam_sector
    lw a0, 0(t0)
    la a1, body_fall
    li a2, 0
    fmv.s fa0, fs4
    call feet_move
    la t0, cam_sector
    sw a0, 0(t0)
    la t0, camera
    fcvt.s.d ft0, fs0
    fsw ft0, CAM_X(t0)
    fcvt.s.d ft0, fs1
    fsw ft0, CAM_Y(t0)
    la t1, k_body_eye_d
    fld ft0, 0(t1)
    fadd.d ft1, fs2, ft0
    fcvt.s.d ft1, ft1
    fsw ft1, CAM_Z(t0)
    ld ra, 104(sp)
    ld s2, 96(sp)
    ld s3, 88(sp)
    ld s4, 80(sp)
    ld s5, 72(sp)
    fld fs0, 64(sp)
    fld fs1, 56(sp)
    fld fs2, 48(sp)
    fld fs3, 40(sp)
    fld fs4, 32(sp)
    fld fs5, 24(sp)
    fld fs6, 16(sp)
    fld fs7, 8(sp)
    addi sp, sp, 112
    ret

feet_move:
    addi sp, sp, -96
    sd ra, 88(sp)
    sd s2, 80(sp)
    sd s3, 72(sp)
    sd s4, 64(sp)
    sd s5, 56(sp)
    sd s6, 48(sp)
    fsd fs3, 40(sp)
    fsd fs4, 32(sp)
    sd a2, 24(sp)                   # the walker
    mv s2, a0                       # the sector
    mv s6, a1                       # the fall speed
    fmv.s fs4, fa0                  # the seconds
    section_count KIND_SECTORS, t1
    bgeu s2, t1, 8f
    li s5, 2
1:
    mv a0, s2
    call sector_at
    lwu s3, SECTOR_FIRST_LOOP(a0)
    lwu s4, SECTOR_LOOP_COUNT(a0)
    add s4, s4, s3
2:
    bgeu s3, s4, 3f
    mv a0, s3
    call loop_at
    lwu t1, LOOP_FIRST_WALL(a0)
    lwu t2, LOOP_WALL_COUNT(a0)
    add t2, t2, t1
    sd t1, 0(sp)
    sd t2, 8(sp)
21:
    ld t1, 0(sp)
    ld t2, 8(sp)
    bgeu t1, t2, 22f
    mv a0, t1
    call wall_push
    ld t1, 0(sp)
    addi t1, t1, 1
    sd t1, 0(sp)
    j 21b
22:
    addi s3, s3, 1
    j 2b
3:
    addi s5, s5, -1
    bnez s5, 1b
8:
    ld a0, 24(sp)
    call bodies_push
    mv a0, s2
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    la t0, k_body_eye_d
    fld ft0, 0(t0)
    fadd.d fa2, fs2, ft0
    call sector_find
    mv s2, a0
    section_count KIND_SECTORS, t1
    bgeu s2, t1, 9f
    mv a0, s2
    li a1, 0
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height
    fmv.d fs3, fa0                  # the floor under the feet
    la t0, k_body_step_d
    fld ft0, 0(t0)
    fadd.d ft1, fs3, ft0            # a step above the floor
    flt.d t1, ft1, fs2
    beqz t1, 5f
    fld ft2, 0(s6)
    la t1, k_body_gravity_d
    fld ft3, 0(t1)
    fcvt.d.s ft4, fs4
    fmadd.d ft2, ft3, ft4, ft2      # the speed down
    fnmsub.d fs2, ft2, ft4, fs2     # the feet lower
    flt.d t1, fs3, fs2
    bnez t1, 6f
    fmv.d fs2, fs3                  # landed
    fcvt.d.w ft2, zero
6:
    fsd ft2, 0(s6)
    j 9f
5:
    fmv.d fs2, fs3                  # standing, or stepped up
    fcvt.d.w ft2, zero
    fsd ft2, 0(s6)
9:
    mv a0, s2
    ld ra, 88(sp)
    ld s2, 80(sp)
    ld s3, 72(sp)
    ld s4, 64(sp)
    ld s5, 56(sp)
    ld s6, 48(sp)
    fld fs3, 40(sp)
    fld fs4, 32(sp)
    addi sp, sp, 96
    ret

bodies_push:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t4, actors
    li t5, MAX_ACTORS
1:
    beqz t5, 5f
    beq t4, a0, 4f
    lwu t2, ACTOR_CLASS(t4)
    li t3, ACTOR_ANDROID
    bne t2, t3, 4f
    lwu t2, ACTOR_FLAGS(t4)
    andi t2, t2, ACTOR_SOLID
    beqz t2, 4f
    fld ft0, ACTOR_X(t4)
    fld ft1, ACTOR_Y(t4)
    fld ft2, ACTOR_Z(t4)
    call body_push
4:
    addi t4, t4, ACTOR_SIZE
    addi t5, t5, -1
    j 1b
5:
    beqz a0, 9f
    la t2, camera
    flw ft0, CAM_X(t2)
    fcvt.d.s ft0, ft0
    flw ft1, CAM_Y(t2)
    fcvt.d.s ft1, ft1
    flw ft2, CAM_Z(t2)
    fcvt.d.s ft2, ft2
    la t2, k_body_eye_d
    fld ft3, 0(t2)
    fsub.d ft2, ft2, ft3            # the player's feet
    call body_push
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

body_push:
    fsub.d ft3, fs2, ft2
    fabs.d ft3, ft3
    la t2, k_body_height_d
    fld ft4, 0(t2)
    fle.d t3, ft4, ft3
    bnez t3, 9f                     # one over the other
    fsub.d ft3, fs0, ft0            # from its feet to these
    fsub.d ft4, fs1, ft1
    jab.f64.vec2.reg.sqrlen ft5, ft3, ft4   # the distance squared
    la t2, k_body_radius_d
    fld ft6, 0(t2)
    fadd.d ft6, ft6, ft6            # the radii
    fmul.d ft7, ft6, ft6
    fle.d t3, ft7, ft5
    bnez t3, 9f                     # clear
    la t2, k_thousandth_d
    fld ft7, 0(t2)
    flt.d t3, ft5, ft7
    bnez t3, 8f
    fsqrt.d ft5, ft5                # the distance
    fsub.d ft7, ft6, ft5            # the shortfall
    fdiv.d ft7, ft7, ft5
    fmadd.d fs0, ft3, ft7, fs0
    fmadd.d fs1, ft4, ft7, fs1
    ret
8:
    fadd.d fs0, fs0, ft6            # on one spot: eastward
9:
    ret

wall_push:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s3, 32(sp)
    sd s4, 24(sp)
    mv s3, a0
    call wall_at
    mv s4, a0
    lwu a0, WALL_A(s4)
    call vertex_at
    flw ft0, VERTEX_X(a0)
    fcvt.d.s ft0, ft0               # a
    flw ft1, VERTEX_Y(a0)
    fcvt.d.s ft1, ft1
    lwu a0, WALL_B(s4)
    call vertex_at
    flw ft2, VERTEX_X(a0)
    fcvt.d.s ft2, ft2               # b
    flw ft3, VERTEX_Y(a0)
    fcvt.d.s ft3, ft3
    fsub.d ft2, ft2, ft0            # the run
    fsub.d ft3, ft3, ft1
    fsub.d ft4, fs0, ft0            # from a to the feet
    fsub.d ft5, fs1, ft1
    fmul.d ft6, ft4, ft2
    fmadd.d ft6, ft5, ft3, ft6      # along
    fmul.d ft7, ft2, ft2
    fmadd.d ft7, ft3, ft3, ft7      # the length squared
    fdiv.d ft6, ft6, ft7
    fcvt.d.w ft8, zero
    fmax.d ft6, ft6, ft8
    la t0, k_one_d
    fld ft8, 0(t0)
    fmin.d ft6, ft6, ft8            # clamped to the segment
    fmadd.d fs5, ft6, ft2, ft0      # the nearest point
    fmadd.d fs6, ft6, ft3, ft1
    fsub.d ft4, fs0, fs5            # from it to the feet
    fsub.d ft5, fs1, fs6
    fmul.d ft9, ft4, ft4
    fmadd.d ft9, ft5, ft5, ft9      # the distance squared
    la t0, k_body_radius_sq_d
    fld ft8, 0(t0)
    fle.d t1, ft8, ft9
    bnez t1, 9f                     # clear of the wall
    lwu t1, (WALL_SURFACE + SURFACE_FLAGS)(s4)
    andi t1, t1, SURFACE_SOLID
    bnez t1, 5f
    lwu a1, WALL_FIRST_PORTAL(s4)
    lwu a2, WALL_PORTAL_COUNT(s4)
    beqz a2, 5f                     # nothing across
    add a2, a2, a1                  # past the last portal
    sd a1, 0(sp)
    sd a2, 8(sp)
1:
    ld a1, 0(sp)
    ld a2, 8(sp)
    bgeu a1, a2, 5f                 # none admitted
    mv a0, a1
    call portal_at
    lwu a5, PORTAL_SECTOR(a0)       # the sector across
    sd a5, 16(sp)
    mv a0, a5
    li a1, 0
    fmv.d fa0, fs5
    fmv.d fa1, fs6
    call plane_height
    fmv.d fs7, fa0                  # the floor across
    ld a0, 16(sp)
    li a1, 1
    fmv.d fa0, fs5
    fmv.d fa1, fs6
    call plane_height               # the ceiling across
    la t0, k_body_step_d
    fld ft0, 0(t0)
    fadd.d ft1, fs2, ft0            # the feet and a step: the highest floor stepped onto
    flt.d t1, ft1, fs7
    bnez t1, 3f                     # too high
    la t0, k_body_height_d
    fld ft0, 0(t0)
    fadd.d ft1, fs7, ft0            # the head over that floor
    flt.d t1, fa0, ft1
    bnez t1, 3f                     # the ceiling too low
    j 9f                            # admitted
3:
    ld a1, 0(sp)
    addi a1, a1, 1
    sd a1, 0(sp)
    j 1b
5:
    fsub.d ft4, fs0, fs5
    fsub.d ft5, fs1, fs6
    jab.f64.vec2.reg.len ft9, ft4, ft5  # the distance
    fcvt.d.w ft8, zero
    flt.d t1, ft8, ft9
    bnez t1, 6f
    lwu a0, WALL_A(s4)
    call vertex_at
    flw ft0, VERTEX_X(a0)
    flw ft1, VERTEX_Y(a0)
    lwu a0, WALL_B(s4)
    call vertex_at
    flw ft2, VERTEX_X(a0)
    flw ft3, VERTEX_Y(a0)
    fsub.s ft4, ft1, ft3            # (ay - by, bx - ax): into the sector
    fcvt.d.s ft4, ft4
    fsub.s ft5, ft2, ft0
    fcvt.d.s ft5, ft5
    jab.f64.vec2.reg.len ft9, ft4, ft5
6:
    la t0, k_body_radius_d
    fld ft0, 0(t0)
    fsub.d ft0, ft0, ft9            # how far in
    fdiv.d ft0, ft0, ft9            # over the distance: the push per unit of the offset
    fmadd.d fs0, ft4, ft0, fs0
    fmadd.d fs1, ft5, ft0, fs1
9:
    ld ra, 40(sp)
    ld s3, 32(sp)
    ld s4, 24(sp)
    addi sp, sp, 48
    ret

.section .bss
.balign 8
body_fall:
    .skip 8
