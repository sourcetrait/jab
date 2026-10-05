.include "jab.inc"
.include "jab_jobs.inc"

.set FIX, 28
.set ESCAPE, (4 << FIX)
.set CAP, 64
.set BAND_ROWS, 8
.set BANDS, (JAB_DISPLAY_HEIGHT / BAND_ROWS)
.set BAR_WIDTH, 12
.set MAX_WORKERS, 3
.set STACK_BYTES, 16384
.set SELECT_WAIT, (2 * JAB_TIME_HZ)
.set PHASE_TICKS, (5 * JAB_TIME_HZ)
.set SLOTS, 128
.set SLOT_TICKS, (JAB_TIME_HZ / 4)
.set ZOOM_NUM, 243
.set ZOOM_CX, -199620386
.set ZOOM_CY, 35386747
.set PROOF_CX, -(1 << (FIX - 1))
.set PROOF_CY, 0
.set STEP0, ((3 << FIX) / JAB_DISPLAY_WIDTH)
.set BENCH_TICKS, (4 * JAB_TIME_HZ)
.set SAMPLES, 3
.set PARAM_LEFT, 0
.set PARAM_TOP, 8
.set PARAM_STEP, 16
.set PARAM_WORKERS, 24
.set ARG_INDEX, JAB_JOB_ARGS
.set OWN_ROWS, JAB_JOB_OWN
.set OWN_TOTAL, (JAB_JOB_OWN + 8)
.set BOX_WIDTH, 500
.set BOX_HEIGHT, 64
.set TEXT_X, (BAR_WIDTH + 16)
.set TEXT_Y, 8
.set TEXT_SCALE, (2 * JAB_TEXT_SCALE_ONE)
.set TEXT_COLOR, 0x00ffffff
.set TICKS_PER_MS, (JAB_TIME_HZ / 1000)

.section .text
.global _start
_start:
    jab.sys.display.open
    bnez a0, no_display
    call find_workers
    beqz a0, no_workers
    call make_zoom
    la t0, workers_n
    ld s0, 0(t0)
    li s1, 0
1:
    bgeu s1, s0, 2f
    mv a0, s1
    call start_worker
    addi s1, s1, 1
    j 1b
2:
    la a0, selector
    li a1, 0
    li a7, JAB_SYS_API_WRITE
    ecall                                   # 0 with the API's port on the machine, 1 without
    bnez a0, animate
    rdtime s7
    li t0, SELECT_WAIT
    add s7, s7, t0                          # the selector's deadline
3:
    la s4, selector
    jab.sys.api.read s4, 1
    bnez a0, 4f
    rdtime t0
    bgeu t0, s7, animate
    jab.sys.await JAB_AWAIT_DISPLAY | JAB_AWAIT_API
    j 3b
4:
    lbu t0, 0(s4)
    li t1, 'p'
    beq t0, t1, proof
    addi t0, t0, -'1'
    li t1, MAX_WORKERS
    bltu t0, t1, bench                      # '1' to '3', the workers
    j animate

no_display:
    la a1, word_no_display
    call say_str
    jab.sys.exit 1

no_workers:
    la a1, word_no_workers
    call say_str
    jab.sys.exit 2

animate:
    rdtime s7                               # the animation's start
1:
    rdtime s8
    sub s8, s8, s7                          # its time
    li t0, PHASE_TICKS
    divu t1, s8, t0
    la t2, workers_n
    ld t2, 0(t2)
    remu t1, t1, t2
    addi s0, t1, 1                          # the workers for this stretch
    li t0, SLOT_TICKS
    divu t1, s8, t0
    andi t1, t1, (SLOTS - 1)
    slli t1, t1, 3
    la t0, zoom_steps
    add t0, t0, t1
    ld a2, 0(t0)                            # the step at this point of the zoom
    li a0, ZOOM_CX
    li a1, ZOOM_CY
    call set_view
    mv a0, s0
    call render
    mv s1, a0                               # the frame's ticks
    call draw_bars
    mv a0, s0
    mv a1, s1
    call draw_caption
    jab.sys.display.await
    jab.sys.display.flip
    j 1b

proof:
    li s0, 1                                # the workers
