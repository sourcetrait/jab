# xxh3.S

XXH3-64, the default fast hash. TheUser's reason for choosing it over the
far smaller XXH64 is that it matches what the estate hashes with everywhere
else, and he took its cost knowingly.

It is four algorithms behind one name, chosen by length, over a fixed
192-byte secret: up to 16 bytes it is a keyed mix and an avalanche; to 128
it is pairs of 16-byte mixes working inward from both ends; to 240 it adds a
second pass; and beyond that it runs eight accumulators over 64-byte
stripes, scrambling them every sixteen, then folds them down. The seed is
always zero here, which removes the seed arithmetic from every branch: what
the reference adds to or subtracts from a secret word is simply that word.

Every constant below, the secret included, is copied from the reference at a
pinned tag rather than written from memory, because one wrong byte is a hash
that is wrong everywhere and says nothing about where. Reads are byte-wise
little-endian so nothing depends on how the program's buffer happens to sit,
and everything that must outlive a call is in bss or on the stack rather
than in a t register.

## xx_short

One to three bytes: the first, the middle and the last, with the length
itself, packed into a word. Four to eight: the first word and the last,
joined. Nine to sixteen: the first eight and the last eight. Nothing at all:
the secret alone, avalanched.

## xx_midlarge

Eight mixes, then the rest against a shifted secret, the two halves
avalanched apart and added; the last sixteen bytes go against the end of the
smallest secret.

## xx_long

The accumulators start at their primes; whole blocks of sixteen stripes go
in, scrambled after each; then the stripes left over, and the last stripe of
all; then the accumulators fold down.

## xx_accumulate

The stripe being done is kept in xx_stripe_n across xx_accumulate_512;
sound_tick keeps t0 and t1, so it survives that call in t0.

## xx_accumulate_512

The neighbouring lane takes the value as it is, and this one the product of
the key's halves.

## xx_le64

Read a byte at a time, as xx_le32 is, so nothing depends on how the buffer
is aligned.

## xx_secret

Copied from the reference at its pinned tag.
