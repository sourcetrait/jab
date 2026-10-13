.include "jab.inc"
.include "jab_jobs.inc"
.include "jab_manifest.inc"

.set ROWS, 64
.set BAND_ROWS, 8
.set BANDS, (ROWS / BAND_ROWS)
.set ROW_STEPS, 4096
.set FEATURE_STEPS, (1 << 20)
.set FEATURE_SEED, 0x2545f4914f6cdd1d
.set FRAMES, 4
.set STACK_BYTES, 16384
.set HOLD_TICKS, (2 * JAB_TIME_HZ)
.set HOLD_IDLE, 0
.set HOLD_HELD, 1
.set HOLD_RELEASED, 2
.set HOLD_EXPIRED, 3
.set ARG_INDEX, JAB_JOB_ARGS
.set ARG_COUNT, (JAB_JOB_ARGS + 8)
.set ARG_HOLD, (JAB_JOB_ARGS + 16)
.set FEAT_DONE, 0
.set FEAT_PARK, 4
.set FEAT_RESULT, 8
.set FEAT_HART, 16
.set FEAT_BYTES, 32
.set REC_FRAME, 0
.set REC_GFX, 8
.set REC_FEATURE, 16
.set REC_SUM, 24
.set REC_ROWS, 32
.set RECORD_BYTES, (REC_ROWS + ROWS)

.macro start_worker entry
    addi t2, a0, -1
    li t1, STACK_BYTES
    mul t2, t2, t1
    la t1, stacks
    add t2, t2, t1                          # the hart's own stack
    li t1, STACK_BYTES
    mv t4, a0
    mv t3, a1
    mv t0, a2
    jab.sys.worker.start t4, \entry, t3, t2, t1, t0
.endm

.section .text
.global _start
_start:
    jab.sys.harts
    andi s0, a1, -2                         # the online secondaries
    la s11, line
    la a1, word_harts
    mv a0, s0
    call field
    call say

reserve:
    jab.sys.harts.reserve JAB_RESERVED_GFX_HARTS
    mv s5, a0
    mv s6, a1                               # the grant
    li t0, JAB_OWNER_RESERVED
    jab.sys.harts.owned t0
    mv s7, a0
    la s11, line
    la a1, word_reserve
    mv a0, s5
    call field
    la a1, word_space
    mv a0, s6
    call field
    la a1, word_owned
    mv a0, s7
    call field
    call say
    bnez s5, stop_run
    mv s0, s6                               # the reservation's grant from here
    cpop s8, s0                             # its harts
    mv a0, s0
    li a1, JAB_FEATURE_SYNTHETIC_IO_HARTS
    call top_harts
    mv s1, a0                               # the feature's harts, the grant's highest
    not t0, s1
    and s2, s0, t0                          # the grant left beside them
    li t0, (JAB_FEATURE_SYNTHETIC_IO_HARTS + JAB_RESERVED_GFX_HARTS)
    sltu s4, s8, t0
    xori s4, s4, 1                          # admitted while the grant past the feature keeps the reservation

startup:
    la a0, word_startup_check
    call check_line
    beqz s4, startup_refused
    jab.sys.harts.claim s1
    mv s5, a0
    mv s3, a1                               # the claim's id
    la a0, word_startup_claim
    mv a1, s5
    mv a2, s3
    call claim_line
    bnez s5, stop_run
    mv a0, s2
    li a1, 1
    call top_harts
    jab.sys.harts.claim a0                  # a hart of the grant left, no worker on it yet
    mv s5, a0
    li t0, JAB_OWNER_RESERVED
    jab.sys.harts.owned t0
    mv s7, a0
    la s11, line
    la a1, word_startup_second
    mv a0, s5
    call field
    la a1, word_left
    mv a0, s7
    call field
    call say
    mv a0, s2
    call start_graphics
    mv s5, a0
    la s11, line
    la a1, word_startup_graphics
    mv a0, s2
    call field
    la a1, word_refused
    mv a0, s5
    call field
    call say
    bnez s5, stop_run
    call feature_run
    j transition

