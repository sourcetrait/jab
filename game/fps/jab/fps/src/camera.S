# camera.S: the camera, the eye and its yaw, pitch, and roll, with the
# basis of right, up, and forward derived from the angles each frame,
# so it is orthonormal by construction and every axis is free. It
# starts at the spawn: the eye EYE_HEIGHT over the spawn's feet, facing
# its yaw and pitch, roll 0. The right stick turns the yaw and the pitch
# at a speed times the throw times the frame's seconds, the pitch held
# short of straight up and down; roll is the engine's alone, for
# effects; the right trigger's button fires (player.S). The left stick
# walks the body under the camera (body.S), which sets the eye's height
# and the sector. The camera's sector follows the eye through the
# portals. The records over the API carry the state, the eye, the
# angles in degrees, and the frame's times, and an event its own fields
# over them. The sky's offsets come from the yaw and pitch. The
# trigonometry is single precision on the FPU, a seventh-order sine and
# an eighth-order cosine each folded into a quarter turn, and an
# eleventh-order arctangent unfolded by octant.

.section .rodata
.balign 4
k_turn_speed:
    .float 3.14159265
k_look_speed:
    .float 1.57079633
k_pitch_limit:
    .float 1.55334306
k_pad_full:
    .float 32767.0
k_dead_zone:
    .float 0.15
k_one:
    .float 1.0
k_zero:
    .float 0.0
k_degree:
    .float 0.0174532925
k_degrees:
    .float 57.2957795
k_eye_height:
    .float 1.6
k_two_pi:
    .float 6.28318531
k_inv_two_pi:
    .float 0.159154943
k_pi:
    .float 3.14159265
k_half_pi:
    .float 1.57079633
k_sin3:
    .float -0.16666667
k_sin5:
    .float 0.0083333333
k_sin7:
    .float -0.00019841270
k_cos2:
    .float -0.5
k_cos4:
    .float 0.041666667
k_cos6:
    .float -0.0013888889
k_cos8:
    .float 0.000024801587
k_sixty_four_k:
    .float 65536.0
k_sky_turns:
    .float 0.636619772
# The arctangent on 0 to 1, odd powers to the eleventh
k_atan1:
    .float 0.99997726
k_atan3:
    .float -0.33262347
k_atan5:
    .float 0.19354346
k_atan7:
    .float -0.11643287
k_atan9:
    .float 0.05265332
k_atan11:
    .float -0.01172120

.section .text

# sine: fa0 becomes the sine of fa0, radians, any size: the angle
# brought into a turn, reflected into a quarter, and a seventh-order
# polynomial. Clobbers ft0 to ft4 and t0.
sine:
    la t0, k_inv_two_pi
    flw ft0, 0(t0)
    fmul.s ft1, fa0, ft0
    fcvt.w.s t0, ft1, rne
    fcvt.s.w ft1, t0
    la t0, k_two_pi
    flw ft0, 0(t0)
    fnmsub.s fa0, ft1, ft0, fa0
    la t0, k_half_pi
    flw ft0, 0(t0)
    flt.s t0, ft0, fa0
    beqz t0, 1f
    la t0, k_pi
    flw ft1, 0(t0)
    fsub.s fa0, ft1, fa0
    j 2f
1:
    fneg.s ft1, ft0
    flt.s t0, fa0, ft1
    beqz t0, 2f
    la t0, k_pi
    flw ft1, 0(t0)
    fneg.s ft1, ft1
    fsub.s fa0, ft1, fa0
2:
    fmul.s ft2, fa0, fa0
    la t0, k_sin7
    flw ft3, 0(t0)
    la t0, k_sin5
    flw ft4, 0(t0)
    fmadd.s ft3, ft3, ft2, ft4
    la t0, k_sin3
    flw ft4, 0(t0)
    fmadd.s ft3, ft3, ft2, ft4
    la t0, k_one
    flw ft4, 0(t0)
    fmadd.s ft3, ft3, ft2, ft4
    fmul.s fa0, fa0, ft3
    ret

# cosine: fa0 becomes the cosine of fa0, radians, any size: the angle
# brought into a turn, folded into a quarter so the even series is
# taken near zero where it is exact, and an eighth-order polynomial.
# Clobbers ft0 to ft4, t0, t1.
cosine:
    la t0, k_inv_two_pi
    flw ft0, 0(t0)
    fmul.s ft1, fa0, ft0
    fcvt.w.s t0, ft1, rne
    fcvt.s.w ft1, t0
    la t0, k_two_pi
    flw ft0, 0(t0)
    fnmsub.s fa0, ft1, ft0, fa0     # within a half turn either way
    fabs.s fa0, fa0
    la t0, k_half_pi
    flw ft0, 0(t0)
    fle.s t1, fa0, ft0
    xori t1, t1, 1                  # 1 past a quarter turn: the cosine is the negative of pi - x's
    beqz t1, 1f
    la t0, k_pi
    flw ft1, 0(t0)
    fsub.s fa0, ft1, fa0
