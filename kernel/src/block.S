.include "riscv.inc"
.include "qemu_virt.inc"
.include "virtio.inc"
.include "pci.inc"
.include "jab.inc"

.section .text

.global sys_block_list
sys_block_list:
    call block_probe
    ld s0, 88(sp)
    la t0, block_count
    ld s1, 0(t0)
    beqz s0, 1f
    addi s0, s0, -1             # an id is one more than its index
1:
    bgeu s0, s1, 8f
    sub s2, s1, s0              # disks from here on
    ld s3, 96(sp)
    bltu s3, s2, 2f
    mv s3, s2                   # never more than there are
2:
    beqz s3, 8f
    li t0, JAB_BLOCK_ENTRY
    mul s4, s3, t0              # bytes to write
    mul s5, s0, t0              # where they start
    ld a0, 80(sp)
    mv a1, s4
    call buffer_bounds
    ld a0, 80(sp)
    la a1, block_records
    add a1, a1, s5
    mv a2, s4
    call copy_bytes
    add t0, s0, s3
    li a1, 0
    bgeu t0, s1, 3f
    addi a1, t0, 1
3:
    mv a0, s3
    j 9f
8:
    li a0, 0
    li a1, 0
9:
    sd a0, 80(sp)
    sd a1, 88(sp)
    j trap_return

.global sys_block_find
sys_block_find:
    call block_probe
    ld a0, 80(sp)
    call message_bounds
    mv s0, a0                   # the serial asked for
    mv s1, a1                   # the window's end
    la s2, block_records
    li s3, 0
    la t0, block_count
    ld s4, 0(t0)
1:
    bgeu s3, s4, 8f
    mv t0, s0
    addi t1, s2, JAB_BLOCK_SERIAL
    li t2, JAB_BLOCK_SERIAL_BYTES
2:
    bgeu t0, s1, 8f             # the string runs past the window
    lbu t3, 0(t0)
    lbu t4, 0(t1)
    bne t3, t4, 4f
    beqz t3, 7f                 # both ended here
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, 2b
    bgeu t0, s1, 8f
    lbu t3, 0(t0)
    beqz t3, 7f
4:
    addi s3, s3, 1
    li t0, JAB_BLOCK_ENTRY
    add s2, s2, t0
    j 1b
7:
    addi a0, s3, 1
    j 9f
8:
    li a0, 0
9:
    sd a0, 80(sp)
    j trap_return

.global sys_block_read
sys_block_read:
    li s0, VIRTIO_BLK_T_IN
    li s1, VIRTQ_DESC_F_WRITE
    j block_transfer

.global sys_block_write
sys_block_write:
    li s0, VIRTIO_BLK_T_OUT
    li s1, 0
    j block_transfer

block_transfer:
    call block_probe
    ld s2, 88(sp)               # the disk
    ld s3, 96(sp)               # the first sector
    ld s4, 104(sp)              # how many
    la t0, block_count
    ld t0, 0(t0)
    li a0, 1
    beqz s2, 9f
    bgtu s2, t0, 9f
    addi t1, s2, -1
    li t2, JAB_BLOCK_ENTRY
    mul t1, t1, t2
    la s5, block_records
    add s5, s5, t1
    lbu t3, JAB_BLOCK_KIND(s5)
    li a0, 2
    beqz t3, 9f                 # the disk never came up
    li a0, 4
    beqz s4, 9f
    ld t4, JAB_BLOCK_SECTORS(s5)
    bgtu s3, t4, 9f
    sub t5, t4, s3
    bgtu s4, t5, 9f
    li t6, JAB_BLOCK_SECTOR
    mul s6, s4, t6              # the bytes it moves
    ld a0, 80(sp)
    mv a1, s6
    call buffer_bounds
    addi s7, s2, -1
    mv a0, s7
    call block_queue
    mv a1, a0
    mv a0, s7
    call block_base
    mv a2, s0
    mv a3, s3
    ld a4, 80(sp)
    mv a5, s6
    mv a6, s1
    call block_request
    li t0, VIRTIO_BLK_S_OK
    beq a0, t0, 8f
    li a0, 3
    j 9f
8:
    li a0, 0
9:
    sd a0, 80(sp)
    j trap_return

.global block_base
block_base:
    slli t0, a0, 3
    la t1, block_bases
    add t1, t1, t0
    ld a0, 0(t1)
    ret

.global block_queue
block_queue:
    li t0, VQ_STRIDE
    mul t0, a0, t0
    la t1, block_queues
    add a0, t1, t0
    ret

.global block_record
block_record:
    li t0, JAB_BLOCK_ENTRY
    mul t0, a0, t0
    la t1, block_records
    add a0, t1, t0
    ret

.global block_count_of
block_count_of:
    la t0, block_count
    ld a0, 0(t0)
    ret

