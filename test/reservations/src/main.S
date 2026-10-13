.include "jab.inc"

.set STACK_BYTES, 16384
.set JOB_WORD, 0
.set JOB_DONE, 4
.set JOB_RESERVE, 8
.set JOB_CLAIM, 16
.set JOB_RELEASE, 24
.set JOB_OWNED, 32
.set JOB_BYTES, 64
.set A3_SENTINEL, 0x3a3a
.set A5_SENTINEL, 0x5555
.set SHORT_COUNT, 9

.section .text
.global _start
_start:
    jab.sys.harts
    andi s0, a1, -2                         # the online secondaries
    ctz s1, s0                              # the lowest
    clz t0, s0
    li s2, 63
    sub s2, s2, t0                          # the highest
    li t0, 1
    sll s9, t0, s2                          # the highest's bit
    la s11, line
    la a1, word_harts
    mv a0, s0
    call field
    la a1, word_space
    mv a0, s1
    call field
    la a1, word_space
    mv a0, s2
    call field
    call say

legacy:                                     # before a reservation: a3 kept, every secondary unowned, a start whatever a5 holds
    li a3, A3_SENTINEL
    jab.sys.harts
    mv s4, a3
    li t0, JAB_OWNER_NONE
    jab.sys.harts.owned t0
    mv s5, a0
    mv a0, s1
    la a1, exit_worker
    li a2, 0
    li a3, A5_SENTINEL
    call start_on
    mv s6, a0
    li t0, 1
    sll a0, t0, s1
    call stop_mask
    mv a0, s1
    call stack_of
    mv t1, a0
    li a5, STACK_BYTES                      # the size in a5, which the five-operand form reads and leaves
    jab.sys.worker.start s1, exit_worker, zero, t1, a5
    mv s7, a0
    li t0, 1
    sll a0, t0, s1
    call stop_mask
    la s11, line
    la a1, word_legacy
    mv a0, s4
    call field
    la a1, word_owned
    mv a0, s5
    call field
    la a1, word_start
    mv a0, s6
    call field
    la a1, word_size
    mv a0, s7
    call field
    call say

refused:                                    # a reservation past the secondaries, then one beside a running worker
    jab.sys.harts.reserve SHORT_COUNT
    mv s4, a0
    mv s5, a1
    mv a0, s1
    la a1, sleep_worker
    la a2, job
    li a3, JAB_OWNER_NONE
    call start_on
    mv s6, a0
    li a0, 1
    li a7, JAB_SYS_HARTS_RESERVE
    ecall
    mv s7, a0
    li t0, 1
    sll a0, t0, s1
    call stop_mask
    jab.sys.harts.claim s9
    mv s8, a0
    la s11, line
    la a1, word_refused
    mv a0, s4
    call field
    la a1, word_space
    mv a0, s5
    call field
    la a1, word_start
    mv a0, s6
    call field
    la a1, word_busy
    mv a0, s7
    call field
    la a1, word_unreserved
    mv a0, s8
    call field
    call say

reserve:                                    # the floor one short of the secondaries, so one hart is surplus
    cpop s3, s0
    addi s3, s3, -1
    mv a0, s3
    li a7, JAB_SYS_HARTS_RESERVE
    ecall
    mv s4, a0
    mv s5, a1
    li t0, JAB_OWNER_RESERVED
    jab.sys.harts.owned t0
    mv s6, a0
    li t0, JAB_OWNER_NONE
    jab.sys.harts.owned t0
    mv s7, a0
    mv a0, s3
    li a7, JAB_SYS_HARTS_RESERVE
    ecall
    mv s8, a0
    la s11, line
    la a1, word_reserve
    mv a0, s3
    call field
    la a1, word_space
    mv a0, s4
    call field
    la a1, word_space
    mv a0, s5
    call field
    la a1, word_owned
    mv a0, s6
    call field
    la a1, word_space
    mv a0, s7
    call field
    la a1, word_again
    mv a0, s8
    call field
    call say

