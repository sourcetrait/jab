.section .rodata
.balign 8
frame_sets:
    .dword word_set_stand, word_set_walk1, word_set_walk2, word_set_walk3
    .dword word_set_walk4, word_set_aim, word_set_fire, word_set_struck
frame_singles:
    .dword word_single_fallen, word_single_spark1, word_single_spark2
    .dword word_single_spark3, word_single_magazine
android_rows:
    .word SET_STAND, 400, ACT_LOOK, ROW_STAND
    .word SET_WALK1, 200, ACT_WALK, ROW_PATROL2
    .word SET_WALK2, 200, ACT_WALK, ROW_PATROL3
    .word SET_WALK3, 200, ACT_WALK, ROW_PATROL4
    .word SET_WALK4, 200, ACT_WALK, ROW_PATROL1
    .word SET_STAND, 300, ACT_ALERT, ROW_AIM
    .word SET_AIM, 600, ACT_AIM, ROW_FIRE
    .word SET_FIRE, 150, ACT_FIRE, ROW_AIM
    .word SET_WALK1, 200, ACT_SEEK, ROW_SEARCH2
    .word SET_WALK2, 200, ACT_SEEK, ROW_SEARCH3
    .word SET_WALK3, 200, ACT_SEEK, ROW_SEARCH4
    .word SET_WALK4, 200, ACT_SEEK, ROW_SEARCH1
    .word SET_STRUCK, 300, ACT_STRUCK, ROW_AIM
    .word SET_STRUCK, 200, ACT_DESTROY, ROW_FALLEN
    .word SET_FALLEN, -1, ACT_FALL, ROW_FALLEN
.balign 8
action_table:
    .dword action_none, action_look, action_walk, action_alert
    .dword action_aim, action_fire, action_seek, action_struck
    .dword action_destroy, action_fall
.balign 4
k_octant:
    .float 0.41421356
k_thousandth_f:
    .float 0.001
k_two:
    .float 2.0
k_spark_seconds:
    .float 0.05
word_set_stand:
    .asciz "stand"
word_set_walk1:
    .asciz "walk1"
word_set_walk2:
    .asciz "walk2"
word_set_walk3:
    .asciz "walk3"
word_set_walk4:
    .asciz "walk4"
word_set_aim:
    .asciz "aim"
word_set_fire:
    .asciz "fire"
word_set_struck:
    .asciz "struck"
word_single_fallen:
    .asciz "android/fallen"
word_single_spark1:
    .asciz "android/spark1"
word_single_spark2:
    .asciz "android/spark2"
word_single_spark3:
    .asciz "android/spark3"
word_single_magazine:
    .asciz "gun/magazine"

.section .text

actors_place:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    la t0, actors
    li t1, (MAX_ACTORS * ACTOR_SIZE)
    add t1, t1, t0
1:
    sd zero, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 1b
    section_count KIND_ENTITIES, s2
    li s3, 0                        # the entity
    la s4, actors                   # the next free actor
2:
    bgeu s3, s2, 9f
    mv a0, s3
    call entity_at
    mv s5, a0
    lwu t0, ENTITY_CLASS(s5)
    li t1, CLASS_ANDROID
    li t2, ACTOR_ANDROID
    beq t0, t1, 3f
    li t1, CLASS_MAGAZINE
    li t2, ACTOR_MAGAZINE
    bne t0, t1, 8f
3:
    la t3, actors
    li t4, (MAX_ACTORS * ACTOR_SIZE)
    add t3, t3, t4
    bgeu s4, t3, 9f                 # the table full
    sw t2, ACTOR_CLASS(s4)
    sw s3, ACTOR_ENTITY(s4)
    flw ft0, ENTITY_X(s5)
    fcvt.d.s ft0, ft0
    fsd ft0, ACTOR_X(s4)
    flw ft0, ENTITY_Y(s5)
    fcvt.d.s ft0, ft0
    fsd ft0, ACTOR_Y(s4)
    flw ft8, ENTITY_YAW(s5)
    jab.f32.rad ft8, ft8
    fsw ft8, ACTOR_YAW(s4)
    lw t3, ENTITY_SECTOR(s5)
    sw t3, ACTOR_SECTOR(s4)
    lw t3, ENTITY_TARGET(s5)
    sw t3, ACTOR_TARGET(s4)
    li t3, -1
    sw t3, ACTOR_ROW(s4)
    lw a0, ENTITY_SECTOR(s5)
    li a1, 0
    fld fa0, ACTOR_X(s4)
    fld fa1, ACTOR_Y(s4)
    call plane_height
    fsd fa0, ACTOR_Z(s4)
    lwu t0, ACTOR_CLASS(s4)
    li t1, ACTOR_ANDROID
    bne t0, t1, 7f
    li t0, ANDROID_HEALTH
    sw t0, ACTOR_HEALTH(s4)
    li t0, (ACTOR_SOLID | ACTOR_SHOOTABLE)
    sw t0, ACTOR_FLAGS(s4)
    lw t0, ACTOR_TARGET(s4)
    li a1, ROW_PATROL1
    bgez t0, 6f
    li a1, ROW_STAND
