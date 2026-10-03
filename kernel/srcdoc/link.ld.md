# link.ld

The Jab kernel at the start of QEMU virt's RAM. .text.boot holds _start and
goes first so the entry sits at 0x80000000 whatever the object order.
Sections are page aligned; bss is zeroed by kmain.
