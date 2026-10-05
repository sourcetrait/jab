# trap.S

The supervisor trap vector, every hart's. A trap from the program lands
here: its registers go into a 256-byte frame on the hart's kernel stack,
the cause picks a handler, and sret returns with the frame restored.
sscratch holds the hart's record, the top of its kernel stack (harts.S),
while the program runs and 0 while the kernel runs: the entry swaps it with
sp, so a swap that yields 0 is a trap the kernel itself took, handled on the
kernel's own stack before anything is stored, and never through the
program's sp, which the frame keeps in slot 2 and the exit puts back before
the swap out. Frame slot n holds register n. Once the frame holds the
program's registers, its tp in slot 32, tp holds the record, which every
handler finds there; the exit restores the program's.

A system call is dispatched through syscall_table by its number in a7; the
dispatch reloads a0 and a7 from the frame and leaves a1 to a5 as the program
set them. Every call is hart 0's but jab.sys.harts and the worker calls: on
a worker's hart any other number, 0 and one past the table included, is
answered JAB_DENIED and nothing is entered (worker_call, sys_denied), so a
worker never reaches a device routine or the unlocked state behind one. A
handler finds its arguments in slots 80 on (a0 to a5) or in the live
registers, leaves its results in slots 80 on (a0, and a1 to a3 where a call
has more), and jumps to trap_return. An external interrupt lands here too,
from the program only, since the kernel runs with interrupts off and takes
its own through wfi: one bounded drain runs (aia.S's irq_drain), which is
where the sound stream is refilled on the device's clock (sound.S), on hart
0 a source masked since is reported on the UART, and the program resumes
where it was.

The return to user mode is the boundary, the safe point where a hart stops
when it must (interrupt_return): another hart's shutdown parks it, a
worker's forced stop takes it out of the program for good (workers.S), and
hart 0 keeps its external interrupts enabled while workers run, so their
faults and wakes reach it in the program.

A fault ends the run, and its line goes out once every hart has stopped. The
faulting hart records the fault in its own record (hart.inc), no lock held:
a trap's cause, pc, and tval, or a line and a value, the unknown call's, the
bad address's, the timer's, and the faults of other files through
fatal_plain, fatal_dec, and fatal_hex. Then it claims the shutdown
(workers.S's shutdown_enter): a hart behind another's claim parks, and the
owner stops every other hart and goes on to fatal_exit, which prints every
recorded line under the line lock, its own first.

## .set SYSCALL_LAST

`u64`: the highest system call number syscall_table holds.

## .set UART_PRINT_TICK

`u64`: bytes sys_uart_print writes between looks at the sound stream.

## sys_uart_print

The UART is polled, so a long message looks at the sound stream every
UART_PRINT_TICK bytes. The whole call goes out under the line lock
(uart.S), so another hart's line never lands inside it; the sound's look
runs inside it and never blocks.

## buffer_bounds

A call that fills a buffer can write it without checking again.

## copy_bytes

Program memory is reached through SUM, so either end may be the program's.

## sys_exit

The exit claims the shutdown first, so every worker stops where it is before
the sound stream plays out (sound.S) and nothing a worker does reaches a
device the flush is driving; behind a worker's fault the claim parks hart 0
instead, and the fault ends the run. Then QEMU ends with the status, since
no launcher exists yet to return to, or with 1 when another hart recorded a
fault; with DEBUG the status is also reported on the debug channel.

## msg_exit

`11 u8`: the exit line's prefix on the debug channel, under DEBUG only.

## kernel_trap

The swap at the entry found 0 in sscratch, so the trap is the kernel's own,
taken inside a call: the swap is undone, which puts the kernel's sp back.
No register is stored anywhere before that, so the program's sp, wherever
it points, is never written through in supervisor mode. One such trap is
expected: hart 0's release store into the interrupt file of a hart the
machine lacks, which nothing decodes, so QEMU raises a store access fault
(harts.S's harts_release). A trap whose sepc is that store's
(hart_wake_store), whose cause is 7, and whose stval is the file's address
being written (hart_wake_target) sets hart_wake_faulted and resumes past
the store, its two registers put back, so the kernel's state is as it was;
any other goes on to kernel_fault.

## kernel_fault

Fatal, on any hart, and its line names the hart. The stack starts again
from the record, whatever the fault left of it. A fault taken while the
hart already reports one is a fault inside the report, which nothing is
left to trust, and ends the run at once; any other is recorded and goes
through the shutdown, since a halted hart would leave the others running.

## timer_left_enabled

Under DEBUG, the check at every return to user mode found the timer's
enable set: the program would take the next timer interrupt as a fault, so
the run ends here at the cause with its line, `jab: timer left enabled`,
rather than later at a fault far from it.

## msg_timer_left

`24 u8`: timer_left_enabled's line, under DEBUG only.

## fault_recorded

The kind is written after the fields, with `fence w, w` between, so a hart
reading another's record and finding a kind finds the fields it vouches for.

## fatal_exit

The owner holds the line lock for every line, so no other hart's line lands
between them, and the other harts are stopped by now. A hart past the
shutdown's bound is named on a line of its own after the faults, `jab:
shutdown unanswered: hart N`, a hart that missed its safe point.

## fault_line

A worker's line names its hart and its argument, the program's own fault
on hart 0 keeps its form, and a kernel fault names its hart on any.

## interrupt_return

The program resumes at the instruction the interrupt came before, not past
it. The program's sp goes back into sscratch first, so the swap out hands it
over and leaves the hart's record, its kernel stack's top, behind for the
next entry. Under DEBUG the timer's enable is read clear first, every
system call's return falling into this path too (timer_left_enabled); the
external enable is left out, since it legitimately stays set where a sound
stream died inside another call. Then the boundary's checks: a shutdown
another hart owns, a worker's forced stop, and, on hart 0, the external
enable set while workers run. A shutdown's owner never comes back this way,
so a claim here is always another's. Every return to user mode passes
here, so a hart a shutdown woke in a nested wait stops once its call
returns, its line and its device work finished.

## syscall_table

`57 addr`: each system call's handler by its number, bad_syscall at 0.

## msg_bad_syscall

`26 u8`: the unknown call line's prefix.

## msg_bad_address

`33 u8`: the bad address line.

## msg_program_fault

`27 u8`: the program fault line's prefix.

## msg_worker_fault

`25 u8`: a worker's fault line's prefix, the hart's id after it.

## msg_kernel_fault

`25 u8`: the kernel fault line's prefix, the hart's id after it.

## msg_argument

`11 u8`: a worker's fault line's argument field.

## msg_cause

`8 u8`: a fault line's cause field after the hart.

## msg_epc

`6 u8`: a fault line's pc field.

## msg_tval

`7 u8`: a fault line's tval field.

## msg_unanswered

`32 u8`: the line for a hart that did not halt in the shutdown's bound,
before its id.
