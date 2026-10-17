.include "jab.inc"

.set DISK, 1
.set FRAME_W, 480
.set FRAME_H, 640
.set FRAMES, 16
.set SPRITE_BYTES, (JAB_SPRITE_PIXELS + FRAMES * FRAME_H * (FRAME_W * 4 + 4))
.set LANES, 8
.set LANE_H, (JAB_DISPLAY_HEIGHT / LANES)
.set PER_LANE, 3
.set SCALE_MIN, 53
.set SCALE_MAX, 75
.set STRIDE, 312
.set ENTRY_GAP, 240
.set ENTRY_WAIT, (4 * JAB_TIME_HZ)
.set ANIM_TICKS, (JAB_TIME_HZ / 16)
.set DT_MAX, (JAB_TIME_HZ / 10)
.set BACKGROUND, 0x00000000
.set W_X, 0                     # the left edge, in 256ths of a pixel
.set W_DIR, 8                   # 1 walking right, -1 walking left
.set W_SCALE, 16
.set W_TINT, 24
.set W_FRAME, 32
.set W_TICK, 40                 # the animation's time since its last frame
.set W_DW, 48                   # the drawn size
.set W_DH, 56
.set W_Y, 64                    # the top, the feet on the lane's floor
.set W_ACTIVE, 72
.set W_SPEED, 80                # 256ths of a pixel a second
.set W_SIZE, 88
.set LANE_WAIT, (PER_LANE * W_SIZE)
.set LANE_SIZE, (LANE_WAIT + 8)
.set R_KIND, 0
.set R_LANE, 1
.set R_SIDE, 2
.set R_SCALE, 3
.set R_TINT, 4
.set R_SIZE, 8

.ifndef CADENCE
.ifdef TIMING
.error "TIMING is one of CADENCE's variants: set cadence with it"
.endif
.ifdef REPLAY
.error "REPLAY is one of CADENCE's variants: set cadence with it"
.endif
.ifdef PREPARE
.error "PREPARE is one of CADENCE's variants: set cadence with it"
.endif
.ifdef CADENCE_TEST
.error "CADENCE_TEST is one of CADENCE's variants: set cadence with it"
.endif
.endif

.ifdef CADENCE
.ifdef WHOLE
.error "CADENCE measures the rectangle list's flips; WHOLE is no build of it"
.endif
.set CADENCE_SEED, 0x2545f4914f6cdd1d
.set REPLAY_WAIT, (10 * JAB_TIME_HZ)
.set ANCHOR_PERIODS, 30
.set TRAIL_PERIODS, 60
.ifdef CADENCE_TEST
.set WINDOW_TICKS, (10 * JAB_TIME_HZ)
.else
.set WINDOW_TICKS, (120 * JAB_TIME_HZ)
.endif
.ifdef REPLAY
.set WINDOW_FIELD, 0
.else
.set WINDOW_FIELD, WINDOW_TICKS
.endif
.set CADENCE_FRAMES, 8192
.set EVENTS_MAX, 4096
.set EVENT_HEADROOM, 48         # eight lanes of three, each leaving and one entering
.set EXPORT_CHUNK, 4096
.set SCHEMA, 4
.set MAGIC, 0x44414357          # WCAD as a le32
.set NONCE_MAGIC, 0x4e4f4e57    # WNON
.set REPLAY_MAGIC, 0x4c505257   # WRPL
.set QUIET_FRAMES, 60
.set STALL_FIRST, 240
.set STALL_LAST, 299
.set STALL_TICKS, (JAB_TIME_HZ / 40)
.set CLAMP_FRAME, 330
.set CLAMP_TICKS, (JAB_TIME_HZ / 20 * 3)
.set FLAG_BITS, 0
.ifdef TIMING
.set FLAG_BITS, (FLAG_BITS | 1)
.endif
.ifdef REPLAY
.set FLAG_BITS, (FLAG_BITS | 2)
.endif
.ifdef PREPARE
.set FLAG_BITS, (FLAG_BITS | 4)
.endif
.ifdef CADENCE_TEST
.set FLAG_BITS, (FLAG_BITS | 8)
.endif
.set F_KIND, 0
.set F_ISSUED, 1
.set F_STATUS, 2
.set F_WALKERS, 3
.set F_FRAME, 4
.set F_START, 8
.set F_CALL_END, 12
.set F_WAIT_START, 16           # TIMING's four
.set F_WAIT_END, 20
.set F_WORK_END, 24
.set F_CALL_START, 28
.set F_RAW, 32
.set F_DT, 36
.set F_RECTS, 40
.set F_ENTERS, 42
.set F_LEAVES, 43
.set F_RECT_AREA, 44
.set F_S, 48
.set F_T, 56
.set F_ORDINAL, 64
.set F_DRAWN, 68
.set F_WAITED, 72
.set F_SCHEMA, 76
.set F_SIZE, 80
.set H_KIND, 0
.set H_ENDED, 1
.set H_ANCHORS, 2
.set H_MAGIC, 4
.set H_SCHEMA, 8
.set H_FRAMES, 12
.set H_EVENTS, 16
.set H_RATE, 20
.set H_SEED, 24
.set H_WINDOW, 32
.set H_FRAME_SIZE, 36
.set H_EVENT_SIZE, 38
.set H_FLAGS, 40
.set H_TRAIL, 44
.set H_HEADER_SIZE, 46
.set H_ORIGIN, 48
.set H_OPENED, 56
.set H_NONCE, 64
.set H_SIZE, 80
.set E_KIND, 0
.set E_MAGIC, 4
.set E_SCHEMA, 8
.set E_FRAMES, 12
.set E_EVENTS, 16
.set E_CRC, 20
.set E_OMITTED, 24
.set E_SIZE, 64
.set N_MAGIC, 0
.set N_ZERO, 4
.set N_NONCE, 8
.set N_SIZE, 16
.set RP_MAGIC, 0
.set RP_SCHEMA, 4
.set RP_FRAMES, 8
.set RP_SEED, 16
.set RP_SIZE, 64
.set ENDED_DURATION, 1
.set ENDED_FRAMES, 2
.set ENDED_EVENTS, 3
.set ENDED_REPLAY, 4
.set ENDED_RANGE, 5
.set NO_STATUS, 255
.endif

