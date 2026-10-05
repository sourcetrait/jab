.include "jab.inc"
.include "jab_jobs.inc"

.set SELECT_WAIT, (2 * JAB_TIME_HZ)
.set STACK_BYTES, 16384
.set MAX_WORKERS, 3
.set OUTPUT_BYTES, 64
.set HOLD_TICKS, 120
.set ROUNDS, 1000
.set DELAY, (JAB_TIME_HZ / 5000)
.set OUT_FACTOR, 7
.set EMPTY_SIZE, 5
.set WRAP_START, 0xfffffffe
.set WRAP_JOBS, 3
.set BAND_TICKS, (JAB_TIME_HZ / 1000)
.set CANCEL_BANDS, 40
.set CANCEL_AFTER, (JAB_TIME_HZ / 200)
.set SIZES, 4
.set COST_ROUNDS, 100
.set COST_BYTES, ((2 + MAX_WORKERS + 1) * SIZES * COST_ROUNDS * 4)
.set ARG_TICKS, JAB_JOB_ARGS
.set ARG_BANDS, (JAB_JOB_ARGS + 8)
.set ARG_DELAY, (JAB_JOB_ARGS + 16)
.set OWN_TAKEN, JAB_JOB_OWN
.set OWN_DONE, (JAB_JOB_OWN + 8)
.set OWN_BANDS, (JAB_JOB_OWN + 16)

.section .text
.global _start
_start:
    rdtime s7
    li t0, SELECT_WAIT
    add s7, s7, t0                          # the selector's deadline
1:
    la s4, selector
    jab.sys.api.read s4, 1
    bnez a0, 2f
    rdtime t0
    bgeu t0, s7, 9f
    jab.sys.await JAB_AWAIT_DISPLAY | JAB_AWAIT_API
    j 1b
2:
    call find_workers
    beqz a0, no_workers
    lbu t0, 0(s4)
    li t1, 'f'
    beq t0, t1, fixture
    li t1, 'c'
    beq t0, t1, costs
9:
    la a1, word_none
    call say_str
    jab.sys.exit 2

no_workers:
    la a1, word_no_workers
    call say_str
    jab.sys.exit 2

fixture:
    la s11, line
    la a1, word_fixture
    la t0, workers_n
    ld a0, 0(t0)
    call field
    call say
    la t0, workers_n
    ld s0, 0(t0)                            # W
    li s1, 0
1:
    bgeu s1, s0, 2f
    mv a0, s1
    call reset_mailbox
    addi s1, s1, 1
    j 1b
2:
    mv a0, s0
    call start_n

idle_hold:
    li s1, HOLD_TICKS
1:
    jab.sys.display.await                   # every worker asleep in its await meanwhile
    addi s1, s1, -1
    bnez s1, 1b
    la s11, line
    la a1, word_idle
    mv a0, s0
    call field
    la a1, word_idle_tail
    call put_str
    call say

race_rounds:
    li s2, 0                                # the variant: before, during, spurious, after
1:
    li t0, 4
    bgeu s2, t0, 8f
    mv a0, s0
    li a1, 0
    li a2, 0
    li a3, 0
    bnez s2, 11f
    li a3, DELAY                            # before: each worker lingers past its completion
11:
    call set_args
    mv a0, s0
    call count_n
    mv s3, a0                               # the completions before
    li s4, 1                                # the round
    li s5, 0                                # outputs wrong
2:
    li t0, ROUNDS
    bgtu s4, t0, 7f
    li t0, 1
    bne s2, t0, 3f
    li a0, DELAY                            # during: every worker asleep before the publish
    call spin
3:
    li t0, 2
    bne s2, t0, 4f
    mv a0, s0
    call mask_n
    jab.sys.worker.wake a0                  # spurious: a wake with nothing published
    li a0, (DELAY / 2)
    call spin
4:
    mv a0, s0
    mv a1, s4
    call publish_n
    mv a0, s0
    call mask_n
    jab.sys.worker.wake a0
    li t0, 3
    bne s2, t0, 5f
    li a0, DELAY                            # after: every job done before the join looks
    call spin
5:
    mv a0, s0
    call join_n
    mv a0, s0
    mv a1, s4
    call check_n
    add s5, s5, a0
    addi s4, s4, 1
    j 2b
7:
    mv a0, s0
    call count_n
    sub s6, a0, s3                          # completions in the variant
    la s11, line
    la t0, variant_words
    slli t1, s2, 3
    add t0, t0, t1
    ld a1, 0(t0)
    call put_str
    li a0, ROUNDS
    la a1, word_rounds
    call put_dec_then
    mv a0, s5
    la a1, word_wrong_comma
    call put_dec_then
    mv a0, s6
    la a1, word_completions
    call put_dec_then
    call say
    addi s2, s2, 1
    j 1b
