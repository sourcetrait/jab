.include "riscv.inc"
.include "qemu_virt.inc"
.include "virtio.inc"

.section .text

.global virtio_find
virtio_find:
    li t0, QEMU_VIRT_VIRTIO0
    li t1, QEMU_VIRT_VIRTIO_COUNT
    li t2, VIRTIO_MAGIC
    li t3, VIRTIO_VERSION_MODERN
    li t5, QEMU_VIRT_VIRTIO_STRIDE
1:
    lwu t4, VIRTIO_MMIO_MAGIC_VALUE(t0)
    bne t4, t2, 2f
    lwu t4, VIRTIO_MMIO_VERSION(t0)
    bne t4, t3, 2f
    lwu t4, VIRTIO_MMIO_DEVICE_ID(t0)
    beq t4, a0, 3f
2:
    add t0, t0, t5
    addi t1, t1, -1
    bnez t1, 1b
    li a0, 0
    ret
3:
    mv a0, t0
    ret

.global virtio_init
.global virtio_init_with
virtio_init:
    li a1, 0
virtio_init_with:
    sw zero, VIRTIO_MMIO_STATUS(a0)
    li t0, VIRTIO_STATUS_ACKNOWLEDGE
    sw t0, VIRTIO_MMIO_STATUS(a0)
    li t0, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER
    sw t0, VIRTIO_MMIO_STATUS(a0)
    sw zero, VIRTIO_MMIO_DRIVER_FEATURES_SEL(a0)
    sw a1, VIRTIO_MMIO_DRIVER_FEATURES(a0)
    li t0, VIRTIO_F_VERSION_1_WORD
    sw t0, VIRTIO_MMIO_DRIVER_FEATURES_SEL(a0)
    li t0, VIRTIO_F_VERSION_1_BIT
    sw t0, VIRTIO_MMIO_DRIVER_FEATURES(a0)
    li t0, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK
    sw t0, VIRTIO_MMIO_STATUS(a0)
    lwu t1, VIRTIO_MMIO_STATUS(a0)
    andi t1, t1, VIRTIO_STATUS_FEATURES_OK
    beqz t1, 1f
    li a0, 0
    ret
1:
    li a0, 1
    ret

.global virtio_queue_setup
virtio_queue_setup:
    sw a1, VIRTIO_MMIO_QUEUE_SEL(a0)
    lwu t0, VIRTIO_MMIO_QUEUE_NUM_MAX(a0)
    li t1, VIRTQ_SIZE
    bltu t0, t1, 1f
    sw t1, VIRTIO_MMIO_QUEUE_NUM(a0)
    addi t0, a2, VQ_DESC
    srli t1, t0, 32
    sw t0, VIRTIO_MMIO_QUEUE_DESC_LOW(a0)
    sw t1, VIRTIO_MMIO_QUEUE_DESC_HIGH(a0)
    addi t0, a2, VQ_AVAIL
    srli t1, t0, 32
    sw t0, VIRTIO_MMIO_QUEUE_DRIVER_LOW(a0)
    sw t1, VIRTIO_MMIO_QUEUE_DRIVER_HIGH(a0)
    addi t0, a2, VQ_USED
    srli t1, t0, 32
    sw t0, VIRTIO_MMIO_QUEUE_DEVICE_LOW(a0)
    sw t1, VIRTIO_MMIO_QUEUE_DEVICE_HIGH(a0)
    li t0, 1
    fence ow, o
    sw t0, VIRTIO_MMIO_QUEUE_READY(a0)
    li a0, 0
    ret
1:
    li a0, 1
    ret

.global virtio_driver_ok
virtio_driver_ok:
    li t0, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK | VIRTIO_STATUS_DRIVER_OK
    fence ow, o
    sw t0, VIRTIO_MMIO_STATUS(a0)
    ret

.global virtio_reset
virtio_reset:
    addi t0, a0, -QEMU_VIRT_VIRTIO_IRQ0
    li t1, QEMU_VIRT_VIRTIO_STRIDE
    mul t0, t0, t1
    li t1, QEMU_VIRT_VIRTIO0
    add t0, t0, t1                          # its transport
    sw zero, VIRTIO_MMIO_STATUS(t0)
    rdtime t2
    li t1, VIRTIO_RESET_TICKS
    add t2, t2, t1                          # the readback's bound, from the write's end
