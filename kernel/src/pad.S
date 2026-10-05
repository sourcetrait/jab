.include "riscv.inc"
.include "qemu_virt.inc"
.include "virtio.inc"
.include "jab.inc"

.set PAD_RING, 256
.set PAD_ENTRY_SIZE, 8
.set PAD_KEYS_BITS, 32
.set BTN_SOUTH_BYTE, (JAB_BTN_SOUTH / 8)
.set BTN_SOUTH_BIT, (JAB_BTN_SOUTH % 8)
.set ABS_BITMAP_BYTES, (JAB_PAD_AXIS_COUNT / 8)
.set PAD_PORT_MAGIC, 0x4441504a
.set PAD_PORT_VERSION, 1
.set PAD_PORT_HEADER_MAGIC, 0
.set PAD_PORT_HEADER_VERSION, 4
.set PAD_PORT_HEADER_NAME, 8
.set PAD_PORT_HEADER_KEYS, 136
.set PAD_PORT_HEADER_AXES, 144
.set PAD_PORT_HEADER_ABSINFO, 152
.set PAD_PORT_HEADER_BYTES, (PAD_PORT_HEADER_ABSINFO + JAB_PAD_AXIS_COUNT * JAB_PAD_AXIS_ENTRY)
.set PAD_PORT_EVENT_BYTES, 8
.set PAD_STREAM_BYTES, 2048
.set PAD_SOURCE_DEVICE, 0
.set PAD_SOURCE_PORT, 1

.section .text

.global sys_pad_read
sys_pad_read:
    ld a0, 80(sp)
    li a1, JAB_PAD_ENTRY
    call buffer_bounds
    call pad_open
    bnez a0, 9f
    call pad_drain
    ld t0, 80(sp)
    la t1, pad_keys
    lwu t1, 0(t1)
    sb t1, JAB_PAD_KEYS(t0)
    srli t2, t1, 8
    sb t2, (JAB_PAD_KEYS + 1)(t0)
    srli t2, t1, 16
    sb t2, (JAB_PAD_KEYS + 2)(t0)
    srli t2, t1, 24
    sb t2, (JAB_PAD_KEYS + 3)(t0)
    li s0, 0
1:
    mv a0, s0
    call pad_normalise
    ld t0, 80(sp)
    slli t1, s0, 1
    add t1, t1, t0
    sb a0, JAB_PAD_AXES(t1)
    srli a0, a0, 8
    sb a0, (JAB_PAD_AXES + 1)(t1)
    addi s0, s0, 1
    li t0, JAB_PAD_AXIS_COUNT
    bltu s0, t0, 1b
    li a0, 0
    j 8f
9:
    li a0, 1
8:
    sd a0, 80(sp)
    j trap_return

.global sys_pad_input
sys_pad_input:
    call pad_open
    bnez a0, 1f
    call pad_drain
    call pad_take
    sd a0, 80(sp)
    sd a1, 88(sp)
    sd a2, 96(sp)
    j trap_return
1:
    sd zero, 80(sp)
    sd zero, 88(sp)
    sd zero, 96(sp)
    j trap_return

.global sys_pad_axis
sys_pad_axis:
    ld a0, 80(sp)
    li a1, JAB_PAD_AXIS_ENTRY
    call buffer_bounds
    call pad_open
    bnez a0, 7f
    ld a0, 88(sp)
    li t0, JAB_PAD_AXIS_COUNT
    bgeu a0, t0, 8f
    call pad_axis_present
    beqz a0, 8f
    ld a1, 88(sp)
    li t0, JAB_PAD_AXIS_ENTRY
    mul a1, a1, t0
    la t0, pad_absinfo
    add a1, a1, t0
    ld a0, 80(sp)
    li a2, JAB_PAD_AXIS_ENTRY
    call copy_bytes
    li a0, 0
    j 9f
7:
    li a0, 1
    j 9f
8:
    li a0, 2