1:
    fmul.s ft2, fa0, fa0
    la t0, k_cos8
    flw ft3, 0(t0)
    la t0, k_cos6
    flw ft4, 0(t0)
    fmadd.s ft3, ft3, ft2, ft4
    la t0, k_cos4
    flw ft4, 0(t0)
    fmadd.s ft3, ft3, ft2, ft4
    la t0, k_cos2
    flw ft4, 0(t0)
    fmadd.s ft3, ft3, ft2, ft4
    la t0, k_one
    flw ft4, 0(t0)
    fmadd.s fa0, ft3, ft2, ft4
    beqz t1, 2f
    fneg.s fa0, fa0
2:
    ret

# atan2: fa0 becomes the angle, radians in a half turn either way, of
# the point fa1, fa0 (x, y) from the x axis counter-clockwise: the
# ratio of the lesser magnitude to the greater through a polynomial for
# the arctangent on 0 to 1, then unfolded by the octant; both 0 gives
# 0. Clobbers t0 to t2, ft0 to ft5.
atan2:
    fabs.s ft0, fa0                 # |y|
    fabs.s ft1, fa1                 # |x|
    la t0, k_zero
    flw ft2, 0(t0)
    feq.s t1, ft0, ft2
    feq.s t2, ft1, ft2
    and t1, t1, t2
    beqz t1, 1f
    fmv.s fa0, ft2
    ret
1:
    fle.s t1, ft0, ft1              # |y| <= |x|: the ratio y over x
    beqz t1, 2f
    fdiv.s ft2, ft0, ft1
    li t2, 0
    j 3f
2:
    fdiv.s ft2, ft1, ft0            # else x over y, unfolded from a quarter
    li t2, 1
3:
    # the arctangent of ft2 on 0 to 1
    fmul.s ft3, ft2, ft2
    la t0, k_atan11
    flw ft4, 0(t0)
    la t0, k_atan9
    flw ft5, 0(t0)
    fmadd.s ft4, ft4, ft3, ft5
    la t0, k_atan7
    flw ft5, 0(t0)
    fmadd.s ft4, ft4, ft3, ft5
    la t0, k_atan5
    flw ft5, 0(t0)
    fmadd.s ft4, ft4, ft3, ft5
    la t0, k_atan3
    flw ft5, 0(t0)
    fmadd.s ft4, ft4, ft3, ft5
    la t0, k_atan1
    flw ft5, 0(t0)
    fmadd.s ft4, ft4, ft3, ft5
    fmul.s ft4, ft4, ft2
    beqz t2, 4f
    la t0, k_half_pi
    flw ft5, 0(t0)
    fsub.s ft4, ft5, ft4
4:
    la t0, k_zero
    flw ft2, 0(t0)
    flt.s t1, fa1, ft2              # x under 0: the angle from the other side
    beqz t1, 5f
    la t0, k_pi
    flw ft5, 0(t0)
    fsub.s ft4, ft5, ft4
5:
    flt.s t1, fa0, ft2              # y under 0: the angle below
    beqz t1, 6f
    fneg.s ft4, ft4
6:
    fmv.s fa0, ft4
    ret

