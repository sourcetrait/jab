.include "riscv.inc"
.include "qemu_virt.inc"
.include "jab.inc"
.include "aia.inc"
.include "hart.inc"

.section .text

.global hart_idle
hart_idle:                                  # a secondary between its workers, on its record's stack
    li t0, SIE_SEIE
    csrw sie, t0
1:
    la t0, shutdown_owner
    ld t0, 0(t0)
    beqz t0, 2f
    j shutdown_park
2:
    ld t0, HART_WORK(tp)
    li t1, WORK_STARTING
    beq t0, t1, worker_enter
    wfi                                     # a start's wake after the check stays pending and ends it at once
    call irq_drain
    j 1b

worker_enter:
.ifdef DEBUG
    la a0, knob_noack
    call knob_value
    ld t0, HART_ID(tp)
    bne a0, t0, 2f
1:
    ld t0, HART_WORK(tp)                    # held until hart 0 takes the start back at its bound
    li t1, WORK_STARTING
    bne t0, t1, 2f
    pause
    j 1b
.pushsection .rodata
knob_noack:
    .asciz "jab.noack="
.popsection
2:
.endif
    addi t0, tp, HART_WORK
    li t1, WORK_STARTING
    li t2, WORK_RUNNING
3:
    lr.d.aqrl t3, (t0)
    bne t3, t1, 7f                          # taken back by hart 0 at its bound
    sc.d.rl t4, t2, (t0)
    bnez t4, 3b
    li a0, 0
    call hart_wake                          # the start taken
.irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    fmv.d.x f\n, zero
.endr
    csrw fcsr, zero
    vsetvli t0, zero, e8, m8, ta, ma
    vmv.v.i v0, 0
    vmv.v.i v8, 0
    vmv.v.i v16, 0
    vmv.v.i v24, 0
    csrw vcsr, zero
    li t0, (1 << 63)
    vsetvl zero, zero, t0                   # vtype's vill again and vl 0, as a reset leaves them
    ld t0, HART_ENTRY(tp)
    csrw sepc, t0
    li t0, (SSTATUS_SPP | SSTATUS_SPIE)
    csrc sstatus, t0
    li t0, (SSTATUS_FS_MASK | SSTATUS_VS_MASK)
    csrc sstatus, t0
    li t0, (SSTATUS_FS_INITIAL | SSTATUS_VS_INITIAL)
    csrs sstatus, t0
    ld a0, HART_ARG(tp)
    ld a1, HART_ID(tp)
    ld sp, HART_STACK_HIGH(tp)
    csrw sscratch, tp                       # its record while the worker runs
    li ra, 0                                # a return faults, naming the worker
    li gp, 0
    li tp, 0
    li t0, 0
    li t1, 0
    li t2, 0
    li s0, 0
    li s1, 0
    li a2, 0
    li a3, 0
    li a4, 0
    li a5, 0
    li a6, 0
    li a7, 0
    li s2, 0
    li s3, 0
    li s4, 0
    li s5, 0
    li s6, 0
    li s7, 0
    li s8, 0
    li s9, 0
    li s10, 0
    li s11, 0
    li t3, 0
    li t4, 0
    li t5, 0
    li t6, 0
    sret
7:
    la t0, shutdown_owner
    ld t0, 0(t0)
    beqz t0, 71f
    j shutdown_park
71:
    ld t0, HART_STATE(tp)                   # failed for the run by hart 0, which writes it next
    li t1, HART_FAILED
    beq t0, t1, 8f
    pause
    j 7b
8:
    csrw sie, zero                          # parked for the run, touching nothing
9:
    wfi
    j 9b

