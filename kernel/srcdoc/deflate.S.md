# deflate.S

DEFLATE, the decompressor only: RFC 1951, the format inside every gzip file
and inside every PNG. A stream is a run of blocks, each with a final bit and
a type - stored, fixed Huffman, or dynamic Huffman. Literals and lengths
share one alphabet where 256 ends the block and 257 upward are lengths with
extra bits; distances have their own. Every Huffman code is canonical, so a
table is nothing more than how many codes there are of each length and the
symbols in order, which is what makes decoding a walk down the lengths
rather than a lookup tree.

The decoder writes straight into the program's own buffer, and a
back-reference reads what it already wrote there, so the window is the
output itself and no separate 32 KiB buffer exists. Everything it needs
besides that lives in kernel bss, and every routine works in t registers
over those globals rather than holding state in callee-saved ones, which
keeps the whole file free of save-and-restore bookkeeping.

The input is a segment of bytes, and a caller may give the decoder a way to
ask for the next one: a PNG carries its stream cut into IDAT chunks, so
png.S hands the decoder each chunk's data as the one before runs out, and
the stream is never copied together. A gzip is one segment and gives no
hook.

## .set DF_OK

The codes are what went wrong, as jab.sys.gz.read reports it, four higher
there (JAB_GZ_*).

## deflate_inflate

The whole stream in one segment: deflate_begin with no hook, then
deflate_run.

## deflate_begin

A hook gives the decoder its next segment through deflate_segment and
returns 1, or returns 0 when there is no more; it may use any register the
decoder does not keep, which is all of them.

## deflate_byte

The bit buffer is left alone, so this reads what surrounds a stream - a zlib
header before it, an Adler-32 after it - from the same cursor the blocks
use.

## deflate_run

Fewer than eight bits are ever left in the bit buffer at the end, so the
next whole byte is the first after the stream.

## df_refill

Keeps nothing, so a caller saves what it holds in t registers first. The
hook is reached by a jump, so it returns straight to df_refill's caller.

## df_bits

When the segment runs out the bit buffer is kept, another segment asked for,
and the take goes on where it left off if one came.

## df_stored

The bits left in the buffer are dropped, then a length and its complement,
then the bytes.

## df_fixed

The tables are built each time rather than kept, since building them is a
few hundred stores.

## df_dynamic

The code-length code lengths come first, in the order the format names them
(df_clorder); then with those, the lengths of the two real tables, run
together: a length of its own, or 16 for the one before it three to six
times, 17 and 18 for runs of zeros; then the literal and length table, and
the distance table after it.

## df_construct

A canonical Huffman code is only its counts per length and its symbols in
order, so that is all this builds. Every symbol unused is no code at all,
which a distance table is allowed to be. Each length doubles what is left
of the code space, and a length that takes more than is left is refused;
then where each length's symbols start, and the symbols in order.

## df_decode

Walks the code lengths, taking one bit at a time, which is what a canonical
code allows: at each length the codes of that length run consecutively, so
a code within the count is the symbol at that offset. Every count here
lives on the stack rather than in a t register, because df_bits is a call
and a call keeps none of them.

## df_codes

A literal is a byte; anything above 256 is a length with a distance after
it, and the copy reads back what the output already holds, from that far
back.
