# purity: the program behind the release-purity test, which reads the
# kernel images rather than running one. It exits 0 and reports which
# build it is, so a debug build of it can be told from a release one.
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