6:
    mv a0, s4
    call actor_row
7:
    addi s4, s4, ACTOR_SIZE
8:
    addi s3, s3, 1
    j 2b
9:
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 48
    ret

actor_row:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    sw a1, ACTOR_ROW(s2)
    la t0, android_rows
    slli t1, a1, 4
    add t0, t0, t1
    lw t1, ROW_MS(t0)
    fcvt.s.w ft0, t1
    la t2, k_thousandth_f
    flw ft1, 0(t2)
    fmul.s ft0, ft0, ft1
    fsw ft0, ACTOR_TIMER(s2)
    lwu t1, ROW_ACTION(t0)
    la t0, action_table
    slli t1, t1, 3
    add t0, t0, t1
    ld t0, 0(t0)
    mv a0, s2
    jalr ra, 0(t0)
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

actor_ms:
    lwu t0, ACTOR_ROW(a0)
    la t1, android_rows
    slli t0, t0, 4
    add t0, t0, t1
    lw t0, ROW_MS(t0)
    ret

actors_tick:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    fsd fs0, 8(sp)
    la t0, frame_seconds
    flw fs0, 0(t0)
    la s2, actors
    li s3, MAX_ACTORS
1:
    beqz s3, 9f
    lwu t0, ACTOR_CLASS(s2)
    beqz t0, 8f
    li t1, ACTOR_SPARK
    beq t0, t1, 5f
    li t1, ACTOR_ANDROID
    bne t0, t1, 8f
    lwu t0, ACTOR_ROW(s2)
    la t1, android_rows
    slli t0, t0, 4
    add t1, t1, t0
    lwu t0, ROW_ACTION(t1)
    li t1, ACT_WALK
    bne t0, t1, 11f
    mv a0, s2
    call actor_patrol_step
    j 12f
11:
    li t1, ACT_SEEK
    bne t0, t1, 12f
    mv a0, s2
    call actor_seek_step
12:
    lwu t0, ACTOR_CLASS(s2)
    beqz t0, 8f
    mv a0, s2
    call actor_ms
    bltz t0, 8f                     # held
    flw ft0, ACTOR_TIMER(s2)
    fsub.s ft0, ft0, fs0
    fsw ft0, ACTOR_TIMER(s2)
    li s4, 8                        # the rows one frame may run through
2:
    flw ft0, ACTOR_TIMER(s2)
    la t0, k_zero
    flw ft1, 0(t0)
    flt.s t0, ft1, ft0
    bnez t0, 8f                     # time remains
    fsw ft0, 0(sp)                  # the leftover, at or below zero
    lwu t0, ACTOR_ROW(s2)
    la t1, android_rows
    slli t0, t0, 4
    add t1, t1, t0
    lwu a1, ROW_NEXT(t1)
    mv a0, s2
    call actor_row
    lwu t0, ACTOR_CLASS(s2)
    beqz t0, 8f                     # the action ended it
    mv a0, s2
    call actor_ms
    bltz t0, 8f
    flw ft0, ACTOR_TIMER(s2)
    flw ft1, 0(sp)
    fadd.s ft0, ft0, ft1
    fsw ft0, ACTOR_TIMER(s2)
    addi s4, s4, -1
    bnez s4, 2b
    j 8f
5:
    flw ft0, ACTOR_TIMER(s2)
    fsub.s ft0, ft0, fs0
    fsw ft0, ACTOR_TIMER(s2)
    la t0, k_zero
    flw ft1, 0(t0)
    flt.s t0, ft1, ft0
    bnez t0, 8f
    lwu t0, ACTOR_FRAME(s2)
    addi t0, t0, 1
    li t1, SPARK_FRAMES
    bltu t0, t1, 6f
    sw zero, ACTOR_CLASS(s2)
    j 8f
6:
    sw t0, ACTOR_FRAME(s2)
    la t0, k_spark_seconds
    flw ft0, 0(t0)
    fsw ft0, ACTOR_TIMER(s2)
8:
    addi s2, s2, ACTOR_SIZE
    addi s3, s3, -1
    j 1b
