.include "riscv.inc"
.include "qemu_virt.inc"
.include "dtb.inc"
.ifndef RAM_READER
.include "jab.inc"
.endif

.set RAM_BANKS, 16
.set RAM_BANK_BYTES, 16
.set RAM_BANK_BASE, 0
.set RAM_BANK_END, 8
.set RAM_REACH, 0x4000000000            # Sv39's identity reach, the lower canonical half
.set RAM_OK, 0
.set RAM_NO_BANK, 1
.set RAM_CELLS, 2
.set RAM_REG, 3
.set RAM_EMPTY, 4
.set RAM_OVERFLOW, 5
.set RAM_OVERLAP, 6
.set RAM_LOW, 7
.set RAM_HIGH, 8
.set RAM_TOO_MANY, 9

.section .text

.global ram_banks
ram_banks:
    addi sp, sp, -96
    sd ra, 88(sp)
    sd s0, 80(sp)
    sd s1, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    sd s7, 24(sp)
    sd s8, 16(sp)
    sd s9, 8(sp)
    mv s0, a0                               # the tree
    mv s1, a1                               # the table
    mv s2, a2                               # its capacity
    li s3, 0                                # the banks
    la a1, ram_path_root
    call dtb_path
    beqz a0, 81f
    mv s4, a0                               # the root
    mv a0, s0
    mv a1, s4
    la a2, ram_word_address_cells
    call dtb_prop
    li t0, 4
    bne a1, t0, 82f
    dtb_be32 s5, a0                         # the cells a base takes
    mv a0, s0
    mv a1, s4
    la a2, ram_word_size_cells
    call dtb_prop
    li t0, 4
    bne a1, t0, 82f
    dtb_be32 s6, a0                         # the cells a size takes
    addi t0, s5, -1
    li t1, 1
    bgtu t0, t1, 82f                        # 1 or 2 cells alone
    addi t0, s6, -1
    bgtu t0, t1, 82f
    li s7, 0                                # the child before
1:
    mv a0, s0
    mv a1, s4
    mv a2, s7
    call dtb_child
    beqz a0, 6f
    mv s7, a0
    mv a0, s0
    mv a1, s7
    la a2, ram_word_device_type
    call dtb_prop
    beqz a0, 1b
    la a2, ram_word_memory
    call dtb_equals
    beqz a0, 1b                             # not a memory node
    mv a0, s0
    mv a1, s7
    la a2, ram_word_reg
    call dtb_prop
    beqz a1, 83f                            # absent or empty
    add t0, s5, s6
    slli t0, t0, 2                          # an entry's bytes
    remu t1, a1, t0
    bnez t1, 83f
    mv s8, a0                               # the entry
    add s9, a0, a1                          # the value's end
2:
    bgeu s8, s9, 1b
    mv a0, s8
    mv a1, s5
    call ram_cells
    mv t5, a0                               # the base
    slli t0, s5, 2
    add s8, s8, t0
    mv a0, s8
    mv a1, s6
    call ram_cells
    mv t6, a0                               # the size
    slli t0, s6, 2
    add s8, s8, t0
    beqz t6, 84f
    add t4, t5, t6                          # the end
    bltu t4, t5, 85f                        # past 2^64
    li t0, QEMU_VIRT_DRAM
    bltu t5, t0, 87f
    li t0, RAM_REACH
    bgtu t4, t0, 88f
    bgeu s3, s2, 89f
    li t0, RAM_BANK_BYTES
    mul t1, s3, t0
    add t1, t1, s1                          # the slot past the last
3:
    beq t1, s1, 4f                          # the first: in place
    ld t2, (RAM_BANK_BASE - RAM_BANK_BYTES)(t1)
    bleu t2, t5, 4f                         # the bank before lies lower: in place
    ld t3, (RAM_BANK_END - RAM_BANK_BYTES)(t1)
    sd t2, RAM_BANK_BASE(t1)
    sd t3, RAM_BANK_END(t1)                 # moved up a slot
    addi t1, t1, -RAM_BANK_BYTES
    j 3b