1:
    li a0, PROOF_CX
    li a1, PROOF_CY
    li a2, STEP0
    call set_view
    call clear_owners
    mv a0, s0
    call render
    mv s1, a0                               # the frame's ticks
    li a0, JAB_DISPLAY_BASE
    la a1, image
    li a2, JAB_DISPLAY_SIZE
    call copy_words                         # into the window, where the kernel's calls reach
    la s2, image
    li s3, JAB_DISPLAY_SIZE
    jab.sys.hash s2, s3
    mv s4, a0                               # the frame's hash, before any bar or text
    call owned_rows
    mv s5, a0
    la s11, line
    la a1, word_proof
    mv a0, s0
    call put_dec_then_rev
    la a1, word_hash
    call put_str
    mv a0, s4
    call put_hex
    la a1, word_rows
    call put_str
    li s6, 0
2:
    li t0, MAX_WORKERS
    bgeu s6, t0, 3f
    li a0, 0
    bgeu s6, s0, 21f
    mv a0, s6
    call mailbox_of
    ld a0, OWN_ROWS(a0)                     # this frame's rows by worker s6
21:
    la a1, word_space
    call put_str
    call put_dec
    addi s6, s6, 1
    j 2b
3:
    la a1, word_owned
    call put_str
    mv a0, s5
    call put_dec
    call say
    call draw_bars                          # the bars and the text after the hash
    mv a0, s0
    mv a1, s1
    call draw_caption
    jab.sys.display.await
    jab.sys.display.flip
    addi s0, s0, 1
    la t0, workers_n
    ld t0, 0(t0)
    bleu s0, t0, 1b
    li s6, 0
4:
    li t0, SAMPLES
    bgeu s6, t0, 5f
    la t0, sample_rows
    slli t1, s6, 3
    add t0, t0, t1
    ld t0, 0(t0)
    li t1, JAB_DISPLAY_PITCH
    mul t0, t0, t1
    la s2, image
    add s2, s2, t0
    li s3, JAB_DISPLAY_PITCH
    jab.sys.api.write s2, s3                # the sampled row, for the host to compute again
    addi s6, s6, 1
    j 4b
5:
    la s11, line
    la a1, word_sent
    li a0, SAMPLES
    call put_dec_then_rev
    la a1, word_sent_tail
    call put_str
    call say
    jab.sys.exit 0

bench:
    addi s0, t0, 1                          # the workers
    la t1, workers_n
    ld t1, 0(t1)
    bleu s0, t1, 1f
    la a1, word_too_few
    call say_str
    jab.sys.exit 2
1:
    li a0, PROOF_CX
    li a1, PROOF_CY
    li a2, STEP0
    call set_view
    rdtime s8                               # the stretch's start
    li t0, BENCH_TICKS
    add s7, s8, t0                          # and its end
    li s1, 0                                # the frames
2:
    mv a0, s0
    call render
    addi s1, s1, 1
    rdtime t0
    bltu t0, s7, 2b
    sub s8, t0, s8                          # the stretch's ticks
    li a0, JAB_DISPLAY_BASE
    la a1, image
    li a2, JAB_DISPLAY_SIZE
    call copy_words
    la s2, image
    li s3, JAB_DISPLAY_SIZE
    jab.sys.hash s2, s3
    mv s4, a0                               # the last frame's hash
    la s11, line
    la a1, word_bench
    mv a0, s0
    call put_dec_then_rev
    la a1, word_frames
    mv a0, s1
    call put_dec_then_rev
    li t0, TICKS_PER_MS
    divu a0, s8, t0
    la a1, word_ms_field
    call put_dec_then_rev
    la a1, word_hash
    call put_str
    mv a0, s4
    call put_hex
    la a1, word_rows
    call put_str
    li s6, 0
3:
    li t0, MAX_WORKERS
    bgeu s6, t0, 4f
    mv a0, s6
    call mailbox_of
    ld a0, OWN_TOTAL(a0)                    # every frame's rows by worker s6
    la a1, word_space
    call put_str
    call put_dec
    addi s6, s6, 1
    j 3b
4:
    call say
    la s2, band_times
    li s3, (BANDS * 16)
    jab.sys.api.write s2, s3                # the last frame's band intervals
    la s2, owners
    li s3, JAB_DISPLAY_HEIGHT
    jab.sys.api.write s2, s3                # and its rows' owners
    jab.sys.exit 0

render:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s0, a0
    la t0, params
    sd s0, PARAM_WORKERS(t0)
    rdtime s1
    li s2, 0
