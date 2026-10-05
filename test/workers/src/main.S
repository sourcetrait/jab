.include "jab.inc"

.set STACK_BYTES, 16384
.set JOB_N, 0
.set JOB_RESULT, 8
.set JOB_DONE, 16
.set JOB_GATE, 20
.set JOB_SPINNING, 24
.set JOB_ENTRY, 32
.set JOB_KEPT, 40
.set JOB_VL, 48
.set JOB_COUNT, 56
.set JOB_ANSWERS, 64
.set JOB_BYTES, 128
.set DENIED_CALLS, 7
.set SUM_ONE, 1000000
.set SUM_TWO, 2000000
.set CHANNEL, 0
.set PROGRAM, 80
.set NOTE, 69
.set VELOCITY, 127
.set HOLD, JAB_TIME_HZ
.set TAIL, (JAB_TIME_HZ / 2)
.set SETTLE_TICKS, 2
.set SPIN_CHUNK, (JAB_TIME_HZ / 50)
.set PESTER_WAKES, 20000
.set TICKS, 6
.set PATTERN_F, 0x3ff0000000000000
.set PATTERN_V, 0x5a5a000000000000
.set FFLAGS_SET, 5
.set VTYPE_E64_M1, 0xd8
.set VTYPE_ILL, (1 << 63)
.set REFUSAL_BYTES, 40
.set KERNEL, 0x80000000
.set JOB_STOPPED, 28
.set SELECT_WAIT, (2 * JAB_TIME_HZ)
.set HELD_WAIT, (JAB_TIME_HZ / 2)
.set RETRY_WAIT, (JAB_TIME_HZ / 5)
.set HOLD_WAIT, (3 * JAB_TIME_HZ / 10)
.set W_HELD, 1
.set W_EXPIRED, 3
.set W_SAW_WORKING, 0x10
.set W_SAW_IDLE, 0x11
.set W_STOP_SAW_WORKING, 0x30
.set W_STOP_SAW_IDLE, 0x31

.section .text
.global _start
_start:
    la s1, selector
    jab.sys.api.write s1, zero              # 1 with no API port: the fixtures in turn
    beqz a0, select
    jab.sys.sound.open
    beqz a0, join_with_sound
    la a1, word_no_sound
    call say_str
    jab.sys.exit 2

select:                                     # the port on the line: one of jab.leavehold's scenarios, by its letter
    rdtime s7
    li t0, SELECT_WAIT
    add s7, s7, t0                          # the selector's deadline
1:
    jab.sys.api.read s1, 1
    bnez a0, 2f                             # it came
    rdtime t0
    bgeu t0, s7, 3f
    jab.sys.await JAB_AWAIT_DISPLAY | JAB_AWAIT_API
    j 1b
2:
    lbu t0, 0(s1)
    li t1, 'r'
    beq t0, t1, restart
    li t1, 's'
    beq t0, t1, stop_exit
3:
    la a1, word_no_scenario
    call say_str
    jab.sys.exit 2

join_with_sound:
    li t0, CHANNEL
    li t1, PROGRAM
    jab.sys.midi.program t0, t1
    li t0, CHANNEL
    li t1, NOTE
    li t2, VELOCITY
    jab.sys.midi.note.on t0, t1, t2
    la s1, job_a
    li t0, HOLD
    sd t0, JOB_N(s1)
    li s0, 1
    la s2, stacks
    li s3, STACK_BYTES
    jab.sys.worker.start s0, hold_worker, s1, s2, s3
    mv s4, a0
    mv a0, s1
    call join
    li t0, CHANNEL
    li t1, NOTE
    jab.sys.midi.note.off t0, t1
    li t0, 2
    jab.sys.worker.stop t0
    mv s5, a0
    mv s6, a1
    la s11, line
    la a1, word_sound_join
    mv a0, s4
    call field
    la a1, word_done
    lw a0, JOB_DONE(s1)
    call field
    la a1, word_stop
    mv a0, s5
    call field
    la a1, word_space
    mv a0, s6
    call field
    call say
    li a0, TAIL
    call spin