.section .text
.global _start
_start:
    la t0, sprite
    li t1, DISK
    jab.sys.sprite.load t0, t1, path_walker, SPRITE_BYTES
    bnez a0, bad_sprite
    jab.sys.display.open
    bnez a0, no_display
.ifdef CADENCE
    rdtime t0
    la t1, header
    sd t0, H_OPENED(t1)
    call cadence_setup
.else
    rdtime t0
    la t1, last_time
    sd t0, 0(t1)
    ori t0, t0, 1
    la t1, seed
    sd t0, 0(t1)
.endif
frame:
.ifdef CADENCE
    call frame_begin
.ifndef PREPARE
    call await_stamped
.endif
.else
    jab.sys.display.await
.endif
    call elapsed
.ifdef CADENCE
    call frame_started
.endif
    la t0, rect_count
    sd zero, 0(t0)
    li s0, 0
2:
    li t0, LANE_SIZE
    mul t0, t0, s0
    la s2, lanes
    add s2, s2, t0              # the lane
    li s3, 0
3:
    li t0, W_SIZE
    mul t0, t0, s3
    add s1, s2, t0              # the walker
    ld t0, W_ACTIVE(s1)
    beqz t0, 5f
    ld s4, W_X(s1)
    srai s4, s4, 8              # the left edge it had
    ld t1, W_FRAME(s1)
    mv t2, s4
    ld t3, W_Y(s1)
    li t4, BACKGROUND
    ld t5, W_SCALE(s1)
    ld t6, W_DIR(s1)
    bgez t6, 32f
    li t6, JAB_SPRITE_FLIP_H | JAB_SPRITE_SOLID
    j 33f
32:
    li t6, JAB_SPRITE_SOLID
33:
    la t0, sprite
    jab.sys.sprite.draw t0, t1, t2, t3, t4, t5, t6
    ld a0, W_X(s1)
    ld a1, W_SPEED(s1)
    ld t2, W_DIR(s1)
    mul a1, a1, t2
    call advance
    sd a0, W_X(s1)
    ld t1, W_TICK(s1)
    la t2, dt
    ld t2, 0(t2)
    add t1, t1, t2
    li t2, ANIM_TICKS
    bltu t1, t2, 4f
    sub t1, t1, t2
    ld t3, W_FRAME(s1)
    addi t3, t3, 1
    li t4, FRAMES
    bltu t3, t4, 31f
    li t3, 0
31:
    sd t3, W_FRAME(s1)