9:
    sd a0, 80(sp)
    j trap_return

.global sys_pad_name
sys_pad_name:
    ld a0, 80(sp)
    li a1, JAB_PAD_NAME_BYTES
    call buffer_bounds
    call pad_open
    bnez a0, 7f
    ld a0, 80(sp)
    la a1, pad_name
    li a2, JAB_PAD_NAME_BYTES
    call copy_bytes
    la t0, pad_name_length
    ld t0, 0(t0)
    sd zero, 80(sp)
    sd t0, 88(sp)
    j trap_return
7:
    li a0, 1
    sd a0, 80(sp)
    sd zero, 88(sp)
    j trap_return

.global pad_open
pad_open:
    la t0, pad_state
    ld t0, 0(t0)
    beqz t0, 1f
    addi a0, t0, -1
    ret
1:
    addi sp, sp, -16
    sd ra, 8(sp)
    call pad_find
    beqz a0, 4f
    la t0, pad_base
    sd a0, 0(t0)
.ifdef DEBUG
    la a0, msg_pad_at
    call debug_puts
    la t0, pad_base
    ld a0, 0(t0)
    call debug_put_hex
    li a0, '\n'
    call debug_putc
    la t0, pad_base
    ld a0, 0(t0)
.pushsection .rodata
msg_pad_at:
    .asciz "jab: pad at "
.popsection
.endif
    call virtio_init
    bnez a0, 6f
    call pad_queue_setup
    bnez a0, 6f
    la t0, pad_queue
    la t1, pad_events
    li t2, 0