startup_refused:
    jab.sys.harts.claim s1                  # the kernel's word on the harts the feature would take
    mv s5, a0
    mv s6, a1
    la a0, word_startup_claim
    mv a1, s5
    mv a2, s6
    call claim_line
    mv a0, s0
    call start_graphics
    mv s5, a0
    la s11, line
    la a1, word_startup_graphics
    mv a0, s0
    call field
    la a1, word_refused
    mv a0, s5
    call field
    call say
    bnez s5, stop_run
    mv a0, s0
    li a1, 0
    li a2, FRAMES
    call frames

transition:
    la a0, word_transition_check
    call check_line
    beqz s4, transition_refused
    la t0, hold_word
    sw zero, 0(t0)                          # HOLD_IDLE before the held frame
    mv a0, s0
    li a1, 0
    ctz a2, s1                              # the band of the feature's first hart held
    call frame_publish
    call hold_wait
    jab.sys.harts.claim s1                  # its worker inside the band
    mv s5, a0
    li t0, JAB_OWNER_RESERVED
    jab.sys.harts.owned t0
    mv s7, a0
    la s11, line
    la a1, word_transition_busy
    mv a0, s5
    call field
    la a1, word_left
    mv a0, s7
    call field
    call say
    call release_hold                       # the boundary: the band let go, the frame joined
    call frame_join
    jab.sys.worker.stop s1                  # then the hart's worker, waiting in its mailbox
    mv s5, a0
    mv s6, a1
    la t0, hold_word
    lw s7, 0(t0)
    la s11, line
    la a1, word_transition_stop
    mv a0, s5
    call field
    la a1, word_interrupted
    mv a0, s6
    call field
    la a1, word_hold
    mv a0, s7
    call field
    call say
    bnez s6, stop_run                       # interrupted: no join after it
    jab.sys.harts.claim s1
    mv s5, a0
    mv s3, a1                               # the claim's id
    la a0, word_transition_claim
    mv a1, s5
    mv a2, s3
    call claim_line
    bnez s5, stop_run
    mv a0, s1
    call start_graphics
    mv s5, a1                               # those refused for their owner
    la s11, line
    la a1, word_transition_owner
    mv a0, s5
    call field
    call say
    call feature_run
    j finish

transition_refused:
    jab.sys.harts.claim s1                  # a hart its graphics worker runs on
    mv s5, a0
    mv s6, a1
    la a0, word_transition_claim
    mv a1, s5
    mv a2, s6
    call claim_line
    mv a0, s0
    li a1, 0
    li a2, FRAMES
    call frames

finish:
    jab.sys.worker.stop s0                  # every graphics worker, waiting in its mailbox
    mv s5, a0
    mv s6, a1
    la t0, frame_next
    ld s7, 0(t0)
    la s11, line
    la a1, word_end_stop
    mv a0, s5
    call field
    la a1, word_interrupted
    mv a0, s6
    call field
    la a1, word_frames
    mv a0, s7
    call field
    call say
    bnez s6, stop_run
    jab.sys.exit 0

stop_run:
    jab.sys.exit 1

feature_run:
    addi sp, sp, -16
    sd ra, 8(sp)
    mv a0, s1
    call feature_start
    mv s5, a0
    la s11, line
    la a1, word_feature_start
    mv a0, s5
    call field
    call say
    bnez s5, stop_run
    mv a0, s2
    mv a1, s1
    li a2, FRAMES
    call frames                             # beside the feature at work
    jab.sys.harts.release s3                # its worker on the hart still
    mv s5, a0
    la s11, line
    la a1, word_feature_release
    mv a0, s5
    call field
    call say
    mv a0, s1
    call feature_join
    jab.sys.worker.stop s1
    mv s5, a0
    mv s6, a1
    la s11, line
    la a1, word_feature_stop
    mv a0, s5
    call field
    la a1, word_interrupted
    mv a0, s6
    call field
    call say
    bnez s6, stop_run
    jab.sys.harts.release s3
    mv s5, a0
    mv s6, a1
    li t0, JAB_OWNER_RESERVED
    jab.sys.harts.owned t0
    mv s7, a0
    la s11, line
    la a1, word_feature_released
    mv a0, s5
    call field
    la a1, word_space
    mv a0, s6
    call field
    la a1, word_left
    mv a0, s7
    call field
    call say
    ctz a0, s1
    mv a1, s3
    call stale_start                        # a start under the released id
    mv s5, a0
    jab.sys.worker.stop s1                  # whatever it started, gone
    jab.sys.harts.release s3
    mv s6, a0
    la s11, line
    la a1, word_feature_stale
    mv a0, s5
    call field
    la a1, word_space
    mv a0, s6
    call field
    call say
    mv a0, s1
    call start_graphics                     # the return
    mv s5, a0
    la s11, line
    la a1, word_feature_return
    mv a0, s5
    call field
    call say
    bnez s5, stop_run
    mv a0, s0
    li a1, 0
    li a2, FRAMES
    call frames                             # on the whole grant again
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

