.section .text

service_init:
    li t0, SERVICE_NONE
    la t1, service_word
    sd t0, 0(t1)                    # no message applied yet
    la t1, service_record
    sd t0, SVC_LAST(t1)
    sd t0, SVC_WORD(t1)
    ret

service_frame:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    rdtime s2                       # the phase's start
    la t0, service_frame_at
    sd s8, 0(t0)                    # the frame, the loop's count
    la s3, service_record
    sw zero, SVC_APPLIED(s3)
    sw zero, SVC_REJECTED(s3)
    sw zero, SVC_AGE_US(s3)
    lwu t0, SVC_FLAGS(s3)
    li t1, ~(SVC_TORN | SVC_STARTED | SVC_STOPPED)
    and t0, t0, t1
    sw t0, SVC_FLAGS(s3)            # the frame's own marks cleared
    la t0, service_state
    lwu t1, 0(t0)
    beqz t1, 8f                     # no service: nothing to apply or pace
.ifdef DEBUG
    la t0, service_lockstep
    lbu t1, 0(t0)
    beqz t1, 1f
    la s4, service_mailbox
    jab.job.join s4                 # LOCKSTEP: the quota offered whole before the boundary applies
1:
.endif
    li a0, MSG_APPLY_MAX
    call service_apply
    sw a0, SVC_APPLIED(s3)
    sw a1, SVC_REJECTED(s3)
    bltz a2, 2f
    sw a2, SVC_AGE_US(s3)           # the oldest applied message's age
2:
    call service_fill               # the counts as the boundary leaves them, before the next quota
    call service_pace
    j 9f
8:
    call service_fill
9:
    rdtime t0
    sub t0, t0, s2
    li t1, US_TICKS
    divu t0, t0, t1
    sw t0, SVC_APPLY_US(s3)         # the phase: the application and the pacing
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 48
    ret

service_apply:
    addi sp, sp, -80
    sd ra, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    sd s7, 24(sp)
    sd s8, 16(sp)
    sd s9, 8(sp)
    mv s2, a0                       # the slots it may consume
    la t0, service_line_w
    ld s3, LINE_INDEX(t0)           # W, the producer's
    fence r, rw                     # the slots below it after the index that published them
    la t0, service_read
    ld s4, 0(t0)                    # R, hart 0's own copy
    sub t0, s3, s4
    bleu t0, s2, 1f
    add s3, s4, s2                  # no more than the limit
1:
    li s5, 0                        # applied
    li s6, 0                        # rejected
    li s8, SERVICE_NONE             # the oldest applied message's age
2:
    bgeu s4, s3, 7f
    andi t0, s4, (MSG_SLOTS - 1)
    slli t0, t0, MSG_SHIFT
    la s7, service_ring
    add s7, s7, t0                  # the slot
    mv a0, s7
    call message_sum
    ld t0, MSG_CHECKSUM(s7)
    bne a0, t0, 5f                  # its checksum failed: rejected, never applied
    ld s9, MSG_SEQUENCE(s7)
    la t0, service_word
    sd s9, 0(t0)                    # applied: the game state's service word
    la t0, service_chain
    ld t1, 0(t0)
    xor t1, t1, a0
    li t2, SERVICE_PRIME
    mul t1, t1, t2
    sd t1, 0(t0)                    # the applied chain, in application order
    la t0, service_next
    ld t1, 0(t0)
    sub t2, s9, t1                  # the gap before it
    addi t3, s9, 1
    sd t3, 0(t0)
    la t0, service_gaps
    ld t1, 0(t0)
    add t1, t1, t2
    sd t1, 0(t0)
    bgez s8, 3f
    rdtime t0
    ld t1, MSG_TIME(s7)
    sub t0, t0, t1
    li t1, US_TICKS
    divu s8, t0, t1                 # the first applied, the oldest
3:
    addi s5, s5, 1
    j 6f
5:
    addi s6, s6, 1
    mv a0, s7
    call service_reject
6:
    addi s4, s4, 1
    j 2b
