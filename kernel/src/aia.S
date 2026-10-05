.include "riscv.inc"
.include "qemu_virt.inc"
.include "virtio.inc"
.include "jab.inc"
.include "dtb.inc"
.include "aia.inc"

.section .text

.global aia_topology
aia_topology:
    addi sp, sp, -96
    sd ra, 88(sp)
    sd s0, 80(sp)
    sd s1, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    sd s7, 24(sp)
    mv s0, a0                               # the tree
    la t0, aia_file
    li t1, JAB_HARTS_MAX
    li t2, 0xff
1:
    sb t2, 0(t0)                            # no file until one is found
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, 1b
    mv a0, s0
    la a1, path_soc
    call dtb_path
    li a1, AIA_NO_IMSIC_S
    beqz a0, 90f
    mv s1, a0                               # /soc
    mv a0, s0
    mv a1, s1
    la a2, word_address_cells
    call aia_cell
    li t0, 1
    beq a0, t0, 2f
    li t0, 2
    li a1, AIA_LAYOUT
    bne a0, t0, 90f
2:
    sd a0, 16(sp)                           # the cells of an address under /soc
    li s2, 0                                # the child before
    li s3, 0                                # the supervisor IMSIC
    li s4, 0                                # the machine IMSIC
    li s5, 0                                # the machine APLIC domain
    li s6, 0                                # an ACLINT timer seen
3:
    mv a0, s0
    mv a1, s1
    mv a2, s2
    call dtb_child
    beqz a0, 6f
    mv s2, a0
    mv a0, s0
    mv a1, s2
    la a2, word_compatible
    call dtb_prop
    beqz a0, 3b
    sd a0, 0(sp)
    sd a1, 8(sp)
    la a2, word_imsics
    call dtb_listed
    bnez a0, 4f
    ld a0, 0(sp)
    ld a1, 8(sp)
    la a2, word_aplic
    call dtb_listed
    bnez a0, 5f
    ld a0, 0(sp)
    ld a1, 8(sp)
    la a2, word_mtimer
    call dtb_listed
    beqz a0, 3b
    li s6, 1
    j 3b
4:
    mv a0, s0
    mv a1, s2
    la a2, word_interrupts_extended
    call dtb_prop
    beqz a0, 3b
    li t0, 8
    bltu a1, t0, 3b
    dtb_be32 t1, a0, 4                      # the first pair's interrupt
    li t0, IMSIC_CAUSE_S
    bne t1, t0, 41f
    mv s3, s2
    j 3b
41:
    li t0, IMSIC_CAUSE_M
    bne t1, t0, 3b
    mv s4, s2
    j 3b
5:
    mv a0, s0
    mv a1, s2
    la a2, word_children
    call dtb_prop
    beqz a0, 3b                             # no children: a supervisor domain
    mv s5, s2
    j 3b
