# main.S

checksum: SHA3-256. Takes the digest of four things and writes each
out as hex, `d <64 hex digits>`: nothing at all, the three bytes the
standard's own vector uses, a short ramp, and a long one that runs to
many blocks. The test holds the first two against the published
answers and the others against what the host computes.

## .set RAMP

`u64`: the short ramp's length.

## .set LONG

`u64`: the long ramp's length, many blocks.

## _start

The ramps are filled before anything is taken of them. Nothing at all is the
short ramp at length 0.

## digest

The digest's four registers are stored to out in order, which is the order
anything else computes it, and printed a byte at a time.

## abc

`3 u8`: the standard's own three-byte vector, unterminated.

## word_d

`3 u8`: a line's first word.

## out

`32 u8`: the digest as it came back in a0 to a3.

## ramp

`200 u8`: the short ramp, each byte its index.

## long

`100000 u8`: the long ramp, each byte its index modulo 251.

## line

`256 u8`: the line being built.

## lineptr

`addr`: the cursor in line.