owner:                                      # every start names its owner now: a5's sentinel raw and through the five-operand form, then the reservation
    mv a0, s1
    la a1, exit_worker
    li a2, 0
    li a3, A5_SENTINEL
    call start_on
    mv s4, a0
    mv a0, s1
    call stack_of
    mv t1, a0
    li t2, STACK_BYTES
    li a5, A5_SENTINEL                      # the five-operand form leaves a5 as the caller had it, and the kernel reads it
    jab.sys.worker.start s1, exit_worker, zero, t1, t2
    mv s5, a0
    li t0, JAB_OWNER_RESERVED
    jab.sys.worker.start s1, exit_worker, zero, t1, t2, t0
    mv s6, a0
    li t0, 1
    sll a0, t0, s1
    call stop_mask
    la s11, line
    la a1, word_owner
    mv a0, s4
    call field
    la a1, word_five
    mv a0, s5
    call field
    la a1, word_reserved
    mv a0, s6
    call field
    call say

claim_refused:                              # an empty mask, hart 0, a hart past the machine, a busy hart, the whole grant
    li t0, 0
    jab.sys.harts.claim t0
    mv s4, a0
    li t0, 1
    jab.sys.harts.claim t0
    mv s5, a0
    slli t0, s9, 1                          # the bit past the highest's, a hart the machine lacks
    jab.sys.harts.claim t0
    mv s6, a0
    mv a0, s2
    la a1, sleep_worker
    la a2, job
    li a3, JAB_OWNER_RESERVED
    call start_on
    mv s10, a0
    jab.sys.harts.claim s9
    mv s7, a0
    mv a0, s9
    call stop_mask
    jab.sys.harts.claim s0
    mv s8, a0
    la s11, line
    la a1, word_claim_refused
    mv a0, s4
    call field
    la a1, word_main
    mv a0, s5
    call field
    la a1, word_past
    mv a0, s6
    call field
    la a1, word_busy
    mv a0, s7
    call field
    la a1, word_floor
    mv a0, s8
    call field
    la a1, word_start
    mv a0, s10
    call field
    call say

claim:                                      # the surplus, the highest secondary, claimed; then it again, and the lowest past the floor
    jab.sys.harts.claim s9
    mv s4, a0
    mv s3, a1                               # the claim's id
    jab.sys.harts.owned s3
    mv s5, a0
    li t0, JAB_OWNER_RESERVED
    jab.sys.harts.owned t0
    mv s6, a0
    jab.sys.harts.claim s9
    mv s7, a0
    li t0, 1
    sll t0, t0, s1
    jab.sys.harts.claim t0
    mv s8, a0
    la s11, line
    la a1, word_claim
    mv a0, s4
    call field
    la a1, word_id
    mv a0, s3
    call field
    la a1, word_owned
    mv a0, s5
    call field
    la a1, word_space
    mv a0, s6
    call field
    la a1, word_again
    mv a0, s7
    call field
    la a1, word_second
    mv a0, s8
    call field
    call say

cross:                                      # each owner's start on the other's hart refused, then a worker of each at once
    mv a0, s2
    la a1, exit_worker
    li a2, 0
    li a3, JAB_OWNER_RESERVED
    call start_on
    mv s4, a0
    mv a0, s1
    la a1, exit_worker
    li a2, 0
    mv a3, s3
    call start_on
    mv s5, a0
    mv a0, s2
    call stack_of
    mv t1, a0
    li t2, STACK_BYTES
    la t3, job
    mv a1, s3                               # the claim's id below the owner's register, which the sixth operand loads first
    jab.sys.worker.start s2, sleep_worker, t3, t1, t2, a1
    mv s6, a0
    mv a0, s1
    la a1, sleep_worker
    la a2, job
    li a3, JAB_OWNER_RESERVED
    call start_on
    mv s7, a0
    mv a0, s2
    la a1, exit_worker
    li a2, 0
    li a3, JAB_OWNER_RESERVED
    call start_on
    mv s10, a0                              # busy and another's: the owner is checked first
    jab.sys.harts.release s3
    mv s8, a0
    li t0, 1
    sll t0, t0, s1
    or a0, t0, s9
    call stop_mask
    la s11, line
    la a1, word_cross
    mv a0, s4
    call field
    la a1, word_space
    mv a0, s5
    call field
    la a1, word_both
    mv a0, s6
    call field
    la a1, word_space
    mv a0, s7
    call field
    la a1, word_order
    mv a0, s10
    call field
    la a1, word_release_busy
    mv a0, s8
    call field
    call say

