# The 3D trace: a ray from a point in a sector along a unit direction for a
# distance, walked sector to sector, then against the capsules.

.section .rodata
.balign 8
k_trace_eps_d:
    .double 0.000000000001
k_trace_step_d:
    .double 0.000001
k_trace_neg_d:
    .double -0.000000001
k_trace_one_plus_d:
    .double 1.000000001
k_trace_range_d:
    .double 100.0

.section .text

# The ray walked: the geometry, then the capsules; trace_hit filled.
# a0 int The sector the origin is in.
# a1 address The actor left out, 0 for none.
# a2 int TRACE_TO_PLAYER to test the player's capsule too.
# fa0 f64 The origin's x; fa1 y; fa2 z.
# fa3 f64 The direction's x; fa4 y; fa5 z, unit.
# fa6 f64 The distance.
# returns
#   a0 The kind met.
trace_ray:
    addi sp, sp, -208
    sd ra, 200(sp)
    sd s2, 192(sp)
    sd s3, 184(sp)
    sd s4, 176(sp)
    sd s5, 168(sp)
    sd s6, 160(sp)
    sd s7, 152(sp)
    sd s8, 144(sp)
    sd s9, 136(sp)
    sd s10, 128(sp)
    sd s11, 120(sp)
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
    fsd fs10, 32(sp)
    fsd fs11, 24(sp)
    mv s2, a0                       # the sector in hand
    mv s4, a1                       # the actor left out
    mv s5, a2                       # the flags
    fmv.d fs0, fa0                  # the origin
    fmv.d fs1, fa1
    fmv.d fs2, fa2
    fmv.d fs3, fa3                  # the direction
    fmv.d fs4, fa4
    fmv.d fs5, fa5
    fmv.d fs6, fa6                  # the distance
    fcvt.d.w fs7, zero              # the distance walked so far
    li s3, 64                       # the sectors the ray may cross
    la t0, trace_hit
    sd zero, TRACE_ACTOR(t0)
1:
    # the sector in hand: the nearest wall crossing past what is walked
    section_count KIND_SECTORS, t0
    bgeu s2, t0, 20f                # in no sector: the ray ends at its distance
    fmv.d fs8, fs6                  # the nearest crossing, the distance to start
    li s6, -1                       # the wall crossed, none yet
    mv a0, s2
    call sector_at
    lwu s11, SECTOR_FIRST_LOOP(a0)
    lwu s10, SECTOR_LOOP_COUNT(a0)
    add s10, s10, s11
2:
    bgeu s11, s10, 6f
    mv a0, s11
    call loop_at
    lwu s8, LOOP_FIRST_WALL(a0)
    lwu s9, LOOP_WALL_COUNT(a0)
    add s9, s9, s8
3:
    bgeu s8, s9, 5f
    mv a0, s8
    call wall_at
    mv s7, a0
    lwu a0, WALL_A(s7)
    call vertex_at
    flw ft0, VERTEX_X(a0)
    fcvt.d.s fs9, ft0               # a
    flw ft0, VERTEX_Y(a0)
    fcvt.d.s fs10, ft0
    lwu a0, WALL_B(s7)
    call vertex_at
    flw ft0, VERTEX_X(a0)
    fcvt.d.s ft2, ft0
    fsub.d ft2, ft2, fs9            # e, the wall's run
    flw ft0, VERTEX_Y(a0)
    fcvt.d.s ft3, ft0
    fsub.d ft3, ft3, fs10
    fmul.d ft4, fs3, ft3
    fnmsub.d ft4, fs4, ft2, ft4     # cross(d, e)
    fabs.d ft5, ft4
    la t0, k_trace_eps_d
    fld ft6, 0(t0)
    flt.d t1, ft5, ft6
    bnez t1, 4f                     # along the wall
    fsub.d ft7, fs9, fs0            # from the origin to a
    fsub.d ft8, fs10, fs1
    fmul.d ft9, ft7, ft3
    fnmsub.d ft9, ft8, ft2, ft9     # cross(a - o, e)
    fdiv.d ft9, ft9, ft4            # the distance along the ray
    la t0, k_trace_step_d
    fld ft6, 0(t0)
    fadd.d ft6, fs7, ft6
    fle.d t1, ft9, ft6
    bnez t1, 4f                     # behind, or the wall entered through
    fle.d t1, fs8, ft9
    bnez t1, 4f                     # farther than the nearest
    fmul.d ft10, ft7, fs4
    fnmsub.d ft10, ft8, fs3, ft10   # cross(a - o, d)
    fdiv.d ft10, ft10, ft4          # the fraction along the wall
    la t0, k_trace_neg_d
    fld ft6, 0(t0)
    flt.d t1, ft10, ft6
    bnez t1, 4f                     # short of a
    la t0, k_trace_one_plus_d
    fld ft6, 0(t0)
    flt.d t1, ft6, ft10
    bnez t1, 4f                     # past b
    fmv.d fs8, ft9
    mv s6, s7
4:
    addi s8, s8, 1
    j 3b