6:
    li a1, AIA_NO_IMSIC_S
    beqz s3, 90f
    li a1, AIA_NO_IMSIC_M
    beqz s4, 90f
    li a1, AIA_NO_TIMER
    beqz s6, 90f
    li a1, AIA_NO_DOMAINS
    beqz s5, 90f
    mv a0, s0
    mv a1, s5
    la a2, word_children
    call aia_cell
    li t0, -1
    li a1, AIA_NO_DOMAINS
    beq a0, t0, 90f
    mv a1, a0
    mv a0, s0
    call dtb_phandle
    li a1, AIA_NO_DOMAINS
    beqz a0, 90f
    mv s7, a0                               # the supervisor APLIC domain
    mv a0, s0
    mv a1, s4
    mv a2, s5
    call aia_parent
    li a1, AIA_NO_DOMAINS
    beqz a0, 90f
    mv a0, s0
    mv a1, s3
    mv a2, s7
    call aia_parent
    li a1, AIA_NO_DOMAINS
    beqz a0, 90f
    ld s1, 16(sp)                           # the address cells
    mv a0, s0
    mv a1, s3
    mv a2, s1
    call aia_reg
    li t0, QEMU_VIRT_IMSIC_S
    li a1, AIA_NOT_QEMU
    bne a0, t0, 90f
    mv a0, s0
    mv a1, s4
    mv a2, s1
    call aia_reg
    li t0, QEMU_VIRT_IMSIC_M
    li a1, AIA_NOT_QEMU
    bne a0, t0, 90f
    mv a0, s0
    mv a1, s5
    mv a2, s1
    call aia_reg
    li t0, QEMU_VIRT_APLIC_M
    li a1, AIA_NOT_QEMU
    bne a0, t0, 90f
    mv a0, s0
    mv a1, s7
    mv a2, s1
    call aia_reg
    li t0, QEMU_VIRT_APLIC_S
    li a1, AIA_NOT_QEMU
    bne a0, t0, 90f
    mv a0, s0
    mv a1, s3
    la a2, word_num_ids
    call aia_cell
    li t0, -1
    li a1, AIA_TOO_FEW
    beq a0, t0, 90f
    li t0, AIA_IDENTITIES - 1
    bltu a0, t0, 90f
    mv a0, s0
    mv a1, s7
    la a2, word_num_sources
    call aia_cell
    li t0, -1
    li a1, AIA_TOO_FEW
    beq a0, t0, 90f
    li t0, AIA_SOURCE_LAST_USED
    bltu a0, t0, 90f
    li t0, APLIC_SOURCES_MAX
    li a1, AIA_TOO_MANY
    bgtu a0, t0, 90f                        # past sourcecfg[1023]: aia_root would write other registers
    la t0, aia_sources
    sd a0, 0(t0)
    mv a0, s0
    mv a1, s3
    la a2, word_group_bits
    call dtb_prop
    li a1, AIA_LAYOUT
    bnez a0, 90f                            # groups: harts over more than one socket
    mv a0, s0
    mv a1, s3
    la a2, word_guest_bits
    call dtb_prop
    beqz a0, 7f                             # no guest files: a file a page
    li t0, 4
    beq a1, t0, 71f
    li a1, AIA_LAYOUT
    j 90f
71:
    dtb_be32 a0, a0
    li t0, IMSIC_GUEST_BITS_MAX
    li a1, AIA_LAYOUT
    bgtu a0, t0, 90f
7:
    la t0, aia_lhxs
    sd a0, 0(t0)
    mv a0, s0
    mv a1, s3
    la a2, word_interrupts_extended
    call dtb_prop
    beqz a0, 91f
    li t0, 8
    bltu a1, t0, 91f
    mv s2, a0                               # the files' list, a hart's controller and 9 a file
    srli s5, a1, 3                          # the files
    li s6, 0                                # the file
8:
    bgeu s6, s5, 81f
    slli t0, s6, 3
    add t0, t0, s2
    dtb_be32 t1, t0                         # its hart's controller
    la t2, harts_intc
    la t3, aia_file
    li t4, 0                                # the hart id
82:
    li t5, JAB_HARTS_MAX
    bgeu t4, t5, 83f
    slli t5, t4, 2
    add t5, t5, t2
    lwu t5, 0(t5)
    beqz t5, 84f
    bne t5, t1, 84f
    add t6, t3, t4
    sb s6, 0(t6)
84:
    addi t4, t4, 1
    j 82b
83:
    addi s6, s6, 1
    j 8b
81:
    li t0, 0                                # the hart index's width
    li t1, 1
85:
    bgeu t1, s5, 86f
    addi t0, t0, 1
    slli t1, t1, 1
    j 85b
86:
    la t1, aia_lhxw
    sd t0, 0(t1)
    la t0, aia_file
    lbu t0, 0(t0)
    li t1, 0xff
    li a1, AIA_NO_FILE
    beq t0, t1, 90f
    ld ra, 88(sp)
    ld s0, 80(sp)
    ld s1, 72(sp)
    ld s2, 64(sp)
    ld s3, 56(sp)
    ld s4, 48(sp)
    ld s5, 40(sp)
    ld s6, 32(sp)
    ld s7, 24(sp)
    addi sp, sp, 96
    ret
