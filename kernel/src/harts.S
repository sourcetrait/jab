.include "riscv.inc"
.include "qemu_virt.inc"
.include "jab.inc"
.include "dtb.inc"
.include "aia.inc"
.include "hart.inc"

.set HARTS_PROBLEMS, 8
.set HARTS_PROBLEM_BYTES, 16
.set PROBLEM_CELLS, 1
.set PROBLEM_REG, 2
.set PROBLEM_PAST_MAX, 3
.set PROBLEM_NO_BOOT, 4
.set BOOT_ARGS_BYTES, 256
.set STRAY_FILE, (QEMU_VIRT_IMSIC_S + 0x100000)

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
    la t0, harts_refused
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
    call uart_lock_fatal
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
    call uart_lock_fatal
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

.global hart_record
hart_record:
    li t0, HART_AREA_BYTES
    mul t0, a0, t0
    la a0, hart_areas
    add a0, a0, t0
    li t0, HART_STACK_BYTES
    add a0, a0, t0
    ret

.global hart_self_check
hart_self_check:
    sd a0, HART_ID(tp)
    li t0, HART_CANARY
    xor t0, t0, a0
    li t1, HART_STACK_BYTES
    sub t1, tp, t1                          # its stack's bottom
    sd t0, 0(t1)
    ld t2, 0(t1)
    bne t2, t0, 1f
    ld t2, HART_ID(tp)
    bne t2, a0, 1f
    li a0, 0
    j 2f
1:
    li a0, 1
2:
    sd a0, HART_RESULT(tp)
    ret

hart_swap:
    addi t0, a0, HART_STATE
1:
    lr.d.aqrl t1, (t0)
    bne t1, a1, 2f
    sc.d.rl t2, a2, (t0)
    bnez t2, 1b
    li a0, 1
    ret
2:
    li a0, 0
    ret

.global harts_masks
harts_masks:
    la t0, harts_discovered
    ld t0, 0(t0)
    li a0, 0                                # online
    li a1, 0                                # failed
    li a2, 0                                # released, not yet in
    li t1, 0                                # the hart
    la t2, hart_areas
    li t3, HART_STACK_BYTES
    add t2, t2, t3                          # its record
1:
    li t3, JAB_HARTS_MAX
    bgeu t1, t3, 9f
    srl t3, t0, t1
    andi t3, t3, 1
    beqz t3, 5f
    li t4, 1
    sll t4, t4, t1
    ld t3, HART_STATE(t2)
    li t5, HART_ONLINE
    bne t3, t5, 2f
    or a0, a0, t4
    j 5f
2:
    li t5, HART_FAILED
    bne t3, t5, 3f
    or a1, a1, t4
    j 5f
3:
    li t5, HART_RELEASED
    bne t3, t5, 5f
    or a2, a2, t4
5:
    addi t1, t1, 1
    li t3, HART_AREA_BYTES
    add t2, t2, t3
    j 1b
9:
    ret

.global harts_release
harts_release:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    la t0, harts_discovered
    ld s0, 0(t0)
    la t0, harts_refused
    ld s3, 0(t0)                            # parked by the tree's problem
    li s1, 1                                # the hart
1:
    li t0, JAB_HARTS_MAX
    bgeu s1, t0, 5f
    srl t0, s0, s1
    andi t0, t0, 1
    beqz t0, 4f                             # not in the tree
    mv a0, s1
    call hart_record
    mv s2, a0                               # its record
    srl t0, s3, s1
    andi t0, t0, 1
    beqz t0, 2f
    li t0, HART_WHY_TOPOLOGY
    j 31f
2:
    mv a0, s1
    call aia_file_page
    bnez a0, 3f
    li t0, HART_WHY_NO_FILE
31:
    sd t0, HART_WHY(s2)
    li t0, HART_FAILED
    sd t0, HART_STATE(s2)
    j 4f
3:
    li t0, HART_RELEASED
    sd t0, HART_STATE(s2)
    fence w, w                              # the state before the slot, whatever wakes the hart
    la t0, hart_release
    slli t1, s1, 3
    add t0, t0, t1
    sd s2, 0(t0)                            # the release: its record, its stack's top
    la t0, hart_wake_target
    sd a0, 0(t0)
    la t0, hart_wake_faulted
    sd zero, 0(t0)
    li t1, AIA_WAKE
    fence w, o                              # the record and the slot before the wake
.option push
.option norvc
33:
    sw t1, 0(a0)                            # no file there: a store access fault, which kernel_trap steps over
.option pop
.pushsection .rodata
.balign 8
.global hart_wake_store
hart_wake_store:
    .quad 33b