.global worker_leave
worker_leave:                               # out of the program for good, back to the idle
    ld t1, HART_ID(tp)
    li t0, HART_STACK_BYTES
    sub t0, tp, t0
    ld t0, 0(t0)
    li t2, HART_CANARY
    xor t2, t2, t1
    bne t0, t2, 9f                          # its kernel stack ran past its bottom
    sd zero, HART_CONTROL(tp)
    sd zero, HART_SLEEPING(tp)
    csrw sscratch, zero
    mv sp, tp                               # the frame let go: the idle runs from the stack's top
    li t0, 1
    sll t0, t0, t1
    not t0, t0
    la t2, workers_live
    amoand.d zero, t0, (t2)                 # its live bit gone before the hart reads idle, so a start's own stays
.ifdef DEBUG
    call leavehold_gap                      # jab.leavehold's hold, between the two publications
.endif
    fence rw, w                             # everything the worker did before the hart reads idle
    li t0, WORK_IDLE
    sd t0, HART_WORK(tp)
    li a0, 0
    call hart_wake                          # hart 0, in case it waits on this exit
    j hart_idle
9:
    la a0, msg_overrun
    mv a1, t1
    j fatal_dec

.global sys_worker_exit
sys_worker_exit:
    ld t0, HART_ID(tp)
    bnez t0, worker_leave
    j sys_denied                            # hart 0 runs the program: no worker of its own to end

.global hart_wake
hart_wake:                                  # a0 a hart: the wake to its file, after every earlier store
    addi sp, sp, -16
    sd ra, 8(sp)
    call aia_file_page
    beqz a0, 1f                             # no file: nothing there to wake
    li t0, AIA_WAKE
    fence w, o
    sw t0, 0(a0)
1:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.global sys_worker_wake
sys_worker_wake:                            # a0 the mask: each hart in it asleep in a wait woken
    mv s0, a0
    fence rw, rw                            # the caller's stores before the sleepers' states
    li s1, 0                                # the harts woken
    li s2, 0                                # the hart
1:
    li t0, JAB_HARTS_MAX
    bgeu s2, t0, 3f
    srl t0, s0, s2
    andi t0, t0, 1
    beqz t0, 2f
    mv a0, s2
    call hart_record
    ld t0, HART_SLEEPING(a0)
    beqz t0, 2f
    mv a0, s2
    call hart_wake
    li t0, 1
    sll t0, t0, s2
    or s1, s1, t0
2:
    addi s2, s2, 1
    j 1b
3:
    sd s1, 80(sp)
    j trap_return

.global sys_worker_wait
sys_worker_wait:                            # a0 a word's address, a1 the value it holds while the caller sleeps
    li t0, JAB_PROGRAM_BASE
    bltu a0, t0, 1f
    li t0, (JAB_STACK_TOP - 4)
    bgtu a0, t0, 1f
    andi t0, a0, 3
    beqz t0, 2f
1:
    j bad_address
2:
    mv s0, a0
    ld s1, 88(sp)
    sext.w s1, s1                           # the value's 32 bits, as lw reads the word
    li t0, 1
    sd t0, HART_SLEEPING(tp)
    li t0, SIE_SEIE
    csrs sie, t0
    fence rw, rw                            # asleep before the word is read, so a waker sees one or the other
3:
    call irq_drain                          # hart 0's devices served, a wake claimed
    ld t0, HART_ID(tp)
    bnez t0, 4f
    call irq_report
4:
    la t0, shutdown_owner
    ld t0, 0(t0)
    bnez t0, 7f                             # back to the boundary, which parks
    ld t0, HART_CONTROL(tp)
    andi t0, t0, WORK_STOP
    bnez t0, 6f
    lw t0, 0(s0)
    bne t0, s1, 5f
    wfi                                     # nothing claims between the check and here
    j 3b
5:
    li s2, JAB_WAIT_CHANGED
    j 8f
6:
    li s2, JAB_WAIT_STOP
    j 8f
7:
    li s2, 0
8:
    sd zero, HART_SLEEPING(tp)
    sd s2, 80(sp)
    ld t0, HART_ID(tp)
    bnez t0, 9f
    la t0, sound_live
    ld t0, 0(t0)
    bnez t0, 9f
    li t0, SIE_SEIE
    csrc sie, t0                            # hart 0's, as its other waits leave it
9:
    j trap_return

