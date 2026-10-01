# exitstatus: exits with a nonzero status, which `just test` must return.
.include "jab.inc"

.section .text
.global _start
_start:
    jab.sys.print message
    jab.sys.exit 3

.section .rodata
message:
    .asciz "exiting with 3\n"
