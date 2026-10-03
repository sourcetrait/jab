.include "jab.inc"

.set RADIUS, 90
.set BACKGROUND, 0x00000000
.set PLAYER, 0x00ff5533
.set BALL, 0x008f00ff
.set LEFT, RADIUS
.set RIGHT, (JAB_DISPLAY_WIDTH - 1 - RADIUS)
.set TOP, RADIUS
.set BOTTOM, (JAB_DISPLAY_HEIGHT - 1 - RADIUS)
.set FIX, 8
.set ONE, (1 << FIX)
.set BALL_VX, (210 * ONE)
.set BALL_VY, (150 * ONE)
.set TOP_SPEED, (780 * ONE)
.set ACCEL, (720 * ONE)
.set DECEL, (450 * ONE)
.set DT_MAX, (JAB_TIME_HZ / 10)
.set TOUCH_SQ, ((2 * RADIUS + 2) * (2 * RADIUS + 2))
.set APART, ((2 * RADIUS + 3) * ONE)

.set CMD_SIZE, 4
.set CMD_CODE, 0
.set CMD_VALUE, 2
.set CMD_READ_BYTES, 64
.set REPORT_SIZE, 12
.set REPORT_KIND, 0
.set REPORT_SPHERE, 1
.set REPORT_AGAINST, 2
.set REPORT_X, 4
.set REPORT_Y, 8
.set REPORT_VELOCITY, 1
.set REPORT_ACCELERATION, 2
.set REPORT_HIT, 3
.set REPORT_COLOR, 4
.set SPHERE_PLAYER, 1
.set SPHERE_BALL, 2
.set AGAINST_WALL, 0
.set REPORT_MAX, 10
.set BUTTONS, 32
.set COLOR_FLOOR, 64
.set COLOR_SPAN, 192
.set LABEL_SCALE, 384
.set LABEL_CELL, (JAB_TEXT_WIDTH * LABEL_SCALE / 256)
.set LABEL_HEIGHT, (JAB_TEXT_HEIGHT * LABEL_SCALE / 256)
.set LABEL_Y, 16
.set LABEL_COLOR, 0x00ebe6dc
.set LABEL_TIME, (3 * JAB_TIME_HZ)
.set NAMED_BUTTONS, 16
.set NO_BUTTON, -1
.set ACCEL_MAX, (ACCEL * 2)
.set BAND, (JAB_PAD_FULL / 3)

.section .text
.global _start
_start:
    jab.sys.display.open
    bnez a0, no_display
    li t0, PLAYER
    la t1, player_color
    sw t0, 0(t1)
    la t0, rand_state
    li t1, 8
    jab.sys.random t0, t1
    beqz a0, 0f
    rdtime t0
    la t1, rand_state
    sd t0, 0(t1)
0:
    la t1, rand_state
    ld t0, 0(t1)
    bnez t0, 5f
    li t0, 1
    sd t0, 0(t1)
5:
    call assign_colors
    la t0, pad_name
    jab.sys.pad.name t0
    bnez a0, 2f
    la t0, pad_name
    la t1, label_text
    sd t0, 0(t1)
    li t0, NO_BUTTON
    la t1, label_code
    sd t0, 0(t1)
    li t0, LABEL_TIME
    la t1, label_left
    sd t0, 0(t1)
    la t1, label_changed
    li t0, 1
    sb t0, 0(t1)
2:
    li t0, JAB_PAD_AXES + 2 * JAB_ABS_Z
    la t1, right_x
    sd t0, 0(t1)
    li t0, JAB_PAD_AXES + 2 * JAB_ABS_RZ
    la t1, right_y
    sd t0, 0(t1)
    la t0, axis_record
    jab.sys.pad.axis t0, JAB_ABS_Z
    li t1, 2
    bne a0, t1, 3f
    li t0, JAB_PAD_AXES + 2 * JAB_ABS_RX
    la t1, right_x
    sd t0, 0(t1)
    li t0, JAB_PAD_AXES + 2 * JAB_ABS_RY
    la t1, right_y
    sd t0, 0(t1)
3:
    li t0, (JAB_DISPLAY_WIDTH / 2) * ONE
    la t1, player_x
    sd t0, 0(t1)
    li t0, (JAB_DISPLAY_HEIGHT / 2) * ONE
    la t1, player_y
    sd t0, 0(t1)
    rdtime t0
    li t1, JAB_DISPLAY_WIDTH - 2 * RADIUS
    remu t2, t0, t1
    addi t2, t2, RADIUS
    slli t2, t2, FIX
    la t1, ball_x
    sd t2, 0(t1)
    li t1, 7919
    divu t0, t0, t1
    li t1, JAB_DISPLAY_HEIGHT - 2 * RADIUS
    remu t2, t0, t1
    addi t2, t2, RADIUS
    slli t2, t2, FIX
    la t1, ball_y
    sd t2, 0(t1)
    li t0, BALL_VX
    la t1, ball_vx
    sd t0, 0(t1)
    li t0, BALL_VY
    la t1, ball_vy
    sd t0, 0(t1)
    call collide
    call remember
    rdtime t0
    la t1, last_time
    sd t0, 0(t1)
