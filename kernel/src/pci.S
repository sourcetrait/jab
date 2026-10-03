.include "riscv.inc"
.include "qemu_virt.inc"
.include "virtio.inc"
.include "pci.inc"

.section .text

.global pci_scan
pci_scan:
    la t0, pci_scanned
    ld t0, 0(t0)
    bnez t0, 9f
    addi sp, sp, -32
    sd ra, 24(sp)
    la t0, pci_scanned
    li t1, 1
    sd t1, 0(t0)
    li t0, QEMU_VIRT_PCIE_MMIO
    la t1, pci_next_base
    sd t0, 0(t1)
    sd zero, 0(sp)              # the device and function being looked at
1:
    ld t0, 0(sp)
    li t1, 256
    bgeu t0, t1, 8f
    la t1, pci_count
    ld t1, 0(t1)
    li t2, PCI_DEV_MAX
    bgeu t1, t2, 8f
    mv a0, t0
    call pci_config
    lhu t1, PCI_CFG_VENDOR(a0)
    li t2, PCI_VIRTIO_VENDOR
    bne t1, t2, 7f
    lbu t1, PCI_CFG_HEADER_TYPE(a0)
    andi t1, t1, PCI_HEADER_TYPE_MASK
    bnez t1, 7f
    ld a0, 0(sp)
    call pci_bring_up
7:
    ld t0, 0(sp)
    addi t0, t0, 1
    sd t0, 0(sp)
    j 1b
8:
    ld ra, 24(sp)
    addi sp, sp, 32
9:
    ret

.global pci_config
pci_config:
    slli a0, a0, 12
    li t0, QEMU_VIRT_PCIE_ECAM
    add a0, a0, t0
    ret

pci_bring_up:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd a0, 0(sp)                # the device and function
    call pci_config
    sd a0, 8(sp)                # its configuration space
    la t0, pci_count
    ld t1, 0(t0)
    li t2, PCI_DEV_SIZE
    mul t2, t2, t1
    la t3, pci_devices
    add t2, t2, t3
    sd t2, 16(sp)               # the record
    addi t1, t1, 1
    sd t1, 0(t0)
    ld t0, 8(sp)
    ld t2, 16(sp)
    lhu t1, PCI_CFG_VENDOR(t0)
    sh t1, PCI_DEV_VENDOR(t2)
    lhu t1, PCI_CFG_DEVICE(t0)
    sh t1, PCI_DEV_DEVICE(t2)
    ld t3, 0(sp)
    srli t3, t3, 3
    sb t3, PCI_DEV_SLOT(t2)
    lbu t4, PCI_CFG_INTERRUPT_PIN(t0)
    sb t4, PCI_DEV_PIN(t2)
    beqz t4, 1f
    add t3, t3, t4
    addi t3, t3, -1
    andi t3, t3, QEMU_VIRT_PCIE_IRQ_COUNT - 1
    addi t3, t3, QEMU_VIRT_PCIE_IRQ0
    j 2f
1:
    li t3, 0
2:
    sb t3, PCI_DEV_LINE(t2)
    lhu t1, PCI_CFG_DEVICE(t0)
    li t3, PCI_VIRTIO_DEVICE_MODERN
    bltu t1, t3, 3f
    sub t1, t1, t3
    j 4f
3:
    lhu t1, PCI_CFG_SUBSYSTEM_DEVICE(t0)
4:
    sw t1, PCI_DEV_VIRTIO_ID(t2)
    sd zero, 24(sp)             # the BAR being sized
5:
    ld t0, 24(sp)
    li t1, PCI_BAR_COUNT
    bgeu t0, t1, 6f
    ld a0, 8(sp)
    ld a1, 16(sp)
    mv a2, t0
    call pci_assign_bar
    ld t0, 24(sp)
    add t0, t0, a0              # one or two slots
    sd t0, 24(sp)
    j 5b
6:
    ld t0, 8(sp)
    lhu t1, PCI_CFG_COMMAND(t0)
    ori t1, t1, PCI_COMMAND_MEMORY | PCI_COMMAND_MASTER
    li t2, PCI_COMMAND_INTX_DISABLE
    not t2, t2
    and t1, t1, t2
    sh t1, PCI_CFG_COMMAND(t0)
    ld a0, 8(sp)
    ld a1, 16(sp)
    call pci_capabilities
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

