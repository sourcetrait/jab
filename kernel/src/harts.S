.include "riscv.inc"
.include "qemu_virt.inc"
.include "jab.inc"
.include "dtb.inc"

.set HARTS_PROBLEMS, 8
.set HARTS_PROBLEM_BYTES, 16
.set PROBLEM_CELLS, 1
.set PROBLEM_REG, 2
.set PROBLEM_PAST_MAX, 3
.set PROBLEM_NO_BOOT, 4
.set BOOT_ARGS_BYTES, 256

.section .text

.global harts_topology
harts_topology:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    mv s0, a0                               # the tree
    li a1, DTB_MAX
    call dtb_check
    bnez a0, 90f
    li t0, 1
    la t1, harts_online
    sd t0, 0(t1)                            # hart 0 runs
    mv a0, s0
    la a1, path_cpus
    call dtb_path
    beqz a0, 91f
    mv s1, a0                               # /cpus
    mv a0, s0
    mv a1, s1
    call timebase_of
    sd a0, 0(sp)                            # /cpus's, a cpu's unless it has its own
    li s2, 0                                # the child before
    li s5, 0                                # a usable cpu met
10:
    mv a0, s0
    mv a1, s1
    mv a2, s2
    call dtb_child
    beqz a0, 12f
    mv s2, a0
    mv a0, s0
    mv a1, s2
    call cpu_usable
    beqz a0, 10b
    li s5, 1
    mv a0, s0
    mv a1, s2
    call timebase_of
    bnez a1, 11f
    ld a0, 0(sp)                            # none of its own
11:
    mv t1, a0
    li t0, QEMU_VIRT_TIMEBASE
    bne t1, t0, 92f
    j 10b
12:
    bnez s5, 13f
    ld t1, 0(sp)                            # no usable cpu: /cpus's is the timer
    li t0, QEMU_VIRT_TIMEBASE
    bne t1, t0, 92f
13:
    mv a0, s0
    mv a1, s1
    la a2, word_address_cells
    call dtb_prop
    li s3, 0                                # the cells a cpu's reg takes
    li t0, 4
    bne a1, t0, 1f
    dtb_be32 s3, a0
1:
    li t0, 1
    beq s3, t0, 2f
    li t0, 2
    beq s3, t0, 2f
    li a0, PROBLEM_CELLS
    mv a1, s3
    call harts_problem
    j 7f
2:
    li s2, 0                                # the child before
3:
    mv a0, s0
    mv a1, s1
    mv a2, s2
    call dtb_child
    beqz a0, 7f
    mv s2, a0
    mv a0, s0
    mv a1, s2
    call cpu_usable
    beqz a0, 3b                             # not a cpu, or disabled
    mv a0, s0
    mv a1, s2
    la a2, word_reg
    call dtb_prop
    slli t0, s3, 2
    bne a1, t0, 5f                          # absent, or not the cells' width
    dtb_be32 s4, a0                         # the hart's id
    li t0, 2
    bne s3, t0, 41f
    dtb_be32 t1, a0, 4
    slli s4, s4, 32
    or s4, s4, t1
41:
    li t0, JAB_HARTS_MAX
    bgeu s4, t0, 6f
    li t0, 1
    sll t0, t0, s4
    la t1, harts_discovered
    ld t2, 0(t1)
    or t2, t2, t0
    sd t2, 0(t1)
    li s5, 0                                # the cpu's child before
42:
    mv a0, s0
    mv a1, s2
    mv a2, s5
    call dtb_child
    beqz a0, 3b                             # no interrupt controller: its phandle stays 0
    mv s5, a0
    mv a0, s0
    mv a1, s5
    la a2, word_intc
    call dtb_named
    beqz a0, 42b
    mv a0, s0
    mv a1, s5
    la a2, word_phandle
    call dtb_prop
    li t0, 4
    bne a1, t0, 3b
    dtb_be32 t1, a0
    la t0, harts_intc
    slli t2, s4, 2
    add t0, t0, t2
    sw t1, 0(t0)
    j 3b
