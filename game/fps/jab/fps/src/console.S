# console.S: the console, a test channel over the API's input: frames
# of CONSOLE_FRAME bytes, a kind byte, three of padding, and the rest by
# the kind, zero to the frame's end; every whole frame done each turn,
# a partial one kept. P: the camera placed, six floats from byte 4, the
# eye's x, y, and z then the yaw, pitch, and roll in degrees, its
# sector found from the whole map, its basis derived at once, and the
# next frame drawn reported on the UART as the first was. T: a trace
# from the eye along the camera's
# forward over the trace's range, answered over the API as kind
# REPORT_TRACE with what it met, the distance, and the point in
# millimetres. F: one round, as the trigger fires it. N: a noise at the
# player, as a shot makes one. Each frame is reported over the API as kind
# REPORT_CONSOLE with the command's byte at 4. Without the port nothing
# arrives.

.set CONSOLE_FRAME, 64
.set CONSOLE_CAPACITY, 1024

.section .text

# console_read: what the host has sent taken in behind what waits,
# every whole frame done, the rest kept.
console_read:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    la t0, console_pending
    lwu s2, 0(t0)                   # the bytes kept
    la a0, console_buf
    add a0, a0, s2
    li a1, CONSOLE_CAPACITY
    sub a1, a1, s2
    li a7, JAB_SYS_API_READ
    ecall
    add s2, s2, a0                  # the bytes held
    la s3, console_buf              # the frame in hand
1:
    li t0, CONSOLE_FRAME
    bltu s2, t0, 8f
    mv a0, s3
    call console_frame
    addi s3, s3, CONSOLE_FRAME
    addi s2, s2, -CONSOLE_FRAME
    j 1b
8:
    # the partial frame moved to the front
    la t0, console_buf
    mv t1, s2
2:
    beqz t1, 3f
    lbu t2, 0(s3)
    sb t2, 0(t0)
    addi s3, s3, 1
    addi t0, t0, 1
    addi t1, t1, -1
    j 2b
3:
    la t0, console_pending
    sw s2, 0(t0)
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

# console_frame: the frame at a0 done by its kind byte, then reported;
# an unknown kind does nothing but the report.
console_frame:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    lbu t0, 0(s2)
    li t1, 'P'
    bne t0, t1, 2f
    la t0, camera
    lw t1, 4(s2)
    sw t1, CAM_X(t0)
    lw t1, 8(s2)
    sw t1, CAM_Y(t0)
    lw t1, 12(s2)
    sw t1, CAM_Z(t0)
    la t2, k_degree
    flw ft0, 0(t2)
    flw ft1, 16(s2)
    fmul.s ft1, ft1, ft0
    fsw ft1, CAM_YAW(t0)
    flw ft1, 20(s2)
    fmul.s ft1, ft1, ft0
    fsw ft1, CAM_PITCH(t0)
    flw ft1, 24(s2)
    fmul.s ft1, ft1, ft0
    fsw ft1, CAM_ROLL(t0)
    la t0, cam_sector
    li t1, -1
    sw t1, 0(t0)
    call camera_locate
    call camera_basis               # fresh for a command in the same batch
    la t0, report_pending           # the next frame reported on the UART
    li t1, 1
    sb t1, 0(t0)
    j 8f
2:
    li t1, 'T'
    bne t0, t1, 3f
    call console_trace
    j 8f
3:
    li t1, 'F'
    bne t0, t1, 4f
    call player_fire
    j 8f
4:
    li t1, 'N'
    bne t0, t1, 8f
    call noise_heard
8:
    la t0, console_record
    li t1, REPORT_CONSOLE
    sw t1, 0(t0)
    lbu t1, 0(s2)
    sw t1, 4(t0)
    li t1, REPORT_SIZE
    jab.api.write t0, t1
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

# console_trace: a trace from the eye along the camera's forward over
# the trace's range, from the camera's sector, the geometry and the
# androids alone; answered as REPORT_TRACE: the kind met, the distance,
# and the point, each in millimetres.
console_trace:
    addi sp, sp, -16
    sd ra, 8(sp)
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
    la t0, k_trace_range_d
    fld fa6, 0(t0)
    la t0, cam_sector
    lw a0, 0(t0)
    li a1, 0
    li a2, 0
    call trace_ray
    la t0, trace_hit
    la t1, k_thousand_d
    fld ft1, 0(t1)
    ld a1, TRACE_KIND(t0)
    fld ft0, TRACE_DIST(t0)
    fmul.d ft0, ft0, ft1
    fcvt.l.d a2, ft0, rne
    fld ft0, TRACE_PX(t0)
    fmul.d ft0, ft0, ft1
    fcvt.l.d a3, ft0, rne
    fld ft0, TRACE_PY(t0)
    fmul.d ft0, ft0, ft1
    fcvt.l.d a4, ft0, rne
    fld ft0, TRACE_PZ(t0)
    fmul.d ft0, ft0, ft1
    fcvt.l.d a5, ft0, rne
    li a0, REPORT_TRACE
    call event_report
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.section .rodata
.balign 8
k_thousand_d:
    .double 1000.0

.section .bss
.balign 8
console_buf:
    .skip CONSOLE_CAPACITY
console_record:
    .skip REPORT_SIZE
console_pending:
    .skip 4
report_pending:
    .skip 1