8:
    mv a0, s0
    call stop_n

empty_full:
    li a0, 0
    call reset_mailbox
    li a0, 1
    li a1, 0
    li a2, 0
    li a3, 0
    call set_args
    li a0, 0
    call mailbox_of
    mv s1, a0                               # worker 0's mailbox
    li a0, 0
    call output_of
    mv s2, a0                               # its output
    jab.job.free s1, s3                     # empty: free
    li s6, EMPTY_SIZE
    jab.job.publish s1, zero, s2, s6, s7
    jab.job.free s1, s4                     # a job in flight: full
    li a0, 0
    call start_worker                       # its await finds the job at its first look
    jab.job.join s1
    jab.job.free s1, s5
    ld s6, 0(s2)
    li a0, 1
    call stop_n
    la s11, line
    la a1, word_free
    call put_str
    mv a0, s3
    la a1, word_then
    call put_dec_then
    mv a0, s4
    la a1, word_then
    call put_dec_then
    mv a0, s5
    la a1, word_out
    call put_dec_then
    mv a0, s6
    call put_dec
    call say

wrap:
    li a0, 0
    call reset_mailbox
    li a0, 1
    li a1, 0
    li a2, 0
    li a3, 0
    call set_args
    li t0, WRAP_START
    sw t0, JAB_JOB_GEN(s1)
    sw t0, JAB_JOB_DONE(s1)
    li a0, 0
    call start_worker
    li a0, 1
    call mask_n
    mv s8, a0                               # worker 0's bit
    li s3, 1                                # the job
    li s4, 0                                # outputs wrong
1:
    li t0, WRAP_JOBS
    bgtu s3, t0, 2f
    jab.job.publish s1, zero, s2, s3, s7
    jab.sys.worker.wake s8
    jab.job.join s1
    ld t0, 0(s2)
    la t1, worker_hart
    ld t1, 0(t1)
    li t2, OUT_FACTOR
    mul t2, t2, s3
    add t2, t2, t1
    beq t0, t2, 11f
    addi s4, s4, 1
11:
    addi s3, s3, 1
    j 1b
2:
    lwu s5, JAB_JOB_DONE(s1)
    li a0, 1
    call stop_n
    la s11, line
    la a1, word_wrap
    call put_str
    li a0, WRAP_JOBS
    la a1, word_jobs_generation
    call put_dec_then
    mv a0, s5
    la a1, word_comma
    call put_dec_then
    mv a0, s4
    la a1, word_wrong
    call put_dec_then
    call say

cancel:
    li a0, 0
    call reset_mailbox
    li a0, 1
    li a1, BAND_TICKS
    li a2, CANCEL_BANDS
    li a3, 0
    call set_args
    li a0, 0
    call start_worker
    jab.job.publish s1, zero, zero, zero, s7
    jab.sys.worker.wake s8
    li a0, CANCEL_AFTER
    call spin
    jab.job.cancel s1, s7                   # mid-job: seen at the worker's next band
    jab.job.join s1
    lwu s3, JAB_JOB_STATUS(s1)
    ld t0, OWN_BANDS(s1)
    sltiu s4, t0, CANCEL_BANDS              # stopped short of its bands
    lw t0, JAB_JOB_GEN(s1)
    addiw t0, t0, 1
    jab.job.cancel s1, t0                   # the next job cancelled before it is published
    jab.job.publish s1, zero, zero, zero, s7
    jab.sys.worker.wake s8
    jab.job.join s1
    lwu s5, JAB_JOB_STATUS(s1)
    ld s6, OWN_BANDS(s1)
    li a0, 1
    call stop_n
    la s11, line
    la a1, word_cancel_during
    call put_str
    mv a0, s3
    la a1, word_under
    call put_dec_then
    mv a0, s4
    la a1, word_cancel_before
    call put_dec_then
    mv a0, s5
    la a1, word_bands
    call put_dec_then
    mv a0, s6
    call put_dec
    call say
    la a1, word_done
    call say_str
    jab.sys.exit 0

costs:
    la s9, cost_samples                     # the next sample's place
    li s0, 1                                # one worker, then every one
1:
    li s1, 0
11:
    bgeu s1, s0, 12f
    mv a0, s1
    call reset_mailbox
    addi s1, s1, 1
    j 11b
12:
    mv a0, s0
    call start_n
    mv a0, s0
    call mask_n
    mv s8, a0                               # the workers' bits
    li s2, 0                                # the size
2:
    li t0, SIZES
    bgeu s2, t0, 6f
    la t0, cost_sizes
    slli t1, s2, 3
    add t0, t0, t1
    ld a1, 0(t0)
    mv a0, s0
    li a2, 1
    li a3, 0
    call set_args
    li s3, 1                                # the round