2:
    slli t3, t2, 4
    add t3, t3, t0
    sd t1, (PADQ_DESC + VIRTQ_DESC_ADDR)(t3)
    li t4, VIRTIO_INPUT_EVENT_SIZE
    sw t4, (PADQ_DESC + VIRTQ_DESC_LEN)(t3)
    li t4, VIRTQ_DESC_F_WRITE
    sh t4, (PADQ_DESC + VIRTQ_DESC_FLAGS)(t3)
    sh zero, (PADQ_DESC + VIRTQ_DESC_NEXT)(t3)
    slli t3, t2, 1
    add t3, t3, t0
    sh t2, (PADQ_AVAIL + VIRTQ_AVAIL_RING)(t3)
    addi t1, t1, VIRTIO_INPUT_EVENT_SIZE
    addi t2, t2, 1
    li t3, PADQ_SIZE
    bltu t2, t3, 2b
    fence w, w
    sh t2, (PADQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    fence rw, rw
    la t0, pad_base
    ld a0, 0(t0)
    call virtio_driver_ok
    la t0, pad_base
    ld a0, 0(t0)
    sw zero, VIRTIO_MMIO_QUEUE_NOTIFY(a0)
    la a1, pad_progress
    la a2, pad_fault
    call virtio_irq_enable
    call pad_ranges
    call pad_name_read
    la t0, pad_source
    li t1, PAD_SOURCE_DEVICE
    sd t1, 0(t0)
    la t0, pad_state
    li t1, 1
    sd t1, 0(t0)
    li a0, 0
    j 8f
4:
    call pad_port_open
    beqz a0, 41f
    li t0, 1
    beq a0, t0, 5f
    j 6f
41:
    la t0, pad_state
    li t1, 1
    sd t1, 0(t0)
    li a0, 0
    j 8f
5:
.ifdef DEBUG
    la a0, msg_no_pad
    call debug_puts
.pushsection .rodata
msg_no_pad:
    .asciz "jab: no pad\n"
.popsection
.endif
    la t0, pad_state
    li t1, 2
    sd t1, 0(t0)
    li a0, 1
    j 8f
6:
    la t0, pad_state
    li t1, 3
    sd t1, 0(t0)
    li a0, 2
8:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

pad_port_open:
    addi sp, sp, -16
    sd ra, 8(sp)
    call pad_port_up
    beqz a0, 7f
1:
    call pad_port_fill
    la t0, pad_stream_length
    ld t0, 0(t0)
    li t1, PAD_PORT_HEADER_BYTES
    bgeu t0, t1, 2f
    call serial_source
    mv a1, a0
    la a0, serial_pad_rx_queue
    call virtio_wait_used
    bnez a1, 8f                 # the port's source stuck
    j 1b
2:
    la t0, pad_stream
    lwu t1, PAD_PORT_HEADER_MAGIC(t0)
    li t2, PAD_PORT_MAGIC
    bne t1, t2, 8f
    lwu t1, PAD_PORT_HEADER_VERSION(t0)
    li t2, PAD_PORT_VERSION
    bne t1, t2, 8f
    la a0, pad_name
    addi a1, t0, PAD_PORT_HEADER_NAME
    li a2, JAB_PAD_NAME_BYTES
    call copy_bytes
    la t0, pad_name
    sb zero, (JAB_PAD_NAME_BYTES - 1)(t0)
    li t1, 0
3:
    add t2, t0, t1
    lbu t2, 0(t2)
    beqz t2, 4f
    addi t1, t1, 1
    j 3b
4:
    la t0, pad_name_length
    sd t1, 0(t0)
    la t0, pad_stream
    ld t1, PAD_PORT_HEADER_AXES(t0)
    la t2, pad_abs_bits
    sd t1, 0(t2)
    la a0, pad_absinfo
    addi a1, t0, PAD_PORT_HEADER_ABSINFO
    li a2, JAB_PAD_AXIS_COUNT * JAB_PAD_AXIS_ENTRY
    call copy_bytes
    call pad_rest
    li a0, PAD_PORT_HEADER_BYTES
    call pad_stream_consume
    la t0, pad_source
    li t1, PAD_SOURCE_PORT
    sd t1, 0(t0)
.ifdef DEBUG
    la a0, msg_pad_port
    call debug_puts
.pushsection .rodata
msg_pad_port:
    .asciz "jab: pad on port\n"
.popsection
.endif
    li a0, 0
    j 9f
7:
    li a0, 1
    j 9f
8:
.ifdef DEBUG
    la a0, msg_pad_port_refused
    call debug_puts
.pushsection .rodata
msg_pad_port_refused:
    .asciz "jab: pad port refused\n"
.popsection
.endif
    li a0, 2
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

pad_port_fill:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, pad_stream_length
    ld t1, 0(t0)
    la a0, pad_stream
    add a0, a0, t1
    li a1, PAD_STREAM_BYTES
    sub a1, a1, t1
    call serial_pad_read
    la t0, pad_stream_length
    ld t1, 0(t0)
    add t1, t1, a0
    sd t1, 0(t0)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

pad_stream_consume:
    la t0, pad_stream_length
    ld t1, 0(t0)
    sub t1, t1, a0
    sd t1, 0(t0)
    la t2, pad_stream
    add t3, t2, a0
1:
    beqz t1, 2f
    lbu t4, 0(t3)
    sb t4, 0(t2)
    addi t2, t2, 1
    addi t3, t3, 1
    addi t1, t1, -1
    j 1b
2:
    ret

pad_port_drain:
    addi sp, sp, -32
    sd ra, 24(sp)
    call pad_port_fill
    sd zero, 0(sp)              # the next event's offset
1:
    ld t0, 0(sp)
    la t1, pad_stream_length
    ld t1, 0(t1)
    sub t1, t1, t0
    li t2, PAD_PORT_EVENT_BYTES
    bltu t1, t2, 2f
    la t1, pad_stream
    add t1, t1, t0
    lhu a0, VIRTIO_INPUT_EVENT_TYPE(t1)
    lhu a1, VIRTIO_INPUT_EVENT_CODE(t1)
    lw a2, VIRTIO_INPUT_EVENT_VALUE(t1)
    call pad_accept
    ld t0, 0(sp)
    addi t0, t0, PAD_PORT_EVENT_BYTES
    sd t0, 0(sp)
    j 1b
2:
    ld a0, 0(sp)
    call pad_stream_consume
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

pad_queue_setup:
    la t2, pad_base
    ld a0, 0(t2)
    la a2, pad_queue
    sw zero, VIRTIO_MMIO_QUEUE_SEL(a0)
    lwu t0, VIRTIO_MMIO_QUEUE_NUM_MAX(a0)
    li t1, PADQ_SIZE
    bltu t0, t1, 1f
    sw t1, VIRTIO_MMIO_QUEUE_NUM(a0)
    addi t0, a2, PADQ_DESC
    srli t1, t0, 32
    sw t0, VIRTIO_MMIO_QUEUE_DESC_LOW(a0)
    sw t1, VIRTIO_MMIO_QUEUE_DESC_HIGH(a0)
    addi t0, a2, PADQ_AVAIL
    srli t1, t0, 32
    sw t0, VIRTIO_MMIO_QUEUE_DRIVER_LOW(a0)
    sw t1, VIRTIO_MMIO_QUEUE_DRIVER_HIGH(a0)
    addi t0, a2, PADQ_USED
    srli t1, t0, 32
    sw t0, VIRTIO_MMIO_QUEUE_DEVICE_LOW(a0)
    sw t1, VIRTIO_MMIO_QUEUE_DEVICE_HIGH(a0)
    li t0, 1
    sw t0, VIRTIO_MMIO_QUEUE_READY(a0)
    li a0, 0
    ret
1:
    li a0, 1
    ret

pad_find:
    li t0, QEMU_VIRT_VIRTIO0
    li t1, QEMU_VIRT_VIRTIO_COUNT
    li t2, VIRTIO_MAGIC
    li t3, VIRTIO_VERSION_MODERN
    li t5, QEMU_VIRT_VIRTIO_STRIDE
    li t6, VIRTIO_ID_INPUT
1:
    lwu t4, VIRTIO_MMIO_MAGIC_VALUE(t0)
    bne t4, t2, 2f
    lwu t4, VIRTIO_MMIO_VERSION(t0)
    bne t4, t3, 2f
    lwu t4, VIRTIO_MMIO_DEVICE_ID(t0)
    bne t4, t6, 2f
    li t4, VIRTIO_INPUT_CFG_EV_BITS
    sb t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SELECT)(t0)
    li t4, EV_KEY
    sb t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SUBSEL)(t0)
    lbu t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SIZE)(t0)
    li a0, BTN_SOUTH_BYTE
    bleu t4, a0, 2f
    lbu t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_DATA + BTN_SOUTH_BYTE)(t0)
    srli t4, t4, BTN_SOUTH_BIT
    andi t4, t4, 1
    beqz t4, 2f
    li t4, VIRTIO_INPUT_CFG_EV_BITS
    sb t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SELECT)(t0)
    li t4, EV_ABS
    sb t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SUBSEL)(t0)
    lbu t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SIZE)(t0)
    beqz t4, 2f
    lbu t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_DATA)(t0)
    andi t4, t4, 1
    bnez t4, 3f
