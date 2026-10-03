.include "jab.inc"

.section .text
.global _start
_start:
    jab.sys.print before
    li t0, 0x80000000
    sw zero, 0(t0)
    jab.sys.print after
    jab.sys.exit 0

.section .rodata
before:
    .asciz "storing into the kernel\n"
after:
    .asciz "the store went through\n"