3:
    li t0, COST_ROUNDS
    bgtu s3, t0, 5f
    rdtime s6                               # before the publish
    mv a0, s0
    mv a1, s3
    call publish_n
    jab.sys.worker.wake s8
    mv a0, s0
    call join_n
    rdtime s7                               # the join back
    li s4, 0                                # the worker
    li s5, 0                                # the last completion's stamp
4:
    bgeu s4, s0, 41f
    mv a0, s4
    call mailbox_of
    ld t0, OWN_TAKEN(a0)
    sub t0, t0, s6
    sw t0, 0(s9)                            # its dispatch: the publish to the take
    addi s9, s9, 4
    ld t0, OWN_DONE(a0)
    bgeu s5, t0, 42f
    mv s5, t0
42:
    addi s4, s4, 1
    j 4b
41:
    sub t0, s7, s5
    sw t0, 0(s9)                            # the barrier: the last completion to the join's return
    addi s9, s9, 4
    addi s3, s3, 1
    j 3b
5:
    addi s2, s2, 1
    j 2b
6:
    mv a0, s0
    call stop_n
    la t0, workers_n
    ld t0, 0(t0)
    beq s0, t0, 7f
    mv s0, t0
    j 1b
7:
    la s4, cost_samples
    sub s5, s9, s4
    jab.sys.api.write s4, s5
    la s11, line
    la a1, word_costs
    la t0, workers_n
    ld a0, 0(t0)
    call put_dec_then_rev
    la a1, word_comma
    mv a0, s5
    call put_dec_then_rev
    la a1, word_costs_tail
    call put_str
    call say
    jab.sys.exit 0

job_worker:
    mv s0, a0                               # its mailbox
    mv s2, a1                               # its hart
1:
    jab.job.await s0, s1
    bnez a0, 9f                             # a stop
    rdtime t0
    sd t0, OWN_TAKEN(s0)
    li s3, 0                                # the bands done
    li s4, JAB_JOB_OK
2:
    ld t0, ARG_BANDS(s0)
    bgeu s3, t0, 4f
    jab.job.cancelled s0, s1, t1
    bnez t1, 3f                             # cancelled at a band's boundary
    ld t0, ARG_TICKS(s0)
    rdtime t1
    add t1, t1, t0
21:
    rdtime t0
    bltu t0, t1, 21b
    addi s3, s3, 1
    j 2b
3:
    li s4, JAB_JOB_CANCELLED
4:
    sd s3, OWN_BANDS(s0)
    ld t0, JAB_JOB_PAYLOAD(s0)
    beqz t0, 5f
    ld t1, JAB_JOB_SIZE(s0)
    li t2, OUT_FACTOR
    mul t1, t1, t2
    add t1, t1, s2
    sd t1, 0(t0)                            # the job's output
5:
    rdtime t0
    sd t0, OWN_DONE(s0)
    jab.job.complete s0, s1, s4
    li t0, 1
    jab.sys.worker.wake t0                  # hart 0, the producer, may be joining
    ld t0, ARG_DELAY(s0)
    beqz t0, 1b
    rdtime t1
    add t1, t1, t0
6:
    rdtime t0
    bltu t0, t1, 6b
    j 1b
9:
    jab.sys.worker.exit

find_workers:
    addi sp, sp, -16
    sd ra, 8(sp)
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
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

mailbox_of:
    slli a0, a0, 7
    la t0, mailboxes
    add a0, a0, t0
    ret

output_of:
    slli a0, a0, 6
    la t0, outputs
    add a0, a0, t0
    ret

reset_mailbox:
    addi sp, sp, -16
    sd ra, 8(sp)
    call mailbox_of
    li t0, JAB_JOB_BYTES
1:
    sd zero, 0(a0)
    addi a0, a0, 8
    addi t0, t0, -8
    bnez t0, 1b
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

set_args:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd a1, 16(sp)
    sd a2, 8(sp)
    sd a3, 0(sp)
    mv s0, a0
    li s1, 0
1:
    bgeu s1, s0, 2f
    mv a0, s1
    call mailbox_of
    ld t0, 16(sp)
    sd t0, ARG_TICKS(a0)
    ld t0, 8(sp)
    sd t0, ARG_BANDS(a0)
    ld t0, 0(sp)
    sd t0, ARG_DELAY(a0)
    addi s1, s1, 1
    j 1b
2:
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    addi sp, sp, 48
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
    mv s1, a0                               # the argument: its mailbox
    la t0, worker_hart
    slli t1, s3, 3
    add t0, t0, t1
    ld s0, 0(t0)                            # its hart
    li t0, STACK_BYTES
    mul t0, t0, s3
    la s2, stacks
    add s2, s2, t0                          # its stack
    li s3, STACK_BYTES
    jab.sys.worker.start s0, job_worker, s1, s2, s3
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