sums:
    la s1, job_a
    la s2, job_b
    li t0, SUM_ONE
    sd t0, JOB_N(s1)
    sw zero, JOB_DONE(s1)
    li t0, SUM_TWO
    sd t0, JOB_N(s2)
    sw zero, JOB_DONE(s2)
    li s0, 1
    la s3, stacks
    li s4, STACK_BYTES
    jab.sys.worker.start s0, sum_worker, s1, s3, s4
    mv s5, a0
    li s0, 2
    add s3, s3, s4
    jab.sys.worker.start s0, sum_worker, s2, s3, s4
    mv s6, a0
    mv a0, s1
    call join
    mv a0, s2
    call join
    li t0, 6
    jab.sys.worker.stop t0
    mv s7, a0
    mv s8, a1
    la s11, line
    la a1, word_sums
    ld a0, JOB_RESULT(s1)
    call field
    la a1, word_space
    ld a0, JOB_RESULT(s2)
    call field
    la a1, word_starts
    mv a0, s5
    call field
    la a1, word_space
    mv a0, s6
    call field
    la a1, word_stop
    mv a0, s7
    call field
    la a1, word_space
    mv a0, s8
    call field
    call say

refusal_codes:
    la s1, job_c
    sw zero, JOB_DONE(s1)
    sd zero, JOB_RESULT(s1)
    li s0, 1
    la s3, stacks
    li s4, STACK_BYTES
    jab.sys.worker.start s0, sleep_worker, s1, s3, s4
    la s11, line
    la s0, refusals
    la s1, refusals_end
2:
    bgeu s0, s1, 3f
    ld a1, 0(s0)
    beqz a1, 21f
    call put_str
21:
    li a0, ' '
    call put_char
    ld a0, 8(s0)
    ld a1, 16(s0)
    ld a2, 24(s0)
    ld a3, 32(s0)
    call start_raw
    call put_signed
    addi s0, s0, REFUSAL_BYTES
    j 2b
3:
    call say

stop_sleeping:
    li t0, 2
    jab.sys.worker.stop t0
    mv s5, a0
    mv s6, a1
    la s11, line
    la a1, word_stop_sleeping
    mv a0, s5
    call field
    la a1, word_space
    mv a0, s6
    call field
    la a1, word_wait
    la t0, job_c
    ld a0, JOB_RESULT(t0)
    call field
    call say

stop_spinning:
    li s0, 2
    la s3, stacks
    li s4, STACK_BYTES
    add s3, s3, s4
    la s1, job_c
    jab.sys.worker.start s0, spin_forever, s1, s3, s4
    mv s5, a0
    li t0, 4
    jab.sys.worker.stop t0
    mv s6, a0
    mv s7, a1
    la s11, line
    la a1, word_stop_spinning
    mv a0, s6
    call field
    la a1, word_space
    mv a0, s7
    call field
    la a1, word_start
    mv a0, s5
    call field
    call say

denied_calls:
    la s1, job_d
    sw zero, JOB_DONE(s1)
    li s0, 1
    la s3, stacks
    li s4, STACK_BYTES
    jab.sys.worker.start s0, denied_worker, s1, s3, s4
    mv a0, s1
    call join
    li t0, 2
    jab.sys.worker.stop t0
    li a7, JAB_SYS_WORKER_EXIT
    ecall                                   # hart 0's own: no worker of its own to end
    mv s5, a0
    la s11, line
    la a1, word_denied
    call put_str
    la s2, job_d
    addi s2, s2, JOB_ANSWERS
    li s3, DENIED_CALLS
4:
    li a0, ' '
    call put_char
    ld a0, 0(s2)
    call put_signed
    addi s2, s2, 8
    addi s3, s3, -1
    bnez s3, 4b
    la a1, word_worker_harts
    ld a0, 0(s2)
    call field
    la a1, word_hart0_exit
    mv a0, s5
    call field
    call say

registers:
    li s10, 1                               # the run
5:
    la s1, job_r
    sw zero, JOB_GATE(s1)
    sw zero, JOB_SPINNING(s1)
    li t0, -1
    sd t0, JOB_ENTRY(s1)
    sd t0, JOB_KEPT(s1)
    li s0, 1
    la s3, stacks
    li s4, STACK_BYTES
    jab.sys.worker.start s0, regs_worker, s1, s3, s4
    li s2, SETTLE_TICKS
51:
    jab.sys.display.await                   # the worker asleep at its gate by the end
    addi s2, s2, -1
    bnez s2, 51b
    li t0, 1
    sw t0, JOB_GATE(s1)
    li t0, 2
    jab.sys.worker.wake t0
    mv s5, a0                               # 2 when it slept
