# A byte generator as macros expanded in place: xorshift64 over a state word
# the program owns, named by the integer register holding its address.
# Scratch: t0-t2.

# Seeds the state word.
# state address The 8-byte word.
# value u64 Zero seeds 0x2545f4914f6cdd1d instead.
.macro jab.rng.seed state, value
    mv t0, \value
    bnez t0, .Ljab_rng_seed_set\@
    li t0, 0x2545f4914f6cdd1d
.Ljab_rng_seed_set\@:
    sd t0, 0(\state)
.endm

# Steps the state word and draws a byte.
# state address The 8-byte word, stepped.
# returns
#   dst u8 Bits 24 to 31 of the new word.
.macro jab.rng.byte dst, state
    ld t0, 0(\state)
    slli t1, t0, 13
    xor t0, t0, t1
    srli t1, t0, 7
    xor t0, t0, t1
    slli t1, t0, 17
    xor t0, t0, t1
    sd t0, 0(\state)
    srli \dst, t0, 24
    andi \dst, \dst, 255
.endm
