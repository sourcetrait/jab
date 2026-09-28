# actor.S: the engine's things in play, the actors: the androids the
# map places, the magazines they drop, the sparks where a round lands.
# An android runs its rows, a frame set for its milliseconds with an
# action on entry: it stands or patrols its waypoints looking for the
# player, rouses when it sees or hears one, aims and fires the G-1,
# searches where it last saw the player, flinches when struck, and
# falls when destroyed, dropping its magazine. Every actor draws through
# sprite_draw from a scratch entity record, an android's frame chosen
# by its row's set and the eighth of a turn its facing makes with the
# direction to the eye, so its front shows when it faces the eye and its
# right side two eighths on.

.section .rodata
.balign 8
# The engine's images: the rotating sets' stems, then the singles'
frame_sets:
    .dword word_set_stand, word_set_walk1, word_set_walk2, word_set_walk3
    .dword word_set_walk4, word_set_aim, word_set_fire, word_set_struck
frame_singles:
    .dword word_single_fallen, word_single_spark1, word_single_spark2
    .dword word_single_spark3, word_single_magazine
# An android's rows: the set, the milliseconds, the action, the next
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
# The tangent of an eighth of a half turn, the octants' edge
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

# actors_place: every actor gone, then one placed for each android and
# magazine entity of the map: facing the entity's yaw, its target the
# entity's, its feet on its sector's floor; an android whole in its
# first row.
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
    flw ft0, ENTITY_YAW(s5)
    la t3, k_degree
    flw ft1, 0(t3)
    fmul.s ft0, ft0, ft1
    fsw ft0, ACTOR_YAW(s4)
    lw t3, ENTITY_SECTOR(s5)
    sw t3, ACTOR_SECTOR(s4)
    lw t3, ENTITY_TARGET(s5)
    sw t3, ACTOR_TARGET(s4)
    li t3, -1
    sw t3, ACTOR_ROW(s4)
    # the feet on the sector's floor
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
    # patrolling from the start when it has a waypoint, else standing
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

# actor_row: the actor a0 put in the row a1: its timer the row's
# milliseconds in seconds, and the row's action taken.
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

# actor_ms: t0 becomes the milliseconds of the actor a0's row, negative
# for a held row. Clobbers t0, t1.
actor_ms:
    lwu t0, ACTOR_ROW(a0)
    la t1, android_rows
    slli t0, t0, 4
    add t0, t0, t1
    lw t0, ROW_MS(t0)
    ret

# actors_tick: one frame of every actor: an android's row's timer run
# by the frame's seconds, a row ended entering the next with the
# leftover carried, a held row staying; a spark's frame advanced every
# SPARK_FRAMES of a second's twentieths and the spark gone after its
# last.
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
    # a walking row steps toward its target
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
    # a spark
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

# actors_draw: every actor whose sector the walk reached drawn.
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

# actor_draw: the actor a0 drawn through sprite_draw from the scratch
# entity: its feet, its yaw, its sector, and by its class and row the
# frame's material, the quad's size, and the facing: a rotating set a
# metre by two, or two by two for aim and fire, facing the camera;
# fallen two metres by half a metre facing the camera, the body lying
# on the floor seen from its side; a spark half a metre facing the
# camera, two-sided; the magazine half a metre flat.
actor_draw:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    mv s2, a0
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
    flw ft0, ACTOR_YAW(s2)
    la t1, k_degrees
    flw ft1, 0(t1)
    fmul.s ft0, ft0, ft1
    fsw ft0, ENTITY_YAW(t0)
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
    # an android: its row's set
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

# actor_rotation: a0 becomes the rotation frame, 0 to 7, of the actor
# a0 as the eye sees it: the eighth of a turn nearest the angle from
# the direction toward the eye to the actor's facing, 0 facing the eye
# and 2 showing its right side; by the octant of the angle's cosine and
# sine, each from the facing and the direction in the plan.
actor_rotation:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    fsd fs0, 8(sp)
    fsd fs1, 0(sp)
    mv s2, a0
    flw fa0, ACTOR_YAW(s2)
    call sine
    fmv.s fs1, fa0                  # the facing's y
    flw fa0, ACTOR_YAW(s2)
    call cosine
    fmv.s fs0, fa0                  # and x
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
    ld ra, 24(sp)
    ld s2, 16(sp)
    fld fs0, 8(sp)
    fld fs1, 0(sp)
    addi sp, sp, 32
    ret

# actor_alloc: a0 becomes a free actor, cleared, or 0 when the table is
# full. Clobbers t0 to t3.
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

# actor_index: a0 becomes the index of the actor a0 in the table.
# Clobbers t0, t1.
actor_index:
    la t0, actors
    sub a0, a0, t0
    li t1, ACTOR_SIZE
    divu a0, a0, t1
    ret

# actor_event: the actor a0's event a1 reported over the API with its
# index and its row.
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

# actor_chest: fa0, fa1, fa2 become the point at the actor a0's chest,
# CHEST_HEIGHT over its feet, doubles. Clobbers t0.
actor_chest:
    fld fa0, ACTOR_X(a0)
    fld fa1, ACTOR_Y(a0)
    fld fa2, ACTOR_Z(a0)
    la t0, k_chest_d
    fld ft0, 0(t0)
    fadd.d fa2, fa2, ft0
    ret

