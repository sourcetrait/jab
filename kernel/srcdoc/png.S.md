# png.S

PNG, decoded in the kernel into a sprite the program owns (jab.inc): what
GIMP 3 exports by default from any image mode, the five colour types at 8
bits a sample, grey and indexed at 1, 2, and 4 as well, never interlaced. A
file is a signature and a run of chunks, each a length, a type, its data,
and a CRC-32 over the type and the data; the IHDR says what the image is,
PLTE and tRNS carry a palette and its transparency, the IDATs carry one
zlib stream between them, and IEND closes the file. Everything else is
skipped by rule.

The file comes from one of two sources through png_fetch: bytes the program
holds (jab.sys.sprite.png) or a file on a romfs disk, read through the
kernel's own bounce (jab.sys.sprite.load), so a program need hold no buffer
for a file at all. Either way the bytes arrive in pieces: the chunk headers
and the small chunks into kernel buffers, each IDAT's data as segments of
PNG_SEGMENT bytes handed to deflate.S as the one before runs out, with a CRC
running over each chunk as it passes and compared at its end. The stream is
DEFLATE in a zlib jacket - two header bytes and an Adler-32 over what comes
out. The decode is in place: the stream inflates into the destination as
filtered rows, each a filter byte and the row's samples; the filters are
undone row by row against the row above; then the rows become native
pixels, four bytes each, front to back where the source is wider (RGBA) and
back to front where it is narrower, so nothing is read after it is
overwritten. The buffer rule in jab.inc is what makes both passes fit.

## .set PNG_ADLER_RUN

Both sums stay inside 64 bits between reductions.

## sys_sprite_png

The frames must divide the height, and the buffer must meet the rule
png_room checks for the whole sheet.

## sys_sprite_load

The first frame says what size every frame is; then the frames are counted
until one is missing; the room is every frame's block and a row on the end;
then each frame is decoded into its own block.

## png_frame_source

The name is built from the end of png_name: the terminator, .png, then the
digits. The file's bytes begin after its header and its name, which
romfs_entry measures.

## png_fetch

From memory a copy; from a disk, through the romfs bounce, as many sectors
as it holds at a time.

## png_le32_store

A record field, written a byte at a time so the record may sit anywhere.

## png_room

The rule is four bytes a pixel and four bytes a row after the header - the
row's filter byte on the way in, its span on the way out.

## png_header

The first chunk is the IHDR, of thirteen bytes, and its CRC is checked.
The compression and filter methods are always 0, and only interlace method
0 is taken. Grey and indexed images may be 1, 2, 4, or 8 bits; the other
types 8. The filters work on bytes a pixel, at least one.

## png_decode

The chunk walk: a palette goes into its buffer, and so does a tRNS; the
first IDAT starts the stream, and the cursor moves with it, the chunk it
stands on then checked whole, since the stream may have ended inside it;
IDATs after the stream has ended are checked and ignored; an IEND before
any IDAT reads as truncated; every chunk answers for itself with its CRC.
Then the rows are unfiltered, then the pixels converted.

## png_stream

The zlib header is method 8 with a window, no preset dictionary, and the
two bytes together a multiple of 31. The hook checks each chunk's CRC as it
is left behind. When the bytes run out the hook says why, or the file
simply ended. The Adler-32 after the stream is big-endian, taken over what
came out.

## png_more

The next piece of the IDAT the cursor stands on becomes the decoder's
segment, through png_seg with the CRC running; when that chunk is spent its
CRC is compared, and when the next chunk is an IDAT the cursor moves to it
and its first piece follows.

## png_adler

The two sums are reduced every PNG_ADLER_RUN bytes, which is as often as
64-bit registers need, and the sound stream is looked at as often; t0, t1,
and t5 live across sound_tick, which keeps every register.

## png_unfilter

The sound stream is looked at once a row. Paeth: the nearest of the byte to
the left, above, and above left to their sum less the corner, the left one
winning a tie, then the one above. Sub: the byte a pixel to the left; the
first pixel has none. Up: the byte above; the first row has none. Average:
half the sum of the two, rounded down.

## png_convert

Each pixel is stored as its four bytes so the record may sit anywhere. RGBA
shrinks by the filter bytes and runs front to back; everything narrower
grows and runs back to front. Grey and indexed: one sample a pixel, at
depth bits, high bits first; a grey sample scales to 255, an index reads
the palette; a grey key is two bytes, anything else is not one. RGB is
three bytes a pixel, back to front; its key is six bytes. Grey with alpha
is two bytes a pixel, back to front. RGBA is four bytes a pixel, front to
back, each row's filter byte stepped over. The rows-left count lives in t2
across sound_tick.
