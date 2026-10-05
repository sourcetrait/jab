.include "jab.inc"
.include "dtb.inc"

.set FILE_BYTES, 65536

.section .text
.global _start
_start:
    call line_reset
    jab.sys.block.find serial_dtb
    beqz a0, 90f
    mv s0, a0                               # the disk
    la s1, files
1:
    ld s2, 0(s1)
    beqz s2, 2f
    mv a0, s2
    call load
    bltz a0, 91f
    mv a1, a0
    la a0, tree
    call dtb_check
    mv s3, a0
    la a0, word_check
    call line_str
    addi a0, s2, 1                          # the name past its /
    call line_str
    li a0, ' '
    call line_char
    mv a0, s3
    call line_dec
    call line_print
    addi s1, s1, 8
    j 1b
2:
    la s2, path_good
    mv a0, s2
    call load
    bltz a0, 91f
    mv a1, a0
    la a0, tree
    call dtb_check
    bnez a0, 92f
    la a0, tree
    la a1, path_cpus
    call dtb_path
    beqz a0, 93f
    mv s1, a0                               # /cpus
    la a0, tree
    mv a1, s1
    la a2, word_address_cells
    call dtb_prop
    beqz a0, 93f
    dtb_be32 s3, a0
    la a0, word_cells
    call line_str
    mv a0, s3
    call line_dec
    call line_print
    li s2, 0                                # the child before
    li s3, 0                                # the cpus counted
3:
    la a0, tree
    mv a1, s1
    mv a2, s2
    call dtb_child
    beqz a0, 4f
    mv s2, a0
    la a0, tree
    mv a1, s2
    la a2, word_device_type
    call dtb_prop
    beqz a0, 3b
    la a2, word_cpu
    call dtb_equals
    add s3, s3, a0
    j 3b
4:
    la a0, word_cpus
    call line_str
    mv a0, s3
    call line_dec
    call line_print
    la a0, tree
    mv a1, s1
    la a2, word_timebase
    call dtb_prop
    beqz a0, 93f
    dtb_be32 s3, a0
    la a0, word_timebase_line
    call line_str
    mv a0, s3
    call line_dec
    call line_print
    la a0, path_cpu2
    call print_reg
    la a0, path_cpu
    call print_reg
    la a0, tree
    la a1, path_intc1
    call dtb_path
    beqz a0, 93f
    mv s2, a0                               # cpu@1's interrupt controller
    la a0, tree
    mv a1, s2
    la a2, word_phandle
    call dtb_prop
    beqz a0, 93f
    dtb_be32 s3, a0                         # its phandle
    la a0, tree
    mv a1, s3
    call dtb_phandle
    mv s1, a0                               # the node the phandle names
    la a0, word_phandle_line
    call line_str
    mv a0, s3
    call line_dec
    li a0, ' '
    call line_char
    la a0, word_same
    bne s1, s2, 5f
    call line_str
    j 6f
5:
    la a0, word_other
    call line_str
6:
    li a0, ' '
    call line_char
    la a0, tree
    mv a1, s1
    call dtb_name
    call line_str
    call line_print
    la a0, tree
    la a1, path_chosen
    call dtb_path
    beqz a0, 93f
    mv a1, a0
    la a0, tree
    la a2, word_bootargs
    call dtb_prop
    beqz a0, 93f
    mv s3, a0
    la a0, word_bootargs_line
    call line_str
    mv a0, s3
    call line_str
    call line_print
    la s1, absent
7:
    ld s2, 0(s1)
    beqz s2, 8f
    la a0, tree
    mv a1, s2
    call dtb_path
    la t0, word_found
    beqz a0, 71f
    mv a0, t0
    j 72f
71:
    la a0, word_absent
72:
    call line_str
    mv a0, s2
    call line_str
    call line_print
    addi s1, s1, 8
    j 7b
8:
    jab.sys.exit 0
90:
    la a0, msg_no_disk
    j 99f
91:
    la a0, word_missing
    call line_str
    mv a0, s2
    call line_str
    call line_print
    jab.sys.exit 1
92:
    la a0, msg_good_refused
    j 99f
93:
    la a0, msg_lookup
99:
    call line_str
    call line_print
    jab.sys.exit 1

print_reg:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s4, 16(sp)
    mv s4, a0                               # the path
    mv a1, a0
    la a0, tree
    call dtb_path
    beqz a0, 1f
    mv a1, a0
    la a0, tree
    la a2, word_reg
    call dtb_prop
    li t0, 4
    bne a1, t0, 1f
    dtb_be32 t1, a0
    sd t1, 8(sp)
    la a0, word_reg_line
    call line_str
    mv a0, s4
    call line_str
    li a0, ' '
    call line_char
    ld a0, 8(sp)
    call line_dec
    call line_print
    j 2f
