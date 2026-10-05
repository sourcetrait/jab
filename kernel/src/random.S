.include "riscv.inc"
.include "qemu_virt.inc"
.include "virtio.inc"
.include "jab.inc"

.section .text

.global sys_random
sys_random:
    ld a0, 80(sp)
    ld a1, 88(sp)
    call buffer_bounds
    call random_open
    bnez a0, 7f
    ld a1, 88(sp)
    beqz a1, 6f
    la t0, random_queue
    ld t1, 80(sp)
    sd t1, (VQ_DESC + VIRTQ_DESC_ADDR)(t0)
    sw a1, (VQ_DESC + VIRTQ_DESC_LEN)(t0)
    li t1, VIRTQ_DESC_F_WRITE
    sh t1, (VQ_DESC + VIRTQ_DESC_FLAGS)(t0)
    sh zero, (VQ_DESC + VIRTQ_DESC_NEXT)(t0)
    lhu t1, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    andi t2, t1, VIRTQ_SIZE - 1
    slli t2, t2, 1
    add t2, t2, t0
    sh zero, (VQ_AVAIL + VIRTQ_AVAIL_RING)(t2)
    fence w, w
    addi t1, t1, 1
    sh t1, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    fence rw, rw
    la t0, random_base
    ld a0, 0(t0)
    sw zero, VIRTIO_MMIO_QUEUE_NOTIFY(a0)
    call irq_mmio_source
    mv a1, a0
    la a0, random_queue
    call virtio_wait_used
    bnez a1, 7f                 # its source stuck: no answer
    ld t1, VQ_LAST_USED(a0)
    andi t2, t1, VIRTQ_SIZE - 1
    slli t2, t2, 3
    add t2, t2, a0
    lwu t3, (VQ_USED + VIRTQ_USED_RING + VIRTQ_USED_ELEM_LEN)(t2)
    addi t1, t1, 1
    li t2, 0xffff
    and t1, t1, t2
    sd t1, VQ_LAST_USED(a0)
    sd zero, 80(sp)
    sd t3, 88(sp)
    j trap_return
6:
    sd zero, 80(sp)
    sd zero, 88(sp)
    j trap_return
7:
    li a0, 1
    sd a0, 80(sp)
    sd zero, 88(sp)
    j trap_return

random_open:
    la t0, random_state
    ld t0, 0(t0)
    beqz t0, 1f
    addi a0, t0, -1
    ret
1:
    addi sp, sp, -16
    sd ra, 8(sp)
    li a0, VIRTIO_ID_RNG
    call virtio_find
    beqz a0, 5f
    la t0, random_base
    sd a0, 0(t0)
.ifdef DEBUG
    la a0, msg_rng_at
    call debug_puts
    la t0, random_base
    ld a0, 0(t0)
    call debug_put_hex
    li a0, '\n'
    call debug_putc
    la t0, random_base
    ld a0, 0(t0)
.pushsection .rodata
msg_rng_at:
    .asciz "jab: rng at "
.popsection
.endif
    call virtio_init
    bnez a0, 6f
    la t0, random_base
    ld a0, 0(t0)
    li a1, 0
    la a2, random_queue
    call virtio_queue_setup
    bnez a0, 6f
    la t0, random_base
    ld a0, 0(t0)
    call virtio_driver_ok
    la t0, random_base
    ld a0, 0(t0)
    la a1, random_progress
    la a2, random_fault
    call virtio_irq_enable
    la t0, random_state
    li t1, 1
    sd t1, 0(t0)
    li a0, 0
    j 8f
5:
.ifdef DEBUG
    la a0, msg_no_rng
    call debug_puts
.pushsection .rodata
msg_no_rng:
    .asciz "jab: no rng\n"
.popsection
.endif
    la t0, random_state
    li t1, 2
    sd t1, 0(t0)
    li a0, 1
    j 8f
6:
    la t0, random_state
    li t1, 3
    sd t1, 0(t0)
    li a0, 2
8:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

random_progress:
    la t0, random_queue
    lhu a0, (VQ_USED + VIRTQ_USED_IDX)(t0)
    ret

random_fault:
    la t0, random_state
    li t1, 3
    sd t1, 0(t0)
    ret

.section .bss
.balign 16
random_queue:
    .skip VQ_BYTES
.balign 8
random_base:
    .skip 8
random_state:
    .skip 8
