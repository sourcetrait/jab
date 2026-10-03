# sha3.S

SHA3-256, which is Keccak with a rate of 136 bytes and a capacity of 64. The
state is 25 lanes of 64 bits, which RV64 holds one to a register; a block is
exclusive-ored into the first 17 of them and the permutation is run; the
last block carries the padding, 0x06 where the message ends and 0x80 in the
last byte, both of which land in the same byte for a block that is one
short. The digest is the first four lanes, and since a lane is written out
little-endian, those four lanes are the digest exactly as anything else
computes it - which is why the call hands them back in a0 to a3 rather than
into a buffer.

The permutation itself is the five steps of the specification, kept as
loops over two small tables rather than unrolled: pi says where each lane
goes and rho how far it turns, and between them they are the only part that
is not arithmetic on neighbours.

## sha3_256

A fresh state, then whole blocks straight out of the message, the sound
stream looked at before each; the last block is what is left, then the
padding.

## sha3_absorb

Each lane is read little-endian a byte at a time so nothing depends on how
the message happens to be aligned.

## keccak_f

SHA3_ROUNDS of theta, rho with pi, chi and iota. Nothing here calls
anything, so the t registers hold throughout. Theta: each column folded to
one lane, then every lane in a column turned by its neighbours,
d = c[x - 1] ^ rotl(c[x + 1], 1). Rho and pi together: every lane turned and
moved at once. Chi: each lane against the two after it in its row. Iota:
this round's constant into the first lane.