52:
    lw t0, JOB_SPINNING(s1)
    bnez t0, 53f
    addi a0, s1, JOB_SPINNING
    jab.sys.worker.wait a0, zero
    j 52b
53:
    li t0, 2
    jab.sys.worker.stop t0                  # its interrupt lands in the worker's spin
    mv s6, a0
    mv s7, a1
    la s11, line
    la a1, word_registers
    mv a0, s10
    call field
    la a1, word_entry
    ld a0, JOB_ENTRY(s1)
    call field
    la a1, word_kept
    ld a0, JOB_KEPT(s1)
    call field
    la a1, word_woke
    mv a0, s5
    call field
    la a1, word_stop
    mv a0, s6
    call field
    la a1, word_space
    mv a0, s7
    call field
    call say
    addi s10, s10, 1
    li t0, 2
    bleu s10, t0, 5b

pestered:
    la s1, job_p
    sw zero, JOB_DONE(s1)
    sd zero, JOB_COUNT(s1)
    li s0, 2
    la s3, stacks
    li s4, STACK_BYTES
    add s3, s3, s4
    jab.sys.worker.start s0, pester, s1, s3, s4
    addi a0, s1, JOB_DONE
    jab.sys.worker.wait a0, zero            # once: it ends when the word moves, whatever wakes it
    fence r, rw
    lw s9, JOB_DONE(s1)
    li s5, 0                                # awaits that ended on the tick
    li s6, TICKS
6:
    jab.sys.display.await
    andi a0, a0, JAB_AWAIT_DISPLAY
    add s5, s5, a0
    addi s6, s6, -1
    bnez s6, 6b
    li t0, 4
    jab.sys.worker.stop t0
    mv s6, a0
    mv s7, a1
    ld t0, JOB_COUNT(s1)
    snez s8, t0                             # hart 0 woken by it at least once
    la s11, line
    la a1, word_pestered
    mv a0, s9
    call field
    la a1, word_woken
    mv a0, s8
    call field
    la a1, word_awaits
    mv a0, s5
    call field
    la a1, word_stop
    mv a0, s6
    call field
    la a1, word_space
    mv a0, s7
    call field
    call say

hart_three:
    la s1, job_c
    sw zero, JOB_DONE(s1)
    li s0, 3
    la s3, stacks
    li s4, STACK_BYTES
    add s3, s3, s4
    add s3, s3, s4
    jab.sys.worker.start s0, sleep_worker, s1, s3, s4
    mv s5, a0
    jab.sys.worker.start s0, sleep_worker, s1, s3, s4
    mv s6, a0
    li t0, 8
    jab.sys.worker.stop t0
    mv s7, a0
    mv s8, a1
    jab.sys.harts
    mv s2, a0
    mv s9, a1
    mv s10, a2
    la s11, line
    la a1, word_hart3
    mv a0, s5
    call field
    la a1, word_then
    mv a0, s6
    call field
    la a1, word_stop
    mv a0, s7
    call field
    la a1, word_space
    mv a0, s8
    call field
    la a1, word_harts
    mv a0, s2
    call field
    la a1, word_space
    mv a0, s9
    call field
    la a1, word_space
    mv a0, s10
    call field
    call say

exit_running:
    li s0, 1
    la s3, stacks
    li s4, STACK_BYTES
    la s1, job_c
    jab.sys.worker.start s0, spin_forever, s1, s3, s4
    li s0, 2
    add s3, s3, s4
    jab.sys.worker.start s0, spin_forever, s1, s3, s4
    la a1, word_exiting
    call say_str
    jab.sys.exit 0

restart:                                    # a start on hart 1 while its first worker's exit holds at its gap
    call hold_exit
    bnez a0, 1f
    la a1, word_restart_never
    call say_str
    jab.sys.exit 0
1:
    la s1, job_e
    sw zero, JOB_DONE(s1)
    sw zero, JOB_GATE(s1)
    sw zero, JOB_STOPPED(s1)
    li s0, 1
    la s3, stacks
    li s4, STACK_BYTES
    jab.sys.worker.start s0, restart_worker, s1, s3, s4
    mv s5, a0                               # the start made inside the hold
    la t0, witness
    lw s6, 0(t0)                            # before any other call
    mv s7, s5
    rdtime s8
    li t0, RETRY_WAIT
    add s8, s8, t0                          # the retries' bound
