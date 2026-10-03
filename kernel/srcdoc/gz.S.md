# gz.S

gzip, the reading half: the thin jacket RFC 1952 puts around a DEFLATE
stream (deflate.S). Ten bytes of header, optional extra field, name and
comment, then the compressed bytes, then a CRC-32 of what comes out and its
length. Both ends of the jacket are checked, so a program that gets
JAB_GZ_OK back knows the bytes are the bytes that went in.

The length in the trailer is what makes one-shot decompression the right
shape here: a program reads it with jab.sys.gz.size, sizes its buffer, and
inflates in one call. DEFLATE cannot be entered in the middle, since a match
may reach back 32 KiB and the Huffman state is built as the stream is read,
so a resumable cursor would mean the kernel holding decoder state between
calls - which is the one thing every other call here avoids.

## sys_gz_read

A header that runs off the end, or leaves no compressed bytes before the
trailer, reads JAB_GZ_TRUNCATED. A deflate code is moved into this call's
range by adding four. The trailer then answers for what came out: first its
length, then its CRC; a mismatch reads JAB_GZ_LENGTH or JAB_GZ_CRC with the
bytes written still reported.

## gz_le32

gzip writes both trailer fields as little-endian longwords.

## gz_crc32

The CRC-32 gzip, zip, and PNG all use, computed as begin, one update, end.
The three parts are separate so bytes arriving in pieces, a PNG chunk
streamed off a disk, sum the same.

## gz_crc_table

Built on first use so nothing sits in the image for a program that never
asks.