9:
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    fld fs0, 8(sp)
    addi sp, sp, 48
    ret

actors_draw:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    la s2, actors
    li s3, MAX_ACTORS
1:
    beqz s3, 9f
    lwu t0, ACTOR_CLASS(s2)
    beqz t0, 8f
    lw t0, ACTOR_SECTOR(s2)
    bltz t0, 8f
    la t1, walk_seen
    add t1, t1, t0
    lbu t1, 0(t1)
    beqz t1, 8f
    mv a0, s2
    call actor_index
    li t0, SURFACE_ACTORS
    add a0, a0, t0
    la t0, sprite_surface
    sd a0, 0(t0)
    mv a0, s2
    call actor_draw
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

actor_draw:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    mv s2, a0
    flw ft8, ACTOR_YAW(s2)
    jab.f32.deg ft8, ft8
    la t0, actor_entity
    li t1, CLASS_SPRITE
    sw t1, ENTITY_CLASS(t0)
    fld ft0, ACTOR_X(s2)
    fcvt.s.d ft0, ft0
    fsw ft0, ENTITY_X(t0)
    fld ft0, ACTOR_Y(s2)
    fcvt.s.d ft0, ft0
    fsw ft0, ENTITY_Y(t0)
    fld ft0, ACTOR_Z(s2)
    fcvt.s.d ft0, ft0
    fsw ft0, ENTITY_Z(t0)
    fsw ft8, ENTITY_YAW(t0)
    sw zero, ENTITY_PITCH(t0)
    lw t1, ACTOR_SECTOR(s2)
    sw t1, ENTITY_SECTOR(t0)
    la t1, frame_base
    lwu s3, 0(t1)                   # the material, the frame added below
    lwu t1, ACTOR_CLASS(s2)
    li t2, ACTOR_MAGAZINE
    beq t1, t2, 3f
    li t2, ACTOR_SPARK
    beq t1, t2, 4f
    lwu t1, ACTOR_ROW(s2)
    la t2, android_rows
    slli t1, t1, 4
    add t2, t2, t1
    lw s5, ROW_SET(t2)
    li t2, SET_FALLEN
    beq s5, t2, 2f
    slli t1, s5, 3
    add s3, s3, t1                  # the set's first frame
    mv a0, s2
    call actor_rotation
    add s3, s3, a0
    li s4, ENTITY_CAMERA
    la t0, actor_entity
    la t1, k_two
    flw ft0, 0(t1)
    fsw ft0, ENTITY_HEIGHT(t0)
    li t1, SET_AIM
    beq s5, t1, 21f
    li t1, SET_FIRE
    beq s5, t1, 21f
    la t1, k_one
    flw ft0, 0(t1)
21:
    fsw ft0, ENTITY_WIDTH(t0)
    j 5f
2:
    addi s3, s3, FRAME_FALLEN
    li s4, ENTITY_CAMERA
    la t0, actor_entity
    la t1, k_two
    flw ft0, 0(t1)
    fsw ft0, ENTITY_WIDTH(t0)
    la t1, k_half
    flw ft0, 0(t1)
    fsw ft0, ENTITY_HEIGHT(t0)
    j 5f
3:
    addi s3, s3, FRAME_MAGAZINE
    li s4, ENTITY_FLAT
    j 41f
4:
    addi s3, s3, FRAME_SPARK1
    lwu t0, ACTOR_FRAME(s2)
    add s3, s3, t0
    li s4, (ENTITY_CAMERA | ENTITY_TWO_SIDED)
41:
    la t0, actor_entity
    la t1, k_half
    flw ft0, 0(t1)
    fsw ft0, ENTITY_WIDTH(t0)
    fsw ft0, ENTITY_HEIGHT(t0)
5:
    la t0, actor_entity
    sw s3, ENTITY_MATERIAL(t0)
    sw s4, ENTITY_FLAGS(t0)
    mv a0, t0
    call sprite_draw
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 48
    ret