2:
    li t0, JAB_START_BUSY
    bne s7, t0, 3f
    rdtime t0
    bgeu t0, s8, 3f
    jab.sys.worker.start s0, restart_worker, s1, s3, s4
    mv s7, a0
    j 2b
3:
    li s9, 0                                # the stopped word after the stop
    bnez s7, 5f                             # no worker started to stop
4:
    lw t0, JOB_DONE(s1)
    bnez t0, 41f
    addi a0, s1, JOB_DONE
    jab.sys.worker.wait a0, zero
    j 4b
41:
    li t0, 2
    jab.sys.worker.stop t0
    lw s9, JOB_STOPPED(s1)                  # the worker's last store, acquired by the stop's return
5:
    la s11, line
    la a1, word_restart
    call put_str
    mv a0, s6
    mv a1, s5
    call start_saw
    call put_str
    la a1, word_comma_then
    mv a0, s7
    call field
    la a1, word_stopped
    mv a0, s9
    call field
    call say
    jab.sys.exit 0

stop_exit:                                  # a stop of hart 1 while its first worker's exit holds at its gap
    call hold_exit
    bnez a0, 1f
    la a1, word_stopexit_never
    call say_str
    jab.sys.exit 0
1:
    rdtime s5
    li t0, 2
    jab.sys.worker.stop t0
    rdtime s6
    la t0, witness
    lw s7, 0(t0)                            # at once, before any other call
    sub s6, s6, s5                          # the stop's elapsed ticks
    la s11, line
    la a1, word_stopexit
    call put_str
    li t0, W_STOP_SAW_WORKING
    beq s7, t0, 2f
    li t0, W_HELD
    beq s7, t0, 3f
    li t0, W_STOP_SAW_IDLE
    la a1, word_saw_idle
    beq s7, t0, 4f
    li t0, W_EXPIRED
    la a1, word_expired
    beq s7, t0, 4f
    la a1, word_other
    j 4f
2:
    la a1, word_saw_working
    call put_str
    la s1, job_e
    li s0, 1
    la s3, stacks
    li s4, STACK_BYTES
    jab.sys.worker.start s0, exit_worker, s1, s3, s4
    la a1, word_comma_then
    call field
    j 5f
3:
    rdtime s8
    li t0, HOLD_WAIT
    add s8, s8, t0                          # the hold's own bound and a margin
31:
    la t0, witness
    lw t0, 0(t0)
    li t1, W_HELD
    bne t0, t1, 32f                         # the hold over, observed late or expired
    rdtime t0
    bltu t0, s8, 31b
32:
    la a1, word_returned_held               # and no start
4:
    call put_str
5:
    call say
    la s11, line
    la a1, word_stop_took
    mv a0, s6
    call field
    la a1, word_ticks
    call put_str
    call say
    jab.sys.exit 0

hold_worker:                                # held JOB_N ticks, then done
    mv s0, a0
    rdtime t0
    ld t1, JOB_N(s0)
    add t1, t1, t0
1:
    rdtime t0
    bltu t0, t1, 1b
    fence rw, w
    li t0, 1
    sw t0, JOB_DONE(s0)
    li t0, 1
    jab.sys.worker.wake t0
    jab.sys.worker.exit

sum_worker:                                 # 1 to JOB_N summed into JOB_RESULT
    mv s0, a0
    ld t1, JOB_N(s0)
    li t0, 0
1:
    beqz t1, 2f
    add t0, t0, t1
    addi t1, t1, -1
    j 1b
2:
    sd t0, JOB_RESULT(s0)
    fence rw, w
    li t0, 1
    sw t0, JOB_DONE(s0)
    li t0, 1
    jab.sys.worker.wake t0
    jab.sys.worker.exit

sleep_worker:                               # asleep on JOB_DONE, which stays 0, its wait's answer kept
    mv s0, a0
    addi s1, s0, JOB_DONE
1:
    jab.sys.worker.wait s1, zero
    beqz a0, 1b
    sd a0, JOB_RESULT(s0)
    fence rw, w
    jab.sys.worker.exit

spin_forever:
    j spin_forever