frame:
    jab.sys.await JAB_AWAIT_DISPLAY | JAB_AWAIT_KEYBOARD | JAB_AWAIT_API | JAB_AWAIT_PAD
    mv s0, a0
    call read_keys
    call read_api
    call read_pad
    andi t0, s0, JAB_AWAIT_DISPLAY
    beqz t0, frame
    call elapsed
    la t0, pad_state
    jab.sys.pad.read t0
    call label_tick
    call right_stick
    call move_player
    call move_ball
    call collide
    call report
    call render
    j frame

no_display:
    jab.sys.uart.print msg_no_display
    jab.sys.exit 1

read_keys:
    addi sp, sp, -16
    sd ra, 8(sp)
1:
    jab.sys.keyboard.input
    beqz a0, 9f
    call apply_key
    j 1b
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

read_api:
    addi sp, sp, -48
    sd ra, 40(sp)
1:
    la t0, cmd_read
    jab.sys.api.read t0, CMD_READ_BYTES
    beqz a0, 9f
    la t0, cmd_read
    sd t0, 0(sp)                # the next byte to take
    sd a0, 8(sp)                # bytes left to take
2:
    ld t1, 8(sp)
    beqz t1, 1b
    ld t0, 0(sp)
    lbu t2, 0(t0)
    addi t0, t0, 1
    sd t0, 0(sp)
    addi t1, t1, -1
    sd t1, 8(sp)
    la t3, cmd_pending
    ld t4, 0(t3)
    la t5, cmd_partial
    add t5, t5, t4
    sb t2, 0(t5)
    addi t4, t4, 1
    sd t4, 0(t3)
    li t5, CMD_SIZE
    bne t4, t5, 2b
    sd zero, 0(t3)
    la t5, cmd_partial
    lhu a0, CMD_CODE(t5)
    lhu a1, CMD_VALUE(t5)
    call apply_key
    j 2b
9:
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

read_pad:
1:
    jab.sys.pad.input
    beqz a0, 9f
    li t0, JAB_EV_KEY
    bne a0, t0, 1b
    addi t0, a1, -JAB_BTN_GAMEPAD
    li t1, BUTTONS
    bgeu t0, t1, 1b
    li t1, JAB_KEY_PRESSED
    beq a2, t1, 3f
    bnez a2, 1b                 # held: nothing new
    la t1, label_code
    ld t1, 0(t1)
    bne a1, t1, 1b
    li t1, LABEL_TIME
    la t2, label_left
    sd t1, 0(t2)
    j 1b
3:
    la t1, label_code
    sd a1, 0(t1)
    la t1, label_left
    sd zero, 0(t1)
    li t3, NAMED_BUTTONS - 1
    bgeu t0, t3, 4f
    mv t3, t0
4:
    slli t3, t3, 3
    la t1, button_names
    add t1, t1, t3
    ld t1, 0(t1)
    la t2, label_text
    sd t1, 0(t2)
    la t1, label_changed
    li t2, 1
    sb t2, 0(t1)
    li t1, JAB_BTN_THUMBL
    beq a1, t1, 7f
    li t1, JAB_BTN_THUMBR
    bne a1, t1, 6f
7:
    la t0, player_vx
    sd zero, 0(t0)
    la t0, player_vy
    sd zero, 0(t0)
    j 1b
6:
    slli t0, t0, 2
    la t1, button_colors
    add t1, t1, t0
    lwu t0, 0(t1)
    la t1, player_color
    sw t0, 0(t1)
    la t1, color_code
    sd a1, 0(t1)
    la t1, color_changed
    li t0, 1
    sb t0, 0(t1)
    j 1b
9:
    ret

label_tick:
    la t0, label_left
    ld t1, 0(t0)
    blez t1, 9f
    la t2, dt
    ld t2, 0(t2)
    sub t1, t1, t2
    bgtz t1, 8f
    li t1, 0
    la t2, name_none
    la t3, label_text
    sd t2, 0(t3)
    li t2, NO_BUTTON
    la t3, label_code
    sd t2, 0(t3)
    la t3, label_changed
    li t2, 1
    sb t2, 0(t3)
8:
    sd t1, 0(t0)
9:
    ret

elapsed:
    rdtime t0
    la t1, last_time
    ld t2, 0(t1)
    sd t0, 0(t1)
    sub t0, t0, t2
    li t1, DT_MAX
    bleu t0, t1, 1f
    mv t0, t1
1:
    la t1, dt
    sd t0, 0(t1)
    ret