2:
    add t0, t0, t5
    addi t1, t1, -1
    bnez t1, 1b
    li a0, 0
    ret
3:
    mv a0, t0
    ret

pad_ranges:
    addi sp, sp, -32
    sd ra, 24(sp)
    la t0, pad_base
    ld t0, 0(t0)
    li t4, VIRTIO_INPUT_CFG_EV_BITS
    sb t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SELECT)(t0)
    li t4, EV_ABS
    sb t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SUBSEL)(t0)
    lbu t1, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SIZE)(t0)
    li t2, ABS_BITMAP_BYTES
    bleu t1, t2, 1f
    mv t1, t2
1:
    la t2, pad_abs_bits
    li t3, 0
2:
    bgeu t3, t1, 3f
    add t4, t0, t3
    lbu t5, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_DATA)(t4)
    add t6, t2, t3
    sb t5, 0(t6)
    addi t3, t3, 1
    j 2b
3:
    sd zero, 0(sp)              # the code
4:
    ld t3, 0(sp)
    li t4, JAB_PAD_AXIS_COUNT
    bgeu t3, t4, 9f
    mv a0, t3
    call pad_axis_present
    beqz a0, 8f
    la t0, pad_base
    ld t0, 0(t0)
    li t4, VIRTIO_INPUT_CFG_ABS_INFO
    sb t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SELECT)(t0)
    ld t3, 0(sp)
    sb t3, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SUBSEL)(t0)
    lbu t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SIZE)(t0)
    li t5, VIRTIO_INPUT_ABS_SIZE
    bltu t4, t5, 8f             # nothing said: the range stays zero
    li t4, JAB_PAD_AXIS_ENTRY
    mul t4, t4, t3
    la t5, pad_absinfo
    add t5, t5, t4              # the entry
    li t6, 0
