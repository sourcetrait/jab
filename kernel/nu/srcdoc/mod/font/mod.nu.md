# font

## font_file

The assembler table the kernel indexes by character, `kernel/src/font.S`,
by this file's place in the kernel's tree, so the command writes it from
any working directory.

## main

The kernel's console font generated from a Spleen 12x24 BDF: the
printable ASCII glyphs, encodings 32 to 126, each `BBX 12 24 0 -5` with 24
`BITMAP` rows of four hex digits, the 12-pixel glyph in the high bits of
each 16, written as `.2byte` rows, eight a line, with a `# <code> <name>`
line before each glyph, under a header naming the Spleen version the BDF
carries and the license, `doc/thirdparty/spleen/LICENSE` (BSD 2-clause).
Asserts 95 glyphs of 24 rows each, then prints the file's path, the glyph
count, and the version. Spleen 2.2.0's `spleen-12x24.bdf` writes the
committed font.S but for the header's line naming its generator, the
committed file's naming `kernel/font/spleen.nu`, the script that wrote it.
