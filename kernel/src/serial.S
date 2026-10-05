.include "riscv.inc"
.include "qemu_virt.inc"
.include "virtio.inc"
.include "jab.inc"

.set SERIAL_API_PORT, 2
.set SERIAL_API_RX_QUEUE, (2 * SERIAL_API_PORT + 2)
.set SERIAL_API_TX_QUEUE, (2 * SERIAL_API_PORT + 3)
.set API_BUFFER_BYTES, 256
.set API_RING_BYTES, (VIRTQ_SIZE * API_BUFFER_BYTES)
.set SERIAL_CONTROL_BYTES, 64
.set SERIAL_PAD_PORT, 3
.set SERIAL_PAD_RX_QUEUE, (2 * SERIAL_PAD_PORT + 2)
.set SERIAL_PAD_TX_QUEUE, (2 * SERIAL_PAD_PORT + 3)
.set PAD_PORT_BUFFER_BYTES, 256
.ifdef DEBUG
.set SERIAL_DEBUG_PORT, 1
.set SERIAL_DEBUG_TX_QUEUE, (2 * SERIAL_DEBUG_PORT + 3)
.set DEBUG_LINE_BYTES, 256
.endif

.section .text

.global serial_open
serial_open:
    la t0, serial_state
    ld t1, 0(t0)
    beqz t1, 1f
    addi a0, t1, -1
    ret
1:
    addi sp, sp, -16
    sd ra, 8(sp)
    li a0, VIRTIO_ID_CONSOLE
    call virtio_find
    beqz a0, 5f
    la t0, serial_base
    sd a0, 0(t0)
    li a1, VIRTIO_CONSOLE_F_MULTIPORT_BIT
    call virtio_init_with
    bnez a0, 6f
    la t0, serial_base
    ld a0, 0(t0)
    li a1, VIRTIO_CONSOLE_CONTROL_RX_QUEUE
    la a2, serial_control_rx_queue
    call virtio_queue_setup
    bnez a0, 6f
    la t0, serial_base
    ld a0, 0(t0)
    li a1, VIRTIO_CONSOLE_CONTROL_TX_QUEUE
    la a2, serial_control_tx_queue
    call virtio_queue_setup
    bnez a0, 6f
.ifdef DEBUG
    la t0, serial_base
    ld a0, 0(t0)
    li a1, SERIAL_DEBUG_TX_QUEUE
    la a2, serial_debug_tx_queue
    call virtio_queue_setup
    bnez a0, 6f
.endif
    la t0, serial_base
    ld a0, 0(t0)
    li a1, SERIAL_API_RX_QUEUE
    la a2, serial_api_rx_queue
    call virtio_queue_setup
    bnez a0, 6f
    la t0, serial_base
    ld a0, 0(t0)
    li a1, SERIAL_API_TX_QUEUE
    la a2, serial_api_tx_queue
    call virtio_queue_setup
    bnez a0, 6f
    la t0, serial_base
    ld a0, 0(t0)
    li a1, SERIAL_PAD_RX_QUEUE
    la a2, serial_pad_rx_queue
    call virtio_queue_setup
    bnez a0, 6f
    la t0, serial_base
    ld a0, 0(t0)
    li a1, SERIAL_PAD_TX_QUEUE
    la a2, serial_pad_tx_queue
    call virtio_queue_setup
    bnez a0, 6f
    la a0, serial_api_rx_queue
    la a1, serial_api_buffers
    li a2, API_BUFFER_BYTES
    call serial_stock
    la a0, serial_pad_rx_queue
    la a1, serial_pad_buffers
    li a2, PAD_PORT_BUFFER_BYTES
    call serial_stock
    la a0, serial_control_rx_queue
    la a1, serial_control_buffers
    li a2, SERIAL_CONTROL_BYTES
    call serial_stock
    la t0, serial_base
    ld a0, 0(t0)
    call virtio_driver_ok
    la t0, serial_base
    ld a0, 0(t0)
    la a1, serial_progress
    la a2, serial_fault
    call virtio_irq_enable
    la t0, serial_base
    ld t0, 0(t0)
    li t1, VIRTIO_CONSOLE_CONTROL_RX_QUEUE
    sw t1, VIRTIO_MMIO_QUEUE_NOTIFY(t0)
    la t0, serial_base
    ld t0, 0(t0)
    li t1, SERIAL_API_RX_QUEUE
    sw t1, VIRTIO_MMIO_QUEUE_NOTIFY(t0)
    la t0, serial_base
    ld t0, 0(t0)
    li t1, SERIAL_PAD_RX_QUEUE
    sw t1, VIRTIO_MMIO_QUEUE_NOTIFY(t0)
    li a0, VIRTIO_CONSOLE_DEVICE_READY
    li a1, 0
    li a2, 1
    call serial_control_send
    bnez a0, 6f                 # abandoned: its source failed
    call serial_control_drain
    bnez a0, 6f