pci_assign_bar:
    slli t0, a2, 2
    addi t0, t0, PCI_CFG_BAR0
    add t0, t0, a0              # the BAR's register
    li t1, -1
    sw t1, 0(t0)
    lwu t2, 0(t0)               # the mask
    beqz t2, 8f
    andi t3, t2, PCI_BAR_IO
    bnez t3, 8f
    andi t3, t2, PCI_BAR_TYPE_MASK
    li t4, PCI_BAR_TYPE_64
    li t5, 1                    # slots taken
    li t6, 0                    # the mask's high word, all ones for 32-bit
    bne t3, t4, 1f
    li t5, 2
    li t1, -1
    sw t1, 4(t0)
    lwu t6, 4(t0)
1:
    li t1, PCI_BAR_ADDRESS_MASK
    and t2, t2, t1
    slli t6, t6, 32
    or t2, t2, t6
    not t2, t2
    addi t2, t2, 1
    li t1, 1
    bne t5, t1, 3f
    li t1, 0xffffffff
    and t2, t2, t1
3:
    la t1, pci_next_base
    ld t3, 0(t1)
    addi t4, t2, -1
    add t3, t3, t4
    not t4, t4
    and t3, t3, t4              # aligned
    add t4, t3, t2
    sd t4, 0(t1)
    sw t3, 0(t0)
    li t1, 1
    beq t5, t1, 4f
    srli t4, t3, 32
    sw t4, 4(t0)
4:
    slli t1, a2, 3
    add t1, t1, a1
    sd t3, PCI_DEV_BARS(t1)
    mv a0, t5
    ret
8:
    li a0, 1
    ret

pci_capabilities:
    lhu t0, PCI_CFG_STATUS(a0)
    andi t0, t0, PCI_STATUS_CAPABILITIES
    beqz t0, 9f
    lbu t0, PCI_CFG_CAPABILITIES(a0)
1:
    beqz t0, 9f
    add t1, a0, t0              # the capability
    lbu t2, 0(t1)
    li t3, PCI_CAP_VENDOR
    bne t2, t3, 8f
    lbu t2, VIRTIO_PCI_CAP_BAR(t1)
    slli t2, t2, 3
    add t2, t2, a1
    ld t2, PCI_DEV_BARS(t2)     # the BAR's base
    lwu t3, VIRTIO_PCI_CAP_OFFSET(t1)
    add t2, t2, t3              # the region
    lbu t3, VIRTIO_PCI_CAP_TYPE(t1)
    li t4, VIRTIO_PCI_CAP_COMMON_CFG
    bne t3, t4, 2f
    sd t2, PCI_DEV_COMMON(a1)
    j 8f
2:
    li t4, VIRTIO_PCI_CAP_NOTIFY_CFG
    bne t3, t4, 3f
    sd t2, PCI_DEV_NOTIFY(a1)
    lwu t4, VIRTIO_PCI_CAP_NOTIFY_MULTIPLIER(t1)
    sd t4, PCI_DEV_NOTIFY_MULTIPLIER(a1)
    j 8f
3:
    li t4, VIRTIO_PCI_CAP_ISR_CFG
    bne t3, t4, 4f
    sd t2, PCI_DEV_ISR(a1)
    j 8f
4:
    li t4, VIRTIO_PCI_CAP_DEVICE_CFG
    bne t3, t4, 8f
    sd t2, PCI_DEV_DEVICE_CFG(a1)
8:
    lbu t0, VIRTIO_PCI_CAP_NEXT(t1)
    j 1b
9:
    ret

.global pci_count_of
pci_count_of:
    la t0, pci_count
    ld a0, 0(t0)
    ret

.global pci_device
pci_device:
    li t0, PCI_DEV_SIZE
    mul t0, t0, a0
    la t1, pci_devices
    add a0, t1, t0
    ret

.global pci_service_line
pci_service_line:
    la t0, pci_count
    ld t0, 0(t0)
    la t1, pci_devices
1:
    beqz t0, 9f
    lbu t2, PCI_DEV_LINE(t1)
    bne t2, a0, 2f
    ld t2, PCI_DEV_ISR(t1)
    beqz t2, 2f
    lbu t3, 0(t2)
2:
    addi t1, t1, PCI_DEV_SIZE
    addi t0, t0, -1
    j 1b
9:
    ret

.section .bss
.balign 8
pci_devices:
    .skip PCI_DEV_MAX * PCI_DEV_SIZE
pci_count:
    .skip 8
pci_scanned:
    .skip 8
pci_next_base:
    .skip 8
