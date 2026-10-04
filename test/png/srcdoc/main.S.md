# main.S

png: the decoder. Reads a set of PNG files out of the romfs disk and,
for each row of its table, asks jab.sys.png.size and reports `s <code>
<width> <height>`, then decodes the file into a sprite of that many
frames with that much buffer and reports `p <code> <frame width>
<height> <frames>`, or `p <code>` when the decode failed; a decoded
sprite's pixels follow as hex, 64 bytes to a line as `x <hex>`, then
its span table as `y <hex>` and its flags as `f <n>`, for the test to
hold against what it put in. Then, for each row of a
second table, loads a sprite from a directory of frames straight off
the disk and reports `l <code> <frame width> <height> <frames>` the
same way. The frames and the capacity come from the tables at run
time, so the plain ecall is used where the macro would want constants.

## .set DISK

`u8`: the romfs disk's id.

## .set PNGBUF

`u64`: room for a PNG, 64 KiB.

## .set SPRITEBUF

`u64`: room for a sprite, 64 KiB.

## .set COLUMNS

`u64`: the bytes a hex line carries.

## _start

Each file comes out of romfs and into memory, a read at a time from the
offset the one before returned. What the header says goes first, then the
decode with the table's frames and capacity. The directories are loaded
straight off the disk. A `done` line ends the run.

## report

On success the pixels go byte by byte, then the span table after them, four
bytes a row of every frame, as `y <hex>` lines, and the flags as `f <n>`.

## table

`78 u64`: the path, the frames, and the capacity of each decode, ended by a 0 path.

The last two rows ask for frames the height does not divide by and for a
buffer too small, on a file the rows before decoded.

## loads

`14 u64`: the directory and the capacity of each load, ended by a 0 directory.

Four frames, then a directory whose second frame is another size, one with
no 0.png, one that is not there, a file where a directory should be, and the
four frames with too small a buffer.

## path_rgba8

`11 u8`: an RGBA PNG at 8 bits.

## path_rgb8

`10 u8`: an RGB PNG at 8 bits.

## path_grey8

`11 u8`: a grey PNG at 8 bits.

## path_grey4

`11 u8`: a grey PNG at 4 bits.

## path_grey2

`11 u8`: a grey PNG at 2 bits.

## path_grey1

`11 u8`: a grey PNG at 1 bit.

## path_ga8

`9 u8`: a grey PNG with alpha at 8 bits.

## path_idx8

`10 u8`: an indexed PNG at 8 bits.

## path_idx4

`10 u8`: an indexed PNG at 4 bits.

## path_idx2

`10 u8`: an indexed PNG at 2 bits.

## path_idx1

`10 u8`: an indexed PNG at 1 bit.

## path_sheet

`11 u8`: a sheet decoded as two frames.

## path_split

`11 u8`.

## path_big

`9 u8`.

## path_extras

`12 u8`.

## path_depth16

`13 u8`.

## path_interlaced

`16 u8`.

## path_badcrc

`12 u8`.

## path_badadler

`14 u8`.

## path_badfilter

`15 u8`.

## path_short

`11 u8`.

## path_truncated

`15 u8`.

## path_notpng

`12 u8`.

## dir_walker

`8 u8`: a directory of four frames.

## dir_mixed

`7 u8`: a directory whose second frame is another size.

## dir_nozero

`8 u8`: a directory with no 0.png.

## dir_missing

`9 u8`: a directory that is not there.

## word_s

`3 u8`: a size line's first word.

## word_p

`3 u8`: a decode line's first word.

## word_l

`3 u8`: a load line's first word.

## word_x

`3 u8`: a pixel hex line's first word.

## word_y

`3 u8`: a span table hex line's first word.

## word_f

`3 u8`: the flags line's first word.

## msg_done

`6 u8`: the last line.

## msg_missing

`27 u8`: the line for a missing fixture.

## rec

`144 u8`: a file's romfs record.

## pngbuf

`65536 u8`: the PNG as read.

## sprite

`65536 u8`: the sprite record decoded into.

## line

`512 u8`: the line being built.

## lineptr

`addr`: the cursor in line.

## digits

`32 u8`: line_dec's digits, built backward.