.ifdef DEBUG
    la t0, serial_ports
    ld t0, 0(t0)
    srli t0, t0, SERIAL_DEBUG_PORT
    andi t0, t0, 1
    beqz t0, 3f
    li a0, VIRTIO_CONSOLE_PORT_OPEN
    li a1, SERIAL_DEBUG_PORT
    li a2, 1
    call serial_control_send
    bnez a0, 6f
    call serial_control_drain
    bnez a0, 6f
3:
.endif
    la t0, serial_ports
    ld t0, 0(t0)
    srli t0, t0, SERIAL_API_PORT
    andi t0, t0, 1
    beqz t0, 4f
    li a0, VIRTIO_CONSOLE_PORT_OPEN
    li a1, SERIAL_API_PORT
    li a2, 1
    call serial_control_send
    bnez a0, 6f
    call serial_control_drain
    bnez a0, 6f
4:
    la t0, serial_ports
    ld t0, 0(t0)
    srli t0, t0, SERIAL_PAD_PORT
    andi t0, t0, 1
    beqz t0, 41f
    li a0, VIRTIO_CONSOLE_PORT_OPEN
    li a1, SERIAL_PAD_PORT
    li a2, 1
    call serial_control_send
    bnez a0, 6f
    call serial_control_drain
    bnez a0, 6f
41:
.ifdef DEBUG
    la a0, knob_unsent
    call knob_value
    li t0, VIRTIO_ID_CONSOLE
    xor a0, a0, t0
    seqz a0, a0
    la t0, serial_unsent
    sd a0, 0(t0)
.pushsection .rodata
knob_unsent:
    .asciz "jab.unsent="
.popsection
.endif
    la t0, serial_state
    li t1, 1
    sd t1, 0(t0)
    li a0, 0
    j 8f
5:
    la t0, serial_state
    li t1, 2
    sd t1, 0(t0)
    li a0, 1
    j 8f
6:
    la t0, serial_state
    li t1, 3
    sd t1, 0(t0)
    li a0, 2
8:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

serial_stock:
    li t2, 0
1:
    slli t3, t2, 4
    add t3, t3, a0
    sd a1, (VQ_DESC + VIRTQ_DESC_ADDR)(t3)
    sw a2, (VQ_DESC + VIRTQ_DESC_LEN)(t3)
    li t4, VIRTQ_DESC_F_WRITE
    sh t4, (VQ_DESC + VIRTQ_DESC_FLAGS)(t3)
    sh zero, (VQ_DESC + VIRTQ_DESC_NEXT)(t3)
    slli t3, t2, 1
    add t3, t3, a0
    sh t2, (VQ_AVAIL + VIRTQ_AVAIL_RING)(t3)
    add a1, a1, a2
    addi t2, t2, 1
    li t3, VIRTQ_SIZE
    bltu t2, t3, 1b
    fence w, w
    sh t2, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(a0)
    fence rw, rw
    ret