advance:
    la t0, dt
    ld t0, 0(t0)
    mul t1, a1, t0
    li t2, JAB_TIME_HZ
    div t1, t1, t2
    add a0, a0, t1
    ret

right_stick:
    addi sp, sp, -32
    sd ra, 24(sp)
    call right_axes
    or t1, a0, a1
    beqz t1, 9f
    sd a0, 0(sp)
    sd a1, 8(sp)
    mul a2, a0, a0
    mul a3, a1, a1
    add a0, a2, a3
    call isqrt
    li t2, JAB_PAD_FULL
    bleu a0, t2, 1f
    mv a0, t2
1:
    li t4, 255
    mul a0, a0, t4
    divu a0, a0, t2             # blue, from how far
    li t5, 2 * JAB_PAD_FULL
    ld t3, 0(sp)
    add t3, t3, t2
    mul t3, t3, t4
    divu t3, t3, t5             # red, from x
    ld t6, 8(sp)
    add t6, t6, t2
    mul t6, t6, t4
    divu t6, t6, t5             # green, from y
    slli t3, t3, 16
    slli t6, t6, 8
    or t3, t3, t6
    or t3, t3, a0
    la t0, player_color
    sw t3, 0(t0)
9:
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

right_axes:
    la t0, pad_state
    la t1, right_x
    ld t1, 0(t1)
    add t1, t1, t0
    lh a0, 0(t1)
    la t1, right_y
    ld t1, 0(t1)
    add t1, t1, t0
    lh a1, 0(t1)
    ret

assign_colors:
    addi sp, sp, -16
    sd ra, 8(sp)
    la s1, button_colors
    li s2, BUTTONS
1:
    call random_color
    sw a0, 0(s1)
    addi s1, s1, 4
    addi s2, s2, -1
    bnez s2, 1b
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

random_color:
    addi sp, sp, -16
    sd ra, 8(sp)
    call random
    li t0, COLOR_SPAN
    remu t1, a0, t0
    addi t1, t1, COLOR_FLOOR
    slli s3, t1, 16
    call random
    li t0, COLOR_SPAN
    remu t1, a0, t0
    addi t1, t1, COLOR_FLOOR
    slli t1, t1, 8
    or s3, s3, t1
    call random
    li t0, COLOR_SPAN
    remu t1, a0, t0
    addi t1, t1, COLOR_FLOOR
    or a0, s3, t1
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

random:
    la t0, rand_state
    ld t1, 0(t0)
    slli t2, t1, 13
    xor t1, t1, t2
    srli t2, t1, 7
    xor t1, t1, t2
    slli t2, t1, 17
    xor t1, t1, t2
    sd t1, 0(t0)
    mv a0, t1
    ret

apply_key:
    li t0, JAB_KEY_SPACE
    bne a0, t0, 2f
    li t0, JAB_KEY_PRESSED
    bne a1, t0, 9f
    la t0, player_vx
    sd zero, 0(t0)
    la t0, player_vy
    sd zero, 0(t0)
    ret
2:
    snez t1, a1
    li t0, JAB_KEY_W
    bne a0, t0, 3f
    la t2, held_w
    sb t1, 0(t2)
    ret
3:
    li t0, JAB_KEY_A
    bne a0, t0, 4f
    la t2, held_a
    sb t1, 0(t2)
    ret
4:
    li t0, JAB_KEY_S
    bne a0, t0, 5f
    la t2, held_s
    sb t1, 0(t2)
    ret
5:
    li t0, JAB_KEY_D
    bne a0, t0, 9f
    la t2, held_d
    sb t1, 0(t2)
9:
    ret

drive_vector:
    addi sp, sp, -48
    sd ra, 40(sp)
    la t0, held_d
    lbu a0, 0(t0)
    la t0, held_a
    lbu t1, 0(t0)
    sub a0, a0, t1
    li t1, ACCEL
    mul a0, a0, t1
    la t0, held_s
    lbu a1, 0(t0)
    la t0, held_w
    lbu t2, 0(t0)
    sub a1, a1, t2
    mul a1, a1, t1
    la t0, pad_state
    lh t2, (JAB_PAD_AXES + 2 * JAB_ABS_X)(t0)
    mul t2, t2, t1
    li t3, JAB_PAD_FULL
    div t2, t2, t3
    add a0, a0, t2
    lh t2, (JAB_PAD_AXES + 2 * JAB_ABS_Y)(t0)
    mul t2, t2, t1
    div t2, t2, t3
    add a1, a1, t2
    lh t2, (JAB_PAD_AXES + 2 * JAB_ABS_HAT0X)(t0)
    beqz t2, 1f
    bltz t2, 11f
    add a0, a0, t1
    j 1f
11:
    sub a0, a0, t1
1:
    lh t2, (JAB_PAD_AXES + 2 * JAB_ABS_HAT0Y)(t0)
    beqz t2, 2f
    bltz t2, 21f
    add a1, a1, t1
    j 2f
