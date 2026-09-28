# badstack: the kernel never touches the program's stack. sp is put
# inside the kernel's own memory, then at zero, then past the end of
# RAM, and a call is made from each place: every call prints, since the
# kernel keeps its own stack whatever the program's sp says, and the
# exit's status comes back from the last of them.
.include "jab.inc"

.section .text
.global _start
_start:
    li sp, 0x80000100
    jab.uart.print msg_kernel
    li sp, 0
    jab.uart.print msg_zero
    li sp, JAB_STACK_TOP + 4096
    jab.uart.print msg_past
    jab.exit 3

.section .rodata
msg_kernel:
    .asciz "badstack: sp inside the kernel\n"
msg_zero:
    .asciz "badstack: sp at zero\n"
msg_past:
    .asciz "badstack: sp past the end of RAM\n"