.global sys_worker_start
sys_worker_start:                           # a0 the hart, a1 the entry, a2 the argument, a3 the stack, a4 its size
    ld s0, 80(sp)
    ld s1, 88(sp)
    ld s2, 96(sp)
    ld s3, 104(sp)
    ld s4, 112(sp)
    li a0, JAB_START_HART
    beqz s0, 9f                             # hart 0 runs the program
    li t0, JAB_HARTS_MAX
    bgeu s0, t0, 9f
    la t0, harts_discovered
    ld t0, 0(t0)
    srl t0, t0, s0
    andi t0, t0, 1
    beqz t0, 9f
    mv a0, s0
    call hart_record
    mv s5, a0                               # its record
    li a0, JAB_START_HART
    ld t0, HART_STATE(s5)
    li t1, HART_ONLINE
    bne t0, t1, 9f
.ifdef DEBUG
    mv a0, s0
    mv a1, s5
    li a2, LEAVEHOLD_BY_START
    call leavehold_work                     # the read jab.leavehold's witness sees
    mv t0, a0
.else
    ld t0, HART_WORK(s5)
.endif
    li a0, JAB_START_BUSY
    bnez t0, 9f                             # a worker there already
    fence r, rw                             # its last worker's exit, released before its idle, before this start's stores
    li a0, JAB_START_ENTRY
    li t0, JAB_PROGRAM_BASE
    bltu s1, t0, 9f
    li t0, JAB_STACK_TOP
    bgeu s1, t0, 9f
    andi t0, s1, 1
    bnez t0, 9f
    li a0, JAB_START_STACK
    beqz s4, 9f
    or t0, s3, s4
    andi t0, t0, 15
    bnez t0, 9f                             # the stack and its size on 16 bytes, so its top is too
    li t0, JAB_PROGRAM_BASE
    bltu s3, t0, 9f
    add s6, s3, s4                          # its top
    bltu s6, s3, 9f                         # a size that wraps
    li t0, JAB_STACK_TOP
    bgtu s6, t0, 9f
    li a0, JAB_START_OVERLAP
    li t0, (JAB_STACK_TOP - JAB_MAIN_STACK)
    bgtu s6, t0, 9f                         # into the main stack's reservation
    li s7, 1                                # the hart
1:
    li t0, JAB_HARTS_MAX
    bgeu s7, t0, 2f
    mv a0, s7
    call hart_record
    ld t0, HART_WORK(a0)
    beqz t0, 11f                            # no worker there
    ld t0, HART_STACK_LOW(a0)
    ld t1, HART_STACK_HIGH(a0)
    bgeu s3, t1, 11f
    bgeu t0, s6, 11f
    li a0, JAB_START_OVERLAP                # a running worker's stack
    j 9f
11:
    addi s7, s7, 1
    j 1b
2:
    sd s1, HART_ENTRY(s5)
    sd s2, HART_ARG(s5)
    sd s3, HART_STACK_LOW(s5)
    sd s6, HART_STACK_HIGH(s5)
    sd zero, HART_CONTROL(s5)
    fence w, w                              # its fields before the state that sends it there
    li t0, WORK_STARTING
    sd t0, HART_WORK(s5)
    li t0, 1
    sll s7, t0, s0                          # its bit
    la t0, workers_live
    amoor.d zero, s7, (t0)
    mv a0, s0
    call hart_wake
    rdtime s8
    li t0, WORK_START_TICKS
    add s8, s8, t0                          # the acknowledgement's bound
3:
    ld t0, HART_WORK(s5)
    li t1, WORK_STARTING
    bne t0, t1, 5f                          # taken
    la t0, shutdown_owner
    ld t0, 0(t0)
    bnez t0, 5f                             # back to the boundary, which parks
    rdtime t0
    bgeu t0, s8, 4f
    csrw stimecmp, s8
    li t0, (SIE_STIE | SIE_SEIE)
    csrs sie, t0
    wfi
    call irq_drain
    call irq_report
    j 3b