91:
    li a1, AIA_NO_FILE
90:
    mv s1, a1
    call uart_lock_fatal
    la a0, msg_platform_refused
    call uart_puts
    mv a0, s1
    call uart_put_dec
    li a0, '\n'
    call uart_putc
    li a0, 1
    j qemu_exit

aia_cell:
    addi sp, sp, -16
    sd ra, 8(sp)
    call dtb_prop
    beqz a0, 1f
    li t0, 4
    bne a1, t0, 1f
    dtb_be32 a0, a0
    j 2f
1:
    li a0, -1
2:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

aia_reg:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a2, 0(sp)
    la a2, word_reg
    call dtb_prop
    beqz a0, 1f
    ld t2, 0(sp)
    slli t0, t2, 2
    bltu a1, t0, 1f
    dtb_be32 t1, a0
    li t0, 2
    bne t2, t0, 2f
    dtb_be32 t3, a0, 4
    slli t1, t1, 32
    or t1, t1, t3
2:
    mv a0, t1
    j 3f
1:
    li a0, -1
3:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

aia_parent:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd a0, 0(sp)
    sd a1, 8(sp)
    mv a1, a2
    la a2, word_msi_parent
    call aia_cell
    sd a0, 16(sp)
    ld a0, 0(sp)
    ld a1, 8(sp)
    la a2, word_phandle
    call aia_cell
    ld t0, 16(sp)
    li t1, -1
    beq t0, t1, 1f
    bne t0, a0, 1f
    li a0, 1
    j 2f
1:
    li a0, 0
2:
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

.global aia_root
aia_root:
    li t0, QEMU_VIRT_APLIC_M
    li t1, (QEMU_VIRT_IMSIC_M >> 12)
    li t5, (QEMU_VIRT_APLIC_M + APLIC_MMSICFGADDR)
    sw t1, 0(t5)
    la t2, aia_lhxw
    ld t2, 0(t2)
    slli t2, t2, APLIC_MSICFGADDRH_LHXW_SHIFT
    li t5, (QEMU_VIRT_APLIC_M + APLIC_MMSICFGADDRH)
    sw t2, 0(t5)
    li t1, (QEMU_VIRT_IMSIC_S >> 12)
    li t5, (QEMU_VIRT_APLIC_M + APLIC_SMSICFGADDR)
    sw t1, 0(t5)
    la t2, aia_lhxs
    ld t2, 0(t2)
    slli t2, t2, APLIC_MSICFGADDRH_LHXS_SHIFT
    li t5, (QEMU_VIRT_APLIC_M + APLIC_SMSICFGADDRH)
    sw t2, 0(t5)
    la t3, aia_sources
    ld t3, 0(t3)
    li t1, 1                                # the source
    li t4, APLIC_SOURCECFG_D                # to the child domain, index 0
1:
    bgtu t1, t3, 2f
    slli t5, t1, 2
    add t5, t5, t0
    sw t4, APLIC_SOURCECFG(t5)
    addi t1, t1, 1
    j 1b
2:
    li t1, APLIC_DOMAINCFG_IE
    sw t1, APLIC_DOMAINCFG(t0)
    ret

.global aia_supervisor
aia_supervisor:
    li t0, QEMU_VIRT_APLIC_S
    li t1, APLIC_DOMAINCFG_IE
    sw t1, APLIC_DOMAINCFG(t0)
.global aia_file_open
aia_file_open:
    li t1, IMSIC_EIDELIVERY
    csrw CSR_SISELECT, t1
    li t1, 1
    csrw CSR_SIREG, t1
    li t1, IMSIC_EITHRESHOLD
    csrw CSR_SISELECT, t1
    csrw CSR_SIREG, zero
    li t1, IMSIC_EIE0
    csrw CSR_SISELECT, t1
    li t1, (1 << AIA_WAKE)
    csrw CSR_SIREG, t1
    ret