serial_control_send:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, serial_control_message
    sw a1, VIRTIO_CONSOLE_CONTROL_ID(t0)
    sh a0, VIRTIO_CONSOLE_CONTROL_EVENT(t0)
    sh a2, VIRTIO_CONSOLE_CONTROL_VALUE(t0)
    la a0, serial_control_tx_queue
    li a1, VIRTIO_CONSOLE_CONTROL_TX_QUEUE
    mv a2, t0
    li a3, VIRTIO_CONSOLE_CONTROL_SIZE
    call serial_send
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

serial_control_drain:
    addi sp, sp, -32
    sd ra, 24(sp)
1:
    la t0, serial_control_rx_queue
    ld t1, VQ_LAST_USED(t0)
    fence rw, rw
    lhu t2, (VQ_USED + VIRTQ_USED_IDX)(t0)
    beq t2, t1, 9f
    andi t2, t1, VIRTQ_SIZE - 1
    slli t2, t2, 3
    add t2, t2, t0
    lwu t3, (VQ_USED + VIRTQ_USED_RING + VIRTQ_USED_ELEM_ID)(t2)
    li t4, SERIAL_CONTROL_BYTES
    mul t4, t4, t3
    la t5, serial_control_buffers
    add t4, t4, t5
    lwu t5, VIRTIO_CONSOLE_CONTROL_ID(t4)
    lhu t6, VIRTIO_CONSOLE_CONTROL_EVENT(t4)
    sd t5, 0(sp)                # the port the message is about
    sd t6, 8(sp)                # the event
    lhu t2, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    andi t4, t2, VIRTQ_SIZE - 1
    slli t4, t4, 1
    add t4, t4, t0
    sh t3, (VQ_AVAIL + VIRTQ_AVAIL_RING)(t4)
    fence w, w
    addi t2, t2, 1
    sh t2, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    addi t1, t1, 1
    li t2, 0xffff
    and t1, t1, t2
    sd t1, VQ_LAST_USED(t0)
    fence rw, rw
    la t0, serial_base
    ld t0, 0(t0)
    li t1, VIRTIO_CONSOLE_CONTROL_RX_QUEUE
    sw t1, VIRTIO_MMIO_QUEUE_NOTIFY(t0)
    ld t6, 8(sp)
    li t0, VIRTIO_CONSOLE_PORT_ADD
    bne t6, t0, 1b
    ld t5, 0(sp)
.ifdef DEBUG
    li t0, SERIAL_DEBUG_PORT
    beq t5, t0, 4f
.endif
    li t0, SERIAL_PAD_PORT
    beq t5, t0, 4f
    li t0, SERIAL_API_PORT
    bne t5, t0, 1b
4:
    la t0, serial_ports
    ld t1, 0(t0)
    li t2, 1
    sll t2, t2, t5
    or t1, t1, t2
    sd t1, 0(t0)
    li a0, VIRTIO_CONSOLE_PORT_READY
    mv a1, t5
    li a2, 1
    call serial_control_send
    beqz a0, 1b
    j 10f                       # abandoned: no more answers
9:
    li a0, 0
10:
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

.global serial_send
serial_send:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a2, (VQ_DESC + VIRTQ_DESC_ADDR)(a0)
    sw a3, (VQ_DESC + VIRTQ_DESC_LEN)(a0)
    sh zero, (VQ_DESC + VIRTQ_DESC_FLAGS)(a0)
    sh zero, (VQ_DESC + VIRTQ_DESC_NEXT)(a0)
    lhu t0, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(a0)
    andi t1, t0, VIRTQ_SIZE - 1
    slli t1, t1, 1
    add t1, t1, a0
    sh zero, (VQ_AVAIL + VIRTQ_AVAIL_RING)(t1)
    fence w, w
    addi t0, t0, 1
    sh t0, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(a0)
    fence rw, rw
.ifdef DEBUG
    li t0, SERIAL_API_TX_QUEUE
    bne a1, t0, 11f
    la t0, serial_unsent
    ld t0, 0(t0)
    bnez t0, 12f                # the knob: published, the device never told
