.include "jab.inc"

.set FLIPS, 64
.set RECEIPTS, 160
.set RECEIPT_BYTES, 64
.set SELECT_WAIT, (2 * JAB_TIME_HZ)
.set HELD_WAIT, (35 * JAB_TIME_HZ / 10)
.set SENTINEL, 0x5a5a5a5a
.set OLD, 0x00204060
.set NEW, 0x00c08040
.set LIST_LONG, 33

.set KIND_CLOSED, 1
.set KIND_BURST, 2
.set KIND_WHOLE, 3
.set KIND_RECT, 4
.set KIND_BADRECT, 5
.set KIND_RECTS, 6
.set KIND_BADRECTS, 7
.set KIND_NORECTS, 8
.set KIND_BEFORE_PRINT, 9
.set KIND_AFTER_PRINT, 10
.set KIND_OLD, 11
.set KIND_LIST, 12
.set KIND_LONG, 13
.set KIND_BADXFER, 14
.set KIND_BADFLUSH, 15
.set KIND_HELD, 16
.set KIND_FAILED, 17

.macro flip_whole kind
    rdtime s8
    jab.sys.display.flip
    rdtime s9
    li t6, \kind
    call keep
.endm

.macro flip_rect kind
    rdtime s8
    jab.sys.display.flip.rect
    rdtime s9
    li t6, \kind
    call keep
.endm

.macro flip_rects kind, buffer, count
    rdtime s8
    jab.sys.display.flip.rects \buffer, \count
    rdtime s9
    li t6, \kind
    call keep
.endm

.section .text
.global _start
_start:
    flip_whole KIND_CLOSED
    la t0, selector
    li t1, 0
    jab.sys.api.write t0, t1
    li t0, 1
    beq a0, t0, plain                       # no API on the machine: the plain run
    rdtime s7
    li t0, SELECT_WAIT
    add s7, s7, t0                          # the selector's deadline
1:
    la s4, selector
    jab.sys.api.read s4, 1
    bnez a0, 2f                             # it came
    rdtime t0
    bgeu t0, s7, no_scenario
    jab.sys.await JAB_AWAIT_DISPLAY | JAB_AWAIT_API
    j 1b
2:
    jab.sys.display.open
    bnez a0, no_display
    lbu t0, 0(s4)
    li t1, 'l'
    beq t0, t1, list
    li t1, 'b'
    beq t0, t1, long
    li t1, 't'
    beq t0, t1, transfer
    li t1, 'f'
    beq t0, t1, flush
    li t1, 's'
    beq t0, t1, held
no_scenario:
    jab.sys.uart.print msg_no_scenario
    jab.sys.exit 2

plain:
    jab.sys.display.open
    bnez a0, no_display
    li s1, FLIPS
1:
    flip_whole KIND_BURST
    addi s1, s1, -1
    bnez s1, 1b
    li s1, FLIPS / 2
3:
    jab.sys.display.await
    flip_whole KIND_WHOLE
    bnez a0, flip_failed
    addi s1, s1, -1
    bnez s1, 3b
    li s1, FLIPS / 2
4:
    jab.sys.display.await
    li a0, 100
    li a1, 100
    li a2, 50
    li a3, 50
    flip_rect KIND_RECT
    bnez a0, flip_failed
    addi s1, s1, -1
    bnez s1, 4b
    jab.sys.display.await
    li a0, 1900
    li a1, 0
    li a2, 100
    li a3, 10
    flip_rect KIND_BADRECT
    jab.sys.display.await
    la t0, two_rects
    li t1, 2
    flip_rects KIND_RECTS, t0, t1
    jab.sys.display.await
    la t0, bad_rects
    li t1, 2
    flip_rects KIND_BADRECTS, t0, t1
    la t0, two_rects
    li t1, 0
    flip_rects KIND_NORECTS, t0, t1
    jab.sys.display.await
    flip_whole KIND_BEFORE_PRINT
    jab.sys.display.print msg_print
    jab.sys.display.await
    flip_whole KIND_AFTER_PRINT
    call report
    jab.sys.kernel.flags
    la a1, flags_digits
    call two_digits
    jab.sys.uart.print flags
    jab.sys.uart.print paced
    jab.sys.exit 0

list:
    li a0, OLD
    call fill
    jab.sys.display.await
    flip_whole KIND_OLD
    li a0, NEW
    call fill
    jab.sys.display.await
    la t0, three_rects
    li t1, 3
    flip_rects KIND_LIST, t0, t1
    call report
    j idle

long:
    jab.sys.display.await
    la t0, long_rects
    li t1, LIST_LONG
    flip_rects KIND_LONG, t0, t1
    call report
    jab.sys.uart.print msg_done
    jab.sys.exit 0