5:
    addi s11, s11, 1
    j 2b
6:
    # the planes met before the crossing: the ray's height against the
    # plane's along it, down through the floor or up through the ceiling
    li s7, 0
7:
    li t0, 2
    bge s7, t0, 10f
    mv a0, s2
    call sector_at
    li t1, SECTOR_CEILING
    mul t1, s7, t1
    add a0, a0, t1
    flw ft0, PLANE_A(a0)
    fcvt.d.s ft0, ft0
    flw ft1, PLANE_B(a0)
    fcvt.d.s ft1, ft1
    flw ft2, PLANE_C(a0)
    fcvt.d.s ft2, ft2
    fmv.d ft3, fs2
    fnmsub.d ft3, ft0, fs0, ft3
    fnmsub.d ft3, ft1, fs1, ft3
    fsub.d ft3, ft3, ft2            # the height over the plane at the origin
    fmv.d ft4, fs5
    fnmsub.d ft4, ft0, fs3, ft4
    fnmsub.d ft4, ft1, fs4, ft4     # its change along the ray
    fabs.d ft5, ft4
    la t0, k_trace_eps_d
    fld ft6, 0(t0)
    flt.d t1, ft5, ft6
    bnez t1, 9f                     # along the plane
    fcvt.d.w ft6, zero
    beqz s7, 8f
    flt.d t1, ft6, ft4              # rising through the ceiling
    beqz t1, 9f
    j 81f
8:
    flt.d t1, ft4, ft6              # falling through the floor
    beqz t1, 9f
81:
    fdiv.d ft7, ft3, ft4
    fneg.d ft7, ft7                 # the distance to the plane
    la t0, k_trace_step_d
    fld ft6, 0(t0)
    fadd.d ft6, fs7, ft6
    fle.d t1, ft7, ft6
    bnez t1, 9f
    fle.d t1, fs8, ft7
    bnez t1, 9f
    fmv.d fs8, ft7
    li s6, -2                       # a plane, before any wall
9:
    addi s7, s7, 1
    j 7b
10:
    li t0, -2
    beq s6, t0, 30f
    bltz s6, 20f
    # the wall's crossing: its point, then the first portal whose
    # sector holds the ray's height there
    fmv.d fa0, fs8
    call trace_point
    lwu s8, WALL_FIRST_PORTAL(s6)
    lwu s9, WALL_PORTAL_COUNT(s6)
    add s9, s9, s8
11:
    bgeu s8, s9, 12f
    mv a0, s8
    call portal_at
    lwu s7, PORTAL_SECTOR(a0)
    la t0, trace_hit
    fld fa0, TRACE_PX(t0)
    fld fa1, TRACE_PY(t0)
    mv a0, s7
    li a1, 0
    call plane_height               # the floor across
    la t0, k_hold_slack_d
    fld ft0, 0(t0)
    fsub.d fa0, fa0, ft0
    la t0, trace_hit
    fld ft1, TRACE_PZ(t0)
    flt.d t1, ft1, fa0
    bnez t1, 111f                   # under its floor
    fld fa0, TRACE_PX(t0)
    fld fa1, TRACE_PY(t0)
    mv a0, s7
    li a1, 1
    call plane_height               # the ceiling across
    la t0, k_hold_slack_d
    fld ft0, 0(t0)
    fadd.d fa0, fa0, ft0
    la t0, trace_hit
    fld ft1, TRACE_PZ(t0)
    flt.d t1, fa0, ft1
    bnez t1, 111f                   # over its ceiling
    # entered
    mv s2, s7
    fmv.d fs7, fs8
    addi s3, s3, -1
    bnez s3, 1b
    j 12f
111:
    addi s8, s8, 1
    j 11b
12:
    # a piece
    la t0, trace_hit
    li t1, TRACE_PIECE
    sd t1, TRACE_KIND(t0)
    fsd fs8, TRACE_DIST(t0)
    sd s2, TRACE_SECTOR(t0)
    j 40f
20:
    # nothing within the distance
    la t0, trace_hit
    sd zero, TRACE_KIND(t0)
    fsd fs6, TRACE_DIST(t0)
    sd s2, TRACE_SECTOR(t0)
    fmv.d fa0, fs6
    call trace_point
    j 40f
30:
    # a plane
    la t0, trace_hit
    li t1, TRACE_PLANE
    sd t1, TRACE_KIND(t0)
    fsd fs8, TRACE_DIST(t0)
    sd s2, TRACE_SECTOR(t0)
    fmv.d fa0, fs8
    call trace_point
40:
    # the capsules within what is met
    la s7, actors
    li s8, MAX_ACTORS
41:
    beqz s8, 45f
    beq s7, s4, 44f
    lwu t0, ACTOR_CLASS(s7)
    li t1, ACTOR_ANDROID
    bne t0, t1, 44f
    lwu t0, ACTOR_FLAGS(s7)
    andi t0, t0, ACTOR_SHOOTABLE
    beqz t0, 44f
    fld fa0, ACTOR_X(s7)
    fld fa1, ACTOR_Y(s7)
    fld fa2, ACTOR_Z(s7)
    call trace_capsule
    beqz a0, 44f
    la t0, trace_hit
    li t1, TRACE_ANDROID
    sd t1, TRACE_KIND(t0)
    fsd fa0, TRACE_DIST(t0)
    sd s7, TRACE_ACTOR(t0)
    call trace_point