1:
    bgeu s2, s0, 2f
    mv a0, s2
    call mailbox_of
    mv t2, a0
    sd s2, ARG_INDEX(t2)                    # its index among the frame's workers
    jab.job.publish t2, zero, zero, zero, t3
    addi s2, s2, 1
    j 1b
2:
    mv a0, s0
    call mask_n
    jab.sys.worker.wake a0
    li s2, 0
3:
    bgeu s2, s0, 4f
    mv a0, s2
    call mailbox_of
    mv s3, a0
    jab.job.join s3
    addi s2, s2, 1
    j 3b
4:
    rdtime a0
    sub a0, a0, s1
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 48
    ret

set_view:
    li t0, (JAB_DISPLAY_WIDTH / 2)
    mul t0, t0, a2
    sub t0, a0, t0
    li t1, (JAB_DISPLAY_HEIGHT / 2)
    mul t1, t1, a2
    add t1, a1, t1
    la t2, params
    sd t0, PARAM_LEFT(t2)
    sd t1, PARAM_TOP(t2)
    sd a2, PARAM_STEP(t2)
    ret

make_zoom:
    la t0, zoom_steps
    li t1, STEP0
    li t2, SLOTS
    li t3, ZOOM_NUM
1:
    sd t1, 0(t0)
    mul t1, t1, t3
    srli t1, t1, 8                          # each slot 243/256 of the one before
    addi t0, t0, 8
    addi t2, t2, -1
    bnez t2, 1b
    ret

clear_owners:
    la t0, owners
    li t1, JAB_DISPLAY_HEIGHT
    li t2, 0xff
1:
    sb t2, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, 1b
    ret

owned_rows:
    la t0, owners
    li t1, JAB_DISPLAY_HEIGHT
    li a0, 0
    li t3, 0xff
1:
    lbu t2, 0(t0)
    beq t2, t3, 2f
    addi a0, a0, 1
2:
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, 1b
    ret

copy_words:
1:
    ld t0, 0(a0)
    sd t0, 0(a1)
    addi a0, a0, 8
    addi a1, a1, 8
    addi a2, a2, -8
    bnez a2, 1b
    ret

draw_bars:
    la t0, owners
    la t1, bar_colors
    li t2, JAB_DISPLAY_BASE
    li t3, JAB_DISPLAY_HEIGHT
1:
    lbu t4, 0(t0)
    andi t4, t4, 7
    slli t4, t4, 2
    add t4, t4, t1
    lwu t4, 0(t4)                           # the row's hart's colour
    li t5, BAR_WIDTH
    mv t6, t2
2:
    sw t4, 0(t6)
    addi t6, t6, 4
    addi t5, t5, -1
    bnez t5, 2b
    addi t0, t0, 1
    li t5, JAB_DISPLAY_PITCH
    add t2, t2, t5
    addi t3, t3, -1
    bnez t3, 1b
    ret

draw_caption:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, a0
    mv s1, a1
    li t0, JAB_DISPLAY_BASE
    addi t0, t0, (BAR_WIDTH * 4)
    li t1, BOX_HEIGHT
1:
    li t2, BOX_WIDTH
    mv t3, t0
2:
    sw zero, 0(t3)                          # the caption's box, black
    addi t3, t3, 4
    addi t2, t2, -1
    bnez t2, 2b
    li t2, JAB_DISPLAY_PITCH
    add t0, t0, t2
    addi t1, t1, -1
    bnez t1, 1b
    la s11, caption
    mv a0, s0
    la a1, word_worker
    li t0, 1
    beq s0, t0, 3f
    la a1, word_workers
3:
    call put_dec_then
    li t0, TICKS_PER_MS
    divu a0, s1, t0
    la a1, word_ms
    call put_dec_then
    sb zero, 0(s11)
    li t0, TEXT_X
    li t1, TEXT_Y
    li t2, TEXT_COLOR
    li t3, 0
    li t4, TEXT_SCALE
    jab.sys.display.text caption, t0, t1, t2, t3, t4
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
    ret

find_workers:
    jab.sys.harts
    andi a1, a1, -2                         # the online secondaries
    la t2, worker_hart
    li t3, 0                                # the workers
    li t4, 1                                # the hart