transfer:
    li a0, OLD
    call fill
    jab.sys.display.await
    flip_whole KIND_OLD
    li a0, NEW
    call fill
    jab.sys.display.await
    flip_whole KIND_BADXFER
    call report
    j idle

flush:
    jab.sys.display.await
    flip_whole KIND_BADFLUSH
    call report
    jab.sys.uart.print msg_done
    jab.sys.exit 0

held:
    jab.sys.display.await
    flip_whole KIND_HELD
    rdtime s7
    li t0, HELD_WAIT
    add s7, s7, t0                          # long enough for the held source's window
1:
    jab.sys.display.await
    rdtime t0
    bltu t0, s7, 1b
    li a1, SENTINEL
    li a2, SENTINEL
    li a3, SENTINEL
    flip_whole KIND_FAILED
    call report
    jab.sys.uart.print msg_done
    jab.sys.exit 0

idle:
    jab.sys.uart.print msg_done
1:
    jab.sys.display.await
    j 1b

no_display:
    jab.sys.uart.print msg_no_display
    jab.sys.exit 1

flip_failed:
    jab.sys.uart.print msg_flip_failed
    jab.sys.exit 2

keep:
    la t0, receipt_count
    ld t1, 0(t0)
    li t2, RECEIPTS
    bgeu t1, t2, 1f                         # full: nothing kept, which the test counts
    slli t3, t1, 6
    la t4, receipts
    add t3, t3, t4
    sd t6, 0(t3)
    sd a0, 8(t3)
    sd s8, 16(t3)
    sd a1, 24(t3)
    sd a2, 32(t3)
    sd a3, 40(t3)
    sd s9, 48(t3)
    addi t1, t1, 1
    sd t1, 0(t0)
1:
    ret

report:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    sd s2, 0(sp)
    li s0, 0                                # the receipt
1:
    la t0, receipt_count
    ld t0, 0(t0)
    bgeu s0, t0, 9f
    slli s1, s0, 6
    la t0, receipts
    add s1, s1, t0
    li s2, 0                                # its field
2:
    slli t0, s2, 3
    add t0, t0, s1
    ld a0, 0(t0)
    li t1, 17
    mul t1, t1, s2
    la a1, line
    add a1, a1, t1
    addi a1, a1, 8
    call put_hex
    addi s2, s2, 1
    li t0, 7
    bltu s2, t0, 2b
    jab.sys.uart.print line
    addi s0, s0, 1
    j 1b
9:
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 32
    ret

put_hex:
    li t0, 60
1:
    srl t1, a0, t0
    andi t1, t1, 15
    li t2, 10
    bltu t1, t2, 2f
    addi t1, t1, 'a' - 10
    j 3f
2:
    addi t1, t1, '0'
3:
    sb t1, 0(a1)
    addi a1, a1, 1
    addi t0, t0, -4
    bgez t0, 1b
    ret

fill:
    li t0, JAB_DISPLAY_BASE
    li t1, JAB_DISPLAY_SIZE
    add t1, t1, t0
    slli t2, a0, 32
    or t2, t2, a0                           # two pixels
1:
    sd t2, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 1b
    ret

two_digits:
    li t1, 10
    divu t2, a0, t1
    remu t3, a0, t1
    addi t2, t2, '0'
    addi t3, t3, '0'
    sb t2, 0(a1)
    sb t3, 1(a1)
    ret

.section .data
line:
    .ascii "receipt "
    .rept 6
    .ascii "0000000000000000 "
    .endr
    .ascii "0000000000000000\n"
    .byte 0
flags:
    .ascii "flags="
flags_digits:
    .asciz "00\n"

.section .rodata
.balign 4
two_rects:
    .word 100, 100, 50, 50
    .word 1000, 800, 200, 100
bad_rects:
    .word 100, 100, 50, 50
    .word 1000, 1070, 200, 100
three_rects:
    .word 100, 100, 200, 100
    .word 500, 100, 200, 100
    .word 900, 100, 200, 100
long_rects:
.set rect, 0
.rept LIST_LONG
    .word (rect * 40), 500, 10, 10
.set rect, rect + 1
.endr
paced:
    .asciz "paced\n"
msg_print:
    .asciz "framecap"
msg_done:
    .asciz "framecap: scenario done\n"
msg_no_scenario:
    .asciz "framecap: no scenario\n"
msg_no_display:
    .asciz "framecap: no display\n"
msg_flip_failed:
    .asciz "framecap: a flip after await failed\n"

.section .bss
.balign 8
receipt_count:
    .skip 8
receipts:
    .skip RECEIPTS * RECEIPT_BYTES
selector:
    .skip 8