5:
    li a0, PROBLEM_REG
    li a1, 0
    call harts_problem
    j 3b
6:
    li a0, PROBLEM_PAST_MAX
    mv a1, s4
    call harts_problem
    j 3b
7:
    la t0, harts_discovered
    ld t1, 0(t0)
    andi t1, t1, 1
    bnez t1, 71f
    li a0, PROBLEM_NO_BOOT
    li a1, 0
    call harts_problem
71:
    la t0, harts_problem_count
    ld t1, 0(t0)
    beqz t1, 72f
    la t0, harts_discovered
    ld t1, 0(t0)
    andi t1, t1, -2
    la t0, harts_failed
    sd t1, 0(t0)                            # a problem keeps every other hart parked
72:
.ifdef DEBUG
    mv a0, s0
    la a1, path_chosen
    call dtb_path
    beqz a0, 8f
    mv a1, a0
    mv a0, s0
    la a2, word_bootargs
    call dtb_prop
    beqz a0, 8f
    li t0, (BOOT_ARGS_BYTES - 1)
    bleu a1, t0, 81f
    mv a1, t0
81:
    la t1, boot_args
82:
    beqz a1, 83f
    lbu t2, 0(a0)
    sb t2, 0(t1)
    addi a0, a0, 1
    addi t1, t1, 1
    addi a1, a1, -1
    j 82b
83:
    sb zero, 0(t1)
8:
.endif
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 64
    ret
90:
    mv s1, a0
    la a0, msg_tree_refused
    call uart_puts
    mv a0, s1
    call uart_put_dec
    li a0, '\n'
    call uart_putc
    li a0, 1
    j qemu_exit
91:
    li t1, 0                                # no /cpus: no timebase at all
92:
    mv s1, t1
    la a0, msg_timer
    call uart_puts
    mv a0, s1
    call uart_put_dec
    li a0, '\n'
    call uart_putc
    li a0, 1
    j qemu_exit

harts_problem:
    la t0, harts_problem_count
    ld t1, 0(t0)
    addi t2, t1, 1
    sd t2, 0(t0)
    li t2, HARTS_PROBLEMS
    bgeu t1, t2, 1f                         # past the table: counted, not named
    li t2, HARTS_PROBLEM_BYTES
    mul t1, t1, t2
    la t0, harts_problems
    add t0, t0, t1
    sd a0, 0(t0)
    sd a1, 8(t0)
1:
    ret

cpu_usable:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, a0
    mv s1, a1
    la a2, word_device_type
    call dtb_prop
    beqz a0, 2f                             # no device_type: not a cpu
    la a2, word_cpu
    call dtb_equals
    beqz a0, 2f
    mv a0, s0
    mv a1, s1
    la a2, word_status
    call dtb_prop
    beqz a0, 1f                             # no status: usable
    la a2, word_okay
    call dtb_equals
    j 3f
1:
    li a0, 1
    j 3f
2:
    li a0, 0
3:
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
    ret

timebase_of:
    addi sp, sp, -16
    sd ra, 8(sp)
    la a2, word_timebase
    call dtb_prop
    beqz a0, 3f                             # none
    li t0, 4
    beq a1, t0, 1f
    li t0, 8
    beq a1, t0, 2f
    li a0, 0                                # another length: unreadable
    j 4f
1:
    dtb_be32 a0, a0
    j 4f
2:
    dtb_be32 t1, a0                         # the high cell first
    dtb_be32 t2, a0, 4
    slli t1, t1, 32
    or a0, t1, t2
4:
    li a1, 1
    j 5f
3:
    li a1, 0
5:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.ifdef DEBUG
.global harts_report
harts_report:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    la a0, msg_harts
    call debug_puts
    la t0, harts_discovered
    ld a0, 0(t0)
    call debug_put_hex
    la a0, msg_online
    call debug_puts
    la t0, harts_online
    ld a0, 0(t0)
    call debug_put_hex
    la a0, msg_failed
    call debug_puts
    la t0, harts_failed
    ld a0, 0(t0)
    call debug_put_hex
    li a0, '\n'
    call debug_putc
    la t0, harts_problem_count
    ld s1, 0(t0)
    li t0, HARTS_PROBLEMS
    bleu s1, t0, 1f
    mv s1, t0
1:
    la s0, harts_problems
2:
    beqz s1, 7f
    ld t0, 0(s0)
    li t1, PROBLEM_CELLS
    beq t0, t1, 3f
    li t1, PROBLEM_REG
    beq t0, t1, 4f
    li t1, PROBLEM_PAST_MAX
    beq t0, t1, 5f
    la a0, msg_no_boot
    call debug_puts
    j 6f
3:
    la a0, msg_cells
    call debug_puts
    ld a0, 8(s0)
    call debug_put_dec
    li a0, '\n'
    call debug_putc
    j 6f
4:
    la a0, msg_reg
    call debug_puts
    j 6f
5:
    la a0, msg_hart
    call debug_puts
    ld a0, 8(s0)
    call debug_put_dec
    la a0, msg_past_max
    call debug_puts
6:
    addi s0, s0, HARTS_PROBLEM_BYTES
    addi s1, s1, -1
    j 2b
7:
    la t0, boot_args
    lbu t1, 0(t0)
    beqz t1, 8f
    la a0, msg_bootargs
    call debug_puts
    la a0, boot_args
    call debug_puts
    li a0, '\n'
    call debug_putc
8:
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
    ret
.pushsection .rodata
msg_harts:
    .asciz "jab: harts discovered "
msg_online:
    .asciz " online "
msg_failed:
    .asciz " failed "
msg_cells:
    .asciz "jab: cpus refused: #address-cells "
msg_reg:
    .asciz "jab: cpu refused: no reg its cells can read\n"
msg_hart:
    .asciz "jab: hart "
msg_past_max:
    .asciz " refused: past JAB_HARTS_MAX\n"
msg_no_boot:
    .asciz "jab: hart 0 not in the device tree\n"
msg_bootargs:
    .asciz "jab: bootargs "
.popsection
.endif

.global sys_harts
sys_harts:
    la t0, harts_discovered
    ld t1, 0(t0)
    sd t1, 80(sp)
    la t0, harts_online
    ld t1, 0(t0)
    sd t1, 88(sp)
    la t0, harts_failed
    ld t1, 0(t0)
    sd t1, 96(sp)
    j trap_return

.section .rodata
path_cpus:
    .asciz "/cpus"
word_timebase:
    .asciz "timebase-frequency"
word_address_cells:
    .asciz "#address-cells"
word_device_type:
    .asciz "device_type"
word_cpu:
    .asciz "cpu"
word_status:
    .asciz "status"
word_okay:
    .asciz "okay"
word_reg:
    .asciz "reg"
word_intc:
    .asciz "interrupt-controller"
word_phandle:
    .asciz "phandle"
msg_tree_refused:
    .asciz "jab: device tree refused: code "
msg_timer:
    .asciz "jab: timer unsupported: timebase-frequency "
.ifdef DEBUG
path_chosen:
    .asciz "/chosen"
word_bootargs:
    .asciz "bootargs"
.endif

.section .bss
.balign 8
.global harts_discovered
harts_discovered:
    .skip 8
.global harts_online
harts_online:
    .skip 8
.global harts_failed
harts_failed:
    .skip 8
.global harts_intc
harts_intc:
    .skip (JAB_HARTS_MAX * 4)
harts_problem_count:
    .skip 8
harts_problems:
    .skip (HARTS_PROBLEMS * HARTS_PROBLEM_BYTES)
.ifdef DEBUG
boot_args:
    .skip BOOT_ARGS_BYTES
.endif