# camera_spawn: the camera at the map's first spawn: the eye
# EYE_HEIGHT over the spawn's feet, its yaw and pitch from degrees,
# roll 0, and the sector the file gives the spawn.
camera_spawn:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, spawn_index
    lw a0, 0(t0)
    call entity_at
    la t0, camera
    flw ft0, ENTITY_X(a0)
    fsw ft0, CAM_X(t0)
    flw ft0, ENTITY_Y(a0)
    fsw ft0, CAM_Y(t0)
    flw ft0, ENTITY_Z(a0)
    la t1, k_eye_height
    flw ft1, 0(t1)
    fadd.s ft0, ft0, ft1
    fsw ft0, CAM_Z(t0)
    la t1, k_degree
    flw ft1, 0(t1)
    flw ft0, ENTITY_YAW(a0)
    fmul.s ft0, ft0, ft1
    fsw ft0, CAM_YAW(t0)
    flw ft0, ENTITY_PITCH(a0)
    fmul.s ft0, ft0, ft1
    fsw ft0, CAM_PITCH(t0)
    sw zero, CAM_ROLL(t0)
    lw t1, ENTITY_SECTOR(a0)
    la t0, cam_sector
    sw t1, 0(t0)
    call camera_basis
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# camera_basis: right, up, and forward from the angles: forward is
# (cos p cos y, cos p sin y, sin p); level, right is (sin y, -cos y, 0)
# and up is right cross forward; the roll then turns right and up
# about forward, a positive roll tilting the camera's up toward its
# right.
camera_basis:
    addi sp, sp, -64
    sd ra, 56(sp)
    fsd fs0, 48(sp)
    fsd fs1, 40(sp)
    fsd fs2, 32(sp)
    fsd fs3, 24(sp)
    fsd fs4, 16(sp)
    fsd fs5, 8(sp)
    la t0, camera
    flw fa0, CAM_YAW(t0)
    call sine
    fmv.s fs0, fa0                  # sy
    la t0, camera
    flw fa0, CAM_YAW(t0)
    call cosine
    fmv.s fs1, fa0                  # cy
    la t0, camera
    flw fa0, CAM_PITCH(t0)
    call sine
    fmv.s fs2, fa0                  # sp
    la t0, camera
    flw fa0, CAM_PITCH(t0)
    call cosine
    fmv.s fs3, fa0                  # cp
    la t0, camera
    flw fa0, CAM_ROLL(t0)
    call sine
    fmv.s fs4, fa0                  # sr
    la t0, camera
    flw fa0, CAM_ROLL(t0)
    call cosine
    fmv.s fs5, fa0                  # cr
    la t0, camera
    # forward
    fmul.s ft0, fs3, fs1
    fsw ft0, (CAM_FORWARD + 0)(t0)
    fmul.s ft0, fs3, fs0
    fsw ft0, (CAM_FORWARD + 4)(t0)
    fsw fs2, (CAM_FORWARD + 8)(t0)
    # level right (sy, -cy, 0) and up (-cy sp, -sy sp, cp)
    fmv.s ft0, fs0
    fneg.s ft1, fs1
    fmul.s ft3, fs1, fs2
    fneg.s ft3, ft3
    fmul.s ft4, fs0, fs2
    fneg.s ft4, ft4
    fmv.s ft5, fs3
    # turned by the roll: right' = right cr - up sr, up' = up cr + right sr
    fmul.s ft6, ft0, fs5
    fnmsub.s ft6, ft3, fs4, ft6
    fsw ft6, (CAM_RIGHT + 0)(t0)
    fmul.s ft6, ft1, fs5
    fnmsub.s ft6, ft4, fs4, ft6
    fsw ft6, (CAM_RIGHT + 4)(t0)
    fmul.s ft6, ft5, fs4
    fneg.s ft6, ft6
    fsw ft6, (CAM_RIGHT + 8)(t0)
    fmul.s ft6, ft3, fs5
    fmadd.s ft6, ft0, fs4, ft6
    fsw ft6, (CAM_UP + 0)(t0)
    fmul.s ft6, ft4, fs5
    fmadd.s ft6, ft1, fs4, ft6
    fsw ft6, (CAM_UP + 4)(t0)
    fmul.s ft6, ft5, fs5
    fsw ft6, (CAM_UP + 8)(t0)
    ld ra, 56(sp)
    fld fs0, 48(sp)
    fld fs1, 40(sp)
    fld fs2, 32(sp)
    fld fs3, 24(sp)
    fld fs4, 16(sp)
    fld fs5, 8(sp)
    addi sp, sp, 64
    ret

# camera_axes: the right stick's axis codes, Z and RZ when the pad has
# a Z, else RX and RY, into right_x and right_y.
camera_axes:
    la a0, axis_record
    li a1, JAB_ABS_Z
    li a7, JAB_SYS_PAD_AXIS
    ecall
    li t1, JAB_ABS_Z
    li t2, JAB_ABS_RZ
    beqz a0, 1f
    li t1, JAB_ABS_RX
    li t2, JAB_ABS_RY
1:
    la t0, right_x
    sw t1, 0(t0)
    la t0, right_y
    sw t2, 0(t0)
    ret

# axis: fa0 becomes the pad's axis a0 as -1 to 1, 0 within the dead
# zone, the rest rescaled to reach 1 at full throw. Clobbers t0 to t2,
# ft0 to ft2.
axis:
    la t0, pad_state
    slli t1, a0, 1
    add t0, t0, t1
    lh t1, JAB_PAD_AXES(t0)
    fcvt.s.w fa0, t1
    la t0, k_pad_full
    flw ft0, 0(t0)
    fdiv.s fa0, fa0, ft0
    fabs.s ft1, fa0
    la t0, k_dead_zone
    flw ft2, 0(t0)
    flt.s t2, ft1, ft2
    beqz t2, 1f
    la t0, k_zero
    flw fa0, 0(t0)
    ret
