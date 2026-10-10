.set CONSOLE_FRAME, 64
.set CONSOLE_CAPACITY, 1024

.section .text

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

console_frame:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    mv s2, a0
    lbu t0, 0(s2)
    li t1, 'P'
    bne t0, t1, 2f
    la t3, camera
    lw t1, 4(s2)
    sw t1, CAM_X(t3)
    lw t1, 8(s2)
    sw t1, CAM_Y(t3)
    lw t1, 12(s2)
    sw t1, CAM_Z(t3)
    flw ft8, 16(s2)
    jab.f32.rad ft8, ft8
    fsw ft8, CAM_YAW(t3)
    flw ft8, 20(s2)
    jab.f32.rad ft8, ft8
    fsw ft8, CAM_PITCH(t3)
    flw ft8, 24(s2)
    jab.f32.rad ft8, ft8
    fsw ft8, CAM_ROLL(t3)
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
    bne t0, t1, 5f
    call noise_heard
    j 8f
5:
    li t1, 'L'
    bne t0, t1, 9f
    lbu t1, 4(s2)
    beqz t1, 6f
    call lumels_bright
.ifdef CENSUS
    la t0, census_stale
    li t1, 1
    sb t1, 0(t0)                    # the census's uniformity unknown again
.endif
6:
.ifdef DEBUG
    lbu t1, 7(s2)
    beqz t1, 62f
    call lumels_parity              # every lumel by its node's parity
.ifdef CENSUS
    la t0, census_stale
    li t1, 1
    sb t1, 0(t0)
.endif
62:
    lbu t1, 6(s2)
    beqz t1, 63f
    call lumels_gradient            # every lumel by its node's column and row
.ifdef CENSUS
    la t0, census_stale
    li t1, 1
    sb t1, 0(t0)
.endif
63:
.endif
    li t1, 1
    la t0, tile_forget
    sb t1, 0(t0)                    # every tile forgotten at the next boundary
    la t0, tile_config_changed
    sb t1, 0(t0)
    li t1, CONFIG_UNLIMITED         # the quota and the allowance lifted
    lbu t2, 5(s2)
    beqz t2, 7f
    li t1, CONFIG_FROZEN            # or construction frozen
7:
    la t0, tile_pending_flags
    ld t2, 0(t0)
    andi t2, t2, CONFIG_STALE
    or t1, t1, t2                   # the stale knob kept
    sd t1, 0(t0)
    j 8f
9:
    li t1, 'R'
    bne t0, t1, 10f
    lwu t1, 4(s2)
    lwu t2, 8(s2)
    slli t2, t2, 32
    or t1, t1, t2                   # the seed, bytes 4 to 11
    la t3, rng
    jab.rng.seed t3, t1
    j 8f
10:
    li t1, 'E'
    bne t0, t1, 11f
    la t1, measure_end
    li t2, 1
    sb t2, 0(t1)                    # the frame records close after this frame's
    j 8f
11:
    li t1, 'C'
    bne t0, t1, 12f
    lbu t1, 4(s2)
    li t2, CADENCE_COUNT
    bgeu t1, t2, 8f                 # any other value leaves the cadence
    la t2, cadence
    sw t1, 0(t2)                    # from this frame's flip on
    j 8f
12:
    li t1, 'W'
    bne t0, t1, 13f
    lbu t1, 4(s2)
    la t2, workers_started
    lwu t2, 0(t2)
    bleu t1, t2, 121f
    mv t1, t2                       # no more than started
121:
    la t2, workers_active
    sw t1, 0(t2)                    # from the next frame's drawing on
    lwu t1, 8(s2)
    li t2, SCREEN_H
    bleu t1, t2, 122f
    mv t1, t2
122:
    la t2, band_grain
    sw t1, 0(t2)                    # rows a band, 0 for a band a worker
    j 8f
13:
.ifdef DEBUG
    li t1, 'S'
    bne t0, t1, 14f
    lbu t1, 4(s2)
    la t2, stall_on
    sb t1, 0(t2)                    # the standing stall on, or the drawing back
    lwu t1, 8(s2)
    la t2, stall_us
    sw t1, 0(t2)
    lwu t1, 12(s2)
    la t2, stall_once
    sw t1, 0(t2)                    # this frame's own stall, 0 for none
    lbu t1, 5(s2)
    la t2, flip_first
    sb t1, 0(t2)                    # this frame's flip tried before its wait
    lwu t1, 16(s2)
    la t2, consume_spin
    sw t1, 0(t2)                    # the spin inside every consume
    j 8f
14:
    li t1, 'K'
    bne t0, t1, 141f
    lwu t1, 4(s2)
    la t2, packet_command_cap
    sw t1, 0(t2)                    # the commands a packet holds, 0 for MAX_COMMANDS
    lwu t1, 8(s2)
    la t2, packet_span_cap
    sw t1, 0(t2)                    # the spans a packet holds, 0 for SPAN_RECORDS
    j 8f
