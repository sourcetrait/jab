.include "jab.inc"

.section .text
.global _start
_start:
    li sp, 0x80000100
    jab.sys.uart.print msg_kernel
    li sp, 0
    jab.sys.uart.print msg_zero
    li sp, JAB_STACK_TOP + 4096
    jab.sys.uart.print msg_past
    jab.sys.exit 3

.section .rodata
msg_kernel:
    .asciz "badstack: sp inside the kernel\n"
msg_zero:
    .asciz "badstack: sp at zero\n"
msg_past:
    .asciz "badstack: sp past the end of RAM\n"