returned:                                   # the claim released, the grant whole again, and its id refused after
    jab.sys.harts.release s3
    mv s4, a0
    mv s5, a1
    li t0, JAB_OWNER_RESERVED
    jab.sys.harts.owned t0
    mv s6, a0
    jab.sys.harts.release s3
    mv s7, a0
    mv a0, s2
    la a1, exit_worker
    li a2, 0
    mv a3, s3
    call start_on
    mv s8, a0
    la s11, line
    la a1, word_returned
    mv a0, s4
    call field
    la a1, word_space
    mv a0, s5
    call field
    la a1, word_owned
    mv a0, s6
    call field
    la a1, word_stale
    mv a0, s7
    call field
    la a1, word_space
    mv a0, s8
    call field
    call say

reclaim:                                    # the same mask claimed again under a fresh id, the old one refused, then once more
    jab.sys.harts.claim s9
    mv s4, a0
    mv s10, a1                              # the new claim's id
    mv a0, s2
    la a1, exit_worker
    li a2, 0
    mv a3, s3
    call start_on
    mv s5, a0
    jab.sys.harts.release s3
    mv s6, a0
    li t0, JAB_OWNER_RESERVED
    jab.sys.harts.owned t0
    mv s7, a0
    jab.sys.harts.claim s9
    mv s8, a0
    la s11, line
    la a1, word_reclaim
    mv a0, s4
    call field
    la a1, word_id
    mv a0, s10
    call field
    la a1, word_stale
    mv a0, s5
    call field
    la a1, word_space
    mv a0, s6
    call field
    la a1, word_owned
    mv a0, s7
    call field
    la a1, word_again
    mv a0, s8
    call field
    call say

released:                                   # the new claim released; no owner and the reservation are no claim's
    jab.sys.harts.release s10
    mv s4, a0
    li t0, JAB_OWNER_NONE
    jab.sys.harts.release t0
    mv s5, a0
    li t0, JAB_OWNER_RESERVED
    jab.sys.harts.release t0
    mv s6, a0
    la s11, line
    la a1, word_released
    mv a0, s4
    call field
    la a1, word_none
    mv a0, s5
    call field
    la a1, word_reserved
    mv a0, s6
    call field
    call say

denied:                                     # a worker's four ownership calls, each hart 0's alone
    la s4, job_denied
    sw zero, JOB_DONE(s4)
    mv a0, s1
    la a1, denied_worker
    mv a2, s4
    li a3, JAB_OWNER_RESERVED
    call start_on
    mv s5, a0
    mv a0, s4
    call join
    li t0, 1
    sll a0, t0, s1
    call stop_mask
    la s11, line
    la a1, word_denied
    mv a0, s5
    call field
    la a1, word_answers
    ld a0, JOB_RESERVE(s4)
    call field
    la a1, word_space
    ld a0, JOB_CLAIM(s4)
    call field
    la a1, word_space
    ld a0, JOB_RELEASE(s4)
    call field
    la a1, word_space
    ld a0, JOB_OWNED(s4)
    call field
    call say
    jab.sys.exit 0

start_on:                                   # a0 the hart, a1 the entry, a2 the argument, a3 the owner in a5: the start's answer
    addi t0, a0, -1
    li t1, STACK_BYTES
    mul t0, t0, t1
    la t1, stacks
    add t0, t0, t1                          # the hart's own stack
    mv a5, a3
    mv a3, t0
    li a4, STACK_BYTES
    li a7, JAB_SYS_WORKER_START
    ecall
    ret