denied_worker:                              # each call hart 0 keeps, its answer kept, then jab.sys.harts
    mv s0, a0
    addi s1, s0, JOB_ANSWERS
    la a0, msg_printed
    li a7, JAB_SYS_PRINT
    ecall
    sd a0, 0(s1)
    li a0, 3
    li a7, JAB_SYS_EXIT
    ecall
    sd a0, 8(s1)
    li a7, JAB_SYS_DISPLAY_FLIP
    ecall
    sd a0, 16(s1)
    li a7, 0
    ecall
    sd a0, 24(s1)
    li a7, 99
    ecall
    sd a0, 32(s1)
    li a0, 2
    li a7, JAB_SYS_WORKER_START
    ecall
    sd a0, 40(s1)
    li a0, 2
    li a7, JAB_SYS_WORKER_STOP
    ecall
    sd a0, 48(s1)
    jab.sys.harts
    sd a0, 56(s1)
    fence rw, w
    li t0, 1
    sw t0, JOB_DONE(s0)
    li t0, 1
    jab.sys.worker.wake t0
    jab.sys.worker.exit

regs_worker:                                # the registers as the start leaves them, then set and kept
    mv s0, a0
    call regs_initial
    sd a0, JOB_ENTRY(s0)
    call regs_set
    csrr t0, vl
    sd t0, JOB_VL(s0)
    li s2, 0                                # registers found changed since
    addi s1, s0, JOB_GATE
1:
    jab.sys.worker.wait s1, zero
    lw t0, JOB_GATE(s0)
    beqz t0, 1b
    mv a0, s0
    call regs_count
    add s2, s2, a0
    li t0, 1
    sw t0, JOB_SPINNING(s0)
    li t0, 1
    jab.sys.worker.wake t0                  # hart 0 waits on the spin's start
2:
    rdtime s3
    li t0, SPIN_CHUNK
    add s3, s3, t0
3:
    mv a0, s0
    call regs_count                         # every pass, so a trap between any two is caught
    add s2, s2, a0
    rdtime t0
    bltu t0, s3, 3b
    li t0, 2
    jab.sys.worker.wait s1, t0              # the gate holds 1: back at once, 1 once a stop is asked
    beqz a0, 2b
    mv a0, s0
    call regs_count
    add s2, s2, a0
    sd s2, JOB_KEPT(s0)
    fence rw, w
    jab.sys.worker.exit

pester:                                     # hart 0 woken in a tight loop, done after PESTER_WAKES, on until stopped
    mv s0, a0
    li s1, 0                                # wakes made
    li s2, 0                                # those that found hart 0 asleep
1:
    li t0, 1
    jab.sys.worker.wake t0
    andi a0, a0, 1
    add s2, s2, a0
    addi s1, s1, 1
    li t0, PESTER_WAKES
    bne s1, t0, 1b
    sd s2, JOB_COUNT(s0)
    fence rw, w
    li t0, 1
    sw t0, JOB_DONE(s0)
2:
    li t0, 1
    jab.sys.worker.wake t0
    j 2b

exit_worker:                                # out at once
    jab.sys.worker.exit

restart_worker:                             # its started word set and hart 0 woken, asleep on its gate until stopped, then its stopped word set
    mv s0, a0
    li t0, 1
    sw t0, JOB_DONE(s0)
    li t0, 1
    jab.sys.worker.wake t0
    addi s1, s0, JOB_GATE
1:
    jab.sys.worker.wait s1, zero
    beqz a0, 1b                             # the gate never moves: a stop alone ends the wait
    li t0, 1
    sw t0, JOB_STOPPED(s0)                  # published by its exit's fence before the hart reads idle
    jab.sys.worker.exit

regs_set:
    li t0, PATTERN_F
.irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    addi t1, t0, \n
    fmv.d.x f\n, t1
.endr
    li t0, FFLAGS_SET
    csrw fcsr, t0
    vsetvli t0, zero, e64, m1, ta, ma
    li t0, PATTERN_V
.irp n, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    addi t1, t0, \n
    vmv.v.x v\n, t1
.endr
    ret

regs_count:                                 # a0 the job, whose JOB_VL is vl as regs_set left it
    mv t5, a0
    li a0, 0
    li t0, PATTERN_F
.irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    fmv.x.d t2, f\n
    addi t1, t0, \n
    xor t2, t2, t1
    snez t2, t2
    add a0, a0, t2