1:
    li t0, JAB_HARTS_MAX
    bgeu t4, t0, 2f
    li t0, MAX_WORKERS
    bgeu t3, t0, 2f
    srl t0, a1, t4
    andi t0, t0, 1
    beqz t0, 11f
    sd t4, 0(t2)
    addi t2, t2, 8
    addi t3, t3, 1
11:
    addi t4, t4, 1
    j 1b
2:
    la t0, workers_n
    sd t3, 0(t0)
    mv a0, t3
    ret

mailbox_of:
    slli a0, a0, 7
    la t0, mailboxes
    add a0, a0, t0
    ret

mask_n:
    la t0, worker_hart
    li t1, 0
1:
    beqz a0, 2f
    ld t2, 0(t0)
    li t3, 1
    sll t3, t3, t2
    or t1, t1, t3
    addi t0, t0, 8
    addi a0, a0, -1
    j 1b
2:
    mv a0, t1
    ret

start_worker:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s3, a0
    call mailbox_of
    mv s1, a0                               # its mailbox, its argument
    la t0, worker_hart
    slli t1, s3, 3
    add t0, t0, t1
    ld s0, 0(t0)                            # its hart
    li t0, STACK_BYTES
    mul t0, t0, s3
    la s2, stacks
    add s2, s2, t0                          # its stack
    li s3, STACK_BYTES
    jab.sys.worker.start s0, frame_worker, s1, s2, s3
    bnez a0, refused
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 48
    ret

refused:
    la a1, word_refused
    call say_str
    jab.sys.exit 3

say_str:
    addi sp, sp, -16
    sd ra, 8(sp)
    la s11, line
    call put_str
    call say
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

say:
    li t0, '\n'
    sb t0, 0(s11)
    sb zero, 1(s11)
    jab.sys.uart.print line
    ret

put_dec_then:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a1, 0(sp)
    call put_dec
    ld a1, 0(sp)
    call put_str
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

put_dec_then_rev:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
    call put_str
    ld a0, 0(sp)
    call put_dec
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

put_str:
    lbu t0, 0(a1)
    beqz t0, 1f
    sb t0, 0(s11)
    addi s11, s11, 1
    addi a1, a1, 1
    j put_str
1:
    ret

put_hex:
    li t2, 60
1:
    srl t0, a0, t2
    andi t0, t0, 15
    li t1, 10
    bltu t0, t1, 2f
    addi t0, t0, ('a' - 10)
    j 3f
2:
    addi t0, t0, '0'
3:
    sb t0, 0(s11)
    addi s11, s11, 1
    addi t2, t2, -4
    bgez t2, 1b
    ret

put_dec:
    la t1, digits
    addi t1, t1, 31
    sb zero, 0(t1)
    li t2, 10
1:
    remu t3, a0, t2
    divu a0, a0, t2
    addi t3, t3, '0'
    addi t1, t1, -1
    sb t3, 0(t1)
    bnez a0, 1b
2:
    lbu t3, 0(t1)
    beqz t3, 3f
    sb t3, 0(s11)
    addi s11, s11, 1
    addi t1, t1, 1
    j 2b
3:
    ret

.balign 4096
mandel_row:
    la t0, params
    ld t1, PARAM_LEFT(t0)                   # c's x at the row's first pixel
    ld t2, PARAM_TOP(t0)
    ld t3, PARAM_STEP(t0)
    mul t4, a0, t3
    sub t2, t2, t4                          # c's y for the row
    li t4, JAB_DISPLAY_PITCH
    mul t4, a0, t4
    li t5, JAB_DISPLAY_BASE
    add a1, t4, t5                          # the row's first pixel
    li a2, JAB_DISPLAY_WIDTH
    la a3, palette
    li a7, ESCAPE
    li t0, CAP
1:
    li a4, 0                                # z's x
    li a5, 0                                # z's y
    li a6, 0                                # the iterations
2:
    mul t4, a4, a4
    srai t4, t4, FIX                        # x squared
    mul t5, a5, a5
    srai t5, t5, FIX                        # y squared
    add t6, t4, t5
    bgt t6, a7, 3f                          # past 2 from the origin: escaped
    mul t6, a4, a5
    srai t6, t6, (FIX - 1)                  # twice x y
    sub a4, t4, t5
    add a4, a4, t1                          # x squared less y squared, plus c's x
    add a5, t6, t2                          # twice x y, plus c's y
    addi a6, a6, 1
    blt a6, t0, 2b
    li t4, 0                                # in the set: black
    j 4f
