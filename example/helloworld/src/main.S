.include "jab.inc"

.section .text
.global _start
_start:
    jab.sys.print message
    jab.sys.exit 0

.section .rodata
message:
    .asciz "Hello, World!\n"