check_line:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s5, 0(sp)
    mv s5, a0
    la s11, line
    mv a1, s5
    mv a0, s8
    call field
    la a1, word_want
    mv a0, s1
    call field
    la a1, word_admit
    mv a0, s4
    call field
    call say
    ld s5, 0(sp)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

claim_line:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s5, 32(sp)
    sd s6, 24(sp)
    sd s7, 16(sp)
    sd s9, 8(sp)
    sd s10, 0(sp)
    mv s5, a0
    mv s6, a1
    mv s7, a2
    jab.sys.harts.owned s7
    mv s9, a0                               # the id's harts
    li t0, JAB_OWNER_RESERVED
    jab.sys.harts.owned t0
    mv s10, a0                              # the reservation's
    la s11, line
    mv a1, s5
    mv a0, s6
    call field
    la a1, word_id
    mv a0, s7
    call field
    la a1, word_owned
    mv a0, s9
    call field
    la a1, word_left
    mv a0, s10
    call field
    call say
    ld s10, 0(sp)
    ld s9, 8(sp)
    ld s7, 16(sp)
    ld s6, 24(sp)
    ld s5, 32(sp)
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

top_harts:
    li t0, 0                                # the harts taken
1:
    beqz a1, 2f
    beqz a0, 2f
    clz t1, a0
    li t2, 63
    sub t1, t2, t1                          # the highest left
    li t2, 1
    sll t2, t2, t1
    or t0, t0, t2
    xor a0, a0, t2
    addi a1, a1, -1
    j 1b
2:
    mv a0, t0
    ret

start_graphics:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s5, 32(sp)
    sd s6, 24(sp)
    sd s7, 16(sp)
    sd s9, 8(sp)
    mv s5, a0
    li s6, 0                                # those refused
    li s7, 0                                # those refused for their owner
    li s9, 1                                # the hart
1:
    li t0, JAB_HARTS_MAX
    bgeu s9, t0, 3f
    srl t0, s5, s9
    andi t0, t0, 1
    beqz t0, 2f
    mv a0, s9
    call gfx_start
    beqz a0, 2f
    li t0, 1
    sll t0, t0, s9
    or s6, s6, t0
    li t1, JAB_START_OWNER
    bne a0, t1, 2f
    or s7, s7, t0
2:
    addi s9, s9, 1
    j 1b
3:
    mv a0, s6
    mv a1, s7
    ld s9, 8(sp)
    ld s7, 16(sp)
    ld s6, 24(sp)
    ld s5, 32(sp)
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

gfx_start:
    slli a1, a0, 7
    la t0, mailboxes
    add a1, a1, t0                          # its mailbox, the argument
    li a2, JAB_OWNER_RESERVED
    start_worker gfx_worker
    ret

feature_start:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s5, 32(sp)
    sd s6, 24(sp)
    sd s7, 16(sp)
    sd s9, 8(sp)
    mv s5, a0
    li s6, 0                                # the first refusal's answer
    li s9, 1                                # the hart