21:
    sub a1, a1, t1
2:
    sd a0, 0(sp)
    sd a1, 8(sp)
    call right_axes
    or t4, a0, a1
    beqz t4, 7f
    sd a0, 16(sp)
    sd a1, 24(sp)
    mul a0, a0, a0
    mul t4, a1, a1
    add a0, a0, t4
    call isqrt
    beqz a0, 7f
    mv t5, a0                   # how far, the direction's length
    li t6, JAB_PAD_FULL
    bleu a0, t6, 22f
    mv a0, t6
22:
    li t4, BAND
    li t1, 1                    # the low third, a quarter of ACCEL
    bleu a0, t4, 23f
    li t1, 4                    # the middle, ACCEL
    slli t4, t4, 1
    bleu a0, t4, 23f
    li t1, 8                    # the high, twice ACCEL
23:
    li t4, ACCEL
    mul t1, t1, t4
    slli t4, t5, 2
    ld t2, 16(sp)
    mul t2, t2, t1
    div t2, t2, t4
    ld t3, 24(sp)
    mul t3, t3, t1
    div t3, t3, t4
    ld a0, 0(sp)
    ld a1, 8(sp)
    add a0, a0, t2
    add a1, a1, t3
    j 8f
7:
    ld a0, 0(sp)
    ld a1, 8(sp)
8:
    li t1, ACCEL_MAX
    ble a0, t1, 3f
    mv a0, t1
3:
    neg t2, t1
    bge a0, t2, 4f
    mv a0, t2
4:
    ble a1, t1, 5f
    mv a1, t1
5:
    bge a1, t2, 6f
    mv a1, t2
6:
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

drive:
    addi sp, sp, -16
    sd ra, 8(sp)
    beqz a1, 2f
    call advance
    j 5f
2:
    mv t3, a0
    li a0, 0
    li a1, DECEL
    call advance
    bltz t3, 3f
    sub a0, t3, a0
    bgez a0, 5f
    j 4f
3:
    add a0, t3, a0
    blez a0, 5f
4:
    li a0, 0
5:
    li t0, TOP_SPEED
    ble a0, t0, 6f
    mv a0, t0
6:
    li t0, -TOP_SPEED
    bge a0, t0, 7f
    mv a0, t0
7:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

wall:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd a1, 16(sp)
    sd a2, 8(sp)
    sd a3, 0(sp)
    call advance
    ld a1, 16(sp)
    ld a2, 8(sp)
    ld a3, 0(sp)
    srai t0, a0, FIX
    bge t0, a2, 1f
    slli a0, a2, FIX
    neg a1, a1
    li a2, 1
    j 3f
1:
    ble t0, a3, 2f
    slli a0, a3, FIX
    neg a1, a1
    li a2, 1
    j 3f
2:
    li a2, 0
3:
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

clamp:
    srai t0, a0, FIX
    bge t0, a1, 1f
    slli a0, a1, FIX
    ret
1:
    ble t0, a2, 2f
    slli a0, a2, FIX
2:
    ret

isqrt:
    beqz a0, 3f
    mv t0, a0
1:
    divu t1, a0, t0
    add t1, t1, t0
    srli t1, t1, 1
    bgeu t1, t0, 2f
    mv t0, t1
    j 1b
2:
    mv a0, t0
3:
    ret

move_player:
    addi sp, sp, -16
    sd ra, 8(sp)
    call drive_vector
    la t0, drive_x
    sd a0, 0(t0)
    la t0, drive_y
    sd a1, 0(t0)
    la t0, player_vx
    ld a0, 0(t0)
    la t0, drive_x
    ld a1, 0(t0)
    call drive
    mv a1, a0
    la t0, player_x
    ld a0, 0(t0)
    li a2, LEFT
    li a3, RIGHT
    call wall
    la t0, player_x
    sd a0, 0(t0)
    la t0, player_vx
    sd a1, 0(t0)
    la t0, player_hit_x
    sb a2, 0(t0)
    la t0, player_vy
    ld a0, 0(t0)
    la t0, drive_y
    ld a1, 0(t0)
    call drive
    mv a1, a0
    la t0, player_y
    ld a0, 0(t0)
    li a2, TOP
    li a3, BOTTOM
    call wall
    la t0, player_y
    sd a0, 0(t0)
    la t0, player_vy
    sd a1, 0(t0)
    la t0, player_hit_y
    sb a2, 0(t0)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

move_ball:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, ball_x
    ld a0, 0(t0)
    la t0, ball_vx
    ld a1, 0(t0)
    li a2, LEFT
    li a3, RIGHT
    call wall
    la t0, ball_x
    sd a0, 0(t0)
    la t0, ball_vx
    sd a1, 0(t0)
    la t0, ball_hit_x
    sb a2, 0(t0)
    la t0, ball_y
    ld a0, 0(t0)
    la t0, ball_vy
    ld a1, 0(t0)
    li a2, TOP
    li a3, BOTTOM
    call wall
    la t0, ball_y
    sd a0, 0(t0)
    la t0, ball_vy
    sd a1, 0(t0)
    la t0, ball_hit_y
    sb a2, 0(t0)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