4:
    addi t0, s5, HART_WORK                  # past the bound: the start taken back, unless taken at the last
    li t1, WORK_STARTING
41:
    lr.d.aqrl t2, (t0)
    bne t2, t1, 5f                          # taken at the last
    sc.d.rl t3, zero, (t0)
    bnez t3, 41b
    not t0, s7
    la t1, workers_live
    amoand.d zero, t0, (t1)
    mv a0, s5
    li a1, HART_ONLINE
    li a2, HART_FAILED
    call hart_swap
    li t0, HART_WHY_NO_START
    sd t0, HART_WHY(s5)
    li s9, JAB_START_NO_ACK
    j 6f
5:
    li s9, JAB_START_OK
6:
    li t0, SIE_STIE
    csrc sie, t0
    li t0, -1
    csrw stimecmp, t0
    la t0, sound_live
    ld t0, 0(t0)
    bnez t0, 7f
    li t0, SIE_SEIE
    csrc sie, t0
7:
    mv a0, s9
9:
    sd a0, 80(sp)
    j trap_return

stop_pending:                               # a0 the harts asked to stop: those still in their workers
    addi sp, sp, -16
    sd ra, 8(sp)
    mv a3, a0
    li a4, 0                                # those still in
    li t3, 0                                # the hart
    la t4, hart_areas
    li t5, HART_STACK_BYTES
    add t4, t4, t5                          # its record
1:
    li t5, JAB_HARTS_MAX
    bgeu t3, t5, 3f
    srl t5, a3, t3
    andi t5, t5, 1
    beqz t5, 2f
.ifdef DEBUG
    mv a0, t3
    mv a1, t4
    li a2, LEAVEHOLD_BY_STOP
    call leavehold_work                     # the read jab.leavehold's witness sees
    mv t5, a0
.else
    ld t5, HART_WORK(t4)
.endif
    beqz t5, 2f                             # idle: out for good
    li t6, 1
    sll t6, t6, t3
    or a4, a4, t6
2:
    addi t3, t3, 1
    li t5, HART_AREA_BYTES
    add t4, t4, t5
    j 1b
3:
    fence r, rw                             # what each stopped worker did, seen after its idle
    mv a0, a4
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.global sys_worker_stop
sys_worker_stop:                            # a0 the mask: a0 its harts free of a worker, a1 those interrupted
    mv s4, a0
    call harts_masks                        # a0 the online harts
    and s0, s4, a0
    andi s0, s0, -2                         # every online secondary in the mask, hart 0 running the program
    li s1, 0                                # those interrupted
    li s2, 0                                # the hart
1:
    li t0, JAB_HARTS_MAX
    bgeu s2, t0, 2f
    srl t0, s0, s2
    andi t0, t0, 1
    beqz t0, 11f
    mv a0, s2
    call hart_record
    mv s3, a0
.ifdef DEBUG
    mv a1, s3
    mv a0, s2
    li a2, LEAVEHOLD_BY_STOP
    call leavehold_work                     # the read jab.leavehold's witness sees
.else
    ld a0, HART_WORK(s3)
.endif
    beqz a0, 11f                            # idle: nothing to stop
    addi t0, s3, HART_CONTROL
    li t1, WORK_STOP
    amoor.d zero, t1, (t0)
    mv a0, s2
    call hart_wake                          # a wait sees it at once, a running worker at its next trap
11:
    addi s2, s2, 1
    j 1b
2:
    rdtime s3
    li t0, WORK_STOP_TICKS
    add s3, s3, t0                          # the stop's bound
3:
    mv a0, s0
    call stop_pending
    beqz a0, 7f                             # every one out
    la t0, shutdown_owner
    ld t0, 0(t0)
    bnez t0, 7f                             # back to the boundary, which parks
    rdtime t0
    bgeu t0, s3, 4f
    csrw stimecmp, s3
    li t0, (SIE_STIE | SIE_SEIE)
    csrs sie, t0
    wfi
    call irq_drain
    call irq_report
    j 3b