actor_rotation:
    addi sp, sp, -32
    sd s2, 16(sp)
    fsd fs0, 8(sp)
    fsd fs1, 0(sp)
    mv s2, a0
    flw fa0, ACTOR_YAW(s2)
    jab.f32.sin fs1, fa0            # the facing's y
    jab.f32.cos fs0, fa0            # and x
    la t0, camera
    flw ft0, CAM_X(t0)
    fld ft1, ACTOR_X(s2)
    fcvt.s.d ft1, ft1
    fsub.s ft0, ft0, ft1            # toward the eye
    flw ft2, CAM_Y(t0)
    fld ft3, ACTOR_Y(s2)
    fcvt.s.d ft3, ft3
    fsub.s ft2, ft2, ft3
    fmul.s ft4, fs0, ft0
    fmadd.s ft4, fs1, ft2, ft4      # the cosine's share
    fmul.s ft5, fs1, ft0
    fnmsub.s ft5, fs0, ft2, ft5     # the sine's
    fabs.s ft6, ft4
    fabs.s ft7, ft5
    la t0, k_octant
    flw ft8, 0(t0)
    la t0, k_zero
    flw ft9, 0(t0)
    fmul.s ft10, ft8, ft6
    fle.s t1, ft7, ft10             # within an eighth of the facing or its back
    beqz t1, 1f
    fle.s t1, ft9, ft4
    li a0, 0
    bnez t1, 9f
    li a0, 4
    j 9f
1:
    fmul.s ft10, ft8, ft7
    fle.s t1, ft6, ft10             # within an eighth of a side
    beqz t1, 2f
    flt.s t1, ft9, ft5
    li a0, 2
    bnez t1, 9f
    li a0, 6
    j 9f
2:
    flt.s t1, ft9, ft4              # ahead
    flt.s t2, ft9, ft5              # to its left
    beqz t1, 3f
    li a0, 1
    bnez t2, 9f
    li a0, 7
    j 9f
3:
    li a0, 3
    bnez t2, 9f
    li a0, 5
9:
    ld s2, 16(sp)
    fld fs0, 8(sp)
    fld fs1, 0(sp)
    addi sp, sp, 32
    ret

actor_alloc:
    la a0, actors
    li t1, MAX_ACTORS
1:
    beqz t1, 8f
    lwu t2, ACTOR_CLASS(a0)
    beqz t2, 2f
    addi a0, a0, ACTOR_SIZE
    addi t1, t1, -1
    j 1b
2:
    mv t2, a0
    li t3, (ACTOR_SIZE / 8)
3:
    sd zero, 0(t2)
    addi t2, t2, 8
    addi t3, t3, -1
    bnez t3, 3b
    ret
8:
    li a0, 0
    ret

actor_index:
    la t0, actors
    sub a0, a0, t0
    li t1, ACTOR_SIZE
    divu a0, a0, t1
    ret

actor_event:
    addi sp, sp, -16
    sd ra, 8(sp)
    lwu a3, ACTOR_ROW(a0)
    call actor_index
    mv a2, a0
    li a0, REPORT_ANDROID
    li a4, 0
    li a5, 0
    call event_report
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

actor_chest:
    fld fa0, ACTOR_X(a0)
    fld fa1, ACTOR_Y(a0)
    fld fa2, ACTOR_Z(a0)
    la t0, k_chest_d
    fld ft0, 0(t0)
    fadd.d fa2, fa2, ft0
    ret

actor_rouse:
    lwu t0, ACTOR_FLAGS(a0)
    andi t1, t0, ACTOR_ROUSED
    bnez t1, 9f
    andi t1, t0, ACTOR_SHOOTABLE
    beqz t1, 9f
    ori t0, t0, (ACTOR_ROUSED | ACTOR_FIRST)
    sw t0, ACTOR_FLAGS(a0)
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    li a1, EVENT_ROUSED
    call actor_event
    mv a0, s2
    li a1, ROW_ALERT
    call actor_row
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
9:
    ret

actor_hurt:
    lwu t0, ACTOR_FLAGS(a0)
    andi t1, t0, ACTOR_SHOOTABLE
    beqz t1, 9f
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    lw t1, ACTOR_HEALTH(s2)
    sub t1, t1, a1
    sw t1, ACTOR_HEALTH(s2)
    bgtz t1, 2f
    sw zero, ACTOR_HEALTH(s2)
    li t1, (ACTOR_SOLID | ACTOR_SHOOTABLE)
    not t1, t1
    and t0, t0, t1
    sw t0, ACTOR_FLAGS(s2)
    li a1, EVENT_DESTROYED
    call actor_event
    mv a0, s2
    li a1, ROW_DESTROYED
    call actor_row
    j 8f
2:
    li a1, EVENT_STRUCK
    call actor_event
    mv a0, s2
    li a1, ROW_STRUCK
    call actor_row
8:
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
9:
    ret