4:
    sd t1, W_TICK(s1)
    ld t0, W_X(s1)
    srai t0, t0, 8
    ld t1, W_DW(s1)
    mv a0, s4
    blt s4, t0, 43f
    mv a0, t0
43:
    add a1, s4, t1
    add t2, t0, t1
    bgt a1, t2, 44f
    mv a1, t2
44:
    ld a2, W_Y(s1)
    ld a3, W_DH(s1)
    call note_rect
    ld t0, W_X(s1)
    srai t0, t0, 8
    ld t2, W_DIR(s1)
    bltz t2, 41f
    li t3, JAB_DISPLAY_WIDTH
    blt t0, t3, 5f
    j 42f
41:
    ld t3, W_DW(s1)
    add t0, t0, t3
    bgtz t0, 5f
42:
    sd zero, W_ACTIVE(s1)
    mv a0, s0
    call leave
5:
    addi s3, s3, 1
    li t0, PER_LANE
    bltu s3, t0, 3b
.ifdef CADENCE_TEST
    li t0, QUIET_FRAMES
    bltu s6, t0, 45f            # the quiet frames admit nobody
.endif
    mv a0, s2
    mv a1, s0
    call admit
45:
    addi s0, s0, 1
    li t0, LANES
    bltu s0, t0, 2b
    li s0, 0
6:
    li t0, LANE_SIZE
    mul t0, t0, s0
    la s2, lanes
    add s2, s2, t0
    li s3, 0
7:
    li t0, W_SIZE
    mul t0, t0, s3
    add s1, s2, t0
    ld t0, W_ACTIVE(s1)
    beqz t0, 8f
.ifdef CADENCE
    call note_drawn
.endif
    ld t1, W_FRAME(s1)
    ld t2, W_X(s1)
    srai t2, t2, 8
    ld t3, W_Y(s1)
    ld t4, W_TINT(s1)
    ld t5, W_SCALE(s1)
    ld t6, W_DIR(s1)
    bgez t6, 71f
    li t6, JAB_SPRITE_FLIP_H
    j 72f
71:
    li t6, 0
72:
    la t0, sprite
    jab.sys.sprite.draw t0, t1, t2, t3, t4, t5, t6
8:
    addi s3, s3, 1
    li t0, PER_LANE
    bltu s3, t0, 7b
    addi s0, s0, 1
    li t0, LANES
    bltu s0, t0, 6b
.ifdef CADENCE
    call frame_present
    beqz a0, frame
    j trail
.else
.ifdef WHOLE
    jab.sys.display.flip
.else
    la t0, rect_count
    ld t1, 0(t0)
    beqz t1, frame
    la t0, rects
    jab.sys.display.flip.rects t0, t1
.endif
    j frame
.endif

bad_sprite:
    la t0, msg_bad_sprite_code
    li t1, 10
    divu t2, a0, t1
    remu t3, a0, t1
    beqz t2, 1f
    addi t2, t2, '0'
    sb t2, 0(t0)
    addi t0, t0, 1
1:
    addi t3, t3, '0'
    sb t3, 0(t0)
    li t3, '\n'
    sb t3, 1(t0)
    sb zero, 2(t0)
    jab.sys.uart.print msg_bad_sprite
    jab.sys.exit 1
no_display:
    jab.sys.uart.print msg_no_display
    jab.sys.exit 1

admit:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd a0, 0(sp)
    sd a1, 8(sp)
    li t1, 0                    # the place
    li t2, -1                   # the free one
    li t3, 0                    # how many are walking
1:
    li t0, W_SIZE
    mul t0, t0, t1
    add t0, t0, a0
    ld t4, W_ACTIVE(t0)
    beqz t4, 11f
    addi t3, t3, 1
    j 12f
11:
    bgez t2, 12f
    mv t2, t1
12:
    addi t1, t1, 1
    li t0, PER_LANE
    bltu t1, t0, 1b
    bltz t2, 9f                 # every place taken
    sd t2, 16(sp)
    beqz t3, 2f                 # an empty lane waits for nothing
    ld t0, LANE_WAIT(a0)
    blez t0, 2f
    la t4, dt
    ld t4, 0(t4)
    sub t0, t0, t4
    sd t0, LANE_WAIT(a0)
    j 9f
2:
    call random
    andi t5, a0, 1
    sd t5, 24(sp)               # the side, 0 the left
    ld a0, 0(sp)
    li t1, 0