4:
    bnez s1, 6f                             # interrupted already and still in: past the second bound
    mv s1, a0                               # still running: interrupted where each is
    li s2, 0
41:
    li t0, JAB_HARTS_MAX
    bgeu s2, t0, 43f
    srl t0, s1, s2
    andi t0, t0, 1
    beqz t0, 42f
    mv a0, s2
    call hart_record
    addi t0, a0, HART_CONTROL
    li t1, WORK_FORCED
    amoor.d zero, t1, (t0)
    mv a0, s2
    call hart_wake
42:
    addi s2, s2, 1
    j 41b
43:
    rdtime s3
    li t0, WORK_FORCE_TICKS
    add s3, s3, t0                          # the interrupted ones' bound
    j 3b
6:
    ctz a1, a0                              # the first still writing what it owned: the run ends
    la a0, msg_stop_refused
    j fatal_dec
7:
    li t0, SIE_STIE
    csrc sie, t0
    li t0, -1
    csrw stimecmp, t0
    la t0, sound_live
    ld t0, 0(t0)
    bnez t0, 8f
    li t0, SIE_SEIE
    csrc sie, t0
8:
    call harts_masks
    and a0, a0, s4
    andi a0, a0, -2                         # every online secondary in the mask, each free now
    sd a0, 80(sp)
    sd s1, 88(sp)
    j trap_return

.global shutdown_enter
shutdown_enter:                             # the run's end claimed by this hart, every other halted; behind another's claim it parks
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    sd s4, 0(sp)
    ld s0, HART_ID(tp)
    addi t0, s0, 1                          # the word holds its owner's id plus one
    la t1, shutdown_owner
1:
    lr.d.aqrl t2, (t1)
    bnez t2, 2f
    sc.d.rl t3, t0, (t1)
    bnez t3, 1b
    j 3f
2:
    beq t2, t0, 9f                          # its own already
    j shutdown_park                         # another's: this hart stops here, its fault recorded
3:
.ifdef DEBUG
    la a0, knob_claimhold
    call knob_value
    blez a0, 30f
    li t0, (QEMU_VIRT_TIMEBASE / 1000)
    mul t0, t0, a0
    rdtime t1
    add t1, t1, t0
301:
    rdtime t0
    bltu t0, t1, 301b                       # the claim held that many ms before the others are woken
.pushsection .rodata
knob_claimhold:
    .asciz "jab.claimhold="
.popsection
30:
.endif
    li s1, 0                                # the hart
31:
    li t0, JAB_HARTS_MAX
    bgeu s1, t0, 4f
    beq s1, s0, 32f
    mv a0, s1
    call hart_record
    ld t0, HART_STATE(a0)
    li t1, HART_ONLINE
    bne t0, t1, 32f
    mv a0, s1
    call hart_wake
32:
    addi s1, s1, 1
    j 31b
4:
    rdtime s2
    li t0, SHUTDOWN_TICKS
    add s2, s2, t0                          # the halt's bound
    li s4, 0                                # those that did not halt in it
    li s1, 0
41:
    li t0, JAB_HARTS_MAX
    bgeu s1, t0, 8f
    beq s1, s0, 44f
    mv a0, s1
    call hart_record
    mv s3, a0
    ld t0, HART_STATE(s3)
    li t1, HART_ONLINE
    bne t0, t1, 44f
42:
    ld t0, HART_WORK(s3)
    li t1, WORK_HALTED
    beq t0, t1, 44f
    rdtime t0
    bgeu t0, s2, 43f
    pause
    j 42b
43:
    li t0, 1                                # past the bound: named after the faults, the run ending anyway
    sll t0, t0, s1
    or s4, s4, t0
44:
    addi s1, s1, 1
    j 41b
8:
    la t0, shutdown_unanswered
    sd s4, 0(t0)
    fence r, rw                             # what each halted hart recorded, seen after its halt
9:
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    ld s4, 0(sp)
    addi sp, sp, 48
    ret