7:
    fence rw, w                     # the slots' reads before the index that frees them
    la t0, service_line_r
    sd s4, LINE_INDEX(t0)           # R, the producer's to read
    la t0, service_read
    sd s4, 0(t0)
    la t0, service_line_r
    ld t1, LINE_COUNT(t0)
    add t1, t1, s5
    sd t1, LINE_COUNT(t0)           # applied, hart 0's alone
    ld t1, LINE_LOSS(t0)
    add t1, t1, s6
    sd t1, LINE_LOSS(t0)            # rejected
    mv a0, s5
    mv a1, s6
    mv a2, s8
    ld ra, 72(sp)
    ld s2, 64(sp)
    ld s3, 56(sp)
    ld s4, 48(sp)
    ld s5, 40(sp)
    ld s6, 32(sp)
    ld s7, 24(sp)
    ld s8, 16(sp)
    ld s9, 8(sp)
    addi sp, sp, 80
    ret

service_reject:
    la t0, reject_record
    li t1, REPORT_SERVICE_REJECT
    sw t1, REPORT_KIND(t0)
    la t1, service_frame_at
    ld t1, 0(t1)
    sw t1, REPORT_FRAME_NUMBER(t0)
    ld t1, MSG_SEQUENCE(a0)
    sd t1, REJECT_SEQUENCE(t0)
    ld t1, MSG_GENERATION(a0)
    sw t1, REJECT_GENERATION(t0)
    la t1, service_ring
    sub t1, a0, t1
    srli t1, t1, MSG_SHIFT
    sw t1, REJECT_SLOT(t0)
    li t1, SERVICE_SCHEMA
    sw t1, REPORT_SCHEMA(t0)
    li t1, REPORT_SIZE
    jab.sys.api.write t0, t1
    ret

service_pace:
    la t0, service_schedule
    ld t1, SCHED_TOTAL(t0)
    ld t2, SCHED_FRAMES(t0)
    ld t3, SCHED_INDEX(t0)
    addi t4, t3, 1
    sd t4, SCHED_INDEX(t0)          # the schedule moves a frame, published or skipped
    mv t4, t1                       # unbounded: the total each frame
    beqz t2, 1f
    li t4, 0
    bgeu t3, t2, 1f                 # the schedule done: no quota
    divu t4, t1, t2
    remu t5, t1, t2
    sltu t5, t3, t5
    add t4, t4, t5                  # one more in each of the first total mod frames
1:
    beqz t4, 9f
    la t5, service_mailbox
    jab.job.free t5, t6
    beqz t6, 8f                     # the producer still on an earlier quota: skipped
    sd t4, SERVICE_QUOTA(t5)        # the quota, before the publish's fence
    la t2, service_frame_at
    ld t2, 0(t2)
    jab.job.publish t5, t2, zero, zero, t3
    la t0, service_harts
    ld t0, 0(t0)
    jab.sys.worker.wake t0          # the producer's hart
    ret
8:
    la t0, service_skipped
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
9:
    ret

service_fill:
    la t0, service_record
    la t1, service_line_w
    ld t2, LINE_COUNT(t1)
    sw t2, SVC_OFFERED(t0)          # the producer's counts as they stand
    ld t2, LINE_LOSS(t1)
    sw t2, SVC_DROPPED(t0)
    ld t2, LINE_INDEX(t1)           # W
    fence r, rw
    la t3, service_read
    ld t3, 0(t3)
    sub t2, t2, t3
    sw t2, SVC_DEPTH(t0)            # the ring after applying
    la t1, service_skipped
    ld t2, 0(t1)
    sw t2, SVC_SKIPPED(t0)
    la t1, service_word
    ld t2, 0(t1)
    sd t2, SVC_LAST(t0)             # the last applied, the game state's word
    lwu t2, SVC_FLAGS(t0)
    andi t2, t2, (SVC_TORN | SVC_STARTED | SVC_STOPPED)
    la t1, service_state
    lwu t3, 0(t1)
    beqz t3, 1f
    ori t2, t2, SVC_RUNNING
1:
.ifdef DEBUG
    la t1, service_lockstep
    lbu t3, 0(t1)
    beqz t3, 2f
    ori t2, t2, SVC_LOCKSTEP
2:
.endif
    la t1, service_header
    ld t3, HEADER_GENERATION(t1)
    slli t3, t3, SVC_GENERATION_SHIFT
    or t2, t2, t3
    sw t2, SVC_FLAGS(t0)
    ret

message_sum:
    li t0, SERVICE_BASIS
    li t1, SERVICE_PRIME
    li t2, 0
