# capture

## wave

Read a wav QEMU's wav backend recorded: its rate, channels, and bits
a sample from the format chunk, and the data chunk's samples as they
lie, little-endian, the channels interleaved a frame at a time, to the
end of the file when the chunk's size was never written.

- the backend writes this size as it closes the file, which
  QEMU 11.1.2 never does at exit, so a size of 0, or one past
  the file's end, means the samples run to the end of the file

## screen

Read a screen `launch` took: its size and its pixels, three bytes
each, red, green, blue, row by row from the top left.

- Bytes whatever the file holds: `open --raw` gives text for a file of
  valid UTF-8, a capture whose every channel is below 0x80 among them
- P6, a line of width and height, the maximum, then the pixels

## ink

Where a color is on a screen: how many pixels have it and their
bounding box (-1 all round when none do). `color` is six hex digits,
RRGGBB.

## pixel

The color of the pixel at x, y as six hex digits, RRGGBB.

## strings

The strings in a binary that start with `prefix`, each read to its
terminator: how a test asks a kernel image what text it carries.

## hot

The named functions of a program's ELF as QEMU's translator sees
them: each one's start and end from the ELF's symbols, the end being
the next symbol's address, an assembler constant passed over (`nm`
lists a `.set` as an absolute symbol, its value no address, and one
valued inside the code would cut a function short; JAB_DENIED's all
ones would not even parse), whether it lies within one page of code,
since a translation block ends at a page boundary and chains within
a page only, so a loop straddling one runs several times slower, and
how many ecalls its code holds, read from the disassembly, since a
kernel call in a hot loop is a trap each time round. The tools are
the ones the build's flags stamp names, beside the ELF.
