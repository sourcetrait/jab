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

## .set GZ_MAGIC0

`u8`: a gzip's first byte.

## .set GZ_MAGIC1

`u8`: its second.

## .set GZ_DEFLATE

`u8`: the compression method byte for DEFLATE.

## .set GZ_FHCRC

`u8`: the header's flag for a header CRC.

## .set GZ_FEXTRA

`u8`: the flag for an extra field.

## .set GZ_FNAME

`u8`: the flag for a name.

## .set GZ_FCOMMENT

`u8`: the flag for a comment.

## .set GZ_HEADER

`u64`: bytes in the fixed header.

## .set GZ_TRAILER

`u64`: bytes in the trailer, the CRC-32 then the length.

## .set GZ_CRC_TICK

`u64`: bytes the CRC takes in between looks at the sound stream.

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

## gz_crc_ready

`u64`: 1 once the table is built.

## gz_crc

`256 u32`: the reflected CRC-32's table.