# actor_rouse: the actor a0 roused, into ALERT, unless it is already or
# is no longer shootable.
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

# actor_hurt: the actor a0 hurt by a1: its health less it; at none,
# destroyed, neither solid nor shootable, else struck, either reported
# and its row entered.
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

# spark_spawn: a spark at the point fa0, fa1, fa2, doubles, in the
# sector a0: a free actor of class spark on its first frame, its feet a
# quarter metre under the point so the quad centres on it; the spark's
# sound there.
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

# actor_walk: the actor a0 walked toward the point fa0, fa1, doubles,
# for the frame: at its speed times the seconds, no further than the
# point, facing its heading, the feet through feet_move; a step that
# made under a quarter of itself counts the frame as blocked. a0
# becomes 1 arrived within the arrival radius, 2 blocked for
# BLOCKED_SECONDS, else 0.
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
    fmul.d ft0, fs3, fs3
    fmadd.d ft0, fs4, fs4, ft0
    fsqrt.d fs5, ft0                # the distance
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
    # facing the heading
    fcvt.s.d fa0, fs4
    fcvt.s.d fa1, fs3
    call atan2
    fsw fa0, ACTOR_YAW(s2)
    lw a0, ACTOR_SECTOR(s2)
    addi a1, s2, ACTOR_FALL
    mv a2, s2
    fcvt.s.d fa0, fs6
    call feet_move
    bltz a0, 1f
    sw a0, ACTOR_SECTOR(s2)
1:
    # the move made against the step
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

# actor_patrol_step: the actor a0's frame of its patrol: walked toward
# its target waypoint; arrived or blocked, the waypoint's own target
# becomes its, the servo sounds at its chest and the waypoint is
# reported, and a waypoint with no target leaves it standing.
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

# actor_seek_step: the actor a0's frame of its search: walked toward
# where it last saw the player; arrived or blocked, its patrol resumes
# at its waypoint, or it stands when it has none.
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

# actor_to_eye: the line from the actor a0's eye to the player's into
# aim: the eye, the unit direction, and the distance, doubles, and its
# level direction to the player in the plan against the actor's facing
# as the cosine's share, fa0. Clobbers t0, ft0 to ft7; sine and cosine
# clobber theirs.
actor_to_eye:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    la t0, aim
    fld ft0, ACTOR_X(s2)
    fsd ft0, AIM_OX(t0)
    fld ft1, ACTOR_Y(s2)
    fsd ft1, AIM_OY(t0)
    fld ft2, ACTOR_Z(s2)
    la t1, k_body_eye_d
    fld ft3, 0(t1)
    fadd.d ft2, ft2, ft3
    fsd ft2, AIM_OZ(t0)
    la t1, camera
    flw ft3, CAM_X(t1)
    fcvt.d.s ft3, ft3
    fsub.d ft3, ft3, ft0            # to the player's eye
    flw ft4, CAM_Y(t1)
    fcvt.d.s ft4, ft4
    fsub.d ft4, ft4, ft1
    flw ft5, CAM_Z(t1)
    fcvt.d.s ft5, ft5
    fsub.d ft5, ft5, ft2
    fmul.d ft6, ft3, ft3
    fmadd.d ft6, ft4, ft4, ft6
    fmadd.d ft6, ft5, ft5, ft6
    fsqrt.d ft6, ft6                # the distance
    fsd ft6, AIM_DIST(t0)
    la t1, k_trace_eps_d
    fld ft7, 0(t1)
    fmax.d ft7, ft6, ft7
    fdiv.d ft3, ft3, ft7
    fdiv.d ft4, ft4, ft7
    fdiv.d ft5, ft5, ft7
    fsd ft3, AIM_DX(t0)
    fsd ft4, AIM_DY(t0)
    fsd ft5, AIM_DZ(t0)
    # the facing's share of the level direction
    flw fa0, ACTOR_YAW(s2)
    call sine
    fcvt.d.s ft1, fa0
    fsd ft1, 0(sp)                  # sin yaw, held past the cosine
    flw fa0, ACTOR_YAW(s2)
    call cosine
    fcvt.d.s ft0, fa0
    fld ft1, 0(sp)
    la t0, aim
    fld ft3, AIM_DX(t0)
    fld ft4, AIM_DY(t0)
    fmul.d fa0, ft0, ft3
    fmadd.d fa0, ft1, ft4, fa0
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

# actor_sight: a0 becomes 1 when the actor a0 sees the player: within
# sight range and the front half turn, or within the near range all
# round, and the trace from eye to eye reaching the player's capsule;
# then its last sight is the player's feet and it is sighted; else 0
# and not sighted.
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
    # seen: the player's feet remembered
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

# actor_face: the actor a0 turned to the player.
actor_face:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    la t0, camera
    flw fa0, CAM_Y(t0)
    fld ft0, ACTOR_Y(s2)
    fcvt.s.d ft0, ft0
    fsub.s fa0, fa0, ft0
    flw fa1, CAM_X(t0)
    fld ft0, ACTOR_X(s2)
    fcvt.s.d ft0, ft0
    fsub.s fa1, fa1, ft0
    call atan2
    fsw fa0, ACTOR_YAW(s2)
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

