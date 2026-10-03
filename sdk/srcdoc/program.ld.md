# program.ld

A Jab program: a flat binary at JAB_PROGRAM_BASE (jab.inc), the address the
script sets as `.`, text first, then read-only data, data, and bss,
contiguous so objcopy emits one image. bss is not in the image; RAM is zero
when QEMU starts. Two segments, code with its read-only data and then
writable data, so the linker sees no segment that is read, write, and
execute at once, though the whole window is. The entry is the program's own
`_start`; the script defines no symbol of its own, so its .eye is empty.
