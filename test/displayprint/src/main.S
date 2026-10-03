.include "jab.inc"

.section .text
.global _start
_start:
    jab.sys.print uart_first
    jab.sys.display.open
    bnez a0, no_display
    jab.sys.print on_screen
    jab.sys.uart.print uart_again
    jab.sys.display.print line_two
idle:
    jab.sys.display.await
    j idle

no_display:
    jab.sys.uart.print msg_no_display
    jab.sys.exit 1

.section .rodata
uart_first:
    .asciz "uart first\n"
on_screen:
    .asciz "on screen\n"
uart_again:
    .asciz "uart again\n"
line_two:
    .asciz "line two\n"
msg_no_display:
    .asciz "displayprint: no display\n"