spark_spawn:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    fsd fa0, 24(sp)
    fsd fa1, 16(sp)
    fsd fa2, 8(sp)
    mv s2, a0
    call actor_alloc
    beqz a0, 9f
    li t0, ACTOR_SPARK
    sw t0, ACTOR_CLASS(a0)
    sw s2, ACTOR_SECTOR(a0)
    fld ft0, 24(sp)
    fsd ft0, ACTOR_X(a0)
    fld ft0, 16(sp)
    fsd ft0, ACTOR_Y(a0)
    fld ft0, 8(sp)
    la t0, k_spark_drop_d
    fld ft1, 0(t0)
    fsub.d ft0, ft0, ft1
    fsd ft0, ACTOR_Z(a0)
    la t0, k_spark_seconds
    flw ft0, 0(t0)
    fsw ft0, ACTOR_TIMER(a0)
    li a0, SOUND_SPARK
    li a1, 0
    fld fa0, 24(sp)
    fld fa1, 16(sp)
    fld fa2, 8(sp)
    call sound_start
9:
    ld ra, 40(sp)
    ld s2, 32(sp)
    addi sp, sp, 48
    ret

actor_walk:
    addi sp, sp, -96
    sd ra, 88(sp)
    sd s2, 80(sp)
    sd s3, 72(sp)
    fsd fs0, 64(sp)
    fsd fs1, 56(sp)
    fsd fs2, 48(sp)
    fsd fs3, 40(sp)
    fsd fs4, 32(sp)
    fsd fs5, 24(sp)
    fsd fs6, 16(sp)
    mv s2, a0
    fld ft0, ACTOR_X(s2)
    fsub.d fs3, fa0, ft0            # to the point
    fld ft0, ACTOR_Y(s2)
    fsub.d fs4, fa1, ft0
    jab.f64.vec2.reg.len fs5, fs3, fs4  # the distance
    la t0, k_arrive_d
    fld ft1, 0(t0)
    flt.d t1, fs5, ft1
    li s3, 1
    bnez t1, 9f                     # arrived
    la t0, frame_seconds
    flw ft1, 0(t0)
    fcvt.d.s fs6, ft1               # the seconds
    la t0, k_android_speed_d
    fld ft2, 0(t0)
    fmul.d ft2, ft2, fs6            # the step
    fmin.d ft2, ft2, fs5
    fdiv.d ft3, ft2, fs5            # its share of the distance
    fld fs0, ACTOR_X(s2)
    fmadd.d fs0, fs3, ft3, fs0      # the feet after the step
    fld fs1, ACTOR_Y(s2)
    fmadd.d fs1, fs4, ft3, fs1
    fld fs2, ACTOR_Z(s2)
    fsd ft2, 0(sp)                  # the step
    fcvt.s.d fa0, fs4
    fcvt.s.d fa1, fs3
    jab.f32.atan2 fa0, fa0, fa1
    fsw fa0, ACTOR_YAW(s2)
    lw a0, ACTOR_SECTOR(s2)
    addi a1, s2, ACTOR_FALL
    mv a2, s2
    fcvt.s.d fa0, fs6
    call feet_move
    bltz a0, 1f
    sw a0, ACTOR_SECTOR(s2)
1:
    fld ft0, ACTOR_X(s2)
    fsub.d ft0, fs0, ft0
    fld ft1, ACTOR_Y(s2)
    fsub.d ft1, fs1, ft1
    fmul.d ft0, ft0, ft0
    fmadd.d ft0, ft1, ft1, ft0      # the move, squared
    fld ft2, 0(sp)
    la t0, k_quarter_d
    fld ft3, 0(t0)
    fmul.d ft2, ft2, ft3
    fmul.d ft2, ft2, ft2            # a quarter of the step, squared
    flw ft4, ACTOR_BLOCKED(s2)
    flt.d t1, ft0, ft2
    beqz t1, 2f
    fcvt.s.d ft5, fs6
    fadd.s ft4, ft4, ft5            # blocked this frame too
    j 3f
2:
    la t0, k_zero
    flw ft4, 0(t0)
3:
    fsw ft4, ACTOR_BLOCKED(s2)
    fsd fs0, ACTOR_X(s2)
    fsd fs1, ACTOR_Y(s2)
    fsd fs2, ACTOR_Z(s2)
    la t0, k_blocked_seconds
    flw ft5, 0(t0)
    flt.s t1, ft5, ft4
    li s3, 0
    beqz t1, 9f
    li s3, 2
9:
    mv a0, s3
    ld ra, 88(sp)
    ld s2, 80(sp)
    ld s3, 72(sp)
    fld fs0, 64(sp)
    fld fs1, 56(sp)
    fld fs2, 48(sp)
    fld fs3, 40(sp)
    fld fs4, 32(sp)
    fld fs5, 24(sp)
    fld fs6, 16(sp)
    addi sp, sp, 96
    ret