1:
    la a0, word_reg_line
    call line_str
    mv a0, s4
    call line_str
    la a0, word_none
    call line_str
    call line_print
2:
    ld ra, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 32
    ret

load:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    mv a3, a0
    la a0, rec
    mv a1, s0
    li a2, JAB_ROMFS_ROOT
    li a7, JAB_SYS_ROMFS_FIND
    ecall
    bnez a0, 8f
    la t0, rec
    lwu s4, JAB_ROMFS_OFFSET(t0)            # the file
    li s5, 0                                # its bytes read
1:
    li a4, FILE_BYTES
    sub a4, a4, s5
    beqz a4, 2f
    la a0, tree
    add a0, a0, s5
    mv a1, s0
    mv a2, s4
    mv a3, s5
    li a7, JAB_SYS_ROMFS_READ
    ecall
    beqz a0, 2f
    add s5, s5, a0
    bnez a1, 1b
2:
    mv a0, s5
    j 9f
8:
    li a0, -1
9:
    ld ra, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 32
    ret

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

line_print:
    la t1, lineptr
    ld t0, 0(t1)
    li t2, '\n'
    sb t2, 0(t0)
    sb zero, 1(t0)
    la a0, line
    li a7, JAB_SYS_UART_PRINT
    ecall
    j line_reset

.include "dtb.S"

.section .rodata
.balign 8
files:
    .quad path_good
    .quad path_magic
    .quad path_version
    .quad path_lastcomp
    .quad path_size
    .quad path_block
    .quad path_cut
    .quad path_name
    .quad path_prop
    .quad path_strings
    .quad path_token
    .quad path_deep16
    .quad path_deep17
    .quad 0
absent:
    .quad path_cpus
    .quad path_root
    .quad path_nope
    .quad path_cpu9
    .quad path_cpus_trailing
    .quad 0

path_good:
    .asciz "/good.dtb"
path_magic:
    .asciz "/magic.dtb"
path_version:
    .asciz "/version.dtb"
path_lastcomp:
    .asciz "/lastcomp.dtb"
path_size:
    .asciz "/size.dtb"
path_block:
    .asciz "/block.dtb"
path_cut:
    .asciz "/cut.dtb"
path_name:
    .asciz "/name.dtb"
path_prop:
    .asciz "/prop.dtb"
path_strings:
    .asciz "/strings.dtb"
path_token:
    .asciz "/token.dtb"
path_deep16:
    .asciz "/deep16.dtb"
path_deep17:
    .asciz "/deep17.dtb"

path_root:
    .asciz "/"
path_cpus:
    .asciz "/cpus"
path_cpus_trailing:
    .asciz "/cpus/"
path_cpu:
    .asciz "/cpus/cpu"
path_cpu2:
    .asciz "/cpus/cpu@2"
path_cpu9:
    .asciz "/cpus/cpu@9"
path_intc1:
    .asciz "/cpus/cpu@1/interrupt-controller"
path_chosen:
    .asciz "/chosen"
path_nope:
    .asciz "/nope"

serial_dtb:
    .asciz "dtb"
word_check:
    .asciz "check "
word_cells:
    .asciz "cells "
word_cpus:
    .asciz "cpus "
word_timebase_line:
    .asciz "timebase "
word_reg_line:
    .asciz "reg "
word_none:
    .asciz " none"
word_phandle_line:
    .asciz "phandle "
word_same:
    .asciz "same"
word_other:
    .asciz "other"
word_bootargs_line:
    .asciz "bootargs "
word_found:
    .asciz "found "
word_absent:
    .asciz "absent "
word_missing:
    .asciz "missing "
word_address_cells:
    .asciz "#address-cells"
word_device_type:
    .asciz "device_type"
word_cpu:
    .asciz "cpu"
word_timebase:
    .asciz "timebase-frequency"
word_reg:
    .asciz "reg"
word_phandle:
    .asciz "phandle"
word_bootargs:
    .asciz "bootargs"
msg_no_disk:
    .asciz "no disk of serial dtb"
msg_good_refused:
    .asciz "the good tree refused"
msg_lookup:
    .asciz "a lookup failed"

.section .bss
.balign 8
tree:
    .skip FILE_BYTES
rec:
    .skip JAB_ROMFS_ENTRY
line:
    .skip 512
lineptr:
    .skip 8
digits:
    .skip 32