4:
    sd t5, RAM_BANK_BASE(t1)
    sd t4, RAM_BANK_END(t1)
    addi s3, s3, 1
    j 2b
6:
    beqz s3, 81f
    li t0, 1
7:
    bgeu t0, s3, 8f
    li t1, RAM_BANK_BYTES
    mul t1, t0, t1
    add t1, t1, s1
    ld t2, RAM_BANK_BASE(t1)
    ld t3, (RAM_BANK_END - RAM_BANK_BYTES)(t1)
    bltu t2, t3, 86f                        # it begins before the one below it ends
    addi t0, t0, 1
    j 7b
8:
    li a0, RAM_OK
    j 9f
81:
    li a0, RAM_NO_BANK
    j 9f
82:
    li a0, RAM_CELLS
    j 9f
83:
    li a0, RAM_REG
    j 9f
84:
    li a0, RAM_EMPTY
    j 9f
85:
    li a0, RAM_OVERFLOW
    j 9f
86:
    li a0, RAM_OVERLAP
    j 9f
87:
    li a0, RAM_LOW
    j 9f
88:
    li a0, RAM_HIGH
    j 9f
89:
    li a0, RAM_TOO_MANY
9:
    mv a1, s3
    ld ra, 88(sp)
    ld s0, 80(sp)
    ld s1, 72(sp)
    ld s2, 64(sp)
    ld s3, 56(sp)
    ld s4, 48(sp)
    ld s5, 40(sp)
    ld s6, 32(sp)
    ld s7, 24(sp)
    ld s8, 16(sp)
    ld s9, 8(sp)
    addi sp, sp, 96
    ret

ram_cells:
    dtb_be32 t0, a0
    li t1, 1
    beq a1, t1, 1f
    dtb_be32 t1, a0, 4
    slli t0, t0, 32
    or t0, t0, t1
1:
    mv a0, t0
    ret

.global ram_backed
ram_backed:
    li t0, 0                                # the bank
1:
    bgeu t0, a1, 8f
    li t1, RAM_BANK_BYTES
    mul t1, t0, t1
    add t1, t1, a0
    ld t2, RAM_BANK_BASE(t1)
    ld t3, RAM_BANK_END(t1)
    addi t0, t0, 1
    bltu a2, t2, 1b
    bgtu a3, t3, 1b
    li a0, 1
    ret
8:
    li a0, 0
    ret

.global ram_free
ram_free:
    li t0, 0                                # the bank
    li t4, 0                                # the free ranges
    mv t5, a4                               # the reservations' end, from RAM's base
1:
    bgeu t0, a1, 8f
    li t1, RAM_BANK_BYTES
    mul t1, t0, t1
    add t1, t1, a0
    ld t2, RAM_BANK_BASE(t1)
    ld t3, RAM_BANK_END(t1)
    addi t0, t0, 1
    bgeu t2, t5, 2f
    mv t2, t5                               # the reserved part left out
2:
    bgeu t2, t3, 1b                         # nothing past the reservations
    bgeu t4, a3, 8f                         # the view's table full
    li t1, RAM_BANK_BYTES
    mul t1, t4, t1
    add t1, t1, a2
    sd t2, RAM_BANK_BASE(t1)
    sd t3, RAM_BANK_END(t1)
    addi t4, t4, 1
    j 1b
8:
    mv a0, t4
    ret

.ifndef RAM_READER
.global ram_topology
ram_topology:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    sd s2, 0(sp)
    la a1, ram_bank_table
    li a2, RAM_BANKS
    call ram_banks
    bnez a0, 90f
    la t0, ram_bank_count
    sd a1, 0(t0)
    mv s0, a1
    li t0, 0                                # the bank
    li t1, 0                                # installed
    la t2, ram_bank_table
1:
    bgeu t0, s0, 2f
    ld t3, RAM_BANK_BASE(t2)
    ld t4, RAM_BANK_END(t2)
    sub t4, t4, t3
    add t1, t1, t4
    addi t2, t2, RAM_BANK_BYTES
    addi t0, t0, 1
    j 1b
