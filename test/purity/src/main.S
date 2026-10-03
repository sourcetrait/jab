.include "jab.inc"

.section .text
.global _start
_start:
.ifdef DEBUG
    jab.sys.uart.print msg_debug
.pushsection .rodata
msg_debug:
    .asciz "purity: debug build\n"
.popsection
.endif
    jab.sys.uart.print msg_done
    jab.sys.exit 0

.section .rodata
msg_done:
    .asciz "purity: done\n"
