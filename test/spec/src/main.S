.include "jab.inc"

.section .text
.global _start
_start:
    jab.sys.uart.print msg_up
    jab.sys.exit 0

.section .rodata
msg_up:
    .asciz "spec: up\n"
