.if JAB_JOB_BYTES != 128
.error "a worker's mailbox is found by a shift of 7"
.endif

.section .text

workers_start:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    jab.sys.harts
    andi s2, a1, -2                 # the online secondaries
    li s0, 0                        # the workers started
    li s1, 1                        # the hart
    li s5, WORKER_STACK
1:
    li t0, JAB_HARTS_MAX
    bgeu s1, t0, 3f
    li t0, WORKERS_MAX
    bgeu s0, t0, 3f
    srl t0, s2, s1
    andi t0, t0, 1
    beqz t0, 2f
    slli s3, s0, 7
    la t0, mailboxes
    add s3, s3, t0                  # its mailbox, its argument
    mul s4, s0, s5
    la t0, worker_stacks
    add s4, s4, t0                  # its stack
    jab.sys.worker.start s1, raster_worker, s3, s4, s5
    bnez a0, 21f
    la t0, worker_hart
    slli t1, s0, 3
    add t0, t0, t1
    sd s1, 0(t0)
    addi s0, s0, 1
    j 2f
21:
.ifdef DEBUG
    mv s3, a0
    la a0, line
    la a1, msg_refused
    call append_str
    mv a1, s1
    call append_dec
    la a1, word_code
    call append_str
    mv a1, s3
    call append_dec
    call line_end
.endif
2:
    addi s1, s1, 1
    j 1b
3:
    la t0, workers_started
    sw s0, 0(t0)
    la t0, workers_active
    sw s0, 0(t0)                    # every worker started, until a W
    li t1, GRAIN_DEFAULT
    la t0, band_grain
    sw t1, 0(t0)
.ifdef DEBUG
    la a0, line
    la a1, msg_workers
    call append_str
    mv a1, s0
    call append_dec
    la a1, word_on_harts
    call append_str
    li s1, 0
4:
    bgeu s1, s0, 5f
    la a1, word_space
    call append_str
    la t0, worker_hart
    slli t1, s1, 3
    add t0, t0, t1
    ld a1, 0(t0)
    call append_dec
    addi s1, s1, 1
    j 4b
5:
    call line_end
.endif
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 64
    ret

round_run:
    addi sp, sp, -112
    sd ra, 104(sp)
    sd s0, 96(sp)
    sd s1, 88(sp)
    sd s2, 80(sp)
    sd s3, 72(sp)
    sd s4, 64(sp)
    sd s5, 56(sp)
    sd s6, 48(sp)
    sd s7, 40(sp)
    sd s8, 32(sp)
    la s0, round
    la t0, span_count
    ld t1, 0(t0)
    la t0, round_first
    lbu t2, 0(t0)
    bnez t2, 1f
    beqz t1, 90f                    # no spans past the frame's first round: no round
1:
    sb zero, 0(t0)                  # the frame's first round taken
    sw t2, ROUND_FLAGS(s0)          # the clear with it
    sw t1, ROUND_SPANS(s0)
    la t0, command_count
    ld t1, 0(t0)
    sw t1, ROUND_COMMANDS(s0)
    la t0, round_workers
    lwu s1, 0(t0)                   # the round's workers
    sw s1, ROUND_WORKERS(s0)
    la t0, round_grain
    lwu t1, 0(t0)
    sw t1, ROUND_GRAIN(s0)
    mv t2, s1                       # fixed bands, one a worker
    beqz t1, 2f
    li t2, (SCREEN_H - 1)
    add t2, t2, t1
    divu t2, t2, t1                 # the grain's bands, the last short
2:
    sw t2, ROUND_BANDS(s0)
    la t0, round_next
    sw zero, 0(t0)                  # the claims, before the publishes' fence
.ifdef DEBUG
    la t0, job_delay_worker
    lbu t1, 0(t0)
    sw t1, ROUND_DELAY_WORKER(s0)   # the J frame's knobs, the workers' through the record
    la t0, job_delay_us
    lwu t1, 0(t0)
    sw t1, ROUND_DELAY_US(s0)
    la t0, job_fault_worker
    lbu t1, 0(t0)
    sb zero, 0(t0)                  # the fault once
    sw t1, ROUND_FAULT_WORKER(s0)
.endif
    la t0, frame_clock
    ld s5, CLOCK_SNAPSHOT(t0)       # the frame, each job's
    rdtime s2                       # the round's start, before its first publish
    li s3, 0                        # the worker
    li s4, 0                        # the round's harts
3:
    bgeu s3, s1, 4f
    slli s6, s3, 7
    la t0, mailboxes
    add s6, s6, t0
    jab.job.publish s6, s5, zero, zero, t3
    la t0, worker_hart
    slli t1, s3, 3
    add t0, t0, t1
    ld t1, 0(t0)
    li t0, 1
    sll t0, t0, t1
    or s4, s4, t0
    addi s3, s3, 1
    j 3b
4:
    jab.sys.worker.wake s4          # one wake for the round
.ifdef DEBUG
    la t0, job_cancel
    lbu t1, 0(t0)
    beqz t1, 42f
    li s3, 0