collide:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s2, 48(sp)
    sd s3, 40(sp)
    sd s4, 32(sp)
    sd s5, 24(sp)
    sd s6, 16(sp)
    sd s7, 8(sp)
    la t0, player_x
    ld s2, 0(t0)
    la t0, player_y
    ld s3, 0(t0)
    la t0, ball_x
    ld s4, 0(t0)
    la t0, ball_y
    ld s5, 0(t0)
    sub s6, s4, s2
    sub s7, s5, s3
    mul a5, s6, s6
    mul t0, s7, s7
    add a5, a5, t0
    li t0, TOUCH_SQ
    slli t0, t0, 2 * FIX
    bgt a5, t0, 9f
    add t0, s2, s4
    srai t0, t0, 1
    la t1, meet_x
    sd t0, 0(t1)
    add t0, s3, s5
    srai t0, t0, 1
    la t1, meet_y
    sd t0, 0(t1)
    li t0, 1
    la t1, met
    sb t0, 0(t1)
    beqz a5, 3f
    la t0, ball_vx
    ld t5, 0(t0)
    la t0, ball_vy
    ld t6, 0(t0)
    mul a0, t5, s6
    mul a1, t6, s7
    add a0, a0, a1
    bgez a0, 1f
    slli a0, a0, 1
    mul a1, a0, s6
    div a1, a1, a5
    sub t5, t5, a1
    mul a1, a0, s7
    div a1, a1, a5
    sub t6, t6, a1
    la t0, ball_vx
    sd t5, 0(t0)
    la t0, ball_vy
    sd t6, 0(t0)
1:
    la t0, player_vx
    ld t5, 0(t0)
    la t0, player_vy
    ld t6, 0(t0)
    mul a0, t5, s6
    mul a1, t6, s7
    add a0, a0, a1
    blez a0, 2f
    slli a0, a0, 1
    mul a1, a0, s6
    div a1, a1, a5
    sub t5, t5, a1
    mul a1, a0, s7
    div a1, a1, a5
    sub t6, t6, a1
    la t0, player_vx
    sd t5, 0(t0)
    la t0, player_vy
    sd t6, 0(t0)
2:
    mv a0, a5
    call isqrt
    mv a4, a0
    j 4f
3:
    li s6, ONE
    li s7, 0
    li a4, ONE
4:
    li t0, APART
    sub t0, t0, a4
    blez t0, 9f
    srai t0, t0, 1
    mul t1, s6, t0
    div t1, t1, a4
    mul t2, s7, t0
    div t2, t2, a4
    sub s2, s2, t1
    sub s3, s3, t2
    add s4, s4, t1
    add s5, s5, t2
    mv a0, s2
    li a1, LEFT
    li a2, RIGHT
    call clamp
    la t0, player_x
    sd a0, 0(t0)
    mv a0, s3
    li a1, TOP
    li a2, BOTTOM
    call clamp
    la t0, player_y
    sd a0, 0(t0)
    mv a0, s4
    li a1, LEFT
    li a2, RIGHT
    call clamp
    la t0, ball_x
    sd a0, 0(t0)
    mv a0, s5
    li a1, TOP
    li a2, BOTTOM
    call clamp
    la t0, ball_y
    sd a0, 0(t0)
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

report:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, report_count
    sd zero, 0(t0)
    la t0, player_vx
    ld a3, 0(t0)
    la t0, player_vy
    ld a4, 0(t0)
    la t0, last_player_vx
    ld t1, 0(t0)
    la t0, last_player_vy
    ld t2, 0(t0)
    beq a3, t1, 1f
    j 11f
1:
    beq a4, t2, 2f
11:
    la t0, last_player_vx
    sd a3, 0(t0)
    la t0, last_player_vy
    sd a4, 0(t0)
    li a0, REPORT_VELOCITY
    li a1, SPHERE_PLAYER
    li a2, AGAINST_WALL
    call append_report
2:
    la t0, ball_vx
    ld a3, 0(t0)
    la t0, ball_vy
    ld a4, 0(t0)
    la t0, last_ball_vx
    ld t1, 0(t0)
    la t0, last_ball_vy
    ld t2, 0(t0)
    beq a3, t1, 3f
    j 31f
3:
    beq a4, t2, 4f
31:
    la t0, last_ball_vx
    sd a3, 0(t0)
    la t0, last_ball_vy
    sd a4, 0(t0)
    li a0, REPORT_VELOCITY
    li a1, SPHERE_BALL
    li a2, AGAINST_WALL
    call append_report