1:
    add t3, a0, t2
    ld t3, 0(t3)
    xor t0, t0, t3
    mul t0, t0, t1
    addi t2, t2, 8
    li t3, MSG_CHECKSUM
    bltu t2, t3, 1b
    mv a0, t0
    ret

service_command:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s2, 0(sp)
    mv s2, a0
    lbu t0, V_MODE(s2)
    beqz t0, 1f
    mv a0, s2
    call service_start
    j 2f
1:
    call service_stop
2:
    la t0, console_record
    sw a0, CONSOLE_STATUS(t0)       # the answer: the start's or the stop's status
    la t1, service_harts
    ld t1, 0(t1)
    sw t1, CONSOLE_HARTS(t0)        # the service's harts
    la t1, service_header
    ld t1, HEADER_GENERATION(t1)
    sw t1, CONSOLE_GENERATION(t0)   # its window's generation
    ld ra, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 16
    ret

service_start:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    mv s2, a0                       # the V frame
    li a0, SERVICE_RUNNING_ALREADY
    la t0, service_state
    lwu t1, 0(t0)
    bnez t1, 9f
    la t0, service_harts
    sd zero, 0(t0)                  # none until the producer starts
    li a0, JAB_FEATURE_SERVICE_IO_HARTS
    call gfx_take                   # the grant's highest hart under the program's claim, its raster worker stopped
    bnez a0, 9f                     # refused: everything as it stood
    la t0, gfx_claim
    ld s3, 0(t0)                    # the claim's id
    jab.sys.harts.owned s3
    mv s4, a0                       # its harts
    li a0, SERVICE_NO_HART
    beqz s4, 7f
    li s5, 0                        # the producer's hart, the claim's lowest
1:
    srl t0, s4, s5
    andi t0, t0, 1
    bnez t0, 2f
    addi s5, s5, 1
    j 1b
2:
    mv a0, s2
    call service_reset
    la t0, service_mailbox
    la t1, service_stack
    li t2, WORKER_STACK
    jab.sys.worker.start s5, service_producer, t0, t1, t2, s3
    bnez a0, 6f
    li t0, 1
    sll t0, t0, s5
    la t1, service_harts
    sd t0, 0(t1)
    la t0, service_state
    li t1, SERVICE_ON
    sw t1, 0(t0)
    la t0, service_record
    lwu t1, SVC_FLAGS(t0)
    ori t1, t1, SVC_STARTED
    sw t1, SVC_FLAGS(t0)            # started this frame
    call service_fill               # the new window's word and generation
    li a0, 0
    j 9f
6:
    addi a0, a0, SERVICE_START_REFUSED  # the start's code past the take's
7:
    mv s4, a0
    call gfx_give                   # the claim back, a raster worker on its hart again
    mv a0, s4
9:
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 48
    ret

service_reset:
    fence rw, w
    la t0, service_line_w
    sd zero, LINE_INDEX(t0)         # W
    sd zero, LINE_COUNT(t0)
    sd zero, LINE_LOSS(t0)
    fence rw, w
    la t0, service_line_r
    sd zero, LINE_INDEX(t0)         # R
    sd zero, LINE_COUNT(t0)
    sd zero, LINE_LOSS(t0)
    la t0, service_read
    sd zero, 0(t0)
    la t0, service_next
    sd zero, 0(t0)
    la t0, service_gaps
    sd zero, 0(t0)
    la t0, service_skipped
    sd zero, 0(t0)
    li t1, SERVICE_BASIS
    la t0, service_chain
    sd t1, 0(t0)
    li t1, SERVICE_NONE
    la t0, service_word
    sd t1, 0(t0)                    # no message applied in the window
    la t0, producer_corrupted
    sd t1, 0(t0)                    # no sequence corrupted
    sd zero, 8(t0)
    la t0, service_header
    ld t2, HEADER_GENERATION(t0)
    addi t2, t2, 1
    sd t2, HEADER_GENERATION(t0)    # the window's generation, the producer's from its start
    sd t1, HEADER_CORRUPT(t0)
    sd zero, HEADER_DELAY(t0)