actor_patrol_step:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s2, a0
    lw s3, ACTOR_TARGET(s2)
    bltz s3, 9f
    mv a0, s3
    call entity_at
    flw ft0, ENTITY_X(a0)
    fcvt.d.s fa0, ft0
    flw ft0, ENTITY_Y(a0)
    fcvt.d.s fa1, ft0
    mv a0, s2
    call actor_walk
    beqz a0, 9f
    mv a0, s3
    call entity_at
    lw t0, ENTITY_TARGET(a0)
    sw t0, ACTOR_TARGET(s2)
    sw zero, ACTOR_BLOCKED(s2)
    mv a0, s2
    call actor_chest
    li a0, SOUND_SERVO
    li a1, 0
    call sound_start
    mv a0, s2
    li a1, EVENT_WAYPOINT
    call actor_event
    lw t0, ACTOR_TARGET(s2)
    bgez t0, 9f
    mv a0, s2
    li a1, ROW_STAND
    call actor_row
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

actor_seek_step:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    fld fa0, ACTOR_SEEN_X(s2)
    fld fa1, ACTOR_SEEN_Y(s2)
    call actor_walk
    beqz a0, 9f
    sw zero, ACTOR_BLOCKED(s2)
    lw t0, ACTOR_TARGET(s2)
    li a1, ROW_PATROL1
    bgez t0, 1f
    li a1, ROW_STAND
1:
    mv a0, s2
    call actor_row
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

actor_to_eye:
    la t3, aim
    fld ft0, ACTOR_X(a0)
    fsd ft0, AIM_OX(t3)
    fld ft1, ACTOR_Y(a0)
    fsd ft1, AIM_OY(t3)
    fld ft2, ACTOR_Z(a0)
    la t1, k_body_eye_d
    fld ft3, 0(t1)
    fadd.d ft2, ft2, ft3
    fsd ft2, AIM_OZ(t3)
    la t1, camera
    flw ft3, CAM_X(t1)
    fcvt.d.s ft3, ft3
    fsub.d ft3, ft3, ft0            # to the player's eye
    fsd ft3, AIM_DX(t3)
    flw ft4, CAM_Y(t1)
    fcvt.d.s ft4, ft4
    fsub.d ft4, ft4, ft1
    fsd ft4, AIM_DY(t3)
    flw ft5, CAM_Z(t1)
    fcvt.d.s ft5, ft5
    fsub.d ft5, ft5, ft2
    fsd ft5, AIM_DZ(t3)
    addi t4, t3, AIM_DX
    jab.f64.vec3.len ft8, t4        # the distance
    fsd ft8, AIM_DIST(t3)
    jab.f64.vec3.norm t4, t4        # the unit direction
    flw fa0, ACTOR_YAW(a0)
    jab.f32.sin fa1, fa0
    fcvt.d.s ft9, fa1               # sin yaw
    jab.f32.cos fa1, fa0
    fcvt.d.s ft10, fa1              # cos yaw
    fld ft3, AIM_DX(t3)
    fld ft4, AIM_DY(t3)
    fmul.d fa0, ft10, ft3
    fmadd.d fa0, ft9, ft4, fa0
    ret

actor_sight:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    lwu t0, ACTOR_FLAGS(s2)
    andi t0, t0, ~ACTOR_SIGHTED
    sw t0, ACTOR_FLAGS(s2)
    call actor_to_eye
    la t0, aim
    fld ft0, AIM_DIST(t0)
    la t1, k_sight_range_d
    fld ft1, 0(t1)
    flt.d t2, ft1, ft0
    bnez t2, 8f                     # out of range
    la t1, k_near_sight_d
    fld ft1, 0(t1)
    flt.d t2, ft0, ft1
    bnez t2, 1f                     # near: all round
    fcvt.d.w ft1, zero
    flt.d t2, fa0, ft1
    bnez t2, 8f                     # behind it
1:
    fld fa0, AIM_OX(t0)
    fld fa1, AIM_OY(t0)
    fld fa2, AIM_OZ(t0)
    fld fa3, AIM_DX(t0)
    fld fa4, AIM_DY(t0)
    fld fa5, AIM_DZ(t0)
    fld fa6, AIM_DIST(t0)
    lw a0, ACTOR_SECTOR(s2)
    mv a1, s2
    li a2, TRACE_TO_PLAYER
    call trace_ray
    li t0, TRACE_PLAYER
    bne a0, t0, 8f
    la t0, camera
    flw ft0, CAM_X(t0)
    fcvt.d.s ft0, ft0
    fsd ft0, ACTOR_SEEN_X(s2)
    flw ft0, CAM_Y(t0)
    fcvt.d.s ft0, ft0
    fsd ft0, ACTOR_SEEN_Y(s2)
    flw ft0, CAM_Z(t0)
    fcvt.d.s ft0, ft0
    la t1, k_body_eye_d
    fld ft1, 0(t1)
    fsub.d ft0, ft0, ft1
    fsd ft0, ACTOR_SEEN_Z(s2)
    lwu t0, ACTOR_FLAGS(s2)
    ori t0, t0, ACTOR_SIGHTED
    sw t0, ACTOR_FLAGS(s2)
    sw zero, ACTOR_LOST(s2)
    li a0, 1
    j 9f
