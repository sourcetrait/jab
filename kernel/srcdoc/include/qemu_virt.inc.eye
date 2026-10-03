set QEMU_VIRT_UART0 address [1] :the 16550 UART, byte registers, transmit at 0 and line status at 5
set QEMU_VIRT_VIRTIO0 address [3] :the first of the virtio-mmio transports
set QEMU_VIRT_VIRTIO_STRIDE u64 [4] :bytes between transports
set QEMU_VIRT_VIRTIO_COUNT u64 [5] :the transports the machine has
set QEMU_VIRT_VIRTIO_IRQ0 u64 [6] :transport 0's PLIC line, transport n's this plus n
set QEMU_VIRT_PCIE_ECAM address [8] :the host bridge's configuration space by ECAM
set QEMU_VIRT_PCIE_ECAM_SIZE u64 [9]
set QEMU_VIRT_PCIE_MMIO address [10] :the window the kernel gives each device its BARs from
set QEMU_VIRT_PCIE_MMIO_SIZE u64 [11]
set QEMU_VIRT_PCIE_IRQ0 u64 [12] :the first INTx line at the PLIC, a device's this plus its slot and pin modulo four
set QEMU_VIRT_PCIE_IRQ_COUNT u64 [13] :the INTx lines
set QEMU_VIRT_PLIC address [15] :the platform interrupt controller
set QEMU_VIRT_PLIC_PRIORITY u64 [16] :offset of the priority words, one per line
set QEMU_VIRT_PLIC_ENABLE u64 [17] :offset of the enable words, one block per context
set QEMU_VIRT_PLIC_ENABLE_STRIDE u64 [18] :bytes between contexts' enable blocks
set QEMU_VIRT_PLIC_CONTEXT u64 [19] :offset of the threshold and claim words, one block per context
set QEMU_VIRT_PLIC_CONTEXT_STRIDE u64 [20] :bytes between contexts' blocks
set QEMU_VIRT_PLIC_THRESHOLD u64 [21] :the threshold word within a context's block
set QEMU_VIRT_PLIC_CLAIM u64 [22] :the claim word within a context's block
set QEMU_VIRT_HART0_S_CONTEXT u64 [23] :hart 0's supervisor context
set QEMU_VIRT_PLIC_SIZE u64 [24]
set QEMU_VIRT_TEST address [26] :the test device, a 32-bit write ending QEMU with an exit code
set QEMU_TEST_PASS u32 [27] :the test device's word for a pass
set QEMU_TEST_FAIL u32 [28] :the test device's word for a failure, the exit code above it from bit 16
set QEMU_VIRT_DRAM address [30] :the start of RAM, where -kernel loads the kernel
set QEMU_VIRT_DRAM_SIZE u64 [31] :the RAM every run line gives the machine
set QEMU_VIRT_TIMEBASE u64 [33] :how many times the time counter ticks a second