.global aia_file_page
aia_file_page:
    la t0, aia_file
    add t0, t0, a0
    lbu t0, 0(t0)
    li t1, 0xff
    beq t0, t1, 1f
    la t1, aia_lhxs
    ld t1, 0(t1)
    addi t1, t1, 12
    sll t0, t0, t1
    li t1, QEMU_VIRT_IMSIC_S
    add a0, t0, t1
    ret
1:
    li a0, 0                                # no file in the tree
    ret

.global irq_mmio_source
irq_mmio_source:
    li t0, QEMU_VIRT_VIRTIO0
    sub a0, a0, t0
    li t0, QEMU_VIRT_VIRTIO_STRIDE
    divu a0, a0, t0
    addi a0, a0, QEMU_VIRT_VIRTIO_IRQ0
    ret

.global virtio_irq_enable
virtio_irq_enable:
.ifdef DEBUG
    addi sp, sp, -32
    sd ra, 24(sp)
    sd a0, 0(sp)
    sd a1, 8(sp)
    sd a2, 16(sp)
    call irq_mmio_source
    ld t0, 0(sp)
    lwu a1, VIRTIO_MMIO_DEVICE_ID(t0)
    call irq_hold
    ld a0, 0(sp)
    ld a1, 8(sp)
    ld a2, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
.endif
    li t0, QEMU_VIRT_VIRTIO0
    sub a0, a0, t0
    li t0, QEMU_VIRT_VIRTIO_STRIDE
    divu a0, a0, t0
    addi a0, a0, QEMU_VIRT_VIRTIO_IRQ0
    j irq_enable

.ifdef DEBUG
.global irq_hold
irq_hold:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd a0, 0(sp)
    sd a1, 8(sp)
    la a0, knob_hold
    call knob_value
    ld t1, 8(sp)
    bne a0, t1, 1f                          # the knob names another device
    ld t0, 0(sp)
    li t1, 1
    sll t1, t1, t0
    la t0, irq_held
    ld t2, 0(t0)
    or t2, t2, t1
    sd t2, 0(t0)
1:
    ld ra, 24(sp)
    addi sp, sp, 32
    ret
.endif

.global irq_enable
irq_enable:
    beqz a0, 9f
    li t0, AIA_SOURCE_MAX
    bgtu a0, t0, 9f
    la t0, irq_faulted
    ld t0, 0(t0)
    srl t0, t0, a0
    andi t0, t0, 1
    bnez t0, 9f                             # failed: masked for the run
    slli t1, a0, 3
    la t2, irq_progress_fns
    add t2, t2, t1
    sd a1, 0(t2)
    la t2, irq_fault_fns
    add t2, t2, t1
    sd a2, 0(t2)
    li t0, QEMU_VIRT_APLIC_S
    slli t1, a0, 2
    add t1, t1, t0
    li t2, APLIC_SM_LEVEL_HIGH
    sw t2, APLIC_SOURCECFG(t1)
    la t3, aia_file
    lbu t3, 0(t3)
    slli t3, t3, APLIC_TARGET_HART_SHIFT
    addi t2, a0, 1                          # its identity
    or t3, t3, t2
    li t4, APLIC_TARGET
    add t4, t4, t1
    sw t3, 0(t4)
    li t4, (QEMU_VIRT_APLIC_S + APLIC_SETIENUM)
    sw a0, 0(t4)
    li t1, IMSIC_EIE0
    csrw CSR_SISELECT, t1
    csrr t3, CSR_SIREG
    li t4, 1
    sll t4, t4, t2
    or t3, t3, t4
    csrw CSR_SIREG, t3
9:
    ret

.global irq_drain
irq_drain:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    sd s2, 0(sp)
    li s0, 0                                # the identities claimed
    li s1, AIA_DRAIN_CLAIMS
