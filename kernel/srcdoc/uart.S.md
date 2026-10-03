# uart.S

The 16550 UART QEMU puts at QEMU_VIRT_UART0: output only, polled. Each
routine waits for the transmit register to empty before every byte. None of
them calls anything, so they clobber only t registers and a0.

## .macro uart_wait

The label carries the expansion counter so it never captures a caller's
numeric label.

## uart_put_dec

The digits are built backwards in 32 bytes of stack, then written.