141:
    li t1, 'O'
    bne t0, t1, 149f
    lbu t1, 4(s2)
    andi t1, t1, (CONFIG_UNLIMITED | CONFIG_FROZEN | CONFIG_STALE | CONFIG_ONCE)
    la t2, tile_pending_flags
    sd t1, 0(t2)                    # the modes, every one
    lwu t1, 8(s2)
    li t2, TILE_SLOTS
    beqz t1, 142f
    bleu t1, t2, 143f
142:
    mv t1, t2
143:
    la t2, tile_pending_effective
    sd t1, 0(t2)                    # the slots the pool may use, 0 for all
    lwu t1, 12(s2)
    li t2, TILE_GUARANTEE
    beqz t1, 144f
    bleu t1, t2, 145f
144:
    mv t1, t2
145:
    la t2, tile_pending_guarantee
    sd t1, 0(t2)                    # a tier's requests, 0 for TILE_GUARANTEE
    lwu t1, 16(s2)
    li t2, TILE_RING
    beqz t1, 146f
    bleu t1, t2, 147f
146:
    mv t1, t2
147:
    la t2, tile_pending_ring
    sd t1, 0(t2)                    # an open ring's entries, 0 for TILE_RING
    lwu t1, 20(s2)
    bnez t1, 148f
    li t1, TILE_MERGE_US
148:
    la t2, tile_pending_merge
    sd t1, 0(t2)                    # the merge's share in microseconds, 0 for TILE_MERGE_US
    lwu t1, 24(s2)
    la t2, tile_pending_quota
    sd t1, 0(t2)                    # a boundary's work in texels under every mode, 0 for the build's own
    li t1, 1
    la t2, tile_config_changed
    sb t1, 0(t2)
    lbu t1, 5(s2)
    la t2, tile_trace
    sb t1, 0(t2)                    # every pass's surfaces on the UART while set
    lbu t1, 6(s2)
    beqz t1, 8f
    li t1, 1
    la t2, tile_forget
    sb t1, 0(t2)                    # a cold start at the next boundary: every tile forgotten
    la t2, tile_cold
    sb t1, 0(t2)                    # and the frame before's requests discarded
    j 8f
149:
    li t1, 'B'
    bne t0, t1, 150f
    lwu t1, 4(s2)
    addi t1, t1, 1
    la t2, tile_build_surface
    sd t1, 0(t2)                    # the surface plus one, every tile of it built at the next boundary
    j 8f
150:
    li t1, 'D'
    bne t0, t1, 151f
    lbu t1, 8(s2)
    la t2, tile_dump_building
    sb t1, 0(t2)                    # the tile in construction too while set
    lwu a0, 4(s2)
    call tile_dump                  # the surface's tiles, or every one's, on the API now
    j 8f
151:
    li t1, 'M'
    bne t0, t1, 15f
    lbu t1, 4(s2)
    la t2, level_raise
    sb t1, 0(t2)                    # every block's level raised by it from this frame's drawing
    lbu t1, 5(s2)
    la t2, hud_stamp
    sb t1, 0(t2)                    # the frame's number stamped by the HUD while set
    j 8f
15:
    li t1, 'J'
.ifdef CENSUS
    bne t0, t1, 16f
.else
    bne t0, t1, 8f
.endif
    lbu t1, 4(s2)
    la t2, job_delay_worker
    sb t1, 0(t2)                    # the delayed worker's index plus one, 0 for none
    lwu t1, 8(s2)
    la t2, job_delay_us
    sw t1, 0(t2)                    # its delay before each band
    lbu t1, 12(s2)
    la t2, job_cancel
    sb t1, 0(t2)                    # every round cancelled after its publish while set
    lbu t1, 13(s2)
    la t2, job_fault_worker
    sb t1, 0(t2)                    # the faulting worker's index plus one, its next round
    lbu t1, 14(s2)
    la t2, job_hold
    sb t1, 0(t2)                    # the delayed worker held until the round's join releases it
.ifdef CENSUS
    j 8f
16:
    li t1, 'Q'
    bne t0, t1, 8f
    lwu t1, 4(s2)
    la t2, census_chunk
    sw t1, 0(t2)                    # a census context line's chunk, 0 for the build's bound
.endif
.endif
8:
    la t0, console_record
    li t1, REPORT_CONSOLE
    sw t1, 0(t0)
    lbu t1, 0(s2)
    sw t1, 4(t0)
    li t1, REPORT_SIZE
    jab.sys.api.write t0, t1
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

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
measure_end:
    .skip 1
.ifdef DEBUG
stall_on:
    .skip 1
flip_first:
    .skip 1
.balign 4
stall_us:
    .skip 4
stall_once:
    .skip 4
consume_spin:
    .skip 4
.endif