1:
    csrrw t0, CSR_STOPEI, zero              # the top identity, claimed as it is read
    srli t0, t0, 16
    andi t0, t0, 0x7ff
    beqz t0, 2f
    li t1, AIA_IDENTITIES
    bgeu t0, t1, 11f
    li t1, 1
    sll t1, t1, t0
    or s0, s0, t1
11:
    addi s1, s1, -1
    bnez s1, 1b
2:
    fence iorw, rw
    li s2, 0                                # a source stuck this pass
    li t0, ~(1 << AIA_WAKE)
    and s0, s0, t0                          # the wake asks for nothing more
    la t0, sound_base
    ld t0, 0(t0)
    beqz t0, 3f
    li t1, QEMU_VIRT_VIRTIO0
    sub t0, t0, t1
    li t1, QEMU_VIRT_VIRTIO_STRIDE
    divu t0, t0, t1
    addi t0, t0, (QEMU_VIRT_VIRTIO_IRQ0 + 1) # the sound's identity
    li t1, 1
    sll t1, t1, t0
    and t2, s0, t1
    beqz t2, 3f
    xor s0, s0, t1
    addi a0, t0, -1
    call irq_serve
    or s2, s2, a0
3:
    beqz s0, 8f
    ctz t0, s0
    li t1, 1
    sll t1, t1, t0
    xor s0, s0, t1
    addi a0, t0, -1
    call irq_serve
    or s2, s2, a0
    j 3b
8:
    mv a0, s2
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 32
    ret

irq_serve:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, a0                               # the source
.ifdef DEBUG
    la t0, irq_held
    ld t0, 0(t0)
    srl t0, t0, s0
    andi s1, t0, 1                          # whether a knob holds its line
.endif
    li t0, QEMU_VIRT_PCIE_IRQ0
    bltu s0, t0, 1f
    addi t0, t0, QEMU_VIRT_PCIE_IRQ_COUNT
    bgeu s0, t0, 3f
.ifdef DEBUG
    bnez s1, 3f                             # held: its devices' ISRs left unread
.endif
    call pci_service_line                   # every device on the line
    j 3f
1:
    addi t2, s0, -QEMU_VIRT_VIRTIO_IRQ0
    li t3, QEMU_VIRT_VIRTIO_STRIDE
    mul t2, t2, t3
    li t3, QEMU_VIRT_VIRTIO0
    add t2, t2, t3                          # its transport
.ifdef DEBUG
    bnez s1, 2f
.endif
    lwu t3, VIRTIO_MMIO_INTERRUPT_STATUS(t2)
    sw t3, VIRTIO_MMIO_INTERRUPT_ACK(t2)
    la t3, sound_base
    ld t3, 0(t3)
    bne t2, t3, 3f
    call sound_service
.ifdef DEBUG
    j 3f
2:
    la t3, sound_base                       # held: no acknowledgement
    ld t3, 0(t3)
    bne t2, t3, 3f
    la t3, sound_live
    ld t3, 0(t3)
    beqz t3, 21f                            # not live: its open's requests acknowledged
    call sound_drain                        # its periods taken back and none offered
    call sound_in_flight
    beqz a0, 3f                             # none left with the device: held from here
21:
    la t2, sound_base
    ld t2, 0(t2)
    lwu t3, VIRTIO_MMIO_INTERRUPT_STATUS(t2)
    sw t3, VIRTIO_MMIO_INTERRUPT_ACK(t2)
.endif
3:
    li t0, (QEMU_VIRT_APLIC_S + APLIC_IN_CLRIP)
    srli t1, s0, 5
    slli t1, t1, 2
    add t1, t1, t0
    lwu t1, 0(t1)                           # the rectified inputs
    andi t2, s0, 31
    srl t1, t1, t2
    andi t1, t1, 1
    slli s1, s0, 3                          # the source's slot in the tables
    beqz t1, 6f                             # its line dropped: no window
    la t0, irq_progress_fns
    add t0, t0, s1
    ld t0, 0(t0)
    li a0, 0
    beqz t0, 4f
    mv a0, s0
    jalr t0                                 # its devices' progress
