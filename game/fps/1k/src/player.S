.set HEALTH_START, 100
.set MAGAZINE_ROUNDS, 30
.set NOISE_HOPS, 6
.set MET_NOTHING, 0
.set MET_GEOMETRY, 1
.set MET_ANDROID, 2

.section .rodata
.balign 8
k_round_range_d:
    .double 100.0
k_pickup_sq_d:
    .double 1.0
k_pickup_rise_d:
    .double 1.0
k_noise_range_sq_d:
    .double 900.0

.section .text

player_reset:
    li t0, HEALTH_START
    la t1, health
    sw t0, 0(t1)
    la t1, rounds
    sw zero, 0(t1)
    la t1, pad_prev
    sw zero, 0(t1)
    la t3, rng
    li t4, 8
    jab.sys.random t3, t4
    beqz a0, 1f
    rdtime t4
    j 2f
1:
    ld t4, 0(t3)
2:
    jab.rng.seed t3, t4
    ret

player_fire:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    li a0, SOUND_G1_SHOT
    li a1, 1
    call sound_start
    la t0, camera
    flw fa0, CAM_X(t0)
    fcvt.d.s fa0, fa0
    flw fa1, CAM_Y(t0)
    fcvt.d.s fa1, fa1
    flw fa2, CAM_Z(t0)
    fcvt.d.s fa2, fa2
    flw fa3, (CAM_FORWARD + 0)(t0)
    fcvt.d.s fa3, fa3
    flw fa4, (CAM_FORWARD + 4)(t0)
    fcvt.d.s fa4, fa4
    flw fa5, (CAM_FORWARD + 8)(t0)
    fcvt.d.s fa5, fa5
    la t0, k_round_range_d
    fld fa6, 0(t0)
    la t0, cam_sector
    lw a0, 0(t0)
    li a1, 0
    li a2, 0
    call trace_ray
    la t0, trace_hit
    ld t1, TRACE_KIND(t0)
    li t2, TRACE_ANDROID
    bne t1, t2, 2f
    ld s2, TRACE_ACTOR(t0)
    fld fa0, TRACE_PX(t0)
    fld fa1, TRACE_PY(t0)
    fld fa2, TRACE_PZ(t0)
    lw a0, ACTOR_SECTOR(s2)
    call spark_spawn
    mv a0, s2
    li a1, ROUND_DAMAGE
    call actor_hurt
    mv a0, s2
    call actor_index
    mv a2, a0
    li a0, REPORT_ROUND
    li a1, MET_ANDROID
    lw a3, ACTOR_HEALTH(s2)
    li a4, 0
    li a5, 0
    call event_report
    j 8f
2:
    beqz t1, 3f
    fld fa0, TRACE_PX(t0)
    fld fa1, TRACE_PY(t0)
    fld fa2, TRACE_PZ(t0)
    ld a0, TRACE_SECTOR(t0)
    call spark_spawn
    li a0, REPORT_ROUND
    li a1, MET_GEOMETRY
    li a2, -1
    li a3, 0
    li a4, 0
    li a5, 0
    call event_report
    j 8f
3:
    li a0, REPORT_ROUND
    li a1, MET_NOTHING
    li a2, -1
    li a3, 0
    li a4, 0
    li a5, 0
    call event_report
8:
    call noise_heard
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

player_hurt:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, health
    lw t1, 0(t0)
    sub t1, t1, a0
    bgez t1, 1f
    li t1, 0
1:
    sw t1, 0(t0)
    mv a1, a0
    mv a2, t1
    li a0, REPORT_HURT
    li a3, 0
    li a4, 0
    li a5, 0
    call event_report
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

player_pickups:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    la s2, actors
    li s3, MAX_ACTORS
1:
    beqz s3, 9f
    lwu t0, ACTOR_CLASS(s2)
    li t1, ACTOR_MAGAZINE
    bne t0, t1, 8f
    la t0, camera
    flw ft0, CAM_X(t0)
    fcvt.d.s ft0, ft0
    fld ft1, ACTOR_X(s2)
    fsub.d ft0, ft0, ft1
    flw ft1, CAM_Y(t0)
    fcvt.d.s ft1, ft1
    fld ft2, ACTOR_Y(s2)
    fsub.d ft1, ft1, ft2
    fmul.d ft0, ft0, ft0
    fmadd.d ft0, ft1, ft1, ft0      # the distance squared in the plan
    la t1, k_pickup_sq_d
    fld ft1, 0(t1)
    flt.d t1, ft1, ft0
    bnez t1, 8f
    flw ft0, CAM_Z(t0)
    fcvt.d.s ft0, ft0
    la t1, k_body_eye_d
    fld ft1, 0(t1)
    fsub.d ft0, ft0, ft1            # the feet
    fld ft1, ACTOR_Z(s2)
    fsub.d ft0, ft0, ft1
    fabs.d ft0, ft0
    la t1, k_pickup_rise_d
    fld ft1, 0(t1)
    flt.d t1, ft1, ft0
    bnez t1, 8f
    sw zero, ACTOR_CLASS(s2)
    la t0, rounds
    lw t1, 0(t0)
    addi t1, t1, MAGAZINE_ROUNDS
    sw t1, 0(t0)
    li a0, SOUND_PICKUP
    li a1, 1
    call sound_start
    la t0, rounds
    lw a1, 0(t0)
    li a0, REPORT_PICKUP
    li a2, 0
    li a3, 0
    li a4, 0
    li a5, 0
    call event_report