11:
.endif
    la t0, serial_base
    ld t0, 0(t0)
    sw a1, VIRTIO_MMIO_QUEUE_NOTIFY(t0)
12:
    sd a0, 0(sp)
    call serial_source
    mv a1, a0
    ld a0, 0(sp)
    call virtio_wait_used
    bnez a1, 1f                 # its source failed: the bytes abandoned
    ld t2, VQ_LAST_USED(a0)
    addi t2, t2, 1
    li t0, 0xffff
    and t2, t2, t0
    sd t2, VQ_LAST_USED(a0)
    li a0, 0
    j 2f
1:
    li a0, 1
2:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.global serial_source
serial_source:
    la t0, serial_base
    ld a0, 0(t0)
    j irq_mmio_source

serial_progress:
    la t0, serial_control_rx_queue
    lhu a0, (VQ_USED + VIRTQ_USED_IDX)(t0)
    la t0, serial_control_tx_queue
    lhu t1, (VQ_USED + VIRTQ_USED_IDX)(t0)
    add a0, a0, t1
    la t0, serial_api_rx_queue
    lhu t1, (VQ_USED + VIRTQ_USED_IDX)(t0)
    add a0, a0, t1
    la t0, serial_api_tx_queue
    lhu t1, (VQ_USED + VIRTQ_USED_IDX)(t0)
    add a0, a0, t1
    la t0, serial_pad_rx_queue
    lhu t1, (VQ_USED + VIRTQ_USED_IDX)(t0)
    add a0, a0, t1
    la t0, serial_pad_tx_queue
    lhu t1, (VQ_USED + VIRTQ_USED_IDX)(t0)
    add a0, a0, t1
.ifdef DEBUG
    la t0, serial_debug_tx_queue
    lhu t1, (VQ_USED + VIRTQ_USED_IDX)(t0)
    add a0, a0, t1
.endif
    ret

serial_fault:
    la t0, serial_state
    li t1, 3
    sd t1, 0(t0)
    j pad_port_fault

.global api_up
api_up:
    la t0, serial_state
    ld t0, 0(t0)
    li t1, 1
    bne t0, t1, 1f
    la t0, serial_ports
    ld t0, 0(t0)
    srli t0, t0, SERIAL_API_PORT
    andi a0, t0, 1
    ret
1:
    li a0, 0
    ret

.global sys_api_write
sys_api_write:
    call api_up
    beqz a0, 8f
    ld a0, 80(sp)
    ld a1, 88(sp)
    call buffer_bounds
    ld a3, 88(sp)
    beqz a3, 7f
    ld a2, 80(sp)
    la a0, serial_api_tx_queue
    li a1, SERIAL_API_TX_QUEUE
    call serial_send
    bnez a0, 6f
7:
    sd zero, 80(sp)
    j trap_return
6:
    li a0, 2                    # interrupted: some of the bytes may have reached the host
    sd a0, 80(sp)
    j trap_return
8:
    li a0, 1
    sd a0, 80(sp)
    j trap_return

.global sys_api_read
sys_api_read:
    ld a0, 80(sp)
    ld a1, 88(sp)
    call buffer_bounds
    call api_up
    beqz a0, 9f
    call api_drain
    la t0, api_head
    ld t0, 0(t0)
    la t1, api_tail
    ld t1, 0(t1)
    sub t2, t0, t1              # bytes in the ring
    ld t3, 88(sp)
    bleu t2, t3, 1f
    mv t2, t3
1:
    ld a0, 80(sp)               # the program's buffer
    sd t2, 80(sp)               # the bytes written
    beqz t2, 3f
    la t4, api_ring
    li t5, API_RING_BYTES - 1
2:
    and t6, t1, t5
    add t6, t6, t4
    lbu a1, 0(t6)
    sb a1, 0(a0)
    addi a0, a0, 1
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, 2b
    la t0, api_tail
    sd t1, 0(t0)
3:
    call api_drain
    call api_waiting
    sd a0, 88(sp)
    j trap_return