.endr
    csrr t2, fcsr
    xori t2, t2, FFLAGS_SET
    snez t2, t2
    add a0, a0, t2
    csrr t2, vtype
    xori t2, t2, VTYPE_E64_M1
    snez t2, t2
    add a0, a0, t2
    csrr t2, vl
    ld t3, JOB_VL(t5)
    xor t2, t2, t3
    snez t2, t2
    add a0, a0, t2
    li t0, PATTERN_V
.irp n, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    addi t1, t0, \n
    vmsne.vx v0, v\n, t1
    vcpop.m t2, v0
    snez t2, t2
    add a0, a0, t2
.endr
    ret

regs_initial:
    li a0, 0
.irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    fmv.x.d t2, f\n
    snez t2, t2
    add a0, a0, t2
.endr
    csrr t2, fcsr
    snez t2, t2
    add a0, a0, t2
    csrr t2, vtype
    li t1, VTYPE_ILL
    xor t2, t2, t1
    snez t2, t2
    add a0, a0, t2
    csrr t2, vl
    snez t2, t2
    add a0, a0, t2
    vsetvli t0, zero, e64, m1, ta, ma
.irp n, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    vmsne.vx v0, v\n, zero
    vcpop.m t2, v0
    snez t2, t2
    add a0, a0, t2
.endr
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
    fence r, rw                             # the worker's results after its mark
    ld ra, 8(sp)
    ld s0, 0(sp)
    addi sp, sp, 16
    ret

start_raw:                                  # a0 the hart, a1 the entry, a2 the stack, a3 its size: the start's answer
    mv a4, a3
    mv a3, a2
    li a2, 0
    li a7, JAB_SYS_WORKER_START
    ecall
    ret

hold_exit:                                  # hart 1's first worker on the witness word, out at once: a0 1 once its exit holds, 0 never
    addi sp, sp, -16
    sd ra, 8(sp)
    la s1, witness
    sw zero, 0(s1)
    li s0, 1
    la s3, stacks
    li s4, STACK_BYTES
    jab.sys.worker.start s0, exit_worker, s1, s3, s4
    bnez a0, 2f                             # refused: never held
    rdtime s2
    li t0, HELD_WAIT
    add s2, s2, t0                          # the poll's bound
1:
    lw t0, 0(s1)
    bnez t0, 3f                             # the exit reached its hold, or already past it
    rdtime t0
    bltu t0, s2, 1b
2:
    li a0, 0
    j 4f
3:
    li a0, 1
4:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

start_saw:                                  # a0 the witness after the start, a1 the start's answer: a1 what the start saw, in a word
    li t0, W_SAW_WORKING
    bne a0, t0, 1f
    li t0, JAB_START_BUSY
    la t1, word_busy
    beq a1, t0, 9f                          # working, and the start answered so
    la t1, word_disagreed
    j 9f
1:
    li t0, W_SAW_IDLE
    bne a0, t0, 2f
    li t0, JAB_START_BUSY
    la t1, word_idle
    bne a1, t0, 9f
    la t1, word_disagreed
    j 9f
2:
    li t0, W_EXPIRED
    la t1, word_expired
    beq a0, t0, 9f
    li t0, W_HELD
    la t1, word_nothing
    beq a0, t0, 9f                          # the start returned with the hold unobserved
    la t1, word_other
9:
    mv a1, t1
    ret

spin:                                       # a0 ticks of rdtime
    rdtime t0
    add t1, t0, a0
1:
    rdtime t0
    bltu t0, t1, 1b
    ret

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

say_str:                                    # a1 a whole line
    addi sp, sp, -16
    sd ra, 8(sp)
    la s11, line
    call put_str
    call say
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

say:                                        # the line at s11 ended and printed
    li t0, '\n'
    sb t0, 0(s11)
    sb zero, 1(s11)
    jab.sys.uart.print line
    ret