3:
    li t0, W_SIZE
    mul t0, t0, t1
    add t0, t0, a0
    ld t4, W_ACTIVE(t0)
    beqz t4, 4f
    ld t4, W_X(t0)
    srai t4, t4, 8
    ld t5, 24(sp)
    bnez t5, 31f
    li t6, ENTRY_GAP
    blt t4, t6, 9f              # too near the left edge
    j 4f
31:
    ld t6, W_DW(t0)
    add t4, t4, t6
    li t6, JAB_DISPLAY_WIDTH - ENTRY_GAP
    bgt t4, t6, 9f              # too near the right edge
4:
    addi t1, t1, 1
    li t0, PER_LANE
    bltu t1, t0, 3b
    ld t2, 16(sp)
    li t0, W_SIZE
    mul t0, t0, t2
    ld a0, 0(sp)
    add a0, a0, t0
    ld a1, 8(sp)
    ld a2, 24(sp)
    call enter
    call random
    li t1, ENTRY_WAIT
    remu t0, a0, t1
    ld a0, 0(sp)
    sd t0, LANE_WAIT(a0)
9:
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

enter:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd a0, 0(sp)
    sd a1, 8(sp)
    sd a2, 16(sp)
    call random
    li t1, SCALE_MAX - SCALE_MIN + 1
    remu t0, a0, t1
    addi t0, t0, SCALE_MIN
    ld a1, 0(sp)
    sd t0, W_SCALE(a1)
    call random
    li t1, 192
    remu t2, a0, t1
    addi t2, t2, 64
    slli t2, t2, 16
    srli a0, a0, 8
    remu t3, a0, t1
    addi t3, t3, 64
    slli t3, t3, 8
    or t2, t2, t3
    srli a0, a0, 8
    remu t3, a0, t1
    addi t3, t3, 64
    or t2, t2, t3
    ld a1, 0(sp)
    sd t2, W_TINT(a1)
    call random
    li t1, FRAMES
    remu t0, a0, t1
    ld a1, 0(sp)
    sd t0, W_FRAME(a1)
    sd zero, W_TICK(a1)
    ld t0, W_SCALE(a1)
    li t1, FRAME_W
    mul t1, t1, t0
    srli t1, t1, 8
    sd t1, W_DW(a1)
    li t2, FRAME_H
    mul t2, t2, t0
    srli t2, t2, 8
    sd t2, W_DH(a1)
    ld t3, 8(sp)
    addi t3, t3, 1
    li t4, LANE_H
    mul t3, t3, t4
    sub t3, t3, t2
    sd t3, W_Y(a1)
    li t3, STRIDE
    mul t3, t3, t0
    sd t3, W_SPEED(a1)
    ld t0, 16(sp)
    bnez t0, 1f
    neg t1, t1
    slli t1, t1, 8
    sd t1, W_X(a1)
    li t2, 1
    sd t2, W_DIR(a1)
    j 2f
1:
    li t1, JAB_DISPLAY_WIDTH
    slli t1, t1, 8
    sd t1, W_X(a1)
    li t2, -1
    sd t2, W_DIR(a1)
2:
    li t0, 1
    sd t0, W_ACTIVE(a1)
    la t0, record
    li t1, 1
    sb t1, R_KIND(t0)
    ld t1, 8(sp)
    sb t1, R_LANE(t0)
    ld t1, 16(sp)
    sb t1, R_SIDE(t0)
    ld t1, W_SCALE(a1)
    sb t1, R_SCALE(t0)
    ld t1, W_TINT(a1)
    sw t1, R_TINT(t0)
.ifdef CADENCE
    call event_append
.else
    la t0, record
    li t1, R_SIZE
    jab.sys.api.write t0, t1
.endif
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

leave:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, record
    li t1, 2
    sb t1, R_KIND(t0)
    sb a0, R_LANE(t0)
    sb zero, R_SIDE(t0)
    sb zero, R_SCALE(t0)
    sw zero, R_TINT(t0)
.ifdef CADENCE
    call event_append
.else
    la t0, record
    li t1, R_SIZE
    jab.sys.api.write t0, t1
.endif
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

note_rect:
    bgez a0, 1f
    li a0, 0
1:
    li t0, JAB_DISPLAY_WIDTH
    ble a1, t0, 2f
    mv a1, t0
2:
    bge a0, a1, 9f
    add t1, a2, a3              # the bottom
    bgez a2, 3f
    li a2, 0
