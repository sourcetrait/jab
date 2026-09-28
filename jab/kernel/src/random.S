.include "riscv.inc"
.include "qemu_virt.inc"
.include "virtio.inc"
.include "jab.inc"

# Random bytes: QEMU's virtio-rng device, the entropy device, over the
# mmio transport, id 4, on the line since the start and drawn from
# here. One queue: the driver offers a buffer the device may write and
# the device fills it with random bytes from the host's own source,
# saying how many it wrote, which is the whole buffer from QEMU's
# default backend but need not be by the specification. The device
# comes up on the first call and the program's own buffer is what the
# device writes, so nothing is copied.

.section .text

# sys_random (jab.random): a0 is a buffer inside the program's window,
# a1 how many bytes. a0 becomes 0 with the bytes written and a1 how
# many the device gave, or 1 with no rng device on the machine.
.global sys_random
sys_random:
    ld a0, 80(sp)
    ld a1, 88(sp)
    call buffer_bounds
    call random_open
    bnez a0, 7f
    ld a1, 88(sp)
    beqz a1, 6f
    # one descriptor the device writes, offered in the next slot
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
    ld t0, 0(t0)
    sw zero, VIRTIO_MMIO_QUEUE_NOTIFY(t0)
    la a0, random_queue
    call virtio_wait_used
    # the used element says how many bytes the device wrote
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

# random_open: find the rng device and bring it up, its queue set up
# and its line let through. Returns 0, or 1 with no rng device on the
# machine, 2 when the device refuses the kernel; asked again it
# answers as before at once. Keeps the s registers.
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

.section .bss
.balign 16
random_queue:
    .skip VQ_BYTES
.balign 8
random_base:
    .skip 8
random_state:
    .skip 8