1:
    li t0, JAB_HARTS_MAX
    bgeu s9, t0, 3f
    srl t0, s5, s9
    andi t0, t0, 1
    beqz t0, 2f
    slli s7, s9, 5
    la t0, feature_records
    add s7, s7, t0                          # its record
    sw zero, FEAT_DONE(s7)
    sw zero, FEAT_PARK(s7)
    mv a0, s9
    mv a1, s7
    mv a2, s3                               # under the claim's id
    start_worker feature_worker
    bnez s6, 2f
    mv s6, a0
2:
    addi s9, s9, 1
    j 1b
3:
    mv a0, s6
    ld s9, 8(sp)
    ld s7, 16(sp)
    ld s6, 24(sp)
    ld s5, 32(sp)
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

stale_start:
    mv a2, a1
    li a1, 0
    start_worker exit_worker
    ret

feature_join:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s5, 16(sp)
    sd s6, 8(sp)
    sd s7, 0(sp)
    mv s5, a0
    la s11, line
    la a1, word_feature_result
    call put_str
    li s6, 1                                # the hart
1:
    li t0, JAB_HARTS_MAX
    bgeu s6, t0, 4f
    srl t0, s5, s6
    andi t0, t0, 1
    beqz t0, 3f
    slli s7, s6, 5
    la t0, feature_records
    add s7, s7, t0                          # its record
2:
    lw t0, FEAT_DONE(s7)
    bnez t0, 21f
    addi a0, s7, FEAT_DONE
    li a1, 0
    li a7, JAB_SYS_WORKER_WAIT
    ecall                                   # asleep while its mark is 0
    j 2b
21:
    fence r, rw                             # its result after its mark
    la a1, word_space
    ld a0, FEAT_HART(s7)
    call field
    la a1, word_space
    ld a0, FEAT_RESULT(s7)
    call hex_field
3:
    addi s6, s6, 1
    j 1b
4:
    call say
    ld s7, 0(sp)
    ld s6, 8(sp)
    ld s5, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

frames:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s5, 16(sp)
    sd s6, 8(sp)
    sd s7, 0(sp)
    mv s5, a0
    mv s6, a1
    mv s7, a2
1:
    beqz s7, 2f
    mv a0, s5
    mv a1, s6
    li a2, 0
    call frame_publish
    call frame_join
    addi s7, s7, -1
    j 1b
2:
    ld s7, 0(sp)
    ld s6, 8(sp)
    ld s5, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

frame_publish:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s5, 32(sp)
    sd s6, 24(sp)
    sd s7, 16(sp)
    sd s9, 8(sp)
    sd s10, 0(sp)
    mv s5, a0
    mv s10, a2
    la t0, frame_gfx
    sd a0, 0(t0)
    la t0, frame_feature
    sd a1, 0(t0)
    la t0, words
    la t1, renderers
    li t2, ROWS
1:
    sd zero, 0(t0)
    sb zero, 0(t1)                          # no renderer yet
    addi t0, t0, 8
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, 1b
    cpop s6, s5                             # the frame's workers
    la t0, frame_next
    ld s7, 0(t0)                            # its number
    li s9, 0                                # a worker's index
    li t3, 1                                # the hart
2:
    li t0, JAB_HARTS_MAX
    bgeu t3, t0, 4f
    srl t0, s5, t3
    andi t0, t0, 1
    beqz t0, 3f
    slli t4, t3, 7
    la t0, mailboxes
    add t4, t4, t0                          # its mailbox
    sd s9, ARG_INDEX(t4)
    sd s6, ARG_COUNT(t4)
    sub t0, t3, s10
    seqz t0, t0
    sd t0, ARG_HOLD(t4)                     # its band held when it is the hart named
    jab.job.publish t4, s7, zero, zero, t5
    addi s9, s9, 1
3:
    addi t3, t3, 1
    j 2b
4:
    jab.sys.worker.wake s5
    ld s10, 0(sp)
    ld s9, 8(sp)
    ld s7, 16(sp)
    ld s6, 24(sp)
    ld s5, 32(sp)
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

frame_join:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s5, 16(sp)
    sd s6, 8(sp)
    sd s7, 0(sp)
    la t0, frame_gfx
    ld s5, 0(t0)
    li s6, 1                                # the hart
