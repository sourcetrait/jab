.include "riscv.inc"
.include "qemu_virt.inc"
.include "virtio.inc"
.include "pci.inc"

.section .text

.global vpci_init
.global vpci_init_with
vpci_init:
    li a1, 0
vpci_init_with:
    ld t0, PCI_DEV_COMMON(a0)
    sb zero, VIRTIO_PCI_COMMON_STATUS(t0)
1:
    lbu t1, VIRTIO_PCI_COMMON_STATUS(t0)
    bnez t1, 1b                 # until the reset has taken
    li t1, VIRTIO_STATUS_ACKNOWLEDGE
    sb t1, VIRTIO_PCI_COMMON_STATUS(t0)
    li t1, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER
    sb t1, VIRTIO_PCI_COMMON_STATUS(t0)
    sw zero, VIRTIO_PCI_COMMON_DRIVER_FEATURE_SELECT(t0)
    sw a1, VIRTIO_PCI_COMMON_DRIVER_FEATURE(t0)
    li t1, VIRTIO_F_VERSION_1_WORD
    sw t1, VIRTIO_PCI_COMMON_DRIVER_FEATURE_SELECT(t0)
    li t1, VIRTIO_F_VERSION_1_BIT
    sw t1, VIRTIO_PCI_COMMON_DRIVER_FEATURE(t0)
    li t1, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK
    sb t1, VIRTIO_PCI_COMMON_STATUS(t0)
    lbu t1, VIRTIO_PCI_COMMON_STATUS(t0)
    andi t1, t1, VIRTIO_STATUS_FEATURES_OK
    beqz t1, 2f
    li a0, 0
    ret
2:
    li a0, 1
    ret

.global vpci_queue_setup
vpci_queue_setup:
    ld t0, PCI_DEV_COMMON(a0)
    sh a1, VIRTIO_PCI_COMMON_QUEUE_SELECT(t0)
    lhu t1, VIRTIO_PCI_COMMON_QUEUE_SIZE(t0)
    li t2, VIRTQ_SIZE
    bltu t1, t2, 1f
    sh t2, VIRTIO_PCI_COMMON_QUEUE_SIZE(t0)
    addi t1, a2, VQ_DESC
    srli t2, t1, 32
    sw t1, VIRTIO_PCI_COMMON_QUEUE_DESC_LOW(t0)
    sw t2, VIRTIO_PCI_COMMON_QUEUE_DESC_HIGH(t0)
    addi t1, a2, VQ_AVAIL
    srli t2, t1, 32
    sw t1, VIRTIO_PCI_COMMON_QUEUE_DRIVER_LOW(t0)
    sw t2, VIRTIO_PCI_COMMON_QUEUE_DRIVER_HIGH(t0)
    addi t1, a2, VQ_USED
    srli t2, t1, 32
    sw t1, VIRTIO_PCI_COMMON_QUEUE_DEVICE_LOW(t0)
    sw t2, VIRTIO_PCI_COMMON_QUEUE_DEVICE_HIGH(t0)
    li t1, 1
    sh t1, VIRTIO_PCI_COMMON_QUEUE_ENABLE(t0)
    lhu t1, VIRTIO_PCI_COMMON_QUEUE_NOTIFY_OFF(t0)
    ld t2, PCI_DEV_NOTIFY_MULTIPLIER(a0)
    mul t1, t1, t2
    ld t2, PCI_DEV_NOTIFY(a0)
    add t1, t1, t2
    sd t1, PCI_DEV_QUEUE_NOTIFY(a0)
    li a0, 0
    ret
1:
    li a0, 1
    ret

.global vpci_driver_ok
vpci_driver_ok:
    ld t0, PCI_DEV_COMMON(a0)
    li t1, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK | VIRTIO_STATUS_DRIVER_OK
    sb t1, VIRTIO_PCI_COMMON_STATUS(t0)
    ret

.global vpci_notify
vpci_notify:
    ld t0, PCI_DEV_QUEUE_NOTIFY(a0)
    sh a1, 0(t0)
    ret