4:
    la t0, drive_x
    ld a3, 0(t0)
    la t0, drive_y
    ld a4, 0(t0)
    la t0, last_ax
    ld t1, 0(t0)
    la t0, last_ay
    ld t2, 0(t0)
    beq a3, t1, 5f
    j 51f
5:
    beq a4, t2, 6f
51:
    la t0, last_ax
    sd a3, 0(t0)
    la t0, last_ay
    sd a4, 0(t0)
    li a0, REPORT_ACCELERATION
    li a1, SPHERE_PLAYER
    li a2, AGAINST_WALL
    call append_report
6:
    la t0, player_hit_x
    lbu t0, 0(t0)
    beqz t0, 7f
    la t0, player_x
    ld a3, 0(t0)
    la t0, player_y
    ld a4, 0(t0)
    call toward_side
    li a0, REPORT_HIT
    li a1, SPHERE_PLAYER
    li a2, AGAINST_WALL
    call append_report
7:
    la t0, player_hit_y
    lbu t0, 0(t0)
    beqz t0, 8f
    la t0, player_x
    ld a3, 0(t0)
    la t0, player_y
    ld a4, 0(t0)
    call toward_edge
    li a0, REPORT_HIT
    li a1, SPHERE_PLAYER
    li a2, AGAINST_WALL
    call append_report
8:
    la t0, ball_hit_x
    lbu t0, 0(t0)
    beqz t0, 9f
    la t0, ball_x
    ld a3, 0(t0)
    la t0, ball_y
    ld a4, 0(t0)
    call toward_side
    li a0, REPORT_HIT
    li a1, SPHERE_BALL
    li a2, AGAINST_WALL
    call append_report
9:
    la t0, ball_hit_y
    lbu t0, 0(t0)
    beqz t0, 10f
    la t0, ball_x
    ld a3, 0(t0)
    la t0, ball_y
    ld a4, 0(t0)
    call toward_edge
    li a0, REPORT_HIT
    li a1, SPHERE_BALL
    li a2, AGAINST_WALL
    call append_report
10:
    la t0, color_changed
    lbu t1, 0(t0)
    beqz t1, 14f
    sb zero, 0(t0)
    la t0, player_color
    lwu a3, 0(t0)
    la t0, color_code
    ld a4, 0(t0)
    li a0, REPORT_COLOR
    li a1, SPHERE_PLAYER
    li a2, AGAINST_WALL
    call append_report
14:
    la t0, met
    lbu t0, 0(t0)
    beqz t0, 12f
    la t0, meet_x
    ld a3, 0(t0)
    la t0, meet_y
    ld a4, 0(t0)
    li a0, REPORT_HIT
    li a1, SPHERE_PLAYER
    li a2, SPHERE_BALL
    call append_report
    la t0, meet_x
    ld a3, 0(t0)
    la t0, meet_y
    ld a4, 0(t0)
    li a0, REPORT_HIT
    li a1, SPHERE_BALL
    li a2, SPHERE_PLAYER
    call append_report
12:
    la t0, player_hit_x
    sb zero, 0(t0)
    la t0, player_hit_y
    sb zero, 0(t0)
    la t0, ball_hit_x
    sb zero, 0(t0)
    la t0, ball_hit_y
    sb zero, 0(t0)
    la t0, met
    sb zero, 0(t0)
    la t0, report_count
    ld t1, 0(t0)
    beqz t1, 13f
    li t2, REPORT_SIZE
    mul t1, t1, t2
    la t0, report_buffer
    jab.sys.api.write t0, t1
13:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

toward_side:
    li t0, LEFT * ONE
    li t1, RADIUS * ONE
    bne a3, t0, 1f
    sub a3, a3, t1
    ret
1:
    add a3, a3, t1
    ret

toward_edge:
    li t0, TOP * ONE
    li t1, RADIUS * ONE
    bne a4, t0, 1f
    sub a4, a4, t1
    ret
1:
    add a4, a4, t1
    ret

append_report:
    la t0, report_count
    ld t1, 0(t0)
    li t2, REPORT_MAX
    bgeu t1, t2, 1f
    li t2, REPORT_SIZE
    mul t2, t2, t1
    la t3, report_buffer
    add t3, t3, t2
    sb a0, REPORT_KIND(t3)
    sb a1, REPORT_SPHERE(t3)
    sb a2, REPORT_AGAINST(t3)
    sb zero, 3(t3)
    sw a3, REPORT_X(t3)
    sw a4, REPORT_Y(t3)
    addi t1, t1, 1
    sd t1, 0(t0)
1:
    ret

render:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, old_player_x
    ld a0, 0(t0)
    la t0, old_player_y
    ld a1, 0(t0)
    li a2, BACKGROUND
    call fill_square
    la t0, old_ball_x
    ld a0, 0(t0)
    la t0, old_ball_y
    ld a1, 0(t0)
    li a2, BACKGROUND
    call fill_square
    la t0, ball_x
    ld a0, 0(t0)
    srai a0, a0, FIX
    la t0, ball_y
    ld a1, 0(t0)
    srai a1, a1, FIX
    li a2, BALL
    call draw_disc
    la t0, player_x
    ld a0, 0(t0)
    srai a0, a0, FIX
    la t0, player_y
    ld a1, 0(t0)
    srai a1, a1, FIX
    la t0, player_color
    lwu a2, 0(t0)
    call draw_disc
    la t0, old_player_x
    ld a0, 0(t0)
    la t0, old_ball_x
    ld t1, 0(t0)
    la t0, player_x
    ld t2, 0(t0)
    srai t2, t2, FIX
    la t0, ball_x
    ld t3, 0(t0)
    srai t3, t3, FIX
    mv a2, a0
    call least_greatest
    addi a0, a0, -RADIUS
    addi a2, a2, RADIUS + 1
    sub a2, a2, a0
    mv s2, a0
    mv s3, a2
    la t0, old_player_y
    ld a0, 0(t0)
    la t0, old_ball_y
    ld t1, 0(t0)
    la t0, player_y
    ld t2, 0(t0)
    srai t2, t2, FIX
    la t0, ball_y
    ld t3, 0(t0)
    srai t3, t3, FIX
    mv a2, a0
    call least_greatest
    addi a1, a0, -RADIUS
    addi a3, a2, RADIUS + 1
    sub a3, a3, a1
    mv a0, s2
    mv a2, s3
    la t0, label_changed
    lbu t1, 0(t0)
    beqz t1, 5f
    sb zero, 0(t0)
    la t0, rects
    sw a0, JAB_RECT_X(t0)
    sw a1, JAB_RECT_Y(t0)
    sw a2, JAB_RECT_WIDTH(t0)
    sw a3, JAB_RECT_HEIGHT(t0)
    sw zero, (JAB_RECT_SIZE + JAB_RECT_X)(t0)
    li t1, LABEL_Y
    sw t1, (JAB_RECT_SIZE + JAB_RECT_Y)(t0)
    li t1, JAB_DISPLAY_WIDTH
    sw t1, (JAB_RECT_SIZE + JAB_RECT_WIDTH)(t0)
    li t1, LABEL_HEIGHT
    sw t1, (JAB_RECT_SIZE + JAB_RECT_HEIGHT)(t0)
    call draw_label
    la t0, rects
    li t1, 2
    jab.sys.display.flip.rects t0, t1
    j 6f
5:
    jab.sys.display.flip.rect
6:
    call remember
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

draw_label:
    addi sp, sp, -16
    sd ra, 8(sp)
    li a0, 0
    li a1, LABEL_Y
    li a2, JAB_DISPLAY_WIDTH
    li a3, LABEL_HEIGHT
    li a4, BACKGROUND
    call fill_rect
    la t0, label_text
    ld a0, 0(t0)
    mv t1, a0
    li t2, 0
1:
    lbu t3, 0(t1)
    beqz t3, 2f
    addi t1, t1, 1
    addi t2, t2, 1
    j 1b
2:
    beqz t2, 9f
    li t3, LABEL_CELL
    mul t2, t2, t3
    addi t2, t2, 1
    li a1, JAB_DISPLAY_WIDTH
    sub a1, a1, t2
    srai a1, a1, 1
    li a2, LABEL_Y
    li a3, LABEL_COLOR
    li a4, JAB_TEXT_BOLD
    li a5, LABEL_SCALE
    li a7, JAB_SYS_DISPLAY_TEXT
    ecall
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

fill_rect:
    li t0, JAB_DISPLAY_PITCH
    mul t0, t0, a1
    slli t1, a0, 2
    add t0, t0, t1
    li t1, JAB_DISPLAY_BASE
    add t0, t0, t1              # the row's first pixel
    mv t2, a3
1:
    mv t3, t0
    mv t4, a2
2:
    sw a4, 0(t3)
    addi t3, t3, 4
    addi t4, t4, -1
    bnez t4, 2b
    li t1, JAB_DISPLAY_PITCH
    add t0, t0, t1
    addi t2, t2, -1
    bnez t2, 1b
    ret

least_greatest:
    bge t1, a0, 1f
    mv a0, t1
1:
    bge t2, a0, 2f
    mv a0, t2
2:
    bge t3, a0, 3f
    mv a0, t3
3:
    ble t1, a2, 4f
    mv a2, t1
4:
    ble t2, a2, 5f
    mv a2, t2
5:
    ble t3, a2, 6f
    mv a2, t3
6:
    ret