1:
    lwu t1, VIRTIO_MMIO_STATUS(t0)
    beqz t1, 2f
    rdtime t3
    bltu t3, t2, 1b
    j device_reset_refused
2:
    ret

.global device_reset_refused
device_reset_refused:
    mv a1, a0                               # the source
    la a0, msg_reset_refused
    j fatal_dec

.global virtio_wait_used
virtio_wait_used:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd a0, 0(sp)
    sd a1, 8(sp)
    sd zero, 16(sp)                         # whether its source failed
    li t4, SIE_SEIE
    csrs sie, t4
1:
    la t0, irq_faulted
    ld t0, 0(t0)
    ld t1, 8(sp)
    srl t0, t0, t1
    andi t0, t0, 1
    bnez t0, 21f                            # failed: whatever the used ring says
    ld a0, 0(sp)
    fence rw, rw
    lhu t0, (VQ_USED + VIRTQ_USED_IDX)(a0)
    ld t1, VQ_LAST_USED(a0)
    bne t0, t1, 2f
    wfi
    call irq_drain
    call irq_report
    j 1b
21:
    li t0, 1
    sd t0, 16(sp)
2:
    call irq_drain
    call irq_report
    la t0, irq_faulted
    ld t0, 0(t0)
    ld t1, 8(sp)
    srl t0, t0, t1
    andi t0, t0, 1
    beqz t0, 22f
    li t0, 1
    sd t0, 16(sp)                           # failed in the last drain: the completion does not count
22:
    la t4, sound_live
    ld t4, 0(t4)
    bnez t4, 3f
    li t4, SIE_SEIE
    csrc sie, t4
3:
    ld a0, 0(sp)
    ld a1, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

.global virtio_request
virtio_request:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a4, (VQ_DESC + 0 * VIRTQ_DESC_SIZE + VIRTQ_DESC_ADDR)(a2)
    sw a3, (VQ_DESC + 0 * VIRTQ_DESC_SIZE + VIRTQ_DESC_LEN)(a2)
    li t0, VIRTQ_DESC_F_NEXT
    sh t0, (VQ_DESC + 0 * VIRTQ_DESC_SIZE + VIRTQ_DESC_FLAGS)(a2)
    li t0, 1
    sh t0, (VQ_DESC + 0 * VIRTQ_DESC_SIZE + VIRTQ_DESC_NEXT)(a2)
    sd a5, (VQ_DESC + 1 * VIRTQ_DESC_SIZE + VIRTQ_DESC_ADDR)(a2)
    sw a6, (VQ_DESC + 1 * VIRTQ_DESC_SIZE + VIRTQ_DESC_LEN)(a2)
    li t0, VIRTQ_DESC_F_WRITE
    sh t0, (VQ_DESC + 1 * VIRTQ_DESC_SIZE + VIRTQ_DESC_FLAGS)(a2)
    sh zero, (VQ_DESC + 1 * VIRTQ_DESC_SIZE + VIRTQ_DESC_NEXT)(a2)
    lhu t0, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(a2)
    andi t1, t0, VIRTQ_SIZE - 1
    slli t1, t1, 1
    add t1, t1, a2
    sh zero, (VQ_AVAIL + VIRTQ_AVAIL_RING)(t1)
    fence w, w
    addi t0, t0, 1
    sh t0, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(a2)
    fence ow, o
    sw a1, VIRTIO_MMIO_QUEUE_NOTIFY(a0)
    call irq_mmio_source
    mv a1, a0
    mv a0, a2
    call virtio_wait_used
    bnez a1, 1f                             # its source stuck: the request abandoned
    ld t2, VQ_LAST_USED(a0)
    addi t2, t2, 1
    li t0, 0xffff
    and t2, t2, t0
    sd t2, VQ_LAST_USED(a0)
1:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.section .rodata
msg_reset_refused:
    .asciz "jab: device reset refused: source "