3:
    andi t4, a6, 15
    slli t4, t4, 2
    add t4, t4, a3
    lwu t4, 0(t4)                           # the escape's colour
4:
    sw t4, 0(a1)
    addi a1, a1, 4
    add t1, t1, t3                          # c's x a step on
    addi a2, a2, -1
    bnez a2, 1b
    ret

frame_worker:
    mv s0, a0                               # its mailbox
    mv s1, a1                               # its hart
1:
    jab.job.await s0, s2
    bnez a0, 9f                             # a stop
    ld s3, ARG_INDEX(s0)                    # its index among the frame's workers
    la t0, params
    ld s4, PARAM_WORKERS(t0)
    li s5, 0                                # its rows this frame
    mv s6, s3                               # its first band its index, each next the workers' count on
2:
    li t0, BANDS
    bgeu s6, t0, 4f
    li t0, BAND_ROWS
    mul s7, s6, t0                          # the band's first row
    li s8, BAND_ROWS
    rdtime s9                               # the band's start
3:
    mv a0, s7
    call mandel_row
    la t0, owners
    add t0, t0, s7
    sb s1, 0(t0)                            # the row's owner
    addi s5, s5, 1
    addi s7, s7, 1
    addi s8, s8, -1
    bnez s8, 3b
    rdtime t0
    la t1, band_times
    slli t2, s6, 4
    add t1, t1, t2
    sd s9, 0(t1)                            # the band's interval
    sd t0, 8(t1)
    add s6, s6, s4
    j 2b
4:
    sd s5, OWN_ROWS(s0)
    ld t0, OWN_TOTAL(s0)
    add t0, t0, s5
    sd t0, OWN_TOTAL(s0)
    li t1, JAB_JOB_OK
    jab.job.complete s0, s2, t1
    li t0, 1
    jab.sys.worker.wake t0                  # hart 0, joining
    j 1b
9:
    jab.sys.worker.exit

.section .rodata
.balign 8
palette:
    .4byte 0x00421e0f, 0x0019071a, 0x0009012f, 0x00040449
    .4byte 0x00000764, 0x000c2c8a, 0x001852b1, 0x00397dd1
    .4byte 0x0086b5e5, 0x00d3ecf8, 0x00f1e9bf, 0x00f8c95f
    .4byte 0x00ffaa00, 0x00cc8000, 0x00995700, 0x006a3403
bar_colors:
    .4byte 0x00000000, 0x00ff4040, 0x0040ff40, 0x004080ff
    .4byte 0x00ffff40, 0x00ff40ff, 0x0040ffff, 0x00ffffff
sample_rows:
    .quad 100, 540, 900
word_no_display:
    .asciz "workers: no display"
word_no_workers:
    .asciz "workers: no worker hart online"
word_refused:
    .asciz "workers: a start refused"
word_too_few:
    .asciz "workers: too few worker harts for the bench"
word_proof:
    .asciz "workers: proof "
word_hash:
    .asciz " hash "
word_rows:
    .asciz " rows"
word_owned:
    .asciz " owned "
word_space:
    .asciz " "
word_sent:
    .asciz "workers: proof sent "
word_sent_tail:
    .asciz " rows"
word_bench:
    .asciz "workers: bench "
word_frames:
    .asciz " frames "
word_ms_field:
    .asciz " ms "
word_worker:
    .asciz " worker, "
word_workers:
    .asciz " workers, "
word_ms:
    .asciz " ms"

.section .bss
.balign 64
mailboxes:
    .skip (MAX_WORKERS * JAB_JOB_BYTES)
params:
    .skip 64
.balign 8
worker_hart:
    .skip (MAX_WORKERS * 8)
workers_n:
    .skip 8
selector:
    .skip 8
zoom_steps:
    .skip (SLOTS * 8)
band_times:
    .skip (BANDS * 16)
owners:
    .skip JAB_DISPLAY_HEIGHT
line:
    .skip 160
caption:
    .skip 64
digits:
    .skip 32
.balign 16
stacks:
    .skip (MAX_WORKERS * STACK_BYTES)
.balign 64
image:
    .skip JAB_DISPLAY_SIZE
