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
k_eye_height:
    .float 1.6
k_sixty_four_k:
    .float 65536.0
k_sky_turns:
    .float 0.636619772

.section .text

camera_spawn:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, spawn_index
    lw a0, 0(t0)
    call entity_at
    la t3, camera
    flw ft0, ENTITY_X(a0)
    fsw ft0, CAM_X(t3)
    flw ft0, ENTITY_Y(a0)
    fsw ft0, CAM_Y(t3)
    flw ft0, ENTITY_Z(a0)
    la t1, k_eye_height
    flw ft1, 0(t1)
    fadd.s ft0, ft0, ft1
    fsw ft0, CAM_Z(t3)
    flw ft8, ENTITY_YAW(a0)
    jab.f32.rad ft8, ft8
    fsw ft8, CAM_YAW(t3)
    flw ft8, ENTITY_PITCH(a0)
    jab.f32.rad ft8, ft8
    fsw ft8, CAM_PITCH(t3)
    sw zero, CAM_ROLL(t3)
    lw t1, ENTITY_SECTOR(a0)
    la t0, cam_sector
    sw t1, 0(t0)
    call camera_basis
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

camera_basis:
    addi sp, sp, -48
    fsd fs0, 40(sp)
    fsd fs1, 32(sp)
    fsd fs2, 24(sp)
    fsd fs3, 16(sp)
    fsd fs4, 8(sp)
    fsd fs5, 0(sp)
    la t3, camera
    flw fa0, CAM_YAW(t3)
    jab.f32.sin fs0, fa0            # sy
    jab.f32.cos fs1, fa0            # cy
    flw fa0, CAM_PITCH(t3)
    jab.f32.sin fs2, fa0            # sp
    jab.f32.cos fs3, fa0            # cp
    flw fa0, CAM_ROLL(t3)
    jab.f32.sin fs4, fa0            # sr
    jab.f32.cos fs5, fa0            # cr
    la t0, camera
    fmul.s ft0, fs3, fs1
    fsw ft0, (CAM_FORWARD + 0)(t0)
    fmul.s ft0, fs3, fs0
    fsw ft0, (CAM_FORWARD + 4)(t0)
    fsw fs2, (CAM_FORWARD + 8)(t0)
    fmv.s ft0, fs0
    fneg.s ft1, fs1
    fmul.s ft3, fs1, fs2
    fneg.s ft3, ft3
    fmul.s ft4, fs0, fs2
    fneg.s ft4, ft4
    fmv.s ft5, fs3
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
    la t1, camera_d
    li t2, (CAM_SIZE / 4)
1:
    flw ft0, 0(t0)
    fcvt.d.s ft0, ft0
    fsd ft0, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 8
    addi t2, t2, -1
    bnez t2, 1b
    fld fs0, 40(sp)
    fld fs1, 32(sp)
    fld fs2, 24(sp)
    fld fs3, 16(sp)
    fld fs4, 8(sp)
    fld fs5, 0(sp)
    addi sp, sp, 48
    ret

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
    jab.sys.pad.read t0
    beqz a0, 1f
    fmv.s fa0, fs0
    la t0, k_zero
    flw fa1, 0(t0)
    flw fa2, 0(t0)
    call body_move
    j 9f
1:
    la t0, pad_state
    lwu t1, JAB_PAD_KEYS(t0)
    la t0, pad_prev
    lwu t2, 0(t0)
    sw t1, 0(t0)
    not t2, t2
    and s2, t1, t2
11:
    jab.sys.pad.input
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
    jab.f32.PI ft8
    jab.f32.TAU ft9
    la t3, camera
    la t1, k_turn_speed
    flw ft0, 0(t1)
    fmul.s ft0, fs3, ft0
    fmul.s ft0, ft0, fs0
    flw ft1, CAM_YAW(t3)
    fsub.s ft1, ft1, ft0
    flt.s t2, ft8, ft1
    beqz t2, 2f
    fsub.s ft1, ft1, ft9
2:
    fneg.s ft2, ft8
    flt.s t2, ft1, ft2
    beqz t2, 3f
    fadd.s ft1, ft1, ft9
3:
    fsw ft1, CAM_YAW(t3)
    la t1, k_look_speed
    flw ft0, 0(t1)
    fmul.s ft0, fs4, ft0
    fmul.s ft0, ft0, fs0
    flw ft1, CAM_PITCH(t3)
    fadd.s ft1, ft1, ft0
    la t1, k_pitch_limit
    flw ft2, 0(t1)
    fmin.s ft1, ft1, ft2
    fneg.s ft2, ft2
    fmax.s ft1, ft1, ft2
    fsw ft1, CAM_PITCH(t3)
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
    jab.sys.api.write t0, t1
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

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
    jab.sys.api.write t0, t1
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

report_fill:
    la t3, report_record
    la t4, cam_sector
    lw t4, 0(t4)
    sw t4, REPORT_SECTOR(t3)
    la t4, camera
    lw t5, CAM_X(t4)
    sw t5, REPORT_X(t3)
    lw t5, CAM_Y(t4)
    sw t5, REPORT_Y(t3)
    lw t5, CAM_Z(t4)
    sw t5, REPORT_Z(t3)
    flw ft8, CAM_YAW(t4)
    jab.f32.deg ft8, ft8
    fsw ft8, REPORT_YAW(t3)
    flw ft8, CAM_PITCH(t4)
    jab.f32.deg ft8, ft8
    fsw ft8, REPORT_PITCH(t3)
    flw ft8, CAM_ROLL(t4)
    jab.f32.deg ft8, ft8
    fsw ft8, REPORT_ROLL(t3)
    la t4, frame_us
    lw t4, 0(t4)
    sw t4, REPORT_FRAME_US(t3)
    la t4, game_us
    lw t4, 0(t4)
    sw t4, REPORT_GAME_US(t3)
    ret

.section .bss
.balign 8
camera:
    .skip CAM_SIZE
.balign 8
camera_d:
    .skip CAMD_SIZE
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