.popsection
    la t0, hart_wake_faulted
    ld t0, 0(t0)
    beqz t0, 4f
    mv a0, s2
    li a1, HART_RELEASED
    li a2, HART_FAILED
    call hart_swap
    beqz a0, 4f                             # in after all
    li t0, HART_WHY_NO_FILE
    sd t0, HART_WHY(s2)
4:
    addi s1, s1, 1
    j 1b
5:
    rdtime t0
    li t1, HART_CHECKIN_TICKS
    add s3, t0, t1                          # the check-in's bound
6:
    call harts_masks
    beqz a2, 8f                             # every released hart in
    rdtime t0
    bgeu t0, s3, 7f
    csrw stimecmp, s3
    li t0, (SIE_STIE | SIE_SEIE)
    csrs sie, t0
    wfi
    call irq_drain
    call irq_report
    j 6b
7:
    mv s0, a2                               # still released at the bound
    li s1, 1
71:
    li t0, JAB_HARTS_MAX
    bgeu s1, t0, 8f
    srl t0, s0, s1
    andi t0, t0, 1
    beqz t0, 72f
    mv a0, s1
    call hart_record
    mv s2, a0
    li a1, HART_RELEASED
    li a2, HART_FAILED
    call hart_swap
    beqz a0, 72f                            # in at the last
    li t0, HART_WHY_NO_CHECKIN
    sd t0, HART_WHY(s2)
72:
    addi s1, s1, 1
    j 71b
8:
    li t0, (SIE_STIE | SIE_SEIE)
    csrc sie, t0
    li t0, -1
    csrw stimecmp, t0
.ifdef DEBUG
    la a0, knob_stray
    call knob_value
    li t0, 1
    bne a0, t0, 9f
    li t0, STRAY_FILE
    sw zero, 0(t0)                          # the release's fault at another store and address
.pushsection .rodata
knob_stray:
    .asciz "jab.stray="
.popsection
9:
.endif
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 48
    ret

.global hart_main
hart_main:
    mv s0, a0                               # its hart, as machine mode hands it
    call hart_record
    mv tp, a0
    la t0, trap_vector
    csrw stvec, t0
    li t0, SSTATUS_SUM
    csrs sstatus, t0
    li t0, (SSTATUS_FS_INITIAL | SSTATUS_VS_INITIAL)
    csrs sstatus, t0
    csrw sie, zero
    li t0, -1
    csrw stimecmp, t0
    li t0, SCOUNTEREN_ALL
    csrw scounteren, t0
    li t0, (SENVCFG_CBZE | SENVCFG_CBCFE | SENVCFG_CBIE_FLUSH)
    csrs senvcfg, t0
    csrw sscratch, zero                     # its interrupt file open since the park
    mv a0, s0
    call hart_self_check
    mv s1, a0                               # 0, or its id or canary read back wrong
.ifdef DEBUG
    la a0, knob_late
    call knob_value
    bne a0, s0, 2f
1:
    ld t0, HART_STATE(tp)                   # held until hart 0 gives up on it
    li t1, HART_FAILED
    beq t0, t1, 2f
    pause
    j 1b
.pushsection .rodata
knob_late:
    .asciz "jab.late="
.popsection
2:
.endif
    mv a0, tp
    li a1, HART_RELEASED
    li a2, HART_ONLINE
    beqz s1, 3f
    li a2, HART_FAILED                      # its self-check failed: out by its own hand
3:
    call hart_swap
    beqz a0, 8f                             # FAILED by hart 0 first: the race lost
    call hart_wake_boot
    bnez s1, 8f
    li t0, SIE_SEIE
    csrs sie, t0
4:
    wfi                                     # idle until a start request
    call irq_drain
    j 4b
8:
    csrw sie, zero                          # parked for the run, touching nothing
9:
    wfi
    j 9b

hart_wake_boot:
    addi sp, sp, -16
    sd ra, 8(sp)
    li a0, 0
    call aia_file_page
    li t1, AIA_WAKE
    fence w, o                              # its record before the wake
    sw t1, 0(a0)
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
    sd s2, 0(sp)
    call harts_masks
    mv s1, a0
    mv s2, a1
    la a0, msg_harts
    call debug_puts
    la t0, harts_discovered
    ld a0, 0(t0)
    call debug_put_hex
    la a0, msg_online
    call debug_puts
    mv a0, s1
    call debug_put_hex
    la a0, msg_failed
    call debug_puts
    mv a0, s2
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
    li s1, 0                                # every discovered hart's line