9:
    sd zero, 80(sp)
    sd zero, 88(sp)
    j trap_return

api_drain:
    la t0, serial_api_rx_queue
    ld t1, VQ_LAST_USED(t0)
    li t6, 0
1:
    fence rw, rw
    lhu t2, (VQ_USED + VIRTQ_USED_IDX)(t0)
    beq t2, t1, 6f
    andi t2, t1, VIRTQ_SIZE - 1
    slli t2, t2, 3
    add t2, t2, t0
    lwu t3, (VQ_USED + VIRTQ_USED_RING + VIRTQ_USED_ELEM_ID)(t2)
    lwu t4, (VQ_USED + VIRTQ_USED_RING + VIRTQ_USED_ELEM_LEN)(t2)
    la t2, api_head
    ld t2, 0(t2)
    la t5, api_tail
    ld t5, 0(t5)
    sub t5, t2, t5
    li a0, API_RING_BYTES
    sub t5, a0, t5              # room
    bltu t5, t4, 6f
    li t5, API_BUFFER_BYTES
    mul t5, t5, t3
    la a0, serial_api_buffers
    add t5, t5, a0              # the buffer
    la a0, api_ring
    li a1, API_RING_BYTES - 1
2:
    beqz t4, 3f
    lbu a2, 0(t5)
    and a3, t2, a1
    add a3, a3, a0
    sb a2, 0(a3)
    addi t5, t5, 1
    addi t2, t2, 1
    addi t4, t4, -1
    j 2b
3:
    la a0, api_head
    sd t2, 0(a0)
    lhu t2, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    andi t4, t2, VIRTQ_SIZE - 1
    slli t4, t4, 1
    add t4, t4, t0
    sh t3, (VQ_AVAIL + VIRTQ_AVAIL_RING)(t4)
    fence w, w
    addi t2, t2, 1
    sh t2, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    addi t1, t1, 1
    li t2, 0xffff
    and t1, t1, t2
    sd t1, VQ_LAST_USED(t0)
    li t6, 1
    j 1b
6:
    beqz t6, 7f
    fence rw, rw
    la t0, serial_base
    ld t0, 0(t0)
    li t1, SERIAL_API_RX_QUEUE
    sw t1, VIRTIO_MMIO_QUEUE_NOTIFY(t0)
7:
    ret

api_waiting:
    la t0, api_head
    ld a0, 0(t0)
    la t0, api_tail
    ld t0, 0(t0)
    sub a0, a0, t0
    la t0, serial_api_rx_queue
    ld t1, VQ_LAST_USED(t0)
    fence rw, rw
    lhu t2, (VQ_USED + VIRTQ_USED_IDX)(t0)
1:
    beq t2, t1, 2f
    andi t3, t1, VIRTQ_SIZE - 1
    slli t3, t3, 3
    add t3, t3, t0
    lwu t4, (VQ_USED + VIRTQ_USED_RING + VIRTQ_USED_ELEM_LEN)(t3)
    add a0, a0, t4
    addi t1, t1, 1
    li t3, 0xffff
    and t1, t1, t3
    j 1b
2:
    ret

.global api_pending
api_pending:
    addi sp, sp, -16
    sd ra, 8(sp)
    call api_up
    beqz a0, 1f
    la t0, api_head
    ld t0, 0(t0)
    la t1, api_tail
    ld t1, 0(t1)
    bne t0, t1, 2f
    la t0, serial_api_rx_queue
    fence rw, rw
    lhu t1, (VQ_USED + VIRTQ_USED_IDX)(t0)
    ld t2, VQ_LAST_USED(t0)
    bne t1, t2, 2f
1:
    li a0, 0
    j 3f
2:
    li a0, 1
3:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.global pad_port_up
pad_port_up:
    la t0, serial_state
    ld t0, 0(t0)
    li t1, 1
    bne t0, t1, 1f
    la t0, serial_ports
    ld t0, 0(t0)
    srli t0, t0, SERIAL_PAD_PORT
    andi a0, t0, 1
    ret