41:
    bgeu s3, s1, 42f
    slli s6, s3, 7
    la t0, mailboxes
    add s6, s6, t0
    lw t3, JAB_JOB_GEN(s6)
    jab.job.cancel s6, t3           # the J frame's cancel of the job in flight
    addi s3, s3, 1
    j 41b
42:
.endif
    li s3, 0
5:
    bgeu s3, s1, 6f
    slli s6, s3, 7
    la t0, mailboxes
    add s6, s6, t0
    jab.job.join s6
    addi s3, s3, 1
    j 5b
6:
    rdtime s7                       # the joins' end
    li s3, 0
    li s4, 0                        # the latest start
    li s8, 0                        # the latest end
    sd zero, 0(sp)                  # the slowest's busy ticks
    sd zero, 8(sp)                  # every worker's
    sd zero, 16(sp)                 # the bands rendered
    sd zero, 24(sp)                 # a job cancelled
7:
    bgeu s3, s1, 8f
    slli s6, s3, 7
    la t0, mailboxes
    add s6, s6, t0
    ld t0, JOB_START(s6)
    ld t1, JOB_END(s6)
    bgeu s4, t0, 71f
    mv s4, t0
71:
    bgeu s8, t1, 72f
    mv s8, t1
72:
    sub t2, t1, t0                  # its busy ticks
    ld t3, 0(sp)
    bgeu t3, t2, 73f
    sd t2, 0(sp)
73:
    ld t3, 8(sp)
    add t3, t3, t2
    sd t3, 8(sp)
    ld t0, JOB_BANDS(s6)
    ld t3, 16(sp)
    add t3, t3, t0
    sd t3, 16(sp)
    la t1, stats
    slli t2, s3, 3
    add t1, t1, t2
    ld t2, STAT_BANDS(t1)
    add t2, t2, t0
    sd t2, STAT_BANDS(t1)           # its bands, the frame's
    lw t0, JAB_JOB_STATUS(s6)
    li t1, JAB_JOB_CANCELLED
    bne t0, t1, 74f
    li t0, 1
    sd t0, 24(sp)
74:
    slli t0, s3, CTX_SHIFT
    la tp, worker_contexts
    add tp, tp, t0
    call context_counts             # its counts, the frame's
    addi s3, s3, 1
    j 7b
8:
    la t0, stats
    sub t1, s4, s2
    ld t2, STAT_DISPATCH(t0)
    add t2, t2, t1
    sd t2, STAT_DISPATCH(t0)        # the latest start less the round's
    sub t1, s7, s8
    ld t2, STAT_BARRIER(t0)
    add t2, t2, t1
    sd t2, STAT_BARRIER(t0)         # the joins' end less the latest end
    ld t1, 0(sp)
    ld t2, STAT_SLOWEST(t0)
    add t2, t2, t1
    sd t2, STAT_SLOWEST(t0)
    ld t1, 8(sp)
    ld t2, STAT_BUSY(t0)
    add t2, t2, t1
    sd t2, STAT_BUSY(t0)
    ld t2, STAT_ROUNDS(t0)
    addi t2, t2, 1
    sd t2, STAT_ROUNDS(t0)
    ld t1, 24(sp)
    beqz t1, 85f
    call round_finish               # the bands the cancelled jobs left, on hart 0
    ld t1, 16(sp)
    add t1, t1, a0
    sd t1, 16(sp)
    la t0, stats
    ld t1, STAT_CANCELLED(t0)
    addi t1, t1, 1
    sd t1, STAT_CANCELLED(t0)
85:
.ifdef DEBUG
    li s3, 0
86:
    bgeu s3, s1, 87f
    slli s6, s3, 7
    la t0, mailboxes
    add s6, s6, t0
    lw t0, JAB_JOB_DONE(s6)
    lw t1, JAB_JOB_GEN(s6)
    addi s3, s3, 1
    beq t0, t1, 86b                 # its job joined, the round's
    jab.sys.uart.print msg_unjoined
    jab.sys.exit 13
87:
    ld t1, 16(sp)
    lwu t2, ROUND_BANDS(s0)
    beq t1, t2, 90f
    jab.sys.uart.print msg_lost_bands
    jab.sys.exit 13
.endif
90:
    ld ra, 104(sp)
    ld s0, 96(sp)
    ld s1, 88(sp)
    ld s2, 80(sp)
    ld s3, 72(sp)
    ld s4, 64(sp)
    ld s5, 56(sp)
    ld s6, 48(sp)
    ld s7, 40(sp)
    ld s8, 32(sp)
    addi sp, sp, 112
    ret

raster_worker:
    mv s0, a0                       # its mailbox
    mv s1, a1                       # its hart
    la t0, mailboxes
    sub t0, s0, t0
    srli s2, t0, 7                  # its index, the mailbox's place
    slli t0, s2, CTX_SHIFT
    la tp, worker_contexts
    add tp, tp, t0                  # its context
1:
    jab.job.await s0, s3            # the generation taken
    bnez a0, 9f                     # a stop
    rdtime t0
    sd t0, JOB_START(s0)
    la s4, round