stack_of:                                   # a0 a hart: a0 its own stack, STACK_BYTES of it
    addi a0, a0, -1
    li t0, STACK_BYTES
    mul a0, a0, t0
    la t0, stacks
    add a0, a0, t0
    ret

stop_mask:                                  # a0 the harts: back once each is free of its worker
    jab.sys.worker.stop a0
    ret

join:                                       # a0 a job: back once its worker has marked it done
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s0, 0(sp)
    mv s0, a0
1:
    lw t0, JOB_DONE(s0)
    bnez t0, 2f
    addi a0, s0, JOB_DONE
    jab.sys.worker.wait a0, zero
    j 1b
2:
    fence r, rw                             # the worker's answers after its mark
    ld ra, 8(sp)
    ld s0, 0(sp)
    addi sp, sp, 16
    ret

exit_worker:                                # out at once
    jab.sys.worker.exit

sleep_worker:                               # asleep on its job's word, which stays 0, until a stop
    mv s0, a0
1:
    jab.sys.worker.wait s0, zero
    beqz a0, 1b
    jab.sys.worker.exit

denied_worker:                              # the four ownership calls from a worker, each answer kept, then hart 0 woken
    mv s0, a0
    li a0, 1
    li a7, JAB_SYS_HARTS_RESERVE
    ecall
    sd a0, JOB_RESERVE(s0)
    li a0, 2
    li a7, JAB_SYS_HARTS_CLAIM
    ecall
    sd a0, JOB_CLAIM(s0)
    li a0, 2
    li a7, JAB_SYS_HARTS_RELEASE
    ecall
    sd a0, JOB_RELEASE(s0)
    li a0, 1
    li a7, JAB_SYS_HARTS_OWNED
    ecall
    sd a0, JOB_OWNED(s0)
    fence rw, w
    li t0, 1
    sw t0, JOB_DONE(s0)
    li t0, 1
    jab.sys.worker.wake t0
    jab.sys.worker.exit

field:                                      # a1 a label, a0 a value after it, signed
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
    call put_str
    ld a0, 0(sp)
    call put_signed
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

say:                                        # the line at s11 ended and printed
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

.section .rodata
word_harts:
    .asciz "harts "
word_space:
    .asciz " "
word_legacy:
    .asciz "legacy a3 "
word_owned:
    .asciz " owned "
word_start:
    .asciz " start "
word_size:
    .asciz " size "
word_unreserved:
    .asciz " unreserved "
word_refused:
    .asciz "refused short "
word_busy:
    .asciz " busy "
word_reserve:
    .asciz "reserve "
word_again:
    .asciz " again "
word_owner:
    .asciz "owner sentinel "
word_five:
    .asciz " five "
word_none:
    .asciz " none "
word_reserved:
    .asciz " reserved "
word_claim_refused:
    .asciz "claim refused empty "
word_main:
    .asciz " main "
word_past:
    .asciz " past "
word_floor:
    .asciz " floor "
word_claim:
    .asciz "claim "
word_id:
    .asciz " id "
word_second:
    .asciz " second "
word_cross:
    .asciz "cross "
word_both:
    .asciz " both "
word_order:
    .asciz " order "
word_release_busy:
    .asciz " release busy "
word_returned:
    .asciz "returned "
word_stale:
    .asciz " stale "
word_reclaim:
    .asciz "reclaim "
word_released:
    .asciz "released "
word_denied:
    .asciz "denied start "
word_answers:
    .asciz " answers "

.section .bss
.balign 64
job:
    .skip JOB_BYTES
job_denied:
    .skip JOB_BYTES
.balign 16
stacks:
    .skip ((JAB_HARTS_MAX - 1) * STACK_BYTES)
line:
    .skip 160
digits:
    .skip 32