3:
    li t0, JAB_DISPLAY_HEIGHT
    ble t1, t0, 4f
    mv t1, t0
4:
    bge a2, t1, 9f
    la t2, rect_count
    ld t3, 0(t2)
    slli t4, t3, 4
    la t0, rects
    add t0, t0, t4
    sw a0, JAB_RECT_X(t0)
    sw a2, JAB_RECT_Y(t0)
    sub a1, a1, a0
    sw a1, JAB_RECT_WIDTH(t0)
    sub t1, t1, a2
    sw t1, JAB_RECT_HEIGHT(t0)
.ifdef CADENCE
    mul t5, a1, t1
    la t6, frame_rect_area
    ld t4, 0(t6)
    add t4, t4, t5
    sd t4, 0(t6)
.endif
    addi t3, t3, 1
    sd t3, 0(t2)
9:
    ret

elapsed:
    rdtime t0
    la t1, last_time
    ld t2, 0(t1)
    sd t0, 0(t1)
    sub t0, t0, t2
.ifdef CADENCE
    la t1, raw_elapsed
    sd t0, 0(t1)
.endif
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

random:
    la t0, seed
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

.ifdef CADENCE
cadence_setup:
    addi sp, sp, -16
    sd ra, 8(sp)
    rdtime s7
    li t0, REPLAY_WAIT
    add s7, s7, t0              # the waits' deadline, taken once
    la a0, nonce_frame
    li a1, N_SIZE
    call api_fill
    bnez a0, no_nonce
    la t0, nonce_frame
    lwu t1, N_MAGIC(t0)
    li t2, NONCE_MAGIC
    bne t1, t2, bad_nonce
    lwu t1, N_ZERO(t0)
    bnez t1, bad_nonce
    ld t1, N_NONCE(t0)
    beqz t1, bad_nonce
    la t2, header
    sd t1, H_NONCE(t2)
.ifdef REPLAY
    la a0, replay_head
    li a1, RP_SIZE
    call api_fill
    bnez a0, no_replay
    la t0, replay_head
    lwu t1, RP_MAGIC(t0)
    li t2, REPLAY_MAGIC
    bne t1, t2, bad_replay
    lwu t1, RP_SCHEMA(t0)
    li t2, 1
    bne t1, t2, bad_replay
    lwu t1, RP_FRAMES(t0)
    beqz t1, bad_replay
    li t2, CADENCE_FRAMES
    bgtu t1, t2, bad_replay
    la a0, replay_dts
    slli a1, t1, 2
    call api_fill
    bnez a0, no_replay
    la t0, replay_head
    ld t1, RP_SEED(t0)
.else
    li t1, CADENCE_SEED
.endif
    la t0, seed
    sd t1, 0(t0)
    la t0, header
    sd t1, H_SEED(t0)
    li t1, 1
    la t0, last_ordinal
    sd t1, 0(t0)                # the display's open, the machine's first present
    li s7, ANCHOR_PERIODS
1:
    jab.sys.display.await
    addi s7, s7, -1
    bnez s7, 1b
    rdtime t0                   # the origin
    la t1, origin
    sd t0, 0(t1)
    la t1, header
    sd t0, H_ORIGIN(t1)
    la t1, last_time
    sd t0, 0(t1)
    li s6, 0
    ld ra, 8(sp)
    addi sp, sp, 16
    ret
no_nonce:
    jab.sys.uart.print msg_no_nonce
    jab.sys.exit 6
bad_nonce:
    jab.sys.uart.print msg_bad_nonce
    jab.sys.exit 6
.ifdef REPLAY
no_replay:
    jab.sys.uart.print msg_no_replay
    jab.sys.exit 5
bad_replay:
    jab.sys.uart.print msg_bad_replay
    jab.sys.exit 5
.endif

api_fill:
    addi sp, sp, -32
    sd s8, 16(sp)
    sd s9, 8(sp)
    mv s8, a0                   # where the next byte goes
    mv s9, a1                   # the bytes still to come
1:
    mv a0, s8
    mv a1, s9
    li a7, JAB_SYS_API_READ
    ecall                       # never waits
    add s8, s8, a0
    sub s9, s9, a0
    beqz s9, 3f
    rdtime t0
    bgeu t0, s7, 2f
    jab.sys.await JAB_AWAIT_DISPLAY | JAB_AWAIT_API
    j 1b
2:
    li a0, 1
    j 4f
3:
    li a0, 0