.global block_probe
block_probe:
    la t0, block_probed
    ld t0, 0(t0)
    bnez t0, 9f
    addi sp, sp, -48
    sd ra, 40(sp)
    la t0, block_probed
    li t1, 1
    sd t1, 0(t0)                # once, whatever comes of it
    call pci_scan
    sd zero, 0(sp)              # the PCI device being looked at
    sd zero, 16(sp)             # disks found so far
1:
    call pci_count_of
    ld t0, 0(sp)
    bgeu t0, a0, 8f
    ld t0, 16(sp)
    li t1, JAB_BLOCK_MAX
    bgeu t0, t1, 8f
    ld a0, 0(sp)
    call pci_device
    sd a0, 8(sp)                # its record
    lwu t1, PCI_DEV_VIRTIO_ID(a0)
    li t2, VIRTIO_ID_BLOCK
    bne t1, t2, 7f
    ld a0, 16(sp)
    call block_record
    sd a0, 24(sp)
    ld t0, 16(sp)
    addi t1, t0, 1
    sb t1, JAB_BLOCK_ID(a0)
    sb zero, JAB_BLOCK_KIND(a0)
    ld a0, 16(sp)
    call block_queue
    sd a0, 32(sp)
    ld t0, 16(sp)
    slli t0, t0, 3
    la t1, block_bases
    add t1, t1, t0
    ld t2, 8(sp)
    sd t2, 0(t1)
.ifdef DEBUG
    la a0, msg_disk_pci
    call debug_puts
    ld t0, 8(sp)
    lbu a0, PCI_DEV_SLOT(t0)
    call debug_put_dec
    li a0, '\n'
    call debug_putc
.pushsection .rodata
msg_disk_pci:
    .asciz "jab: disk on pci slot "
.popsection
.endif
    ld a0, 8(sp)
    call vpci_init
    bnez a0, 6f
    ld a0, 8(sp)
    li a1, 0
    ld a2, 32(sp)
    call vpci_queue_setup
    bnez a0, 6f
    ld a0, 8(sp)
    call vpci_driver_ok
    ld t0, 8(sp)
    lbu a0, PCI_DEV_LINE(t0)
    beqz a0, 2f
    la a1, block_progress
    la a2, block_fault
    call irq_enable
2:
    ld t0, 8(sp)
    ld t0, PCI_DEV_DEVICE_CFG(t0)
    lwu t1, VIRTIO_BLK_CFG_CAPACITY_LOW(t0)
    lwu t2, VIRTIO_BLK_CFG_CAPACITY_HIGH(t0)
    slli t2, t2, 32
    or t1, t1, t2
    ld t3, 24(sp)
    sd t1, JAB_BLOCK_SECTORS(t3)
    addi t4, t3, JAB_BLOCK_SERIAL
    sd zero, 0(t4)
    sd zero, 8(t4)
    sw zero, 16(t4)
    ld a0, 8(sp)
    ld a1, 32(sp)
    li a2, VIRTIO_BLK_T_GET_ID
    li a3, 0
    ld a4, 24(sp)
    addi a4, a4, JAB_BLOCK_SERIAL
    li a5, VIRTIO_BLK_ID_BYTES
    li a6, VIRTQ_DESC_F_WRITE
    call block_request
    ld a0, 8(sp)
    ld a1, 32(sp)
    li a2, VIRTIO_BLK_T_IN
    li a3, 0
    la a4, block_bounce
    li a5, JAB_BLOCK_SECTOR
    li a6, VIRTQ_DESC_F_WRITE
    call block_request
    ld t3, 24(sp)
    li t0, JAB_BLOCK_KIND_RAW
    sb t0, JAB_BLOCK_KIND(t3)
    bnez a0, 6f
    la a0, block_bounce
    call romfs_magic
    beqz a0, 6f
    ld t3, 24(sp)
    li t0, JAB_BLOCK_KIND_ROMFS
    sb t0, JAB_BLOCK_KIND(t3)
6:
    ld t0, 16(sp)
    addi t0, t0, 1
    sd t0, 16(sp)
7:
    ld t0, 0(sp)
    addi t0, t0, 1
    sd t0, 0(sp)
    j 1b
8:
    ld t0, 16(sp)
    la t1, block_count
    sd t0, 0(t1)
    ld ra, 40(sp)
    addi sp, sp, 48
9:
    ret