.ifdef DEBUG
    ld t1, V_CORRUPT(a0)
    addi t1, t1, -1
    sd t1, HEADER_CORRUPT(t0)       # the corruption knob's sequence, all ones none
    lwu t1, V_DELAY(a0)
    li t2, US_TICKS
    mul t1, t1, t2
    sd t1, HEADER_DELAY(t0)         # the hold knob's ticks before each message
    lbu t1, V_FLAGS(a0)
    andi t1, t1, V_LOCKSTEP
    la t2, service_lockstep
    sb t1, 0(t2)
.endif
    lwu t1, V_TOTAL(a0)
    lwu t2, V_FRAMES(a0)
    la t0, service_schedule
    sd t1, SCHED_TOTAL(t0)
    sd t2, SCHED_FRAMES(t0)
    sd zero, SCHED_INDEX(t0)
    la t0, service_mailbox
    addi t1, t0, JAB_JOB_BYTES
1:
    sd zero, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 1b                 # a fresh mailbox: nothing published or done
    la t0, service_result
    addi t1, t0, RESULT_SIZE
2:
    sd zero, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 2b                 # no evidence, its ready word clear
    ret

service_stop:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    li a0, SERVICE_NOT_RUNNING
    la t0, service_state
    lwu t1, 0(t0)
    beqz t1, 9f
    la s2, service_mailbox
    jab.job.free s2, t2
    bnez t2, 1f
    lw t3, JAB_JOB_GEN(s2)
    jab.job.cancel s2, t3           # the quota in flight cancelled at its next message
1:
    la t0, service_harts
    ld t1, 0(t0)
    jab.sys.worker.stop t1          # answered in its await, else forced past WORK_STOP_TICKS
    mv s3, a1                       # those interrupted
    li s5, 0                        # discarded
    la t0, service_result
    ld t1, RESULT_READY(t0)
    bnez s3, 3f
    beqz t1, 3f
    li s4, END_VALID                # its evidence ready, nothing interrupted: a valid handoff
    li a0, MSG_SLOTS
    call service_apply              # the ring drained through the application path
    j 4f
3:
    li s4, END_FORCED               # forced: what the ring holds discarded, nothing applied
    la t0, service_line_w
    ld t1, LINE_INDEX(t0)           # W as the producer left it
    fence r, rw
    la t2, service_read
    ld t3, 0(t2)
    sub s5, t1, t3
    sd t1, 0(t2)
    fence rw, w
    la t0, service_line_r
    sd t1, LINE_INDEX(t0)           # R past them
4:
    mv a0, s4
    mv a1, s5
    call service_end
    la t0, service_state
    sw zero, 0(t0)
    la t0, service_record
    lwu t1, SVC_FLAGS(t0)
    ori t1, t1, SVC_STOPPED
    sw t1, SVC_FLAGS(t0)            # stopped this frame
    call service_fill               # the word after the drain, the window closed
    call gfx_give                   # the claim released: its hart a raster worker's again
    li a0, 0
    li t0, END_FORCED
    bne s4, t0, 9f
    li a0, SERVICE_FORCED
9:
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 48
    ret

service_end:
    la t0, service_end_records
    li t1, REPORT_SERVICE_END
    sw t1, REPORT_KIND(t0)
    la t1, service_frame_at
    ld t1, 0(t1)
    sw t1, REPORT_FRAME_NUMBER(t0)
    la t2, service_line_r
    ld t3, LINE_COUNT(t2)
    sw t3, END_APPLIED(t0)
    ld t3, LINE_LOSS(t2)
    sw t3, END_REJECTED(t0)
    sw a1, END_DISCARDED(t0)
    la t2, service_skipped
    ld t3, 0(t2)
    sw t3, END_SKIPPED(t0)
    andi t3, a0, END_VALID
    beqz t3, 1f
    la t2, service_result           # a valid handoff: the producer's evidence
    ld t3, RESULT_OFFERED(t2)
    sw t3, END_OFFERED(t0)
    ld t3, RESULT_DROPPED(t2)
    sw t3, END_DROPPED(t0)
    ld t3, RESULT_LAST(t2)
    sd t3, END_LAST(t0)
    ld t3, RESULT_PUBLISHED(t2)
    sd t3, END_PUBLISHED(t0)
    ld t3, RESULT_EXPECTED(t2)
    sd t3, END_EXPECTED(t0)
    ld t3, RESULT_CORRUPTED_COUNT(t2)
    slli t3, t3, END_CORRUPTED_SHIFT
    or a0, a0, t3
    ld t4, RESULT_CORRUPTED(t2)
    j 2f