1:
    li a0, 0
    ret

.global serial_pad_read
serial_pad_read:
    mv a2, a0                   # where the next byte goes
    mv a3, a1                   # the room left
    li a4, 0                    # the bytes copied
    li a5, 0                    # whether a buffer went back
    la t0, serial_pad_rx_queue
    ld t1, VQ_LAST_USED(t0)
1:
    fence rw, rw
    lhu t2, (VQ_USED + VIRTQ_USED_IDX)(t0)
    beq t2, t1, 6f
    andi t2, t1, VIRTQ_SIZE - 1
    slli t2, t2, 3
    add t2, t2, t0
    lwu t3, (VQ_USED + VIRTQ_USED_RING + VIRTQ_USED_ELEM_ID)(t2)
    lwu t4, (VQ_USED + VIRTQ_USED_RING + VIRTQ_USED_ELEM_LEN)(t2)
    bltu a3, t4, 6f             # no room for the whole of it
    li t5, PAD_PORT_BUFFER_BYTES
    mul t5, t5, t3
    la t6, serial_pad_buffers
    add t5, t5, t6              # the buffer
2:
    beqz t4, 3f
    lbu t6, 0(t5)
    sb t6, 0(a2)
    addi t5, t5, 1
    addi a2, a2, 1
    addi a3, a3, -1
    addi a4, a4, 1
    addi t4, t4, -1
    j 2b
