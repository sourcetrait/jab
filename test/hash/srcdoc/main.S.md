# main.S

hash: XXH3-64. Fills a buffer with a ramp, then hashes prefixes of it
at lengths chosen to reach every one of the algorithm's four paths and
the boundaries between them, writing each as `h <length> <16 hex>`.
The test holds every one against the reference implementation.

## .set LONGEST

`u64`: the ramp's length, the longest prefix hashed.

## .set MODULUS

`u64`: the ramp's period, each byte its index modulo this.

## lengths

`26 i64`: the prefix lengths hashed, reaching the four paths and the boundaries between them, ended by -1.

## word_h

`3 u8`: a line's first word.

## buf

`20000 u8`: the ramp.

## line

`128 u8`: the line being built.

## lineptr

`addr`: the cursor in line.

## digits

`32 u8`: line_dec's digits, built backward.