1:
    la t2, service_line_w           # forced: the counts as the producer last left them
    ld t3, LINE_COUNT(t2)
    sw t3, END_OFFERED(t0)
    ld t3, LINE_LOSS(t2)
    sw t3, END_DROPPED(t0)
    li t3, SERVICE_NONE
    sd t3, END_LAST(t0)             # unknown
    sd zero, END_PUBLISHED(t0)
    sd zero, END_EXPECTED(t0)
    li t4, SERVICE_NONE
2:
    la t2, service_header
    ld t3, HEADER_GENERATION(t2)
    slli t5, t3, END_GENERATION_SHIFT
    or a0, a0, t5
    sw a0, END_FLAGS(t0)
    li t5, SERVICE_SCHEMA
    sw t5, REPORT_SCHEMA(t0)
    addi t0, t0, REPORT_SIZE        # the evidence record
    li t1, REPORT_SERVICE_EVIDENCE
    sw t1, REPORT_KIND(t0)
    la t1, service_frame_at
    ld t1, 0(t1)
    sw t1, REPORT_FRAME_NUMBER(t0)
    la t1, service_chain
    ld t1, 0(t1)
    sd t1, EVIDENCE_APPLIED(t0)
    sd t4, EVIDENCE_CORRUPTED(t0)
    la t1, service_next
    ld t5, 0(t1)
    sd t5, EVIDENCE_NEXT(t0)
    la t1, service_gaps
    ld t1, 0(t1)
    andi t6, a0, END_VALID
    beqz t6, 3f
    la t2, service_result
    ld t6, RESULT_LAST(t2)
    addi t6, t6, 1                  # the sequences offered
    sub t6, t6, t5
    add t1, t1, t6                  # the trailing gap, to the last offered
3:
    sd t1, EVIDENCE_GAPS(t0)
    sw t3, EVIDENCE_GENERATION(t0)
    li t5, SERVICE_SCHEMA
    sw t5, REPORT_SCHEMA(t0)
    la t0, service_end_records
    li t1, (REPORT_SIZE * 2)
    jab.sys.api.write t0, t1
    ret

service_producer:
    addi sp, sp, -16
    mv s0, a0                       # its mailbox
    mv s1, a1                       # its hart
    la t0, service_header
    ld s2, HEADER_GENERATION(t0)    # the window's generation
.ifdef DEBUG
    ld s6, HEADER_CORRUPT(t0)       # the corruption knob's sequence, all ones none
    ld s7, HEADER_DELAY(t0)         # the hold knob's ticks before each message, 0 none
.endif
    li s3, 0                        # the next sequence
    li s4, SERVICE_BASIS            # the published chain
    li s5, SERVICE_BASIS            # the expected chain
    li s10, 0                       # W, 0 at a start
1:
    jab.job.await s0, s8
    bnez a0, 9f                     # a stop
    ld s9, SERVICE_QUOTA(s0)        # the quota
    li s11, 0                       # offered of it
    li t0, JAB_JOB_OK
    sd t0, 0(sp)
2:
    beqz s9, 7f
    jab.job.cancelled s0, s8, t2
    bnez t2, 6f
.ifdef DEBUG
    beqz s7, 3f
    rdtime t0
    add t0, t0, s7
4:
    rdtime t1
    bltu t1, t0, 4b                 # the hold knob's spin before the message
3:
.endif
    call service_offer
    addi s9, s9, -1
    addi s11, s11, 1
    j 2b
6:
    li t0, JAB_JOB_CANCELLED
    sd t0, 0(sp)
7:
    sd s11, SERVICE_JOB_OFFERED(s0) # the quota's offered count, before the completion's fence
    ld t3, 0(sp)
    jab.job.complete s0, s8, t3
    li t0, 1
    jab.sys.worker.wake t0          # hart 0, should it join
    j 1b