.global shutdown_park
shutdown_park:                              # stopped for another hart's shutdown, the halt its answer
    csrw sie, zero
    fence rw, w                             # its fault, recorded, before its halt
    li t0, WORK_HALTED
    sd t0, HART_WORK(tp)
1:
    wfi
    j 1b

.ifdef DEBUG
leavehold_gap:                              # jab.leavehold=<hart>: that hart's first exit held here, its worker's argument the witness word
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, leavehold_spent
    ld t1, 0(t0)
    bnez t1, 9f                             # one-shot, and spent
    la a0, knob_leavehold
    call knob_value
    ld t0, HART_ID(tp)
    bne a0, t0, 9f                          # another hart's, or no knob
    la t0, leavehold_spent
    li t1, 1
    sd t1, 0(t0)
    ld a0, HART_ARG(tp)                     # the word, checked before anything is written there
    li t0, JAB_PROGRAM_BASE
    bltu a0, t0, 9f
    li t0, (JAB_STACK_TOP - 4)
    bgtu a0, t0, 9f
    andi t0, a0, 3
    bnez t0, 9f                             # no word of the program's: inert for this exit
    la t0, leavehold_word
    sd a0, 0(t0)
    fence w, w                              # the address before the enable that vouches for it
    ld t1, HART_ID(tp)
    addi t1, t1, 1
    la t0, leavehold_hart
    sd t1, 0(t0)
    fence rw, w                             # the hold's publication before its word reads held
    li t1, LEAVEHOLD_HELD
    sw t1, 0(a0)
    rdtime t2
    li t0, LEAVEHOLD_TICKS
    add t2, t2, t0                          # the hold's bound
1:
    lw t0, 0(a0)
    bne t0, t1, 3f                          # an observation released it
    rdtime t0
    bgeu t0, t2, 2f
    pause
    j 1b
2:
    li t3, LEAVEHOLD_EXPIRED
21:
    lr.w t0, (a0)
    bne t0, t1, 3f                          # observed at the last: the observation stands
    sc.w t0, t3, (a0)
    bnez t0, 21b
3:
    fence r, rw                             # the observer's code, and what it read first, before going on
    la t0, leavehold_hart
    sd zero, 0(t0)
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret
.pushsection .rodata
knob_leavehold:
    .asciz "jab.leavehold="
.popsection

leavehold_work:                             # a0 a hart, a1 its record, a2 the observer: a0 its HART_WORK, witnessed while jab.leavehold holds it
    la t0, leavehold_hart
    ld t0, 0(t0)
    addi t1, a0, 1
    bne t0, t1, 8f                          # not the hart held
    fence r, r                              # the enable before the address it vouches for
    la t0, leavehold_word
    ld t2, 0(t0)
    lw t0, 0(t2)
    li t1, LEAVEHOLD_HELD
    bne t0, t1, 8f                          # not held yet, or observed already
    fence r, rw                             # the hold's publication before the read
    ld a0, HART_WORK(a1)                    # the read the caller decides by
    snez t0, a0
    xori t0, t0, 1
    addi t0, t0, LEAVEHOLD_SAW_WORKING      # working, or idle one past it
    add a2, a2, t0                          # the observation: who looked and what it saw
1:
    lr.w t0, (t2)
    bne t0, t1, 9f                          # an expiry's 3 stands
    sc.w.rl t0, a2, (t2)                    # the read before the release
    bnez t0, 1b
    ret
8:
    ld a0, HART_WORK(a1)
9:
    ret
.endif

.section .rodata
msg_stop_refused:
    .asciz "jab: worker stop refused: hart "
msg_overrun:
    .asciz "jab: kernel stack overrun: hart "

.section .bss
.balign 8
.global workers_live
workers_live:
    .skip 8
.global shutdown_owner
shutdown_owner:
    .skip 8
.global shutdown_unanswered
shutdown_unanswered:
    .skip 8
.ifdef DEBUG
leavehold_hart:
    .skip 8
leavehold_word:
    .skip 8
leavehold_spent:
    .skip 8
.endif
