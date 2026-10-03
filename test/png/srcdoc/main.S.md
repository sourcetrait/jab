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

## _start

Each file comes out of romfs and into memory, a read at a time from the
offset the one before returned. What the header says goes first, then the
decode with the table's frames and capacity. The directories are loaded
straight off the disk. A `done` line ends the run.

## report

On success the pixels go byte by byte, then the span table after them, four
bytes a row of every frame, as `y <hex>` lines, and the flags as `f <n>`.

## table

The last two rows ask for frames the height does not divide by and for a
buffer too small, on a file the rows before decoded.

## loads

Four frames, then a directory whose second frame is another size, one with
no 0.png, one that is not there, a file where a directory should be, and the
four frames with too small a buffer.
