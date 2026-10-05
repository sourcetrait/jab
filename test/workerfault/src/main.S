.include "jab.inc"

.set SELECT_WAIT, (2 * JAB_TIME_HZ)
.set STACK_BYTES, 16384
.set KERNEL, 0x80000000
.set LATE, (JAB_TIME_HZ / 10)
.set LONG_BYTES, 32768

.section .text
.global _start
_start:
    rdtime s7
    li t0, SELECT_WAIT
    add s7, s7, t0                          # the selector's deadline
1:
    la s4, selector
    jab.sys.api.read s4, 1
    bnez a0, 2f                             # it came
    rdtime t0
    bgeu t0, s7, 9f
    jab.sys.await JAB_AWAIT_DISPLAY | JAB_AWAIT_API
    j 1b
2:
    lbu t0, 0(s4)
    li t1, 'k'
    beq t0, t1, store
    li t1, 't'
    beq t0, t1, two
    li t1, 'j'
    beq t0, t1, joined
    li t1, 'a'
    beq t0, t1, address
    li t1, 'p'
    beq t0, t1, printing
9:
    la a1, word_none
    call say_str
    jab.sys.exit 2

store:                                      # a worker's store into the kernel
    la a1, name_store
    call echo
    li a0, 1
    la a1, store_worker
    li a2, 0xa1
    call start_one
    bnez a0, refused
    j forever

two:                                        # two workers' stores at once
    la a1, name_two
    call echo
    li a0, 1
    la a1, gated_worker
    li a2, 0xb1
    call start_one
    bnez a0, refused
    li a0, 2
    la a1, gated_worker
    li a2, 0xb2
    call start_one
    bnez a0, refused
    la t0, go
    li t1, 1
    sw t1, 0(t0)                            # both through their gates together
    j forever

joined:                                     # a worker's store while hart 0 joins it
    la a1, name_join
    call echo
    li a0, 1
    la a1, late_worker
    li a2, 0xc1
    call start_one
    bnez a0, refused
    la s0, never
1:
    jab.sys.worker.wait s0, zero            # a join whose worker faults instead
    j 1b

address:                                    # a worker's wait on a word outside the window
    la a1, name_address
    call echo
    li a0, 1
    la a1, wait_worker
    li a2, 0xe1
    call start_one
    bnez a0, refused
    j forever

printing:                                   # a worker's store while hart 0 prints a long line with the sound live
    la a1, name_print
    call echo
    jab.sys.sound.open
    bnez a0, refused
    la s4, silence
    li s5, JAB_SOUND_RING
    jab.sys.sound.write s4, s5              # the stream live, so the print's sound_tick drains under its lock
    la t0, long_line
    li t1, LONG_BYTES
    li t2, 'x'
1:
    sb t2, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, 1b
    li t2, '\n'
    sb t2, 0(t0)
    sb zero, 1(t0)
    li a0, 1
    la a1, gated_worker
    li a2, 0xd1
    call start_one
    bnez a0, refused
    la t0, go
    li t1, 1
    sw t1, 0(t0)
    jab.sys.uart.print long_line            # the worker faults while this goes out
    la a1, word_after
    call say_str                            # never: hart 0 stops at the boundary after its line
    j forever

forever:                                    # hart 0 awaits what never comes: more bytes over the API
    jab.sys.await JAB_AWAIT_API
    j forever

refused:
    la a1, word_refused
    call say_str
    jab.sys.exit 3

store_worker:
    li t0, KERNEL
    sd zero, 0(t0)
1:
    j 1b

gated_worker:                               # through the gate, then a store at an address of its own
    la t0, go
1:
    lw t1, 0(t0)
    beqz t1, 1b
    andi t1, a0, 0xf
    slli t1, t1, 3
    li t0, KERNEL
    add t0, t0, t1
    sd zero, 0(t0)
2:
    j 2b

late_worker:                                # a tenth of a second, then the store
    rdtime t0
    li t1, LATE
    add t1, t1, t0
1:
    rdtime t0
    bltu t0, t1, 1b
    li t0, KERNEL
    sd zero, 0(t0)
2:
    j 2b

wait_worker:
    li a0, KERNEL
    li a1, 0
    li a7, JAB_SYS_WORKER_WAIT
    ecall
1:
    j 1b

start_one:                                  # a0 the hart, a1 the entry, a2 the argument: on a stack of its own
    la a3, stacks
    addi t0, a0, -1
    li t1, STACK_BYTES
    mul t0, t0, t1
    add a3, a3, t0
    li a4, STACK_BYTES
    li a7, JAB_SYS_WORKER_START
    ecall
    ret

echo:                                       # a1 the scenario's name
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a1, 0(sp)
    la s3, line
    la a1, word_scenario
    call put_str
    ld a1, 0(sp)
    call put_str
    call say
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

say_str:                                    # a1 a whole line
    addi sp, sp, -16
    sd ra, 8(sp)
    la s3, line
    call put_str
    call say
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

say:
    li t0, '\n'
    sb t0, 0(s3)
    sb zero, 1(s3)
    jab.sys.uart.print line
    ret

put_str:
    lbu t0, 0(a1)
    beqz t0, 1f
    sb t0, 0(s3)
    addi s3, s3, 1
    addi a1, a1, 1
    j put_str
1:
    ret

.section .rodata
word_none:
    .asciz "workerfault: no scenario"
word_scenario:
    .asciz "workerfault: scenario "
word_refused:
    .asciz "workerfault: a start refused"
word_after:
    .asciz "workerfault: after the line"
name_store:
    .asciz "store"
name_two:
    .asciz "two"
name_join:
    .asciz "join"
name_address:
    .asciz "address"
name_print:
    .asciz "print"

.section .bss
.balign 8
selector:
    .skip 8
go:
    .skip 8
never:
    .skip 8
line:
    .skip 128
.balign 16
stacks:
    .skip (2 * STACK_BYTES)
silence:
    .skip (JAB_SOUND_RING * JAB_SOUND_FRAME_BYTES)
long_line:
    .skip (LONG_BYTES + 2)