5:
    add t1, t0, t6
    lbu t2, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_DATA)(t1)
    add t1, t5, t6
    sb t2, 0(t1)
    addi t6, t6, 1
    li t1, VIRTIO_INPUT_ABS_SIZE
    bltu t6, t1, 5b
8:
    ld t3, 0(sp)
    addi t3, t3, 1
    sd t3, 0(sp)
    j 4b
9:
    call pad_rest
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

pad_rest:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd zero, 0(sp)              # the code
1:
    ld t3, 0(sp)
    li t4, JAB_PAD_AXIS_COUNT
    bgeu t3, t4, 9f
    mv a0, t3
    call pad_axis_present
    beqz a0, 8f
    ld t3, 0(sp)
    li t4, JAB_PAD_AXIS_ENTRY
    mul t4, t4, t3
    la t5, pad_absinfo
    add t5, t5, t4              # the entry
    lw t1, JAB_PAD_AXIS_MIN(t5)
    lw t2, JAB_PAD_AXIS_MAX(t5)
    li t4, JAB_ABS_GAS
    beq t3, t4, 6f
    li t4, JAB_ABS_BRAKE
    beq t3, t4, 6f
    add t1, t1, t2
    li t2, 2
    div t1, t1, t2
6:
    slli t4, t3, 2
    la t2, pad_raw
    add t2, t2, t4
    sw t1, 0(t2)
8:
    ld t3, 0(sp)
    addi t3, t3, 1
    sd t3, 0(sp)
    j 1b
9:
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

pad_name_read:
    la t0, pad_base
    ld t0, 0(t0)
    li t4, VIRTIO_INPUT_CFG_ID_NAME
    sb t4, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SELECT)(t0)
    sb zero, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SUBSEL)(t0)
    lbu t1, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_SIZE)(t0)
    li t2, JAB_PAD_NAME_BYTES - 1
    bleu t1, t2, 1f
    mv t1, t2
1:
    la t2, pad_name
    li t3, 0
2:
    bgeu t3, t1, 3f
    add t4, t0, t3
    lbu t5, (VIRTIO_MMIO_CONFIG + VIRTIO_INPUT_CFG_DATA)(t4)
    beqz t5, 3f                 # the device may end it early
    add t6, t2, t3
    sb t5, 0(t6)
    addi t3, t3, 1
    j 2b
3:
    add t6, t2, t3
    sb zero, 0(t6)
    la t0, pad_name_length
    sd t3, 0(t0)
    ret

pad_axis_present:
    srli t0, a0, 3
    la t1, pad_abs_bits
    add t1, t1, t0
    lbu t1, 0(t1)
    andi t0, a0, 7
    srl t1, t1, t0
    andi a0, t1, 1
    ret

.global pad_drain
pad_drain:
    la t0, pad_source
    ld t0, 0(t0)
    bnez t0, pad_port_drain
    j pad_input_drain