.ifdef DEBUG
    lwu t1, ROUND_FAULT_WORKER(s4)
    addi t2, s2, 1
    bne t1, t2, 2f
    li t0, SCRATCH_POISON
    ld t0, 0(t0)                    # the J frame's fault: a load no page maps
2:
.endif
    lwu s5, ROUND_FLAGS(s4)         # the clear
    lwu s8, ROUND_GRAIN(s4)
    li s6, 0                        # its bands
    li s7, JAB_JOB_OK
    bnez s8, 3f
.ifdef DEBUG
    mv a0, s2
    call job_delay
.endif
    jab.job.cancelled s0, s3, t2    # fixed bands: its own, the worker's index
    bnez t2, 7f
    lwu t2, ROUND_WORKERS(s4)
    li t3, SCREEN_H
    mul a0, s2, t3
    divu a0, a0, t2
    addi t4, s2, 1
    mul a1, t4, t3
    divu a1, a1, t2
    mv a2, s5
    call band_render
    li s6, 1
    j 8f
3:
    lwu s9, ROUND_BANDS(s4)
4:
.ifdef DEBUG
    mv a0, s2
    call job_delay
.endif
    jab.job.cancelled s0, s3, t2    # at every band's boundary
    bnez t2, 7f
    la t0, round_next
    li t1, 1
    amoadd.w t2, t1, (t0)           # the next band, one a claim
    bgeu t2, s9, 8f                 # every band claimed
    mul a0, t2, s8
    add a1, a0, s8
    li t3, SCREEN_H
    bleu a1, t3, 5f
    mv a1, t3                       # the last band short
5:
    mv a2, s5
    call band_render
    addi s6, s6, 1
    j 4b
7:
    li s7, JAB_JOB_CANCELLED
8:
    sd s6, JOB_BANDS(s0)
    rdtime t0
    sd t0, JOB_END(s0)
    jab.job.complete s0, s3, s7
    li t0, 1
    jab.sys.worker.wake t0          # hart 0, joining
    j 1b
9:
    jab.sys.worker.exit

round_finish:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    la tp, raster_context
    la s0, round
    lwu s1, ROUND_GRAIN(s0)
    lwu s2, ROUND_FLAGS(s0)         # the clear on a first round
    li s3, 0                        # the bands hart 0 renders
    bnez s1, 3f
    lwu s4, ROUND_WORKERS(s0)
    li s5, 0                        # the worker
1:
    bgeu s5, s4, 5f
    slli t0, s5, 7
    la t1, mailboxes
    add t0, t0, t1
    ld t1, JOB_BANDS(t0)
    bnez t1, 2f                     # its band rendered before it read the cancel
    li t3, SCREEN_H
    mul a0, s5, t3
    divu a0, a0, s4
    addi t4, s5, 1
    mul a1, t4, t3
    divu a1, a1, s4
    mv a2, s2
    call band_render
    addi s3, s3, 1
2:
    addi s5, s5, 1
    j 1b
3:
    lwu s4, ROUND_BANDS(s0)
4:
    la t0, round_next
    li t1, 1
    amoadd.w t2, t1, (t0)           # the bands no worker claimed
    bgeu t2, s4, 5f
    mul a0, t2, s1
    add a1, a0, s1
    li t3, SCREEN_H
    bleu a1, t3, 41f
    mv a1, t3
41:
    mv a2, s2
    call band_render
    addi s3, s3, 1
    j 4b
5:
    call context_counts             # hart 0's counts, the frame's
    mv a0, s3
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 64
    ret

.ifdef DEBUG
job_delay:
    la t0, round
    lwu t1, ROUND_DELAY_WORKER(t0)
    addi t2, a0, 1
    bne t1, t2, 9f
    lwu t1, ROUND_DELAY_US(t0)
    li t2, US_TICKS
    mul t1, t1, t2
    rdtime t2
    add t1, t1, t2                  # the delay's end
1:
    rdtime t2
    bltu t2, t1, 1b
9:
    ret
.endif

.section .rodata
.ifdef DEBUG
msg_workers:
    .asciz "fps: workers "
word_on_harts:
    .asciz " on harts"
msg_refused:
    .asciz "fps: worker refused on hart "
msg_lost_bands:
    .asciz "fps: round lost bands\n"
msg_unjoined:
    .asciz "fps: round unjoined\n"
.endif

.section .bss
.balign 64
mailboxes:
    .skip (WORKERS_MAX * JAB_JOB_BYTES)
worker_contexts:
    .skip (WORKERS_MAX * CTX_SIZE)
round:
    .skip ROUND_SIZE
round_next:
    .skip 64
.balign 8
worker_hart:
    .skip (WORKERS_MAX * 8)
workers_started:
    .skip 4
workers_active:
    .skip 4
band_grain:
    .skip 4
round_workers:
    .skip 4
round_grain:
    .skip 4
round_first:
    .skip 1
.ifdef DEBUG
job_delay_worker:
    .skip 1
job_cancel:
    .skip 1
job_fault_worker:
    .skip 1
.balign 4
job_delay_us:
    .skip 4
.endif
.balign 16
worker_stacks:
    .skip (WORKERS_MAX * WORKER_STACK)
