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

## .set XX_STRIPE

`u64`: bytes in a stripe.

## .set XX_ACCS

`u64`: the accumulators.

## .set XX_SECRET

`u64`: bytes in the secret.

## .set XX_CONSUME

`u64`: bytes the secret moves on by each stripe.

## .set XX_STRIPES_PER_BLOCK

`u64`: the stripes between scrambles.

## .set XX_BLOCK

`u64`: bytes in a block of stripes.

## .set XX_MERGE_START

`u64`: the secret's offset where the fold starts.

## .set XX_LASTACC_START

`u64`: how far before the secret's last stripe the input's last stripe is read against.

## .set XX_SECRET_SIZE_MIN

`u64`: the reference's smallest secret.

## .set XX_MIDSIZE_START

`u64`: the secret's offset for the rounds past the eighth from 129 to 240 bytes.

## .set XX_MIDSIZE_LAST

`u64`: how far before the smallest secret's end the last sixteen bytes are read against.

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

## xx_prime64_1

`u64`.

## xx_prime64_2

`u64`.

## xx_prime64_3

`u64`.

## xx_prime64_4

`u64`.

## xx_prime64_5

`u64`.

## xx_prime32_1

`u64`.

## xx_prime_mx1

`u64`.

## xx_prime_mx2

`u64`.

## xx_init

`8 u64`: what the eight accumulators start at.

## xx_secret

`192 u8`: the default secret.

Copied from the reference at its pinned tag.

## xx_acc

`8 u64`: the accumulators.

## xx_lo

`u64`: a mix's low input, or the fold's.

## xx_hi

`u64`: a mix's high input.

## xx_data

`u64`: a stripe lane's input.

## xx_stripe_n

`u64`: the stripe xx_accumulate is at.
