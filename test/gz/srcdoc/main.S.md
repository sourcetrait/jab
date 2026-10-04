# main.S

gz: the decompressor. Reads a set of .gz files out of the romfs disk,
asks each how long its contents will be, inflates it in one call, and
reports `g <code> <bytes> <said>` for each: the code the call gave,
the bytes that came out, and the length the trailer promised. The
kernel checks the CRC-32 itself, so JAB_GZ_OK already means the bytes
are the bytes that went in; the first file is also written out as hex
so the test can see that for itself once.

## .set DISK

`u8`: the romfs disk's id.

## .set GZBUF

`u64`: room for a compressed file, 64 KiB.

## .set OUTBUF

`u64`: room for a file's contents, 64 KiB.

## .set COLUMNS

`u64`: the bytes a hex line carries.

## _start

The compressed file comes out of romfs and into memory, a read at a time
from the offset the one before returned. Its path sits in a register, so the
find goes by the plain call, its registers loaded by hand, rather than the
macro, which takes a label.

How long the contents will be comes from jab.sys.gz.size, and then all of
them at once from jab.sys.gz.read, its capacity the length the trailer
promised. The g line carries a fourth number after the three above,
jab.sys.gz.size's own code.

The first file is written out byte by byte, COLUMNS bytes a line after
`x `, so the test sees one whole answer.

## paths

`7 addr`: the files inflated, ended by 0.

## path_text

`13 u8`: a text file's path on the romfs.

## path_random

`15 u8`: a random file's path on the romfs.

## path_tiny

`13 u8`: a tiny file's path on the romfs.

## path_empty

`10 u8`: an empty file's path on the romfs.

## path_png

`13 u8`: a compressed PNG's path on the romfs.

## path_font

`11 u8`: a source file's path on the romfs.

## word_g

`3 u8`: a file line's first word.

## word_x

`3 u8`: a hex line's first word.

## rec

`144 u8`: a file's romfs record.

## gzbuf

`65536 u8`: the compressed file as read.

## outbuf

`65536 u8`: the contents inflated.

## line

`512 u8`: the line being built.

## lineptr

`addr`: the cursor in line.

## digits

`32 u8`: line_dec's digits, built backward.
