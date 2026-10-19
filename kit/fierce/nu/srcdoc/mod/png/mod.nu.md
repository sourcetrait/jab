# png

PNG files written without a compressor, the image data as stored deflate blocks:
`write-rgb <path> <w> <h> <pixels>` and `write-rgba <path> <w> <h> <pixels>`,
the pixels the rows in order, three or four bytes each; the chunk, CRC, and
Adler helpers exported for a writer of its own.

## write-rgb

An 8-bit RGB PNG of the pixels, w times h times three bytes.

## write-rgba

An 8-bit RGBA PNG of the pixels, w times h times four bytes.

## zlib

A zlib stream of the bytes as stored deflate blocks of at most 65535.

## chunk

A chunk: its length, kind, data, and CRC.