8:
    addi s2, s2, ACTOR_SIZE
    addi s3, s3, -1
    j 1b
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

noise_heard:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    la t0, cam_sector
    lw s2, 0(t0)
    section_count KIND_SECTORS, t1
    bgeu s2, t1, 9f
    la t0, noise_seen
    add t1, t0, t1
1:
    beq t0, t1, 2f
    sb zero, 0(t0)
    addi t0, t0, 1
    j 1b
2:
    la t0, noise_seen
    add t0, t0, s2
    li t1, 1
    sb t1, 0(t0)
    la t0, noise_fifo
    sw s2, 0(t0)                    # the sector, the depth above it
    li s3, 0                        # the fifo's read
    li s4, 1                        # and write
3:
    bgeu s3, s4, 5f
    la t0, noise_fifo
    slli t1, s3, 2
    add t0, t0, t1
    lwu t1, 0(t0)
    addi s3, s3, 1
    srli s5, t1, 16                 # the depth
    slli s2, t1, 48
    srli s2, s2, 48                 # the sector
    li t0, NOISE_HOPS
    bgeu s5, t0, 3b                 # deep enough
    addi s5, s5, 1
    slli s5, s5, 16                 # the neighbours' depth, in place
    mv a0, s2
    call sector_at
    lwu t1, SECTOR_FIRST_LOOP(a0)
    lwu t2, SECTOR_LOOP_COUNT(a0)
    li t3, LOOP_SIZE
    mul t1, t1, t3
    section_at KIND_LOOPS, t3
    add t1, t1, t3                  # the loop
    section_at KIND_WALLS, a3
    section_at KIND_PORTALS, a4
31:
    beqz t2, 3b
    lwu t3, LOOP_FIRST_WALL(t1)
    lwu t4, LOOP_WALL_COUNT(t1)
    li t5, WALL_SIZE
    mul t3, t3, t5
    add t3, t3, a3                  # the wall
32:
    beqz t4, 34f
    lwu t5, WALL_FIRST_PORTAL(t3)
    lwu t6, WALL_PORTAL_COUNT(t3)
    slli t5, t5, 3
    add t5, t5, a4                  # the portal
33:
    beqz t6, 331f
    lwu a1, PORTAL_SECTOR(t5)
    la a2, noise_seen
    add a2, a2, a1
    lbu a5, 0(a2)
    bnez a5, 330f
    li a5, 1
    sb a5, 0(a2)
    la a2, noise_fifo
    slli a5, s4, 2
    add a2, a2, a5
    or a1, a1, s5
    sw a1, 0(a2)
    addi s4, s4, 1
330:
    addi t5, t5, PORTAL_SIZE
    addi t6, t6, -1
    j 33b
331:
    addi t3, t3, WALL_SIZE
    addi t4, t4, -1
    j 32b
34:
    addi t1, t1, LOOP_SIZE
    addi t2, t2, -1
    j 31b
5:
    la s2, actors
    li s3, MAX_ACTORS
6:
    beqz s3, 9f
    lwu t0, ACTOR_CLASS(s2)
    li t1, ACTOR_ANDROID
    bne t0, t1, 8f
    lwu t0, ACTOR_FLAGS(s2)
    andi t1, t0, ACTOR_SHOOTABLE
    beqz t1, 8f
    andi t1, t0, ACTOR_ROUSED
    bnez t1, 8f
    lw t0, ACTOR_SECTOR(s2)
    bltz t0, 8f
    la t1, noise_seen
    add t1, t1, t0
    lbu t1, 0(t1)
    beqz t1, 8f
    la t0, camera
    flw ft0, CAM_X(t0)
    fcvt.d.s ft0, ft0
    fld ft1, ACTOR_X(s2)
    fsub.d ft0, ft0, ft1
    flw ft1, CAM_Y(t0)
    fcvt.d.s ft1, ft1
    fld ft2, ACTOR_Y(s2)
    fsub.d ft1, ft1, ft2
    flw ft2, CAM_Z(t0)
    fcvt.d.s ft2, ft2
    fld ft3, ACTOR_Z(s2)
    fsub.d ft2, ft2, ft3
    fmul.d ft0, ft0, ft0
    fmadd.d ft0, ft1, ft1, ft0
    fmadd.d ft0, ft2, ft2, ft0
    la t0, k_noise_range_sq_d
    fld ft1, 0(t0)
    flt.d t1, ft1, ft0
    bnez t1, 8f                     # out of range
    mv a0, s2
    call actor_rouse
8:
    addi s2, s2, ACTOR_SIZE
    addi s3, s3, -1
    j 6b
9:
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 48
    ret

.section .bss
.balign 8
rng:
    .skip 8
health:
    .skip 4
rounds:
    .skip 4
pad_prev:
    .skip 4
.balign 8
noise_fifo:
    .skip (MAX_SECTORS * 4)
noise_seen:
    .skip MAX_SECTORS
