.include "jab.inc"

.section .text
.global _start
_start:
    la t0, disks
    jab.sys.block.list t0
    mv s0, a0                   # the records written
    mv s1, a1                   # where the next page would start
    la s2, disks
    li s3, 0
1:
    bgeu s3, s0, 2f
    call line_reset
    la a0, word_disk
    call line_str
    lbu a0, JAB_BLOCK_ID(s2)
    call line_dec
    la a0, word_kind
    call line_str
    lbu a0, JAB_BLOCK_KIND(s2)
    call line_dec
    la a0, word_sectors
    call line_str
    ld a0, JAB_BLOCK_SECTORS(s2)
    call line_dec
    la a0, word_serial
    call line_str
    addi a0, s2, JAB_BLOCK_SERIAL
    call line_str
    call line_nl
    jab.sys.uart.print line
    addi s3, s3, 1
    li t0, JAB_BLOCK_ENTRY
    add s2, s2, t0
    j 1b
2:
    call line_reset
    la a0, word_count
    call line_str
    mv a0, s0
    call line_dec
    la a0, word_next
    call line_str
    mv a0, s1
    call line_dec
    call line_nl
    jab.sys.uart.print line
    la t0, sector
    li t1, 1
    li t2, 0
    li t3, 1
    jab.sys.block.write t0, t1, t2, t3
    mv s4, a0
    call line_reset
    la a0, word_write
    call line_str
    mv a0, s4
    call line_dec
    call line_nl
    jab.sys.uart.print line
    jab.sys.exit 0

line_reset:
    la t0, line
    la t1, lineptr
    sd t0, 0(t1)
    ret

line_char:
    la t1, lineptr
    ld t0, 0(t1)
    sb a0, 0(t0)
    addi t0, t0, 1
    sd t0, 0(t1)
    ret

line_nl:
    la t1, lineptr
    ld t0, 0(t1)
    li t2, '\n'
    sb t2, 0(t0)
    addi t0, t0, 1
    sb zero, 0(t0)
    sd t0, 0(t1)
    ret

line_str:
    mv t2, a0
    la t1, lineptr
    ld t0, 0(t1)
1:
    lbu t3, 0(t2)
    beqz t3, 2f
    sb t3, 0(t0)
    addi t0, t0, 1
    addi t2, t2, 1
    j 1b
2:
    sd t0, 0(t1)
    ret

line_dec:
    mv t2, a0
    la t1, lineptr
    ld t0, 0(t1)
    la t4, digits
    addi t4, t4, 31
    sb zero, 0(t4)
    li t5, 10
1:
    remu t6, t2, t5
    divu t2, t2, t5
    addi t6, t6, '0'
    addi t4, t4, -1
    sb t6, 0(t4)
    bnez t2, 1b
2:
    lbu t6, 0(t4)
    beqz t6, 3f
    sb t6, 0(t0)
    addi t0, t0, 1
    addi t4, t4, 1
    j 2b
3:
    sd t0, 0(t1)
    ret

.section .rodata
word_disk:
    .asciz "disk "
word_kind:
    .asciz " kind "
word_sectors:
    .asciz " sectors "
word_serial:
    .asciz " serial "
word_count:
    .asciz "count "
word_next:
    .asciz " next "
word_write:
    .asciz "write "

.section .bss
.balign 8
disks:
    .skip JAB_BLOCK_LIST_SIZE
sector:
    .skip JAB_BLOCK_SECTOR
line:
    .skip 256
lineptr:
    .skip 8
digits:
    .skip 32
