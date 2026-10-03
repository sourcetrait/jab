# page.S

Sv39 with 2 MiB pages, one root table and one level 1 table per GiB in use,
built once and never changed: the first 2 MiB (QEMU's test device), the
2 MiB at the UART, the PLIC's two, and the PCI ECAM's 128 for the kernel,
and the PCI MMIO window's whole GiB as one leaf in the root; in RAM the
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
and unless the PCI MMIO window is one aligned GiB.

## page_init

The root's entry for the first GiB points to the devices' table, then an
entry per GiB of RAM points to its table; the PCI MMIO window is a GiB leaf
in the root. The devices and the kernel's page are supervisor only, the
framebuffer user read-write, and the program's pages user
read-write-execute to the end of RAM, running on from one GiB's table into
the next.