start_n:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, a0
    li s1, 0
1:
    bgeu s1, s0, 2f
    mv a0, s1
    call start_worker
    addi s1, s1, 1
    j 1b
2:
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
    ret

mask_n:
    la t0, worker_hart
    li t1, 0                                # the mask
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

stop_n:
    addi sp, sp, -16
    sd ra, 8(sp)
    call mask_n
    jab.sys.worker.stop a0
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

publish_n:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s0, a0
    mv s1, a1                               # the round, each job's size
    li s2, 0
1:
    bgeu s2, s0, 2f
    mv a0, s2
    call output_of
    mv s3, a0
    mv a0, s2
    call mailbox_of
    mv t2, a0
    jab.job.publish t2, zero, s3, s1, t3
    addi s2, s2, 1
    j 1b
2:
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 48
    ret

join_n:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    sd s2, 0(sp)
    mv s0, a0
    li s1, 0
1:
    bgeu s1, s0, 2f
    mv a0, s1
    call mailbox_of
    mv s2, a0
    jab.job.join s2
    addi s1, s1, 1
    j 1b
2:
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 32
    ret

check_n:
    la t3, worker_hart
    la t4, outputs
    li t5, 0                                # outputs wrong
    li t6, OUT_FACTOR
    mul t6, t6, a1
1:
    beqz a0, 2f
    ld t0, 0(t4)
    ld t1, 0(t3)
    add t1, t1, t6
    beq t0, t1, 11f
    addi t5, t5, 1
11:
    addi t3, t3, 8
    addi t4, t4, OUTPUT_BYTES
    addi a0, a0, -1
    j 1b
2:
    mv a0, t5
    ret

count_n:
    la t0, mailboxes
    li t1, 0                                # the completions
1:
    beqz a0, 2f
    ld t2, JAB_JOB_COUNT(t0)
    add t1, t1, t2
    addi t0, t0, JAB_JOB_BYTES
    addi a0, a0, -1
    j 1b
2:
    mv a0, t1
    ret

spin:
    rdtime t0
    add t1, t0, a0
1:
    rdtime t0
    bltu t0, t1, 1b
    ret

field:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
    call put_str
    ld a0, 0(sp)
    call put_dec
    ld ra, 8(sp)
    addi sp, sp, 16
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

put_str:
    lbu t0, 0(a1)
    beqz t0, 1f
    sb t0, 0(s11)
    addi s11, s11, 1
    addi a1, a1, 1
    j put_str
1:
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

.section .rodata
.balign 8
cost_sizes:
    .quad (JAB_TIME_HZ / 100000), (JAB_TIME_HZ / 10000), (JAB_TIME_HZ / 1000), (JAB_TIME_HZ / 100)
variant_words:
    .quad word_before, word_during, word_spurious, word_after
word_none:
    .asciz "jobs: no scenario"
word_no_workers:
    .asciz "jobs: no worker hart online"
word_refused:
    .asciz "jobs: a start refused"
word_fixture:
    .asciz "jobs: scenario fixture, workers "
word_idle:
    .asciz "idle "
word_idle_tail:
    .asciz " workers held"
word_before:
    .asciz "before "
word_during:
    .asciz "during "
word_spurious:
    .asciz "spurious "
word_after:
    .asciz "after "
word_rounds:
    .asciz " rounds, "
word_wrong:
    .asciz " wrong"
word_wrong_comma:
    .asciz " wrong, "
word_completions:
    .asciz " completions"
word_free:
    .asciz "free "
word_then:
    .asciz " then "
word_out:
    .asciz ", out "
word_wrap:
    .asciz "wrap "
word_jobs_generation:
    .asciz " jobs, generation "
word_comma:
    .asciz ", "
word_cancel_during:
    .asciz "cancel during "
word_under:
    .asciz " under "
word_cancel_before:
    .asciz ", cancel before "
word_bands:
    .asciz " bands "
word_done:
    .asciz "jobs: done"
word_costs:
    .asciz "jobs: costs, workers "
word_costs_tail:
    .asciz " bytes"

.section .bss
.balign 64
mailboxes:
    .skip (MAX_WORKERS * JAB_JOB_BYTES)
outputs:
    .skip (MAX_WORKERS * OUTPUT_BYTES)
.balign 8
worker_hart:
    .skip (MAX_WORKERS * 8)
workers_n:
    .skip 8
selector:
    .skip 8
line:
    .skip 160
digits:
    .skip 32
.balign 8
cost_samples:
    .skip COST_BYTES
.balign 16
stacks:
    .skip (MAX_WORKERS * STACK_BYTES)