4:
    la t1, irq_since
    add t1, t1, s1
    ld t2, 0(t1)
    la t3, irq_last
    add t3, t3, s1
    ld t4, 0(t3)
    beqz t2, 5f                             # no window yet
    bne a0, t4, 5f                          # progress: a fresh window
    rdtime t5
    sub t5, t5, t2
    li t6, AIA_STALL_TICKS
    bgeu t5, t6, 7f                         # asserted, and no progress the whole of it
    j 51f
5:
    rdtime t5
    sd t5, 0(t1)
    sd a0, 0(t3)
51:
    li t0, (QEMU_VIRT_APLIC_S + APLIC_SETIPNUM)
    sw s0, 0(t0)                            # pended again while its input is high
    li a0, 0
    j 9f
6:
    la t1, irq_since
    add t1, t1, s1
    sd zero, 0(t1)
    li a0, 0
    j 9f
7:
    li t0, (QEMU_VIRT_APLIC_S + APLIC_CLRIENUM)
    sw s0, 0(t0)                            # masked
    la t0, irq_fault_fns
    add t0, t0, s1
    ld t0, 0(t0)
    beqz t0, 71f
    mv a0, s0
    jalr t0                                 # its driver in its error state, its devices reset
71:
    fence io, rw                            # the reset read back before the failure shows
    li t1, 1
    sll t1, t1, s0
    la t0, irq_faulted
    ld t2, 0(t0)
    or t2, t2, t1
    sd t2, 0(t0)
    la t0, irq_unreported
    ld t2, 0(t0)
    or t2, t2, t1
    sd t2, 0(t0)
    li a0, 1
9:
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
    ret

.global irq_report
irq_report:
    la t0, irq_unreported
    ld t1, 0(t0)
    beqz t1, 9f
    sd zero, 0(t0)
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, t1
1:
    beqz s0, 8f
    ctz s1, s0
    li t0, 1
    sll t0, t0, s1
    xor s0, s0, t0
    call uart_lock
    la a0, msg_source
    call uart_puts
    mv a0, s1
    call uart_put_dec
    la a0, msg_stalled
    call uart_puts
    call uart_unlock
    j 1b
8:
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
9:
    ret

.section .rodata
path_soc:
    .asciz "/soc"
word_address_cells:
    .asciz "#address-cells"
word_compatible:
    .asciz "compatible"
word_imsics:
    .asciz "riscv,imsics"
word_aplic:
    .asciz "riscv,aplic"
word_mtimer:
    .asciz "riscv,aclint-mtimer"
word_interrupts_extended:
    .asciz "interrupts-extended"
word_children:
    .asciz "riscv,children"
word_msi_parent:
    .asciz "msi-parent"
word_phandle:
    .asciz "phandle"
word_reg:
    .asciz "reg"
word_num_ids:
    .asciz "riscv,num-ids"
word_num_sources:
    .asciz "riscv,num-sources"
word_group_bits:
    .asciz "riscv,group-index-bits"
word_guest_bits:
    .asciz "riscv,guest-index-bits"
msg_platform_refused:
    .asciz "jab: interrupt platform refused: code "
msg_source:
    .asciz "jab: interrupt source "
msg_stalled:
    .asciz " stalled\n"
.ifdef DEBUG
knob_hold:
    .asciz "jab.hold="
.endif

.section .bss
.balign 8
.global aia_file
aia_file:
    .skip JAB_HARTS_MAX
.balign 8
aia_sources:
    .skip 8
aia_lhxw:
    .skip 8
aia_lhxs:
    .skip 8
irq_progress_fns:
    .skip (AIA_IDENTITIES * 8)
irq_fault_fns:
    .skip (AIA_IDENTITIES * 8)
irq_last:
    .skip (AIA_IDENTITIES * 8)
irq_since:
    .skip (AIA_IDENTITIES * 8)
.global irq_faulted
irq_faulted:
    .skip 8
irq_unreported:
    .skip 8
.ifdef DEBUG
irq_held:
    .skip 8
.endif