# actor_footstep: the actor a0's footstep for its row, the first on the
# first walking frame and the second on the third, at its feet.
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

# The actions, each the actor a0's on entering a row.
action_none:
    ret

# action_look: the player seen rouses it.
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

# action_walk: a patrol row: its footstep, then the look.
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

# action_alert: the alert sound at its chest, faced to the player.
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

# action_aim: faced to the player and the sight taken; the sight lost
# for LOST_SECONDS, counted a cycle of aim and fire at a time, sends it
# searching where it last saw the player.
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

# action_fire: with the player sighted, a round, the first after
# rousing certain and the rest by FIRE_CHANCE in 256: the G-1's report
# at its chest, the line from its eye to the player's strayed by chance
# within the G-1's stray, traced to the player's capsule; the player
# met hurt by the round's damage, else a spark where the round lands;
# the round reported.
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
    call random_byte
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
    # the stray: the direction moved along the level right and up by
    # two shares of chance, then made unit again
    call random_byte
    addi t0, a0, -128
    fcvt.d.w ft0, t0
    la t1, k_stray_d
    fld ft1, 0(t1)
    fmul.d ft0, ft0, ft1            # along the right
    fsd ft0, 0(sp)
    call random_byte
    addi t0, a0, -128
    fcvt.d.w ft2, t0
    la t1, k_stray_d
    fld ft1, 0(t1)
    fmul.d ft2, ft2, ft1            # upward
    fld ft0, 0(sp)
    la t0, aim
    fld ft3, AIM_DX(t0)
    fld ft4, AIM_DY(t0)
    fld ft5, AIM_DZ(t0)
    fmul.d ft6, ft3, ft3
    fmadd.d ft6, ft4, ft4, ft6
    fsqrt.d ft6, ft6                # the level length
    la t1, k_trace_eps_d
    fld ft7, 0(t1)
    fmax.d ft6, ft6, ft7
    fdiv.d ft7, ft4, ft6            # the level right, (dy, -dx) over it
    fdiv.d ft8, ft3, ft6
    fneg.d ft8, ft8
    fmadd.d ft3, ft7, ft0, ft3
    fmadd.d ft4, ft8, ft0, ft4
    fadd.d ft5, ft5, ft2
    fmul.d ft6, ft3, ft3
    fmadd.d ft6, ft4, ft4, ft6
    fmadd.d ft6, ft5, ft5, ft6
    fsqrt.d ft6, ft6
    fdiv.d fa3, ft3, ft6
    fdiv.d fa4, ft4, ft6
    fdiv.d fa5, ft5, ft6
    fld fa0, AIM_OX(t0)
    fld fa1, AIM_OY(t0)
    fld fa2, AIM_OZ(t0)
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

# action_seek: a search row: its footstep, then the look, the player
# seen rousing it afresh.
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

# action_struck: the struck sound at its chest; roused.
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

# action_destroy: the destruction's sound at its chest and three sparks
# about it, each within half a metre by chance.
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
    call random_byte
    addi t0, a0, -128
    fcvt.d.w ft0, t0
    la t1, k_spark_spread_d
    fld ft1, 0(t1)
    fmul.d ft0, ft0, ft1
    fsd ft0, 0(sp)
    call random_byte
    addi t0, a0, -128
    fcvt.d.w ft0, t0
    la t1, k_spark_spread_d
    fld ft1, 0(t1)
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

# action_fall: the magazine dropped beside the fallen frame, half a
# metre to the android's right, on its floor; the fall reported.
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
    call sine
    fcvt.d.s ft2, fa0
    fsd ft2, 0(sp)                  # sin yaw, held past the cosine
    flw fa0, ACTOR_YAW(s2)
    call cosine
    fcvt.d.s ft3, fa0               # cos yaw
    fld ft2, 0(sp)
    la t0, k_half_d
    fld ft4, 0(t0)
    fld ft0, ACTOR_X(s2)
    fmadd.d ft0, ft2, ft4, ft0      # to its right: (sin yaw, -cos yaw)
    fsd ft0, ACTOR_X(s3)
    fld ft0, ACTOR_Y(s2)
    fnmsub.d ft0, ft3, ft4, ft0
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
# The chest over the feet, a spark's drop under its point, and how far
# the destruction's sparks spread a unit of chance
k_chest_d:
    .double 1.2
k_spark_drop_d:
    .double 0.25
k_spark_spread_d:
    .double 0.004
# The android's numbers: its walk a second, the arrival radius, its
# sight's range and the range all round, and the G-1's stray a unit of
# chance, the tangent of twelve degrees over 128
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
# The seconds blocked before a waypoint is given up, a cycle of aim and
# fire, and the seconds without sight before the search
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
# The scratch entity an actor draws through
actor_entity:
    .skip ENTITY_SIZE
# The line from an actor's eye to the player's: the eye, the unit
# direction, the distance
aim:
    .skip AIM_SIZE