4:
    ld s9, 8(sp)
    ld s8, 16(sp)
    addi sp, sp, 32
    ret

frame_begin:
    li t0, F_SIZE
    mul t0, t0, s6
    la s5, frames
    add s5, s5, t0
    la t0, frame_enters
    sd zero, 0(t0)
    la t0, frame_leaves
    sd zero, 0(t0)
    la t0, frame_walkers
    sd zero, 0(t0)
    la t0, frame_drawn
    sd zero, 0(t0)
    la t0, frame_rect_area
    sd zero, 0(t0)
    ret

await_stamped:
    addi sp, sp, -16
    sd ra, 8(sp)
.ifdef TIMING
    rdtime a0
    li a1, F_WAIT_START
    call stamp
.endif
    jab.sys.display.await
    li t0, 1
    sb t0, F_WAITED(s5)
.ifdef TIMING
    rdtime a0
    li a1, F_WAIT_END
    call stamp
.endif
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

frame_started:
    addi sp, sp, -16
    sd ra, 8(sp)
.ifdef REPLAY
    la t0, replay_dts
    slli t1, s6, 2
    add t0, t0, t1
    lwu t1, 0(t0)
    la t0, dt
    sd t1, 0(t0)
.endif
    la t0, last_time
    ld a0, 0(t0)
    li a1, F_START
    call stamp
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

stamp:
    la t0, origin
    ld t0, 0(t0)
    sub t0, a0, t0
    srli t1, t0, 32
    bnez t1, 1f
    add t1, s5, a1
    sw t0, 0(t1)
    ret
1:
    li t1, 1                    # past the range: not stored, the window ends here
    la t2, range_hit
    sd t1, 0(t2)
    ret

note_drawn:
    la t0, frame_walkers
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
    ld t1, W_DW(s1)
    ld t2, W_DH(s1)
    mul t1, t1, t2
    la t0, frame_drawn
    ld t2, 0(t0)
    add t2, t2, t1
    sd t2, 0(t0)
    ret

event_append:
    la t0, record
    lbu t1, R_KIND(t0)
    li t2, 1
    la t3, frame_enters
    beq t1, t2, 1f
    la t3, frame_leaves
1:
    ld t2, 0(t3)
    addi t2, t2, 1
    sd t2, 0(t3)
    la t3, event_count
    ld t1, 0(t3)
    li t2, EVENTS_MAX
    bgeu t1, t2, 2f
    slli t2, t1, 3
    la t4, events
    add t4, t4, t2
    ld t2, 0(t0)                # the record's eight bytes whole
    sd t2, 0(t4)
    addi t1, t1, 1
    sd t1, 0(t3)
    ret
2:
    la t3, event_omitted
    ld t1, 0(t3)
    addi t1, t1, 1
    sd t1, 0(t3)
    ret

frame_present:
    addi sp, sp, -16
    sd ra, 8(sp)
.ifdef CADENCE_TEST
    call test_spin
.endif
.ifdef TIMING
    rdtime a0
    li a1, F_WORK_END
    call stamp
.endif
.ifdef PREPARE
    call await_stamped
.endif
    la t0, rect_count
    ld t1, 0(t0)
    beqz t1, 3f
1:
.ifdef TIMING
    rdtime a0
    li a1, F_CALL_START
    call stamp
.endif
    la t0, rect_count
    ld t1, 0(t0)
    la t0, rects
    jab.sys.display.flip.rects t0, t1
    mv s7, a0                   # the receipt: status, acceptance, tick, ordinal
    mv s8, a1
    mv s9, a2
    mv s10, a3
    rdtime a0
    li a1, F_CALL_END
    call stamp
.ifdef PREPARE
    li t0, 1
    bne s7, t0, 2f
    jab.sys.display.await       # early: waited again, the image unchanged
.ifdef TIMING
    rdtime a0
    li a1, F_WAIT_END
    call stamp
.endif
    j 1b
2:
.endif
    li t0, 1
    sb t0, F_ISSUED(s5)
    sb s7, F_STATUS(s5)
    sd s8, F_S(s5)
    sd s9, F_T(s5)
    sw s10, F_ORDINAL(s5)
    la t0, last_ordinal
    sd s10, 0(t0)
    j 4f
3:
    rdtime s7                   # no rectangle: the skip's one stamp
.ifdef TIMING
    mv a0, s7
    li a1, F_CALL_START
    call stamp
