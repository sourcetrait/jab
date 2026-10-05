# uart.S

The 16550 UART QEMU puts at QEMU_VIRT_UART0: output only, polled. Each
routine waits for the transmit register to empty before every byte. None of
them calls anything, so they clobber only t registers and a0.

Every line the kernel writes on the UART goes out under the line lock, so
lines from different harts never interleave: a caller takes it before the
line's first byte and gives it back after its newline, holding it for one
line and never across a wait. A fault's line takes it through
uart_lock_fatal, which stops waiting after UART_FATAL_WAIT, so the line goes
out even past a hart that holds the lock and will not let go.

## .set UART_FATAL_WAIT

`u64`: the ticks a fault's line waits for the line lock, a second.

## .macro uart_wait

The label carries the expansion counter so it never captures a caller's
numeric label.

## uart_put_dec

The digits are built backwards in 32 bytes of stack, then written.

## uart_lock

An amoswap with acquire ordering takes the lock; a hart that finds it held
spins on it with a pause hint. Then `fence rw, io`: an AMO's acquire orders
the memory domain alone, and the line's bytes are device writes, which
only a fence orders after the lock (the RISC-V A extension's ordering
rules).

## uart_unlock

`fence io, w` first, then an amoswap of 0 with release ordering, so the
line's device writes are out before another hart can take the lock; the
release alone would order only the memory accesses before it.

## uart_lock_fatal

Takes the lock as uart_lock does, its fence included, when it gets it
within UART_FATAL_WAIT; past the wait the line goes out without it.

## uart_line_lock

`u32`: 1 while a hart holds the line lock. In .data, so it reads 0 before
the bss clear, where machine mode's trap can already print.
