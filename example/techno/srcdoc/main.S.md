# main.S

techno: technojab.mid, the piece shipped on the program's romfs,
played through the kernel's synthesizer on its own, with TECHNOJAB in
the middle of the screen while it plays; when the piece ends, so does
the program, its last release played out by the exit.

## read_piece

The file is read from its romfs record's offset, each read going on from
the offset the one before returned, until a read brings nothing or the file
ends.