1:
    fsub.s ft1, ft1, ft2
    la t0, k_one
    flw ft0, 0(t0)
    fsub.s ft0, ft0, ft2
    fdiv.s ft1, ft1, ft0
    fsgnj.s fa0, ft1, fa0
    ret

# camera_look: one frame of the pad, fa0 the seconds since the frame
# before: the right trigger's button pressed fires a round (player.S);
# the right stick's throws turn the yaw, right positive, and the pitch,
# up positive, the yaw kept within a turn and the pitch within its
# limit; then the body walked by the left stick's throws (body.S),
# which sets the sector and the eye's height. No pad, the body still
# meets the floor.
camera_look:
    addi sp, sp, -64
    sd ra, 56(sp)
    fsd fs0, 48(sp)
    fsd fs1, 40(sp)
    fsd fs2, 32(sp)
    fsd fs3, 24(sp)
    fsd fs4, 16(sp)
    sd s2, 8(sp)
    fmv.s fs0, fa0
    la t0, pad_state
    jab.pad.read t0
    beqz a0, 1f
    # no pad: the body stands where it is
    fmv.s fa0, fs0
    la t0, k_zero
    flw fa1, 0(t0)
    flw fa2, 0(t0)
    call body_move
    j 9f
1:
    # the buttons pressed since the frame before, and every press among
    # the events since, so a press released within the frame is kept
    la t0, pad_state
    lwu t1, JAB_PAD_KEYS(t0)
    la t0, pad_prev
    lwu t2, 0(t0)
    sw t1, 0(t0)
    not t2, t2
    and s2, t1, t2
11:
    jab.pad.input
    beqz a0, 12f
    li t0, JAB_EV_KEY
    bne a0, t0, 11b
    li t0, JAB_KEY_PRESSED
    bne a2, t0, 11b
    addi t0, a1, -JAB_BTN_GAMEPAD
    li t1, 32
    bgeu t0, t1, 11b
    li t1, 1
    sll t1, t1, t0
    or s2, s2, t1
    j 11b
12:
    li t0, TRIGGER_BIT
    and t0, s2, t0
    beqz t0, 13f
    call player_fire
13:
    li a0, JAB_ABS_X
    call axis
    fmv.s fs1, fa0                  # strafe, right positive
    li a0, JAB_ABS_Y
    call axis
    fneg.s fs2, fa0                 # forward, up positive
    la t0, right_x
    lw a0, 0(t0)
    call axis
    fmv.s fs3, fa0                  # turn, right positive
    la t0, right_y
    lw a0, 0(t0)
    call axis
    fneg.s fs4, fa0                 # look, up positive
    la t0, camera
    # the yaw, counter-clockwise from east, so a right turn takes from it
    la t1, k_turn_speed
    flw ft0, 0(t1)
    fmul.s ft0, fs3, ft0
    fmul.s ft0, ft0, fs0
    flw ft1, CAM_YAW(t0)
    fsub.s ft1, ft1, ft0
    la t1, k_pi
    flw ft2, 0(t1)
    la t1, k_two_pi
    flw ft3, 0(t1)
    flt.s t2, ft2, ft1
    beqz t2, 2f
    fsub.s ft1, ft1, ft3
2:
    fneg.s ft2, ft2
    flt.s t2, ft1, ft2
    beqz t2, 3f
    fadd.s ft1, ft1, ft3
3:
    fsw ft1, CAM_YAW(t0)
    # the pitch, within its limit
    la t1, k_look_speed
    flw ft0, 0(t1)
    fmul.s ft0, fs4, ft0
    fmul.s ft0, ft0, fs0
    flw ft1, CAM_PITCH(t0)
    fadd.s ft1, ft1, ft0
    la t1, k_pitch_limit
    flw ft2, 0(t1)
    fmin.s ft1, ft1, ft2
    fneg.s ft2, ft2
    fmax.s ft1, ft1, ft2
    fsw ft1, CAM_PITCH(t0)
    # the walk: the body moved by the left stick's throws
    fmv.s fa0, fs0
    fmv.s fa1, fs1
    fmv.s fa2, fs2
    call body_move
9:
    ld ra, 56(sp)
    fld fs0, 48(sp)
    fld fs1, 40(sp)
    fld fs2, 32(sp)
    fld fs3, 24(sp)
    fld fs4, 16(sp)
    ld s2, 8(sp)
    addi sp, sp, 64
    ret

