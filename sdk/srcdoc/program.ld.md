# program.ld

A Jab program: a flat binary at JAB_PROGRAM_BASE (jab.inc), the address the
script sets as `.`. Its first page first: `.jab.header`, the jump to the
code and the header's fields, which the tool generates into `jab_header.S`
at every build (header-source), held to 64 bytes; `.jab.decl` at 64 bytes
in, the program's declaration, empty for one listing no specs, held to end
inside the page; then `__jab_code`, the address the jump takes, held to
the second page, with text there, then read-only data, data, and bss,
contiguous so objcopy emits one image, the page's gaps zero. bss is not in
the image; RAM is zero when QEMU starts. Two segments, code with the first
page and its read-only data and then writable data, so the linker sees no
segment that is read, write, and execute at once, though the whole window
is. The entry is the program's own `_start`; the script's one symbol is
`__jab_code`, and its .eye is empty.
