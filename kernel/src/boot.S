.include "riscv.inc"
.include "qemu_virt.inc"
.include "jab.inc"
.include "hart.inc"

.section .text.boot
.global _start
_start:
    li t0, -1
    csrw pmpaddr0, t0
    li t0, PMP_NAPOT_RWX
    csrw pmpcfg0, t0
    la t0, mtrap
    csrw mtvec, t0
    li t0, MEDELEG_ALL
    csrw medeleg, t0
    li t0, MIDELEG_S_ALL
    csrw mideleg, t0
    li t0, MIE_SEIE                         # the park's wake alone
    csrw mie, t0
    li t0, (MENVCFG_STCE | MENVCFG_CBZE | MENVCFG_CBCFE | MENVCFG_CBIE_FLUSH)
    csrs menvcfg, t0
    li t0, (MSTATEEN0_ENVCFG | MSTATEEN0_SVSLCT | MSTATEEN0_AIA | MSTATEEN0_IMSIC)
    csrs mstateen0, t0
    li t0, MCOUNTEREN_ALL
    csrw mcounteren, t0
    csrr t0, mstatus
    li t1, MSTATUS_MPP_MASK
    not t1, t1
    and t0, t0, t1
    li t1, MSTATUS_MPP_S
    or t0, t0, t1
    csrw mstatus, t0
    csrr t0, mhartid
    bnez t0, hart_park
    mv s1, a1                               # the device tree QEMU hands every hart
    la sp, hart_areas
    li t0, HART_STACK_BYTES
    add sp, sp, t0                          # hart 0's record, its stack's top
    la t0, _bss_start
    la t1, _bss_end
1:
    bgeu t0, t1, 2f
    sd zero, 0(t0)
    addi t0, t0, 8
    j 1b
2:
    mv a0, s1
    call harts_topology
    mv a0, s1
    call aia_topology
    call aia_root
    la t0, kmain
    csrw mepc, t0
    csrr a0, mhartid                        # kmain's hart
    mret

hart_park:
    mv s0, t0                               # its hart id
    li t1, JAB_HARTS_MAX
    bgeu s0, t1, 9f
    call aia_file_open                      # its supervisor file, the wake let through
    la s1, hart_release
    slli t1, s0, 3
    add s1, s1, t1                          # its release slot
1:
    wfi
    csrrw t1, CSR_STOPEI, zero              # the wake claimed, if it came
    fence iorw, rw
    ld s2, 0(s1)
    beqz s2, 1b                             # spurious: asleep again
    call page_activate
    mv sp, s2                               # its record, its stack's top
    la t1, hart_main
    csrw mepc, t1
    mv a0, s0
    mret
9:
    csrw mie, zero                          # past the harts the kernel keeps: parked for good
91:
    wfi
    j 91b

.balign 4
mtrap:
    call uart_lock_fatal
    la a0, msg_machine_trap
    call uart_puts
    csrr a0, mcause
    call uart_put_hex
    la a0, msg_mepc
    call uart_puts
    csrr a0, mepc
    call uart_put_hex
    la a0, msg_mtval
    call uart_puts
    csrr a0, mtval
    call uart_put_hex
    li a0, '\n'
    call uart_putc
    li a0, 1
    j qemu_exit

.section .rodata
msg_machine_trap:
    .asciz "jab: machine trap: cause="
msg_mepc:
    .asciz " epc="
msg_mtval:
    .asciz " tval="
