.include "jab.inc"

.set STACK_BYTES, 16384
.set WAIT_TICKS, (2 * JAB_TIME_HZ)
.set HART_BIT, 2

.section .text
.global _start
_start:
    li s1, 1                                # the worker's hart
    la t1, stack
    li t2, STACK_BYTES
    la t3, word
    jab.sys.worker.start s1, waiter, t3, t1, t2
    bnez a0, refused
    rdtime s7
    li t0, WAIT_TICKS
    add s7, s7, t0                          # the deadline
1:
    li s2, HART_BIT
    jab.sys.worker.wake s2
    andi a0, a0, HART_BIT
    bnez a0, 2f                             # woken asleep in its wait
    rdtime t0
    bgeu t0, s7, never_slept
    jab.sys.await JAB_AWAIT_DISPLAY
    j 1b
2:
    la t0, word
    li t1, 1
    sw t1, 0(t0)                            # the word it waits on changed
3:
    li s2, HART_BIT
    jab.sys.worker.wake s2
    la t0, done
    lw t0, 0(t0)
    bnez t0, 4f
    rdtime t0
    bgeu t0, s7, never_done
    jab.sys.await JAB_AWAIT_DISPLAY
    j 3b
4:
    jab.sys.uart.print word_done
    jab.sys.exit 0

refused:
    jab.sys.uart.print word_refused
    jab.sys.exit 3

never_slept:
    jab.sys.uart.print word_never_slept
    jab.sys.exit 3

never_done:
    jab.sys.uart.print word_never_done
    jab.sys.exit 3

waiter:                                     # a0 the word: asleep in its wait until it changes, then done
    mv s0, a0
    jab.sys.worker.wait s0, zero
    la t0, done
    li t1, 1
    sw t1, 0(t0)
    jab.sys.worker.exit

.section .rodata
word_done:
    .asciz "owners: woken asleep, then done\n"
word_refused:
    .asciz "owners: the start refused\n"
word_never_slept:
    .asciz "owners: the worker never slept\n"
word_never_done:
    .asciz "owners: the worker never finished\n"

.section .bss
.balign 8
word:
    .skip 8
done:
    .skip 8
.balign 16
stack:
    .skip STACK_BYTES