8:
    li a0, 0
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

actor_face:
    la t3, camera
    flw fa0, CAM_Y(t3)
    fld ft0, ACTOR_Y(a0)
    fcvt.s.d ft0, ft0
    fsub.s fa0, fa0, ft0
    flw fa1, CAM_X(t3)
    fld ft0, ACTOR_X(a0)
    fcvt.s.d ft0, ft0
    fsub.s fa1, fa1, ft0
    jab.f32.atan2 fa0, fa0, fa1
    fsw fa0, ACTOR_YAW(a0)
    ret

actor_footstep:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    lwu t0, ACTOR_ROW(s2)
    li t1, ROW_PATROL1
    li a0, SOUND_FOOTSTEP1
    beq t0, t1, 1f
    li t1, ROW_SEARCH1
    beq t0, t1, 1f
    li t1, ROW_PATROL3
    li a0, SOUND_FOOTSTEP2
    beq t0, t1, 1f
    li t1, ROW_SEARCH3
    beq t0, t1, 1f
    j 9f
1:
    fld fa0, ACTOR_X(s2)
    fld fa1, ACTOR_Y(s2)
    fld fa2, ACTOR_Z(s2)
    li a1, 0
    call sound_start
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

action_none:
    ret

action_look:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    call actor_sight
    beqz a0, 9f
    mv a0, s2
    call actor_rouse
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

action_walk:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    call actor_footstep
    mv a0, s2
    call action_look
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

action_alert:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    call actor_face
    mv a0, s2
    call actor_chest
    li a0, SOUND_ALERT
    li a1, 0
    call sound_start
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

action_aim:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    call actor_face
    mv a0, s2
    call actor_sight
    bnez a0, 9f
    flw ft0, ACTOR_LOST(s2)
    la t0, k_cycle_seconds
    flw ft1, 0(t0)
    fadd.s ft0, ft0, ft1
    fsw ft0, ACTOR_LOST(s2)
    la t0, k_lost_seconds
    flw ft1, 0(t0)
    flt.s t1, ft1, ft0
    beqz t1, 9f
    sw zero, ACTOR_LOST(s2)
    mv a0, s2
    li a1, ROW_SEARCH1
    call actor_row
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

action_fire:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    lwu t0, ACTOR_FLAGS(s2)
    andi t1, t0, ACTOR_SIGHTED
    beqz t1, 9f
    andi t1, t0, ACTOR_FIRST
    bnez t1, 1f
    la t3, rng
    jab.rng.byte a0, t3
    li t0, FIRE_CHANCE
    bgeu a0, t0, 9f                 # held this cycle
    j 2f
1:
    andi t0, t0, ~ACTOR_FIRST
    sw t0, ACTOR_FLAGS(s2)
2:
    mv a0, s2
    call actor_chest
    li a0, SOUND_G1_SHOT
    li a1, 0
    call sound_start
    mv a0, s2
    call actor_to_eye
    la t3, rng
    jab.rng.byte a0, t3
    addi t0, a0, -128
    fcvt.d.w ft8, t0
    la t1, k_stray_d
    fld ft1, 0(t1)
    fmul.d ft8, ft8, ft1            # along the right
    jab.rng.byte a0, t3
    addi t0, a0, -128
    fcvt.d.w ft9, t0
    fmul.d ft9, ft9, ft1            # upward
    la t4, aim
    addi t5, t4, AIM_DX
    jab.f64.vec2.len ft10, t5       # the level length
    la t1, k_trace_eps_d
    fld ft7, 0(t1)
    fmax.d ft10, ft10, ft7
    fld ft3, AIM_DX(t4)
    fld ft4, AIM_DY(t4)
    fld ft5, AIM_DZ(t4)
    fdiv.d ft7, ft4, ft10           # the level right, (dy, -dx) over it
    fdiv.d ft6, ft3, ft10
    fneg.d ft6, ft6
    fmadd.d ft3, ft7, ft8, ft3
    fmadd.d ft4, ft6, ft8, ft4
    fadd.d ft5, ft5, ft9
    jab.f64.vec3.reg.norm ft3, ft4, ft5
    fmv.d fa3, ft3
    fmv.d fa4, ft4
    fmv.d fa5, ft5
    fld fa0, AIM_OX(t4)
    fld fa1, AIM_OY(t4)
    fld fa2, AIM_OZ(t4)
    la t1, k_round_range_d
    fld fa6, 0(t1)
    lw a0, ACTOR_SECTOR(s2)
    mv a1, s2
    li a2, TRACE_TO_PLAYER
    call trace_ray
    li t0, TRACE_PLAYER
    bne a0, t0, 1f
    li a0, ROUND_DAMAGE
    call player_hurt
    j 2f