3:
    lhu t2, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    andi t4, t2, VIRTQ_SIZE - 1
    slli t4, t4, 1
    add t4, t4, t0
    sh t3, (VQ_AVAIL + VIRTQ_AVAIL_RING)(t4)
    fence w, w
    addi t2, t2, 1
    sh t2, (VQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    addi t1, t1, 1
    li t2, 0xffff
    and t1, t1, t2
    sd t1, VQ_LAST_USED(t0)
    li a5, 1
    j 1b
6:
    beqz a5, 7f
    fence rw, rw
    la t0, serial_base
    ld t0, 0(t0)
    li t1, SERIAL_PAD_RX_QUEUE
    sw t1, VIRTIO_MMIO_QUEUE_NOTIFY(t0)
7:
    mv a0, a4
    ret

.global serial_pad_pending
serial_pad_pending:
    la t0, serial_pad_rx_queue
    fence rw, rw
    lhu t1, (VQ_USED + VIRTQ_USED_IDX)(t0)
    ld t2, VQ_LAST_USED(t0)
    xor a0, t1, t2
    snez a0, a0
    ret

.ifdef DEBUG
.global serial_report
serial_report:
    la t0, serial_base
    ld t0, 0(t0)
    beqz t0, 9f                 # no serial device on the machine
    addi sp, sp, -16
    sd ra, 8(sp)
    la a0, msg_serial_at
    call debug_puts
    la t0, serial_base
    ld a0, 0(t0)
    call debug_put_hex
    li a0, '\n'
    call debug_putc
    ld ra, 8(sp)
    addi sp, sp, 16
9:
    ret
.pushsection .rodata
msg_serial_at:
    .asciz "jab: serial at "
.popsection

.global debug_putc
debug_putc:
    la t0, debug_length
    ld t1, 0(t0)
    la t2, debug_line
    add t2, t2, t1
    sb a0, 0(t2)
    addi t1, t1, 1
    sd t1, 0(t0)
    li t2, '\n'
    beq a0, t2, debug_flush
    li t2, DEBUG_LINE_BYTES
    beq t1, t2, debug_flush
    ret

.global debug_flush
debug_flush:
    la t0, debug_length
    ld a3, 0(t0)
    beqz a3, 9f
    sd zero, 0(t0)
    la t0, serial_state
    ld t0, 0(t0)
    li t1, 1
    bne t0, t1, 5f
    la t0, serial_ports
    ld t0, 0(t0)
    srli t0, t0, SERIAL_DEBUG_PORT
    andi t0, t0, 1
    beqz t0, 5f
    addi sp, sp, -16
    sd ra, 8(sp)
    la a0, serial_debug_tx_queue
    li a1, SERIAL_DEBUG_TX_QUEUE
    la a2, debug_line
    call serial_send
    ld ra, 8(sp)
    addi sp, sp, 16
    ret
5:
    addi sp, sp, -32
    sd ra, 24(sp)
    la t2, debug_line
    sd t2, 0(sp)
    sd a3, 8(sp)
    call uart_lock
6:
    ld t2, 0(sp)
    lbu a0, 0(t2)
    call uart_putc
    ld t2, 0(sp)
    addi t2, t2, 1
    sd t2, 0(sp)
    ld t3, 8(sp)
    addi t3, t3, -1
    sd t3, 8(sp)
    bnez t3, 6b
    call uart_unlock
    ld ra, 24(sp)
    addi sp, sp, 32
9:
    ret

.global debug_puts
debug_puts:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
1:
    ld t0, 0(sp)
    lbu a0, 0(t0)
    beqz a0, 2f
    addi t0, t0, 1
    sd t0, 0(sp)
    call debug_putc
    j 1b
2:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.global debug_put_hex
debug_put_hex:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd a0, 0(sp)                # the value
    li t0, 60
    sd t0, 8(sp)                # the shift of the digit being written
    li a0, '0'
    call debug_putc
    li a0, 'x'
    call debug_putc
1:
    ld t0, 0(sp)
    ld t1, 8(sp)
    srl t0, t0, t1
    andi t0, t0, 0xf
    li t1, 10
    blt t0, t1, 2f
    addi t0, t0, 'a' - 10
    j 3f
2:
    addi t0, t0, '0'
3:
    mv a0, t0
    call debug_putc
    ld t1, 8(sp)
    addi t1, t1, -4
    sd t1, 8(sp)
    bgez t1, 1b
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

.global debug_put_dec
debug_put_dec:
    addi sp, sp, -48
    sd ra, 40(sp)
    addi t2, sp, 31             # the digits, built backwards from here
    sb zero, 0(t2)
    li t3, 10
1:
    remu t4, a0, t3
    divu a0, a0, t3
    addi t4, t4, '0'
    addi t2, t2, -1
    sb t4, 0(t2)
    bnez a0, 1b
    sd t2, 32(sp)
2:
    ld t2, 32(sp)
    lbu a0, 0(t2)
    beqz a0, 3f
    addi t2, t2, 1
    sd t2, 32(sp)
    call debug_putc
    j 2b
3:
    ld ra, 40(sp)
    addi sp, sp, 48
    ret
.endif

.section .bss
.balign 16
serial_control_rx_queue:
    .skip VQ_BYTES
.balign 16
serial_control_tx_queue:
    .skip VQ_BYTES
.balign 16
serial_api_rx_queue:
    .skip VQ_BYTES
.balign 16
serial_api_tx_queue:
    .skip VQ_BYTES
.balign 16
.global serial_pad_rx_queue
serial_pad_rx_queue:
    .skip VQ_BYTES
.balign 16
serial_pad_tx_queue:
    .skip VQ_BYTES
.ifdef DEBUG
.balign 16
serial_debug_tx_queue:
    .skip VQ_BYTES
.balign 8
debug_line:
    .skip DEBUG_LINE_BYTES
debug_length:
    .skip 8
serial_unsent:
    .skip 8
.endif
.balign 8
serial_api_buffers:
    .skip VIRTQ_SIZE * API_BUFFER_BYTES
serial_pad_buffers:
    .skip VIRTQ_SIZE * PAD_PORT_BUFFER_BYTES
api_ring:
    .skip API_RING_BYTES
api_head:
    .skip 8
api_tail:
    .skip 8
serial_control_buffers:
    .skip VIRTQ_SIZE * SERIAL_CONTROL_BYTES
serial_control_message:
    .skip VIRTIO_CONSOLE_CONTROL_SIZE
serial_base:
    .skip 8
serial_state:
    .skip 8
serial_ports:
    .skip 8