2:
    la t0, ram_installed
    sd t1, 0(t0)
    la s1, ram_required
3:
    ld s2, 0(s1)                            # the range's name
    beqz s2, 4f
    la a0, ram_bank_table
    mv a1, s0
    ld a2, 8(s1)
    ld a3, 16(s1)
    call ram_backed
    beqz a0, 91f
    addi s1, s1, 24
    j 3b
4:
    la a0, ram_bank_table
    mv a1, s0
    la a2, ram_free_table
    li a3, RAM_BANKS
    li a4, JAB_STACK_TOP                    # the protected prefix, then the program's window
    call ram_free
    la t0, ram_free_count
    sd a0, 0(t0)
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 32
    ret
90:
    mv s0, a0
    call uart_lock_fatal
    la a0, msg_ram_refused
    call uart_puts
    mv a0, s0
    call uart_put_dec
    li a0, '\n'
    call uart_putc
    li a0, 1
    j qemu_exit
91:
    call uart_lock_fatal
    la a0, msg_ram_missing
    call uart_puts
    mv a0, s2
    call uart_puts
    la a0, msg_ram_colon
    call uart_puts
    ld a0, 8(s1)
    call uart_put_hex
    li a0, '-'
    call uart_putc
    ld a0, 16(s1)
    call uart_put_hex
    li a0, '\n'
    call uart_putc
    li a0, 1
    j qemu_exit

.ifdef DEBUG
.global ram_report
ram_report:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    la t0, ram_free_count
    ld s0, 0(t0)
    la s1, ram_free_table
    bnez s0, 1f
    la a0, msg_ram_free_none
    call debug_puts
    j 2f
1:
    beqz s0, 2f
    la a0, msg_ram_free
    call debug_puts
    ld a0, RAM_BANK_BASE(s1)
    call debug_put_hex
    li a0, '-'
    call debug_putc
    ld a0, RAM_BANK_END(s1)
    call debug_put_hex
    li a0, '\n'
    call debug_putc
    addi s1, s1, RAM_BANK_BYTES
    addi s0, s0, -1
    j 1b
2:
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
    ret
.endif
.endif

.section .rodata
ram_path_root:
    .asciz "/"
ram_word_address_cells:
    .asciz "#address-cells"
ram_word_size_cells:
    .asciz "#size-cells"
ram_word_device_type:
    .asciz "device_type"
ram_word_memory:
    .asciz "memory"
ram_word_reg:
    .asciz "reg"
.ifndef RAM_READER
msg_ram_refused:
    .asciz "jab: ram refused: code "
msg_ram_missing:
    .asciz "jab: ram missing for "
msg_ram_colon:
    .asciz ": "
ram_name_kernel:
    .asciz "the kernel"
ram_name_display:
    .asciz "the framebuffer"
ram_name_window:
    .asciz "the program's window"
.ifdef DEBUG
msg_ram_free:
    .asciz "jab: ram free "
msg_ram_free_none:
    .asciz "jab: ram free none\n"
.endif

.balign 8
ram_required:
    .quad ram_name_kernel, QEMU_VIRT_DRAM, _kernel_end
    .quad ram_name_display, JAB_DISPLAY_BASE, (JAB_DISPLAY_BASE + JAB_DISPLAY_SIZE)
    .quad ram_name_window, JAB_PROGRAM_BASE, JAB_STACK_TOP
    .quad 0

.section .bss
.balign 8
.global ram_installed
ram_installed:
    .skip 8
.global ram_bank_count
ram_bank_count:
    .skip 8
.global ram_bank_table
ram_bank_table:
    .skip (RAM_BANKS * RAM_BANK_BYTES)
.global ram_free_count
ram_free_count:
    .skip 8
.global ram_free_table
ram_free_table:
    .skip (RAM_BANKS * RAM_BANK_BYTES)
.endif
