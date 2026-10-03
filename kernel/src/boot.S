.include "riscv.inc"
.include "qemu_virt.inc"

.section .text.boot
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park
    la sp, kernel_stack_top
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
    csrw mie, zero
    li t0, (MENVCFG_STCE | MENVCFG_CBZE | MENVCFG_CBCFE | MENVCFG_CBIE_FLUSH)
    csrs menvcfg, t0
    li t0, MSTATEEN0_ENVCFG
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
    la t0, kmain
    csrw mepc, t0
    mret

park:
    wfi
    j park

.balign 4
mtrap:
    j mtrap