9:
    la t0, service_result
    la t1, service_line_w
    ld t2, LINE_COUNT(t1)
    sd t2, RESULT_OFFERED(t0)
    ld t2, LINE_LOSS(t1)
    sd t2, RESULT_DROPPED(t0)
    addi t2, s3, -1
    sd t2, RESULT_LAST(t0)          # the last sequence offered, all ones for none
    sd s4, RESULT_PUBLISHED(t0)
    sd s5, RESULT_EXPECTED(t0)
    la t1, producer_corrupted
    ld t2, 0(t1)
    sd t2, RESULT_CORRUPTED(t0)
    ld t2, 8(t1)
    sd t2, RESULT_CORRUPTED_COUNT(t0)
    fence rw, w                     # the evidence before its ready word
    li t2, 1
    sd t2, RESULT_READY(t0)
    jab.sys.worker.exit

service_offer:
    la t0, service_line_r
    ld t1, LINE_INDEX(t0)           # R, hart 0's
    fence r, rw                     # its reads of the slots before any overwrite
    sub t2, s10, t1
    li t3, MSG_SLOTS
    bgeu t2, t3, 8f                 # full: dropped, never waited on
    andi t2, s10, (MSG_SLOTS - 1)
    slli t2, t2, MSG_SHIFT
    la t3, service_ring
    add t2, t2, t3                  # the slot
    sd s3, MSG_SEQUENCE(t2)
    sd s2, MSG_GENERATION(t2)
    rdtime t3
    sd t3, MSG_TIME(t2)
    li t4, 0
    li t5, SERVICE_GOLDEN
1:
    add t3, s3, t4
    mul t3, t3, t5
    slli t6, t4, 3
    add t6, t6, t2
    sd t3, MSG_PAYLOAD(t6)          # the payload, from the sequence
    addi t4, t4, 1
    li t3, MSG_PAYLOAD_WORDS
    bltu t4, t3, 1b
    mv t6, t2
    mv a0, t2
    mv t5, ra
    call message_sum
    mv ra, t5
    sd a0, MSG_CHECKSUM(t6)
    xor s4, s4, a0
    li t3, SERVICE_PRIME
    mul s4, s4, t3                  # the published chain, every message as built
.ifdef DEBUG
    bne s3, s6, 2f
    lbu t3, MSG_PAYLOAD(t6)
    xori t3, t3, 0xff
    sb t3, MSG_PAYLOAD(t6)          # the corruption knob: a payload byte changed after its checksum
    la t3, producer_corrupted
    sd s3, 0(t3)
    ld t4, 8(t3)
    addi t4, t4, 1
    sd t4, 8(t3)
    j 3f
2:
.endif
    xor s5, s5, a0
    li t3, SERVICE_PRIME
    mul s5, s5, t3                  # the expected chain, every message untouched
3:
    fence rw, w                     # the slot before the index that publishes it
    addi s10, s10, 1
    la t0, service_line_w
    sd s10, LINE_INDEX(t0)          # W
    ld t1, LINE_COUNT(t0)
    addi t1, t1, 1
    sd t1, LINE_COUNT(t0)           # offered
    addi s3, s3, 1
    ret
8:
    la t0, service_line_w
    ld t1, LINE_COUNT(t0)
    addi t1, t1, 1
    sd t1, LINE_COUNT(t0)           # offered
    ld t1, LINE_LOSS(t0)
    addi t1, t1, 1
    sd t1, LINE_LOSS(t0)            # dropped
    addi s3, s3, 1
    ret

.section .bss
.balign 64
service_line_w:
    .skip 64
service_line_r:
    .skip 64
service_mailbox:
    .skip JAB_JOB_BYTES
service_result:
    .skip RESULT_SIZE
service_header:
    .skip 64
service_ring:
    .skip (MSG_SLOTS * MSG_BYTES)
service_record:
    .skip REPORT_SIZE
service_end_records:
    .skip (REPORT_SIZE * 2)
reject_record:
    .skip REPORT_SIZE
.balign 8
service_word:
    .skip 8
service_read:
    .skip 8
service_next:
    .skip 8
service_gaps:
    .skip 8
service_chain:
    .skip 8
service_skipped:
    .skip 8
service_harts:
    .skip 8
service_frame_at:
    .skip 8
service_schedule:
    .skip SCHED_SIZE
producer_corrupted:
    .skip 16
service_state:
    .skip 4
.ifdef DEBUG
service_lockstep:
    .skip 1
.endif
.balign 16
service_stack:
    .skip WORKER_STACK