1:
    li t0, JAB_HARTS_MAX
    bgeu s6, t0, 3f
    srl t0, s5, s6
    andi t0, t0, 1
    beqz t0, 2f
    slli s7, s6, 7
    la t0, mailboxes
    add s7, s7, t0
    jab.job.join s7
2:
    addi s6, s6, 1
    j 1b
3:
    la t0, record
    la t1, frame_next
    ld t2, 0(t1)
    sd t2, REC_FRAME(t0)
    addi t2, t2, 1
    sd t2, 0(t1)                            # the next frame's number
    sd s5, REC_GFX(t0)
    la t1, frame_feature
    ld t2, 0(t1)
    sd t2, REC_FEATURE(t0)
    la t1, words
    li t2, ROWS
    li t3, 0
4:
    ld t4, 0(t1)
    add t3, t3, t4                          # the rows' words summed, wrapping
    addi t1, t1, 8
    addi t2, t2, -1
    bnez t2, 4b
    sd t3, REC_SUM(t0)
    la t1, renderers
    addi t2, t0, REC_ROWS
    li t3, ROWS
5:
    lbu t4, 0(t1)
    sb t4, 0(t2)
    addi t1, t1, 1
    addi t2, t2, 1
    addi t3, t3, -1
    bnez t3, 5b
    la a0, record
    li a1, RECORD_BYTES
    li a7, JAB_SYS_API_WRITE
    ecall
    ld s7, 0(sp)
    ld s6, 8(sp)
    ld s5, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

hold_wait:
1:
    la t2, hold_word
    lw t0, 0(t2)
    li t1, HOLD_IDLE
    bne t0, t1, 2f
    mv a0, t2
    mv a1, t1
    li a7, JAB_SYS_WORKER_WAIT
    ecall                                   # asleep while it holds HOLD_IDLE
    j 1b
2:
    fence r, rw                             # the band's first row after its hold
    ret

release_hold:
    la t0, hold_word
    li t1, HOLD_HELD
    li t2, HOLD_RELEASED
1:
    lr.w t3, (t0)
    bne t3, t1, 2f                          # expired: the expiry stands
    sc.w.rl t3, t2, (t0)
    bnez t3, 1b
2:
    ret

gfx_worker:
    mv s0, a0                               # its mailbox
    mv s1, a1                               # its hart
1:
    jab.job.await s0, s2
    bnez a0, 9f                             # a stop
    ld s3, ARG_INDEX(s0)
    ld s4, ARG_COUNT(s0)
    ld s5, JAB_JOB_FRAME(s0)
    ld s6, ARG_HOLD(s0)
    mv s7, s3                               # its first band its index, each next the workers' count on
2:
    li t0, BANDS
    bgeu s7, t0, 5f
    li t0, BAND_ROWS
    mul s8, s7, t0                          # the band's first row
    li s9, BAND_ROWS
3:
    mv a0, s5
    mv a1, s8
    call row_word
    la t0, words
    slli t1, s8, 3
    add t0, t0, t1
    sd a0, 0(t0)
    la t0, renderers
    add t0, t0, s8
    sb s1, 0(t0)                            # the row's renderer
    beqz s6, 4f
    li s6, 0
    call hold_band                          # held inside its band, after its first row
4:
    addi s8, s8, 1
    addi s9, s9, -1
    bnez s9, 3b
    add s7, s7, s4
    j 2b
5:
    li t1, JAB_JOB_OK
    jab.job.complete s0, s2, t1
    li t0, 1
    jab.sys.worker.wake t0                  # hart 0, joining
    j 1b
9:
    jab.sys.worker.exit

hold_band:
    la t0, hold_word
    li t1, HOLD_HELD
    fence rw, w                             # the band's first row before the word that holds it
    sw t1, 0(t0)
    li a0, 1
    li a7, JAB_SYS_WORKER_WAKE
    ecall                                   # hart 0, waiting on the word
    rdtime t2
    li t3, HOLD_TICKS
    add t2, t2, t3                          # the watchdog's bound
    la t0, hold_word
    li t1, HOLD_HELD