# camera_locate: cam_sector followed to the sector holding the eye,
# from the one it was in; none stays none until one holds it.
camera_locate:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, camera
    flw fa0, CAM_X(t0)
    fcvt.d.s fa0, fa0
    flw fa1, CAM_Y(t0)
    fcvt.d.s fa1, fa1
    flw fa2, CAM_Z(t0)
    fcvt.d.s fa2, fa2
    la t0, cam_sector
    lw a0, 0(t0)
    call sector_find
    la t0, cam_sector
    sw a0, 0(t0)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# sky_setup: the sky's offsets for the frame from the camera's yaw and
# pitch, in texture repeats, 16.16: four repeats a full turn, the paper
# sky's scroll, a right turn scrolling it left and a look up scrolling
# it down. Clobbers t0, t1, ft0, ft1.
sky_setup:
    la t0, camera
    la t1, k_sky_turns
    flw ft0, 0(t1)
    la t1, k_sixty_four_k
    flw ft1, 0(t1)
    fmul.s ft0, ft0, ft1            # 16.16 repeats a radian
    flw ft1, CAM_YAW(t0)
    fmul.s ft1, ft1, ft0
    fneg.s ft1, ft1
    fcvt.l.s t1, ft1, rne
    la t0, sky_uoff
    sd t1, 0(t0)
    la t0, camera
    flw ft1, CAM_PITCH(t0)
    fmul.s ft1, ft1, ft0
    fcvt.l.s t1, ft1, rne
    la t0, sky_voff
    sd t1, 0(t0)
    ret

# state_report: the state record over the API when the run has the
# port: the kind, the camera's sector, the eye, the yaw, pitch, and
# roll in degrees, and the last frame's drawing and game microseconds,
# zero after.
state_report:
    addi sp, sp, -16
    sd ra, 8(sp)
    call report_fill
    la t0, report_record
    li t1, REPORT_STATE
    sw t1, REPORT_KIND(t0)
    sw zero, REPORT_FIELD0(t0)
    sw zero, REPORT_FIELD1(t0)
    sw zero, REPORT_FIELD2(t0)
    sw zero, REPORT_FIELD3(t0)
    sw zero, REPORT_FIELD4(t0)
    li t1, REPORT_SIZE
    jab.api.write t0, t1
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# event_report: a record of the kind a0 over the API with the fields
# a1 to a5 from REPORT_FIELD0, over the state's fields.
event_report:
    addi sp, sp, -16
    sd ra, 8(sp)
    call report_fill
    la t0, report_record
    sw a0, REPORT_KIND(t0)
    sw a1, REPORT_FIELD0(t0)
    sw a2, REPORT_FIELD1(t0)
    sw a3, REPORT_FIELD2(t0)
    sw a4, REPORT_FIELD3(t0)
    sw a5, REPORT_FIELD4(t0)
    li t1, REPORT_SIZE
    jab.api.write t0, t1
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

# report_fill: the state's fields into report_record: the camera's
# sector, the eye, the angles in degrees, the last frame's drawing and
# game microseconds. Clobbers t0 to t2, ft0, ft1.
report_fill:
    la t0, report_record
    la t1, cam_sector
    lw t1, 0(t1)
    sw t1, REPORT_SECTOR(t0)
    la t1, camera
    lw t2, CAM_X(t1)
    sw t2, REPORT_X(t0)
    lw t2, CAM_Y(t1)
    sw t2, REPORT_Y(t0)
    lw t2, CAM_Z(t1)
    sw t2, REPORT_Z(t0)
    la t2, k_degrees
    flw ft0, 0(t2)
    flw ft1, CAM_YAW(t1)
    fmul.s ft1, ft1, ft0
    fsw ft1, REPORT_YAW(t0)
    flw ft1, CAM_PITCH(t1)
    fmul.s ft1, ft1, ft0
    fsw ft1, REPORT_PITCH(t0)
    flw ft1, CAM_ROLL(t1)
    fmul.s ft1, ft1, ft0
    fsw ft1, REPORT_ROLL(t0)
    la t1, frame_us
    lw t1, 0(t1)
    sw t1, REPORT_FRAME_US(t0)
    la t1, game_us
    lw t1, 0(t1)
    sw t1, REPORT_GAME_US(t0)
    ret

.section .bss
.balign 8
camera:
    .skip CAM_SIZE
.balign 8
cam_sector:
    .skip 4
right_x:
    .skip 4
right_y:
    .skip 4
.balign 8
report_record:
    .skip REPORT_SIZE
.balign 4
pad_state:
    .skip JAB_PAD_ENTRY
axis_record:
    .skip JAB_PAD_AXIS_ENTRY
