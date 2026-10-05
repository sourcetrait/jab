.include "riscv.inc"
.include "qemu_virt.inc"
.include "jab.inc"

.set TEST_PTE, ((((QEMU_VIRT_TEST >> 21) << 21) >> 12) << 10)
.set TEST_SLOT, (((QEMU_VIRT_TEST >> 21) & 0x1ff) * 8)
.set UART_PTE, ((((QEMU_VIRT_UART0 >> 21) << 21) >> 12) << 10)
.set UART_SLOT, (((QEMU_VIRT_UART0 >> 21) & 0x1ff) * 8)
.set APLIC_S_PTE, ((((QEMU_VIRT_APLIC_S >> 21) << 21) >> 12) << 10)
.set APLIC_S_SLOT, (((QEMU_VIRT_APLIC_S >> 21) & 0x1ff) * 8)
.set IMSIC_S_PTE, ((((QEMU_VIRT_IMSIC_S >> 21) << 21) >> 12) << 10)
.set IMSIC_S_SLOT, (((QEMU_VIRT_IMSIC_S >> 21) & 0x1ff) * 8)
.set ECAM_PTE, ((((QEMU_VIRT_PCIE_ECAM >> 21) << 21) >> 12) << 10)
.set ECAM_SLOT, (((QEMU_VIRT_PCIE_ECAM >> 21) & 0x1ff) * 8)
.set ECAM_PAGES, (QEMU_VIRT_PCIE_ECAM_SIZE >> 21)
.set PCIE_MMIO_PTE, ((QEMU_VIRT_PCIE_MMIO >> 12) << 10)
.set PCIE_MMIO_ROOT_SLOT, (((QEMU_VIRT_PCIE_MMIO >> 30) & 0x1ff) * 8)
.set KERNEL_PTE, ((((QEMU_VIRT_DRAM >> 21) << 21) >> 12) << 10)
.set KERNEL_SLOT, (((QEMU_VIRT_DRAM - QEMU_VIRT_DRAM) >> 21) * 8)
.set DISPLAY_PTE, ((((JAB_DISPLAY_BASE >> 21) << 21) >> 12) << 10)
.set DISPLAY_SLOT, (((JAB_DISPLAY_BASE - QEMU_VIRT_DRAM) >> 21) * 8)
.set DISPLAY_PAGES, ((JAB_DISPLAY_SIZE + 0x1fffff) >> 21)
.set PROGRAM_PTE, ((((JAB_PROGRAM_BASE >> 21) << 21) >> 12) << 10)
.set PROGRAM_SLOT, (((JAB_PROGRAM_BASE - QEMU_VIRT_DRAM) >> 21) * 8)
.set PROGRAM_PAGES, (JAB_PROGRAM_SIZE >> 21)
.set RAM_GIBS, (QEMU_VIRT_DRAM_SIZE >> 30)
.set RAM_ROOT_SLOT, (((QEMU_VIRT_DRAM >> 30) & 0x1ff) * 8)
.set PAGE_PTE_STEP, ((0x200000 >> 12) << 10)

.if (JAB_PROGRAM_BASE + JAB_PROGRAM_SIZE) != (QEMU_VIRT_DRAM + QEMU_VIRT_DRAM_SIZE)
.error "the program's window does not end at the end of RAM"
.endif
.if (JAB_DISPLAY_BASE + DISPLAY_PAGES * 0x200000) != JAB_PROGRAM_BASE
.error "the program's window does not begin after the framebuffer"
.endif
.if (QEMU_VIRT_PCIE_MMIO & 0x3fffffff) != 0 || QEMU_VIRT_PCIE_MMIO_SIZE != 0x40000000
.error "the PCI MMIO window is not one aligned GiB"
.endif
.if ((QEMU_VIRT_APLIC_S >> 21) == (QEMU_VIRT_APLIC_M >> 21)) || ((QEMU_VIRT_IMSIC_S >> 21) == (QEMU_VIRT_IMSIC_M >> 21))
.error "a supervisor page shares its 2 MiB with the machine level's"
.endif

.section .text
.global page_build
page_build:
    la t0, page_root
    la t1, page_l1_devices
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, PTE_TABLE
    sd t1, (((QEMU_VIRT_TEST >> 30) & 0x1ff) * 8)(t0)
    li t1, PCIE_MMIO_PTE | PTE_KERNEL_RW
    sd t1, PCIE_MMIO_ROOT_SLOT(t0)
    li t1, RAM_ROOT_SLOT
    add t0, t0, t1
    la t1, page_l1_ram
    li t2, RAM_GIBS
    li t4, 4096
1:
    srli t3, t1, 12
    slli t3, t3, 10
    ori t3, t3, PTE_TABLE
    sd t3, 0(t0)
    addi t0, t0, 8
    add t1, t1, t4
    addi t2, t2, -1
    bnez t2, 1b
    la t0, page_l1_devices
    li t1, TEST_PTE | PTE_KERNEL_RW
    sd t1, TEST_SLOT(t0)
    li t1, UART_PTE | PTE_KERNEL_RW
    sd t1, UART_SLOT(t0)
    li t1, APLIC_S_PTE | PTE_KERNEL_RW
    li t2, APLIC_S_SLOT
    add t2, t2, t0
    sd t1, 0(t2)
    li t1, IMSIC_S_PTE | PTE_KERNEL_RW
    li t2, IMSIC_S_SLOT
    add t2, t2, t0
    sd t1, 0(t2)
    li t1, ECAM_SLOT
    add t0, t0, t1
    li t1, ECAM_PTE | PTE_KERNEL_RW
    li t2, ECAM_PAGES
    li t3, PAGE_PTE_STEP
21:
    sd t1, 0(t0)
    add t1, t1, t3
    addi t0, t0, 8
    addi t2, t2, -1
    bnez t2, 21b
    la t0, page_l1_ram
    li t1, KERNEL_PTE | PTE_KERNEL_RWX
    sd t1, KERNEL_SLOT(t0)
    li t1, DISPLAY_SLOT
    add t0, t0, t1
    li t1, DISPLAY_PTE | PTE_USER_RW
    li t2, DISPLAY_PAGES
    li t3, PAGE_PTE_STEP
3:
    sd t1, 0(t0)
    add t1, t1, t3
    addi t0, t0, 8
    addi t2, t2, -1
    bnez t2, 3b
    la t0, page_l1_ram
    li t1, PROGRAM_SLOT
    add t0, t0, t1
    li t1, PROGRAM_PTE | PTE_USER_RWX
    li t2, PROGRAM_PAGES
    li t3, PAGE_PTE_STEP
4:
    sd t1, 0(t0)
    add t1, t1, t3
    addi t0, t0, 8
    addi t2, t2, -1
    bnez t2, 4b
    ret

.global page_activate
page_activate:
    la t0, page_root
    srli t0, t0, 12
    li t1, SATP_MODE_SV39
    or t0, t0, t1
    csrw satp, t0
    sfence.vma
    ret

.section .bss
.balign 4096
page_root:
    .skip 4096
page_l1_devices:
    .skip 4096
page_l1_ram:
    .skip 4096 * RAM_GIBS