.global block_request
block_request:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd a0, 0(sp)
    sd a1, 8(sp)
    la t0, block_header
    sw a2, VIRTIO_BLK_REQ_TYPE(t0)
    sw zero, VIRTIO_BLK_REQ_IOPRIO(t0)
    sd a3, VIRTIO_BLK_REQ_SECTOR(t0)
    la t1, block_status
    li t2, 0xff
    sb t2, 0(t1)                # so an unanswered request cannot read OK
    mv t3, a1
    sd t0, (VQ_DESC + 0 * VIRTQ_DESC_SIZE + VIRTQ_DESC_ADDR)(t3)
    li t4, VIRTIO_BLK_REQ_SIZE
    sw t4, (VQ_DESC + 0 * VIRTQ_DESC_SIZE + VIRTQ_DESC_LEN)(t3)
    li t4, VIRTQ_DESC_F_NEXT
    sh t4, (VQ_DESC + 0 * VIRTQ_DESC_SIZE + VIRTQ_DESC_FLAGS)(t3)
    li t4, 1
    sh t4, (VQ_DESC + 0 * VIRTQ_DESC_SIZE + VIRTQ_DESC_NEXT)(t3)
    sd a4, (VQ_DESC + 1 * VIRTQ_DESC_SIZE + VIRTQ_DESC_ADDR)(t3)
    sw a5, (VQ_DESC + 1 * VIRTQ_DESC_SIZE + VIRTQ_DESC_LEN)(t3)
    ori t4, a6, VIRTQ_DESC_F_NEXT
    sh t4, (VQ_DESC + 1 * VIRTQ_DESC_SIZE + VIRTQ_DESC_FLAGS)(t3)
    li t4, 2
    sh t4, (VQ_DESC + 1 * VIRTQ_DESC_SIZE + VIRTQ_DESC_NEXT)(t3)
    sd t1, (VQ_DESC + 2 * VIRTQ_DESC_SIZE + VIRTQ_DESC_ADDR)(t3)
    li t4, 1
    sw t4, (VQ_DESC + 2 * VIRTQ_DESC_SIZE + VIRTQ_DESC_LEN)(t3)
    li t4, VIRTQ_DESC_F_WRITE
    sh t4, (VQ_DESC + 2 * VIRTQ_DESC_SIZE + VIRTQ_DESC_FLAGS)(t3)
    sh zero, (VQ_DESC + 2 * VIRTQ_DESC_SIZE + VIRTQ_DESC_NEXT)(t3)
    lhu t4, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(t3)
    andi t5, t4, VIRTQ_SIZE - 1
    slli t5, t5, 1
    add t5, t5, t3
    sh zero, (VQ_AVAIL + VIRTQ_AVAIL_RING)(t5)
    fence w, w
    addi t4, t4, 1
    sh t4, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(t3)
    fence rw, rw
    ld a0, 0(sp)
    li a1, 0
    call vpci_notify
    ld t0, 0(sp)
    lbu a1, PCI_DEV_LINE(t0)    # its source
    ld a0, 8(sp)
    call virtio_wait_used
    bnez a1, 1f                 # its line stuck: the status unanswered
    ld t2, VQ_LAST_USED(a0)
    addi t2, t2, 1
    li t0, 0xffff
    and t2, t2, t0
    sd t2, VQ_LAST_USED(a0)
1:
    la t0, block_status
    lbu a0, 0(t0)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

block_progress:
    mv t6, a0                   # the line
    li a0, 0
    la t0, block_count
    ld t0, 0(t0)
    li t1, 0                    # the disk
1:
    bgeu t1, t0, 9f
    slli t2, t1, 3
    la t3, block_bases
    add t3, t3, t2
    ld t3, 0(t3)
    lbu t2, PCI_DEV_LINE(t3)
    bne t2, t6, 2f
    li t2, VQ_STRIDE
    mul t2, t2, t1
    la t3, block_queues
    add t3, t3, t2
    lhu t2, (VQ_USED + VIRTQ_USED_IDX)(t3)
    add a0, a0, t2
2:
    addi t1, t1, 1
    j 1b
9:
    ret

block_fault:
    la t0, block_count
    ld t0, 0(t0)
    li t1, 0                    # the disk
1:
    bgeu t1, t0, 9f
    slli t2, t1, 3
    la t3, block_bases
    add t3, t3, t2
    ld t3, 0(t3)
    lbu t2, PCI_DEV_LINE(t3)
    bne t2, a0, 2f
    li t2, JAB_BLOCK_ENTRY
    mul t2, t2, t1
    la t3, block_records
    add t3, t3, t2
    sb zero, JAB_BLOCK_KIND(t3) # down: its calls answer that it never came up
2:
    addi t1, t1, 1
    j 1b
9:
    ret

.section .bss
.balign 16
block_queues:
    .skip JAB_BLOCK_MAX * VQ_STRIDE
.balign 8
block_records:
    .skip JAB_BLOCK_LIST_SIZE
block_bases:
    .skip JAB_BLOCK_MAX * 8
block_count:
    .skip 8
block_probed:
    .skip 8
block_header:
    .skip VIRTIO_BLK_REQ_SIZE
block_status:
    .skip 8
.balign 8
.global block_bounce
block_bounce:
    .skip JAB_BLOCK_SECTOR