remember:
    la t0, player_x
    ld t1, 0(t0)
    srai t1, t1, FIX
    la t0, old_player_x
    sd t1, 0(t0)
    la t0, player_y
    ld t1, 0(t0)
    srai t1, t1, FIX
    la t0, old_player_y
    sd t1, 0(t0)
    la t0, ball_x
    ld t1, 0(t0)
    srai t1, t1, FIX
    la t0, old_ball_x
    sd t1, 0(t0)
    la t0, ball_y
    ld t1, 0(t0)
    srai t1, t1, FIX
    la t0, old_ball_y
    sd t1, 0(t0)
    ret

fill_square:
    li t0, -RADIUS
    li t6, RADIUS
1:
    add t1, a1, t0
    li t2, JAB_DISPLAY_PITCH
    mul t1, t1, t2
    addi t2, a0, -RADIUS
    slli t2, t2, 2
    add t1, t1, t2
    li t2, JAB_DISPLAY_BASE
    add t1, t1, t2
    li t3, 2 * RADIUS + 1
2:
    sw a2, 0(t1)
    addi t1, t1, 4
    addi t3, t3, -1
    bnez t3, 2b
    addi t0, t0, 1
    ble t0, t6, 1b
    ret

draw_disc:
    li t0, -RADIUS
    li t6, RADIUS
    li a3, RADIUS * RADIUS
1:
    add t1, a1, t0
    li t2, JAB_DISPLAY_PITCH
    mul t1, t1, t2
    li t2, JAB_DISPLAY_BASE
    add t1, t1, t2
    slli t2, a0, 2
    add t1, t1, t2
    mul t4, t0, t0
    li t2, -RADIUS
2:
    mul t3, t2, t2
    add t3, t3, t4
    bgt t3, a3, 3f
    slli a4, t2, 2
    add a4, a4, t1
    sw a2, 0(a4)
3:
    addi t2, t2, 1
    ble t2, t6, 2b
    addi t0, t0, 1
    ble t0, t6, 1b
    ret

.section .bss
.balign 8
player_x:
    .skip 8
player_y:
    .skip 8
player_vx:
    .skip 8
player_vy:
    .skip 8
ball_x:
    .skip 8
ball_y:
    .skip 8
ball_vx:
    .skip 8
ball_vy:
    .skip 8
old_player_x:
    .skip 8
old_player_y:
    .skip 8
old_ball_x:
    .skip 8
old_ball_y:
    .skip 8
last_player_vx:
    .skip 8
last_player_vy:
    .skip 8
last_ball_vx:
    .skip 8
last_ball_vy:
    .skip 8
last_ax:
    .skip 8
last_ay:
    .skip 8
drive_x:
    .skip 8
drive_y:
    .skip 8
meet_x:
    .skip 8
meet_y:
    .skip 8
report_count:
    .skip 8
cmd_pending:
    .skip 8
rand_state:
    .skip 8
color_code:
    .skip 8
label_code:
    .skip 8
label_text:
    .skip 8
label_left:
    .skip 8
last_time:
    .skip 8
dt:
    .skip 8
report_buffer:
    .skip REPORT_MAX * REPORT_SIZE
cmd_read:
    .skip CMD_READ_BYTES
cmd_partial:
    .skip CMD_SIZE
right_x:
    .skip 8
right_y:
    .skip 8
.balign 4
pad_state:
    .skip JAB_PAD_ENTRY
axis_record:
    .skip JAB_PAD_AXIS_ENTRY
button_colors:
    .skip BUTTONS * 4
player_color:
    .skip 4
rects:
    .skip 2 * JAB_RECT_SIZE
pad_name:
    .skip JAB_PAD_NAME_BYTES
color_changed:
    .skip 1
label_changed:
    .skip 1
held_w:
    .skip 1
held_a:
    .skip 1
held_s:
    .skip 1
held_d:
    .skip 1
player_hit_x:
    .skip 1
player_hit_y:
    .skip 1
ball_hit_x:
    .skip 1
ball_hit_y:
    .skip 1
met:
    .skip 1

.section .rodata
msg_no_display:
    .asciz "pad: no display\n"
name_south:
    .asciz "SOUTH"
name_east:
    .asciz "EAST"
name_c:
    .asciz "C"
name_north:
    .asciz "NORTH"
name_west:
    .asciz "WEST"
name_z:
    .asciz "Z"
name_tl:
    .asciz "TL"
name_tr:
    .asciz "TR"
name_tl2:
    .asciz "TL2"
name_tr2:
    .asciz "TR2"
name_select:
    .asciz "SELECT"
name_start:
    .asciz "START"
name_mode:
    .asciz "MODE"
name_thumbl:
    .asciz "THUMBL"
name_thumbr:
    .asciz "THUMBR"
name_none:
    .asciz ""
.balign 8
button_names:
    .quad name_south, name_east, name_c, name_north, name_west, name_z
    .quad name_tl, name_tr, name_tl2, name_tr2, name_select, name_start
    .quad name_mode, name_thumbl, name_thumbr, name_none
