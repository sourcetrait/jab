# link.ld

The Jab kernel at the start of QEMU virt's RAM. .text.boot holds _start and
goes first so the entry sits at 0x80000000 whatever the object order.
Sections are page aligned; bss is zeroed by kmain.

## _bss_start

`addr`: the start of bss, where kmain starts zeroing.

## _bss_end

`addr`: the end of bss, page aligned.

## _kernel_end

`addr`: the end of the kernel image.
