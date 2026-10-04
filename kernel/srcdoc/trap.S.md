# trap.S

The supervisor trap vector. A trap from the program lands here: its
registers go into a 256-byte frame on the kernel stack, the cause picks a
handler, and sret returns with the frame restored. sscratch holds the kernel
stack top while the program runs and 0 while the kernel runs: the entry
swaps it with sp, so a swap that yields 0 is a trap the kernel itself took,
handled on the kernel's own stack before anything is stored, and never
through the program's sp, which the frame keeps in slot 2 and the exit puts
back before the swap out. Frame slot n holds register n.

A system call is dispatched through syscall_table by its number in a7; the
dispatch reloads a0 and a7 from the frame and leaves a1 to a5 as the program
set them. A handler finds its arguments in slots 80 on (a0 to a5) or in the
live registers, leaves its results in slots 80 on (a0, and a1 to a3 where a
call has more), and jumps to trap_return. An external interrupt lands here
too, from the program only, since the kernel runs with interrupts off and
takes its own through wfi: the PLIC is serviced, which is where the sound
stream is refilled on the device's clock (sound.S), and the program resumes
where it was.

## .set SYSCALL_LAST

`u64`: the highest system call number syscall_table holds.

## .set UART_PRINT_TICK

`u64`: bytes sys_uart_print writes between looks at the sound stream.

## sys_uart_print

The UART is polled, so a long message looks at the sound stream every
UART_PRINT_TICK bytes.

## buffer_bounds

A call that fills a buffer can write it without checking again.

## copy_bytes

Program memory is reached through SUM, so either end may be the program's.

## sys_exit

The sound stream, if live, plays out first (sound.S); then QEMU ends with
the status, since no launcher exists yet to return to; with DEBUG the status
is also reported on the debug channel.

## msg_exit

`11 u8`: the exit line's prefix on the debug channel, under DEBUG only.

## kernel_trap

The swap at the entry found 0 in sscratch, so the trap is the kernel's own,
taken inside a call: the swap is undone, which puts the kernel's sp back,
and the fault is reported from there. No register is stored anywhere first,
so the program's sp, wherever it points, is never written through in
supervisor mode.

## interrupt_return

The program resumes at the instruction the interrupt came before, not past
it. The program's sp goes back into sscratch first, so the swap out hands it
over and leaves the kernel stack top behind for the next entry.

## syscall_table

`51 addr`: each system call's handler by its number, bad_syscall at 0.

## msg_bad_syscall

`26 u8`: the unknown call line's prefix.

## msg_bad_address

`34 u8`: the bad address line.

## msg_program_fault

`27 u8`: the program fault line's prefix.

## msg_kernel_fault

`26 u8`: the kernel fault line's prefix.

## msg_epc

`6 u8`: a fault line's pc field.

## msg_tval

`7 u8`: a fault line's tval field.