81:
    li t0, JAB_HARTS_MAX
    bgeu s1, t0, 89f
    la t0, harts_discovered
    ld t0, 0(t0)
    srl t0, t0, s1
    andi t0, t0, 1
    beqz t0, 88f
    mv a0, s1
    call hart_record
    mv s2, a0
    la a0, msg_hart
    call debug_puts
    mv a0, s1
    call debug_put_dec
    ld t0, HART_STATE(s2)
    fence r, r                              # its state before what its swap published
    li t1, HART_ONLINE
    bne t0, t1, 84f
    ld t0, HART_ID(s2)
    bne t0, s1, 83f
    ld t0, HART_RESULT(s2)
    bnez t0, 83f
    li t0, HART_CANARY
    xor t0, t0, s1
    li t1, HART_STACK_BYTES
    sub t1, s2, t1
    ld t1, 0(t1)
    bne t0, t1, 83f
    la a0, msg_hart_online
    j 87f
83:
    la a0, msg_hart_overwritten
    j 87f
84:
    la a0, msg_hart_unsettled
    li t1, HART_FAILED
    bne t0, t1, 87f
    ld t0, HART_WHY(s2)
    la a0, msg_hart_self_check              # no reason of hart 0's: out by its own hand
    beqz t0, 87f
    la a0, msg_hart_topology
    li t1, HART_WHY_TOPOLOGY
    beq t0, t1, 87f
    la a0, msg_hart_no_file
    li t1, HART_WHY_NO_FILE
    beq t0, t1, 87f
    la a0, msg_hart_no_checkin
87:
    call debug_puts
88:
    addi s1, s1, 1
    j 81b
89:
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    ld s2, 0(sp)
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
msg_hart_online:
    .asciz " online\n"
msg_hart_overwritten:
    .asciz " online, its record or canary wrong\n"
msg_hart_topology:
    .asciz " failed: topology\n"
msg_hart_no_file:
    .asciz " failed: no interrupt file\n"
msg_hart_no_checkin:
    .asciz " failed: no check-in\n"
msg_hart_self_check:
    .asciz " failed: self-check\n"
msg_hart_unsettled:
    .asciz " unsettled\n"
.popsection
.endif

.ifdef DEBUG
.global knob_value
knob_value:
    la t0, boot_args
1:
    lbu t1, 0(t0)                           # a token's start
    beqz t1, 8f
    li t2, ' '
    bne t1, t2, 2f
    addi t0, t0, 1
    j 1b
2:
    mv t3, t0
    mv t4, a0
3:
    lbu t5, 0(t4)
    beqz t5, 5f                             # the whole name, its '=' with it
    lbu t6, 0(t3)
    bne t5, t6, 4f
    addi t3, t3, 1
    addi t4, t4, 1
    j 3b
4:
    lbu t1, 0(t0)                           # another token: past it
    beqz t1, 8f
    li t2, ' '
    beq t1, t2, 1b
    addi t0, t0, 1
    j 4b
5:
    li t4, 0                                # the value
    li t2, 0                                # its digits
6:
    lbu t5, 0(t3)
    addi t5, t5, -'0'
    li t6, 10
    bgeu t5, t6, 7f
    li t6, 10
    mul t4, t4, t6
    add t4, t4, t5
    addi t3, t3, 1
    addi t2, t2, 1
    j 6b
7:
    beqz t2, 8f                             # no digits: no value
    lbu t5, 0(t3)
    beqz t5, 71f
    li t6, ' '
    bne t5, t6, 8f                          # a digit run with more after it
71:
    mv a0, t4
    ret
8:
    li a0, -1
    ret
.endif

.global sys_harts
sys_harts:
    call harts_masks
    sd a0, 88(sp)
    sd a1, 96(sp)
    la t0, harts_discovered
    ld t1, 0(t0)
    sd t1, 80(sp)
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

.section .data
.balign 8
.global hart_release
hart_release:
    .skip (JAB_HARTS_MAX * 8)

.section .bss
.balign 8
.global harts_discovered
harts_discovered:
    .skip 8
harts_refused:
    .skip 8
.global harts_intc
harts_intc:
    .skip (JAB_HARTS_MAX * 4)
harts_problem_count:
    .skip 8
harts_problems:
    .skip (HARTS_PROBLEMS * HARTS_PROBLEM_BYTES)
.global hart_wake_target
hart_wake_target:
    .skip 8
.global hart_wake_faulted
hart_wake_faulted:
    .skip 8
.ifdef DEBUG
boot_args:
    .skip BOOT_ARGS_BYTES
.endif
.balign 16
.global hart_areas
hart_areas:
    .skip (JAB_HARTS_MAX * HART_AREA_BYTES)
