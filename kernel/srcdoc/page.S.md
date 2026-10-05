# page.S

Sv39 with 2 MiB pages, one root table and one level 1 table per GiB in use,
built once and never changed: the first 2 MiB (QEMU's test device), the
2 MiB at the UART, the APLIC supervisor domain's 2 MiB, the supervisor
IMSIC files' 2 MiB, and the PCI ECAM's 128 for the kernel, and the PCI MMIO
window's whole GiB as one leaf in the root, the machine level's domain and
files never mapped; in RAM the
kernel's own 2 MiB at its start, supervisor only, then the framebuffer's
pages, user read-write, then the program's window, user
read-write-execute, which is every page from there to the end of the
machine's 4 GiB. Everything is mapped at its physical address; the virtio
transports sit in the UART's page. The RAM tables sit side by side in bss,
so a 2 MiB page's slot is its distance from the start of RAM, in pages,
times eight, whichever GiB it falls in.

For each address the file sets the PTE of the 2 MiB page holding it, the
page's aligned base as a PPN shifted into place, and the byte offset of that
page's slot in a level 1 table. Assembly stops unless the program's window,
as the SDK states it, ends where RAM does and begins after the framebuffer,
unless the PCI MMIO window is one aligned GiB, and unless each supervisor
page of the AIA has its 2 MiB apart from the machine level's.

## .set TEST_PTE

`u64`: the PTE, flags clear, of the 2 MiB page holding the test device.

## .set TEST_SLOT

`u64`: that page's slot in a level 1 table, in bytes.

## .set UART_PTE

`u64`: the PTE, flags clear, of the 2 MiB page holding the UART.

## .set UART_SLOT

`u64`: that page's slot in a level 1 table, in bytes.

## .set APLIC_S_PTE

`u64`: the PTE, flags clear, of the 2 MiB page holding the APLIC's
supervisor domain.

## .set APLIC_S_SLOT

`u64`: that page's slot in a level 1 table, in bytes.

## .set IMSIC_S_PTE

`u64`: the PTE, flags clear, of the 2 MiB page holding the supervisor
IMSIC files, a page a hart.

## .set IMSIC_S_SLOT

`u64`: that page's slot in a level 1 table, in bytes.

## .set ECAM_PTE

`u64`: the PTE, flags clear, of the PCI ECAM's first 2 MiB page.

## .set ECAM_SLOT

`u64`: that page's slot in a level 1 table, in bytes.

## .set ECAM_PAGES

`u64`: the 2 MiB pages the PCI ECAM spans.

## .set PCIE_MMIO_PTE

`u64`: the PTE, flags clear, of the PCI MMIO window's GiB leaf.

## .set PCIE_MMIO_ROOT_SLOT

`u64`: that leaf's slot in the root table, in bytes.

## .set KERNEL_PTE

`u64`: the PTE, flags clear, of the kernel's 2 MiB page.

## .set KERNEL_SLOT

`u64`: that page's slot across the RAM tables, in bytes.

## .set DISPLAY_PTE

`u64`: the PTE, flags clear, of the framebuffer's first 2 MiB page.

## .set DISPLAY_SLOT

`u64`: that page's slot across the RAM tables, in bytes.

## .set DISPLAY_PAGES

`u64`: the 2 MiB pages the framebuffer spans.

## .set PROGRAM_PTE

`u64`: the PTE, flags clear, of the program window's first 2 MiB page.

## .set PROGRAM_SLOT

`u64`: that page's slot across the RAM tables, in bytes.

## .set PROGRAM_PAGES

`u64`: the 2 MiB pages of the program's window.

## .set RAM_GIBS

`u64`: the GiBs of RAM, a level 1 table each.

## .set RAM_ROOT_SLOT

`u64`: the first RAM GiB's slot in the root table, in bytes.

## .set PAGE_PTE_STEP

`u64`: how much more PTE the next 2 MiB page is.

## page_build

The root's entry for the first GiB points to the devices' table, then an
entry per GiB of RAM points to its table; the PCI MMIO window is a GiB leaf
in the root. The devices and the kernel's page are supervisor only, the
framebuffer user read-write, and the program's pages user
read-write-execute to the end of RAM, running on from one GiB's table into
the next. Hart 0 builds them once; every hart shares them, and a change
after the secondaries are released would need a shootdown across the harts.

## page_activate

The tables in satp, Sv39, and sfence.vma: each hart's own, hart 0 in kmain
and a secondary in machine mode before its mret, where satp takes effect for
supervisor mode.

## page_root

`512 u64`: the root table.

## page_l1_devices

`512 u64`: the level 1 table for the first GiB, the devices.

## page_l1_ram

`2048 u64`: the level 1 tables for RAM, a GiB each, side by side.