1:
    lw t4, 0(t0)
    bne t4, t1, 3f                          # released
    rdtime t4
    bgeu t4, t2, 2f
    pause
    j 1b
2:
    li t5, HOLD_EXPIRED
21:
    lr.w t4, (t0)
    bne t4, t1, 3f                          # released at the last: the release stands
    sc.w t4, t5, (t0)
    bnez t4, 21b
3:
    fence r, rw                             # hart 0's release before the band goes on
    ret

row_word:
    slli a0, a0, 8
    or a0, a0, a1
    addi a0, a0, 1                          # the seed, never 0
    li t0, ROW_STEPS
1:
    slli t1, a0, 13
    xor a0, a0, t1
    srli t1, a0, 7
    xor a0, a0, t1
    slli t1, a0, 17
    xor a0, a0, t1
    addi t0, t0, -1
    bnez t0, 1b
    ret

feature_worker:
    mv s0, a0                               # its record
    mv s1, a1                               # its hart
    li t0, FEATURE_SEED
    li t1, FEATURE_STEPS
1:
    slli t2, t0, 13
    xor t0, t0, t2
    srli t2, t0, 7
    xor t0, t0, t2
    slli t2, t0, 17
    xor t0, t0, t2
    addi t1, t1, -1
    bnez t1, 1b
    sd t0, FEAT_RESULT(s0)
    sd s1, FEAT_HART(s0)
    fence rw, w                             # the result before the mark
    li t0, 1
    sw t0, FEAT_DONE(s0)
    li t0, 1
    jab.sys.worker.wake t0                  # hart 0, joining
2:
    addi t0, s0, FEAT_PARK
    jab.sys.worker.wait t0, zero            # its park word stays 0
    beqz a0, 2b
    jab.sys.worker.exit

exit_worker:
    jab.sys.worker.exit

field:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
    call put_str
    ld a0, 0(sp)
    call put_signed
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

hex_field:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
    call put_str
    ld a0, 0(sp)
    call put_hex
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

put_signed:
    bgez a0, put_dec
    li t0, '-'
    sb t0, 0(s11)
    addi s11, s11, 1
    neg a0, a0
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

.section .rodata
word_harts:
    .asciz "harts "
word_reserve:
    .asciz "reserve "
word_space:
    .asciz " "
word_owned:
    .asciz " owned "
word_startup_check:
    .asciz "startup check "
word_transition_check:
    .asciz "transition check "
word_want:
    .asciz " want "
word_admit:
    .asciz " admit "
word_startup_claim:
    .asciz "startup claim "
word_transition_claim:
    .asciz "transition claim "
word_id:
    .asciz " id "
word_left:
    .asciz " left "
word_startup_second:
    .asciz "startup second "
word_startup_graphics:
    .asciz "startup graphics "
word_refused:
    .asciz " refused "
word_feature_start:
    .asciz "feature start "
word_feature_release:
    .asciz "feature release "
word_feature_result:
    .asciz "feature result"
word_feature_stop:
    .asciz "feature stop "
word_interrupted:
    .asciz " interrupted "
word_feature_released:
    .asciz "feature released "
word_feature_stale:
    .asciz "feature stale "
word_feature_return:
    .asciz "feature return "
word_transition_busy:
    .asciz "transition busy "
word_transition_stop:
    .asciz "transition stop "
word_hold:
    .asciz " hold "
word_transition_owner:
    .asciz "transition owner "
word_end_stop:
    .asciz "end stop "
word_frames:
    .asciz " frames "

.section .bss
.balign 64
mailboxes:
    .skip (JAB_HARTS_MAX * JAB_JOB_BYTES)
feature_records:
    .skip (JAB_HARTS_MAX * FEAT_BYTES)
.balign 8
words:
    .skip (ROWS * 8)
renderers:
    .skip ROWS
.balign 8
record:
    .skip RECORD_BYTES
frame_next:
    .skip 8
frame_gfx:
    .skip 8
frame_feature:
    .skip 8
hold_word:
    .skip 8
line:
    .skip 200
digits:
    .skip 32
.balign 16
stacks:
    .skip ((JAB_HARTS_MAX - 1) * STACK_BYTES)