put_char:
    sb a0, 0(s11)
    addi s11, s11, 1
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
.balign 8
refusals:
    .quad word_r_hart, 0, sleep_worker, stacks + STACK_BYTES, STACK_BYTES
    .quad 0, JAB_HARTS_MAX, sleep_worker, stacks + STACK_BYTES, STACK_BYTES
    .quad 0, 5, sleep_worker, stacks + STACK_BYTES, STACK_BYTES
    .quad word_r_entry, 2, KERNEL, stacks + STACK_BYTES, STACK_BYTES
    .quad 0, 2, sleep_worker + 1, stacks + STACK_BYTES, STACK_BYTES
    .quad 0, 2, JAB_STACK_TOP, stacks + STACK_BYTES, STACK_BYTES
    .quad word_r_stack, 2, sleep_worker, stacks + STACK_BYTES, 0
    .quad 0, 2, sleep_worker, stacks + STACK_BYTES + 8, STACK_BYTES
    .quad 0, 2, sleep_worker, stacks + STACK_BYTES, STACK_BYTES - 8
    .quad 0, 2, sleep_worker, KERNEL, STACK_BYTES
    .quad 0, 2, sleep_worker, stacks + STACK_BYTES, -16
    .quad 0, 2, sleep_worker, JAB_STACK_TOP - 16, 32
    .quad word_r_overlap, 2, sleep_worker, JAB_STACK_TOP - JAB_MAIN_STACK - 16, 32
    .quad 0, 2, sleep_worker, JAB_STACK_TOP - 65536, 4096
    .quad 0, 2, sleep_worker, stacks + 8192, STACK_BYTES
    .quad word_r_busy, 1, sleep_worker, stacks + STACK_BYTES, STACK_BYTES
refusals_end:
word_no_sound:
    .asciz "workers: no sound"
word_sound_join:
    .asciz "join with sound: start "
word_done:
    .asciz ", done "
word_stop:
    .asciz ", stop "
word_space:
    .asciz " "
word_sums:
    .asciz "sums "
word_starts:
    .asciz ", starts "
word_r_hart:
    .asciz "refused hart"
word_r_entry:
    .asciz ", entry"
word_r_stack:
    .asciz ", stack"
word_r_overlap:
    .asciz ", overlap"
word_r_busy:
    .asciz ", busy"
word_stop_sleeping:
    .asciz "stop sleeping "
word_wait:
    .asciz ", wait "
word_stop_spinning:
    .asciz "stop spinning "
word_start:
    .asciz ", start "
word_denied:
    .asciz "denied"
word_worker_harts:
    .asciz ", worker harts "
word_hart0_exit:
    .asciz ", hart 0 exit "
word_registers:
    .asciz "registers "
word_entry:
    .asciz ": entry "
word_kept:
    .asciz ", kept "
word_woke:
    .asciz ", woke "
word_pestered:
    .asciz "pestered: done "
word_woken:
    .asciz ", woken "
word_awaits:
    .asciz ", awaits "
word_hart3:
    .asciz "hart 3 start "
word_then:
    .asciz " then "
word_harts:
    .asciz ", harts "
word_exiting:
    .asciz "workers: exit with two running"
word_no_scenario:
    .asciz "workers: no scenario"
word_restart:
    .asciz "restart: held, start saw "
word_restart_never:
    .asciz "restart: never held"
word_busy:
    .asciz "busy"
word_idle:
    .asciz "idle"
word_disagreed:
    .asciz "disagreed"
word_expired:
    .asciz "expired"
word_nothing:
    .asciz "nothing"
word_other:
    .asciz "other"
word_comma_then:
    .asciz ", then "
word_stopped:
    .asciz ", stopped "
word_stopexit:
    .asciz "stopexit: held, "
word_stopexit_never:
    .asciz "stopexit: never held"
word_saw_working:
    .asciz "stop saw working"
word_saw_idle:
    .asciz "stop saw idle"
word_returned_held:
    .asciz "stop returned while held"
word_stop_took:
    .asciz "stopexit: the stop took "
word_ticks:
    .asciz " ticks"
msg_printed:
    .asciz "workers: a worker printed\n"

.section .bss
.balign 64
job_a:
    .skip JOB_BYTES
job_b:
    .skip JOB_BYTES
job_c:
    .skip JOB_BYTES
job_d:
    .skip JOB_BYTES
job_r:
    .skip JOB_BYTES
job_p:
    .skip JOB_BYTES
job_e:
    .skip JOB_BYTES
.balign 16
stacks:
    .skip (3 * STACK_BYTES)
line:
    .skip 160
digits:
    .skip 32
.balign 8
selector:
    .skip 8
witness:
    .skip 8