pad_input_drain:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd zero, 16(sp)             # whether a buffer went back
1:
    la t0, pad_queue
    ld t1, PADQ_LAST_USED(t0)
    fence rw, rw
    lhu t2, (PADQ_USED + VIRTQ_USED_IDX)(t0)
    beq t2, t1, 6f
    andi t2, t1, PADQ_SIZE - 1
    slli t2, t2, 3
    add t2, t2, t0
    lwu t3, (PADQ_USED + VIRTQ_USED_RING + VIRTQ_USED_ELEM_ID)(t2)
    sd t3, 0(sp)
    slli t4, t3, 3
    la t5, pad_events
    add t4, t4, t5
    lhu a0, VIRTIO_INPUT_EVENT_TYPE(t4)
    lhu a1, VIRTIO_INPUT_EVENT_CODE(t4)
    lw a2, VIRTIO_INPUT_EVENT_VALUE(t4)
    call pad_accept
    la t0, pad_queue
    ld t3, 0(sp)
    lhu t2, (PADQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    andi t4, t2, PADQ_SIZE - 1
    slli t4, t4, 1
    add t4, t4, t0
    sh t3, (PADQ_AVAIL + VIRTQ_AVAIL_RING)(t4)
    fence w, w
    addi t2, t2, 1
    sh t2, (PADQ_AVAIL + VIRTQ_AVAIL_IDX)(t0)
    ld t1, PADQ_LAST_USED(t0)
    addi t1, t1, 1
    li t2, 0xffff
    and t1, t1, t2
    sd t1, PADQ_LAST_USED(t0)
    li t2, 1
    sd t2, 16(sp)
    j 1b
6:
    ld t2, 16(sp)
    beqz t2, 7f
    fence rw, rw
    la t0, pad_base
    ld t0, 0(t0)
    sw zero, VIRTIO_MMIO_QUEUE_NOTIFY(t0)
7:
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

pad_accept:
    li t0, EV_KEY
    beq a0, t0, 1f
    li t0, EV_ABS
    beq a0, t0, 2f
    ret
1:
    addi t1, a1, -JAB_BTN_GAMEPAD
    li t2, PAD_KEYS_BITS
    bgeu t1, t2, 3f
    li t2, 1
    sll t2, t2, t1
    la t3, pad_keys
    lwu t4, 0(t3)
    beqz a2, 11f
    or t4, t4, t2
    j 12f
11:
    not t2, t2
    and t4, t4, t2
12:
    sw t4, 0(t3)
    j 3f
2:
    li t2, JAB_PAD_AXIS_COUNT
    bgeu a1, t2, 3f
    slli t2, a1, 2
    la t3, pad_raw
    add t3, t3, t2
    sw a2, 0(t3)
3:
    la t0, pad_head
    ld t1, 0(t0)
    la t2, pad_tail
    ld t2, 0(t2)
    sub t2, t1, t2
    li t3, PAD_RING
    bgeu t2, t3, 9f
    andi t2, t1, PAD_RING - 1
    slli t2, t2, 3
    la t3, pad_ring
    add t2, t2, t3
    sh a0, 0(t2)
    sh a1, 2(t2)
    sw a2, 4(t2)
    addi t1, t1, 1
    sd t1, 0(t0)
9:
    ret

pad_progress:
    la t0, pad_queue
    lhu a0, (PADQ_USED + VIRTQ_USED_IDX)(t0)
    ret

pad_fault:
    la t0, pad_state
    li t1, 3
    sd t1, 0(t0)
    ret

.global pad_pending
pad_pending:
    la t0, pad_head
    ld t0, 0(t0)
    la t1, pad_tail
    ld t1, 0(t1)
    bne t0, t1, 1f
    la t0, pad_source
    ld t0, 0(t0)
    bnez t0, serial_pad_pending
    la t0, pad_queue
    fence rw, rw
    lhu t1, (PADQ_USED + VIRTQ_USED_IDX)(t0)
    ld t2, PADQ_LAST_USED(t0)
    bne t1, t2, 1f
    li a0, 0
    ret
1:
    li a0, 1
    ret

pad_take:
    la t0, pad_head
    ld t0, 0(t0)
    la t1, pad_tail
    ld t2, 0(t1)
    beq t0, t2, 1f
    andi t3, t2, PAD_RING - 1
    slli t3, t3, 3
    la t4, pad_ring
    add t3, t3, t4
    lhu a0, 0(t3)
    lhu a1, 2(t3)
    lw a2, 4(t3)
    addi t2, t2, 1
    sd t2, 0(t1)
    ret
1:
    li a0, 0
    li a1, 0
    li a2, 0
    ret

pad_normalise:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a0, 0(sp)
    call pad_axis_present
    beqz a0, 8f
    ld a0, 0(sp)
    li t0, JAB_PAD_AXIS_ENTRY
    mul t0, t0, a0
    la t1, pad_absinfo
    add t1, t1, t0
    lw t2, JAB_PAD_AXIS_MIN(t1)
    lw t3, JAB_PAD_AXIS_MAX(t1)
    lw t4, JAB_PAD_AXIS_FLAT(t1)
    slli t0, a0, 2
    la t5, pad_raw
    add t5, t5, t0
    lw t5, 0(t5)                # the raw value
    li t0, JAB_ABS_GAS
    beq a0, t0, 5f
    li t0, JAB_ABS_BRAKE
    beq a0, t0, 5f
    add t6, t2, t3
    li t0, 2
    div t6, t6, t0              # the middle
    add t0, t6, t4              # the band's top
    bgt t5, t0, 3f
    sub t0, t6, t4              # the band's bottom
    blt t5, t0, 4f
    li a0, 0
    j 9f
3:
    sub t1, t3, t0              # from the band's top to max
    blez t1, 7f
    sub t5, t5, t0
    li t2, JAB_PAD_FULL
    mul t5, t5, t2
    div a0, t5, t1
    j 6f
4:
    sub t1, t0, t2              # from min to the band's bottom
    blez t1, 71f
    sub t5, t0, t5
    li t2, JAB_PAD_FULL
    mul t5, t5, t2
    div a0, t5, t1
    neg a0, a0
    j 6f
5:
    add t0, t2, t4              # min plus flat
    ble t5, t0, 8f
    sub t1, t3, t0
    blez t1, 7f
    sub t5, t5, t0
    li t2, JAB_PAD_FULL
    mul t5, t5, t2
    div a0, t5, t1
6:
    li t0, JAB_PAD_FULL
    ble a0, t0, 61f
    mv a0, t0
61:
    neg t0, t0
    bge a0, t0, 9f
    mv a0, t0
    j 9f
7:
    li a0, JAB_PAD_FULL
    j 9f
71:
    li a0, -JAB_PAD_FULL
    j 9f
8:
    li a0, 0
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.section .bss
.balign 16
pad_queue:
    .skip PADQ_BYTES
.balign 8
pad_events:
    .skip PADQ_SIZE * VIRTIO_INPUT_EVENT_SIZE
pad_ring:
    .skip PAD_RING * PAD_ENTRY_SIZE
pad_head:
    .skip 8
pad_tail:
    .skip 8
pad_base:
    .skip 8
pad_state:
    .skip 8
pad_keys:
    .skip 8
pad_abs_bits:
    .skip 8
pad_name_length:
    .skip 8
pad_name:
    .skip JAB_PAD_NAME_BYTES
pad_source:
    .skip 8
pad_stream_length:
    .skip 8
.balign 8
pad_stream:
    .skip PAD_STREAM_BYTES
.balign 4
pad_raw:
    .skip JAB_PAD_AXIS_COUNT * 4
pad_absinfo:
    .skip JAB_PAD_AXIS_COUNT * JAB_PAD_AXIS_ENTRY