.endif
    mv a0, s7
    li a1, F_CALL_END
    call stamp
    sb zero, F_ISSUED(s5)
    li t0, NO_STATUS
    sb t0, F_STATUS(s5)
    sd zero, F_S(s5)
    sd zero, F_T(s5)
    la t0, last_ordinal
    ld t0, 0(t0)
    sw t0, F_ORDINAL(s5)
4:
    call frame_end
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

frame_end:
    li t0, 1
    sb t0, F_KIND(s5)
    sw s6, F_FRAME(s5)
    la t0, frame_walkers
    ld t1, 0(t0)
    sb t1, F_WALKERS(s5)
    la t0, raw_elapsed
    ld t1, 0(t0)
    srli t2, t1, 32
    beqz t2, 1f
    li t1, -1                   # saturated, every bit of the stored word
1:
    sw t1, F_RAW(s5)
    la t0, dt
    ld t1, 0(t0)
    sw t1, F_DT(s5)
    la t0, rect_count
    ld t1, 0(t0)
    sh t1, F_RECTS(s5)
    la t0, frame_enters
    ld t1, 0(t0)
    sb t1, F_ENTERS(s5)
    la t0, frame_leaves
    ld t1, 0(t0)
    sb t1, F_LEAVES(s5)
    la t0, frame_rect_area
    ld t1, 0(t0)
    sw t1, F_RECT_AREA(s5)
    la t0, frame_drawn
    ld t1, 0(t0)
    sw t1, F_DRAWN(s5)
    li t1, SCHEMA
    sw t1, F_SCHEMA(s5)
    addi s6, s6, 1
    la t0, range_hit
    ld t1, 0(t0)
    li a0, ENDED_RANGE
    bnez t1, 8f
.ifdef REPLAY
    la t0, replay_head
    lwu t1, RP_FRAMES(t0)
    li a0, ENDED_REPLAY
    beq s6, t1, 8f
.else
    lwu t1, F_CALL_END(s5)
    li t2, WINDOW_TICKS
    li a0, ENDED_DURATION
    bgeu t1, t2, 8f
.endif
    li t1, CADENCE_FRAMES
    li a0, ENDED_FRAMES
    beq s6, t1, 8f
    la t0, event_count
    ld t1, 0(t0)
    li t2, EVENTS_MAX - EVENT_HEADROOM
    li a0, ENDED_EVENTS
    bgtu t1, t2, 8f
    li a0, 0
    ret
8:
    la t0, ended_by
    sd a0, 0(t0)
    li a0, 1
    ret

.ifdef CADENCE_TEST
test_spin:
    li t1, CLAMP_TICKS
    li t0, CLAMP_FRAME
    beq s6, t0, 1f
    li t1, STALL_TICKS
    li t0, STALL_FIRST
    bltu s6, t0, 3f
    li t0, STALL_LAST
    bgtu s6, t0, 3f
1:
    la t0, last_time
    ld t0, 0(t0)
    add t0, t0, t1              # the frame's start and its work
2:
    rdtime t2
    bltu t2, t0, 2b
3:
    ret
.endif

trail:
    li s7, TRAIL_PERIODS
1:
    jab.sys.display.await
    addi s7, s7, -1
    bnez s7, 1b
    call export
    jab.sys.exit 0

export:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, header
    li t1, 4
    sb t1, H_KIND(t0)
    la t2, ended_by
    ld t1, 0(t2)
    sb t1, H_ENDED(t0)
    li t1, ANCHOR_PERIODS
    sh t1, H_ANCHORS(t0)
    li t1, MAGIC
    sw t1, H_MAGIC(t0)
    li t1, SCHEMA
    sw t1, H_SCHEMA(t0)
    sw s6, H_FRAMES(t0)
    la t2, event_count
    ld t1, 0(t2)
    sw t1, H_EVENTS(t0)
    li t1, JAB_TIME_HZ
    sw t1, H_RATE(t0)
    li t1, WINDOW_FIELD
    sw t1, H_WINDOW(t0)
    li t1, F_SIZE
    sh t1, H_FRAME_SIZE(t0)
    li t1, R_SIZE
    sh t1, H_EVENT_SIZE(t0)
    li t1, FLAG_BITS
    sw t1, H_FLAGS(t0)
    li t1, TRAIL_PERIODS
    sh t1, H_TRAIL(t0)
    li t1, H_SIZE
    sh t1, H_HEADER_SIZE(t0)
    la t0, end_record
    li t1, 5
    sb t1, E_KIND(t0)
    li t1, MAGIC
    sw t1, E_MAGIC(t0)
    li t1, SCHEMA
    sw t1, E_SCHEMA(t0)
    sw s6, E_FRAMES(t0)
    la t2, event_count
    ld t1, 0(t2)
    sw t1, E_EVENTS(t0)
    la t2, event_omitted
    ld t1, 0(t2)
    sw t1, E_OMITTED(t0)
    li a0, 0xffffffff
    la a1, header
    li a2, H_SIZE
    call crc32
    la a1, frames
    li t0, F_SIZE
    mul a2, s6, t0
    call crc32
    la a1, events
    la t0, event_count
    ld t0, 0(t0)
    slli a2, t0, 3
    call crc32
    li t0, 0xffffffff
    xor a0, a0, t0
    la t0, end_record
    sw a0, E_CRC(t0)
    la a0, header
    li a1, H_SIZE
    call api_out
    la a0, frames
    li t0, F_SIZE
    mul a1, s6, t0
    call api_out
    la a0, events
    la t0, event_count
    ld t0, 0(t0)
    slli a1, t0, 3
    call api_out
    la a0, end_record
    li a1, E_SIZE
    call api_out
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

crc32:
    beqz a2, 3f
    li t3, 0xedb88320
1:
    lbu t0, 0(a1)
    xor a0, a0, t0
    li t1, 8
2:
    andi t2, a0, 1
    neg t2, t2
    and t2, t2, t3
    srli a0, a0, 1
    xor a0, a0, t2
    addi t1, t1, -1
    bnez t1, 2b
    addi a1, a1, 1
    addi a2, a2, -1
    bnez a2, 1b
3:
    ret

api_out:
    addi sp, sp, -32
    sd s8, 16(sp)
    sd s9, 8(sp)
    mv s8, a0
    mv s9, a1
1:
    beqz s9, 4f
    mv a1, s9
    li t0, EXPORT_CHUNK
    bleu a1, t0, 2f
    mv a1, t0
2:
    mv a0, s8
    add s8, s8, a1
    sub s9, s9, a1
    li a7, JAB_SYS_API_WRITE
    ecall
    beqz a0, 1b
    li t0, 1
    beq a0, t0, 3f
    jab.sys.exit 4              # interrupted, a prefix perhaps at the host
3:
    jab.sys.exit 3              # no API port
4:
    ld s9, 8(sp)
    ld s8, 16(sp)
    addi sp, sp, 32
    ret
.endif

.section .rodata
path_walker:
    .asciz "/walker"
msg_no_display:
    .asciz "walk: no display\n"
.ifdef CADENCE
msg_no_nonce:
    .asciz "walk: no nonce frame came within the wait\n"
msg_bad_nonce:
    .asciz "walk: the nonce frame is malformed\n"
.ifdef REPLAY
msg_no_replay:
    .asciz "walk: no replay stream came within the wait\n"
msg_bad_replay:
    .asciz "walk: the replay stream's header is malformed\n"
.endif
.endif

.section .data
msg_bad_sprite:
    .ascii "walk: the walker would not load, code "
msg_bad_sprite_code:
    .skip 4

.section .bss
.balign 8
seed:
    .skip 8
last_time:
    .skip 8
dt:
    .skip 8
record:
    .skip R_SIZE
rect_count:
    .skip 8
rects:
    .skip LANES * PER_LANE * JAB_RECT_SIZE
lanes:
    .skip LANES * LANE_SIZE
.ifdef CADENCE
origin:
    .skip 8
raw_elapsed:
    .skip 8
last_ordinal:
    .skip 8
range_hit:
    .skip 8
ended_by:
    .skip 8
event_count:
    .skip 8
event_omitted:
    .skip 8
frame_enters:
    .skip 8
frame_leaves:
    .skip 8
frame_walkers:
    .skip 8
frame_drawn:
    .skip 8
frame_rect_area:
    .skip 8
nonce_frame:
    .skip N_SIZE
header:
    .skip H_SIZE
end_record:
    .skip E_SIZE
frames:
    .skip CADENCE_FRAMES * F_SIZE
events:
    .skip EVENTS_MAX * R_SIZE
.ifdef REPLAY
replay_head:
    .skip RP_SIZE
replay_dts:
    .skip CADENCE_FRAMES * 4
.endif
.endif
sprite:
    .skip SPRITE_BYTES
