set TEST_PTE u64 [5] :the PTE, flags clear, of the 2 MiB page holding the test device
set TEST_SLOT u64 [6] :that page's slot in a level 1 table, in bytes
set UART_PTE u64 [7] :the PTE, flags clear, of the 2 MiB page holding the UART
set UART_SLOT u64 [8] :that page's slot in a level 1 table, in bytes
set PLIC_PTE u64 [9] :the PTE, flags clear, of the PLIC's first 2 MiB page
set PLIC_SLOT u64 [10] :that page's slot in a level 1 table, in bytes
set PLIC_PAGES u64 [11] :the 2 MiB pages the PLIC spans
set ECAM_PTE u64 [12] :the PTE, flags clear, of the PCI ECAM's first 2 MiB page
set ECAM_SLOT u64 [13] :that page's slot in a level 1 table, in bytes
set ECAM_PAGES u64 [14] :the 2 MiB pages the PCI ECAM spans
set PCIE_MMIO_PTE u64 [15] :the PTE, flags clear, of the PCI MMIO window's GiB leaf
set PCIE_MMIO_ROOT_SLOT u64 [16] :that leaf's slot in the root table, in bytes
set KERNEL_PTE u64 [17] :the PTE, flags clear, of the kernel's 2 MiB page
set KERNEL_SLOT u64 [18] :that page's slot across the RAM tables, in bytes
set DISPLAY_PTE u64 [19] :the PTE, flags clear, of the framebuffer's first 2 MiB page
set DISPLAY_SLOT u64 [20] :that page's slot across the RAM tables, in bytes
set DISPLAY_PAGES u64 [21] :the 2 MiB pages the framebuffer spans
set PROGRAM_PTE u64 [22] :the PTE, flags clear, of the program window's first 2 MiB page
set PROGRAM_SLOT u64 [23] :that page's slot across the RAM tables, in bytes
set PROGRAM_PAGES u64 [24] :the 2 MiB pages of the program's window
set RAM_GIBS u64 [25] :the GiBs of RAM, a level 1 table each
set RAM_ROOT_SLOT u64 [26] :the first RAM GiB's slot in the root table, in bytes
set PAGE_PTE_STEP u64 [27] :how much more PTE the next 2 MiB page is
call page_init > tables page_root u64 [41:124] :turns on Sv39 through satp, everything at its physical address
 tables :the root table and page_l1_devices and page_l1_ram it points to, set once and never changed
bss local page_root 512 u64 [128:129] :the root table
bss local page_l1_devices 512 u64 [130:131] :the level 1 table for the first GiB, the devices
bss local page_l1_ram 2048 u64 [132:133] :the level 1 tables for RAM, a GiB each, side by side