44:
    addi s7, s7, ACTOR_SIZE
    addi s8, s8, -1
    j 41b
45:
    andi t0, s5, TRACE_TO_PLAYER
    beqz t0, 50f
    la t0, camera
    flw fa0, CAM_X(t0)
    fcvt.d.s fa0, fa0
    flw fa1, CAM_Y(t0)
    fcvt.d.s fa1, fa1
    flw fa2, CAM_Z(t0)
    fcvt.d.s fa2, fa2
    la t0, k_body_eye_d
    fld ft0, 0(t0)
    fsub.d fa2, fa2, ft0            # the player's feet
    call trace_capsule
    beqz a0, 50f
    la t0, trace_hit
    li t1, TRACE_PLAYER
    sd t1, TRACE_KIND(t0)
    fsd fa0, TRACE_DIST(t0)
    sd zero, TRACE_ACTOR(t0)
    call trace_point
50:
    la t0, trace_hit
    ld a0, TRACE_KIND(t0)
    ld ra, 200(sp)
    ld s2, 192(sp)
    ld s3, 184(sp)
    ld s4, 176(sp)
    ld s5, 168(sp)
    ld s6, 160(sp)
    ld s7, 152(sp)
    ld s8, 144(sp)
    ld s9, 136(sp)
    ld s10, 128(sp)
    ld s11, 120(sp)
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
    fld fs10, 32(sp)
    fld fs11, 24(sp)
    addi sp, sp, 208
    ret

# trace_hit's point set to the ray's at a distance, from the origin and
# direction trace_ray holds in fs0 to fs5.
# fa0 f64 The distance, kept.
# returns Clobbers t0, ft0.
trace_point:
    la t0, trace_hit
    fmadd.d ft0, fs3, fa0, fs0
    fsd ft0, TRACE_PX(t0)
    fmadd.d ft0, fs4, fa0, fs1
    fsd ft0, TRACE_PY(t0)
    fmadd.d ft0, fs5, fa0, fs2
    fsd ft0, TRACE_PZ(t0)
    ret

# Whether the ray trace_ray holds in fs0 to fs5 meets the capsule on the
# feet fa0, fa1, fa2 before the distance in trace_hit.
# fa0 f64 The feet's x; fa1 y; fa2 z.
# returns Clobbers t0, t1, ft0 to ft11.
#   a0 1 or 0.
#   fa0 f64 The distance when met.
trace_capsule:
    fmul.d ft0, fs3, fs3
    fmadd.d ft0, fs4, fs4, ft0      # the direction's share in the plan
    la t0, k_trace_eps_d
    fld ft1, 0(t0)
    flt.d t1, ft0, ft1
    bnez t1, 9f                     # straight up or down
    fsub.d ft2, fs0, fa0            # from the axis to the origin
    fsub.d ft3, fs1, fa1
    fmul.d ft4, ft2, fs3
    fmadd.d ft4, ft3, fs4, ft4
    fadd.d ft4, ft4, ft4            # twice along
    fmul.d ft5, ft2, ft2
    fmadd.d ft5, ft3, ft3, ft5
    la t0, k_body_radius_sq_d
    fld ft6, 0(t0)
    fsub.d ft5, ft5, ft6            # the offset's square less the radius's
    fmul.d ft7, ft4, ft4
    fmul.d ft8, ft0, ft5
    fadd.d ft8, ft8, ft8
    fadd.d ft8, ft8, ft8
    fsub.d ft7, ft7, ft8            # the discriminant
    fcvt.d.w ft9, zero
    flt.d t1, ft7, ft9
    bnez t1, 9f                     # a miss in the plan
    fsqrt.d ft7, ft7
    fneg.d ft8, ft4
    fsub.d ft8, ft8, ft7
    fadd.d ft10, ft0, ft0
    fdiv.d ft8, ft8, ft10           # the nearer meeting
    fle.d t1, ft8, ft9
    bnez t1, 9f                     # behind, or the origin inside
    la t0, trace_hit
    fld ft10, TRACE_DIST(t0)
    fle.d t1, ft10, ft8
    bnez t1, 9f                     # past what is met
    fmadd.d ft11, fs5, ft8, fs2     # the height there
    flt.d t1, ft11, fa2
    bnez t1, 9f                     # under the feet
    la t0, k_body_height_d
    fld ft6, 0(t0)
    fadd.d ft6, fa2, ft6
    flt.d t1, ft6, ft11
    bnez t1, 9f                     # over the head
    fmv.d fa0, ft8
    li a0, 1
    ret
9:
    li a0, 0
    ret

.section .bss
.balign 8
trace_hit:
    .skip TRACE_SIZE