1:
    beqz a0, 2f
    la t0, trace_hit
    fld fa0, TRACE_PX(t0)
    fld fa1, TRACE_PY(t0)
    fld fa2, TRACE_PZ(t0)
    ld a0, TRACE_SECTOR(t0)
    call spark_spawn
2:
    mv a0, s2
    li a1, EVENT_FIRED
    call actor_event
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

action_seek:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    call actor_footstep
    mv a0, s2
    call actor_sight
    beqz a0, 9f
    mv a0, s2
    li a1, ROW_ALERT
    call actor_row
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

action_struck:
    addi sp, sp, -16
    sd ra, 8(sp)
    lwu t0, ACTOR_FLAGS(a0)
    ori t0, t0, ACTOR_ROUSED
    sw t0, ACTOR_FLAGS(a0)
    call actor_chest
    li a0, SOUND_STRUCK
    li a1, 0
    call sound_start
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

action_destroy:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s2, a0
    call actor_chest
    li a0, SOUND_DESTROY
    li a1, 0
    call sound_start
    li s3, 3
1:
    beqz s3, 9f
    la t3, rng
    jab.rng.byte a0, t3
    addi t0, a0, -128
    fcvt.d.w ft0, t0
    la t1, k_spark_spread_d
    fld ft1, 0(t1)
    fmul.d ft0, ft0, ft1
    fsd ft0, 0(sp)
    jab.rng.byte a0, t3
    addi t0, a0, -128
    fcvt.d.w ft0, t0
    fmul.d ft2, ft0, ft1
    mv a0, s2
    call actor_chest
    fld ft0, 0(sp)
    fadd.d fa0, fa0, ft0
    fadd.d fa2, fa2, ft2
    lw a0, ACTOR_SECTOR(s2)
    call spark_spawn
    addi s3, s3, -1
    j 1b
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

action_fall:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s2, a0
    call actor_alloc
    beqz a0, 8f
    mv s3, a0
    li t0, ACTOR_MAGAZINE
    sw t0, ACTOR_CLASS(s3)
    lw t0, ACTOR_SECTOR(s2)
    sw t0, ACTOR_SECTOR(s3)
    flw fa0, ACTOR_YAW(s2)
    jab.f32.sin fa1, fa0
    fcvt.d.s ft8, fa1               # sin yaw
    jab.f32.cos fa1, fa0
    fcvt.d.s ft9, fa1               # cos yaw
    la t0, k_half_d
    fld ft4, 0(t0)
    fld ft0, ACTOR_X(s2)
    fmadd.d ft0, ft8, ft4, ft0      # to its right: (sin yaw, -cos yaw)
    fsd ft0, ACTOR_X(s3)
    fld ft0, ACTOR_Y(s2)
    fnmsub.d ft0, ft9, ft4, ft0
    fsd ft0, ACTOR_Y(s3)
    fld ft0, ACTOR_Z(s2)
    fsd ft0, ACTOR_Z(s3)
    flw ft0, ACTOR_YAW(s2)
    fsw ft0, ACTOR_YAW(s3)
8:
    mv a0, s2
    li a1, EVENT_FALLEN
    call actor_event
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

.section .rodata
.balign 8
k_chest_d:
    .double 1.2
k_spark_drop_d:
    .double 0.25
k_spark_spread_d:
    .double 0.004
k_android_speed_d:
    .double 1.5
k_arrive_d:
    .double 0.3
k_quarter_d:
    .double 0.25
k_sight_range_d:
    .double 40.0
k_near_sight_d:
    .double 3.0
k_stray_d:
    .double 0.0016606
.balign 4
k_blocked_seconds:
    .float 1.0
k_cycle_seconds:
    .float 0.75
k_lost_seconds:
    .float 2.0

.section .bss
.balign 8
actors:
    .skip (MAX_ACTORS * ACTOR_SIZE)
actor_entity:
    .skip ENTITY_SIZE
aim:
    .skip AIM_SIZE
