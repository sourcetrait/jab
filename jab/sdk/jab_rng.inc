# jab_rng.inc: a generator of chance as macros the program expands in
# place, an xorshift over a 64-bit state word the program owns: nothing
# here is a call, nothing traps, and the library carries no data, so
# the program declares the word and passes its address. `.include
# "jab_rng.inc"` after jab.inc, which includes none of these.
#
# Operands are registers, the destination first, and a macro is named
# for what its destination becomes; the state is named by the integer
# register holding its address. The scratch set, which any macro here
# may use and no operand or live value sits in, is t0 to t2. A program
# seeds once, from a fixed word for a run it wants repeated or from
# jab.sys.random, the kernel's entropy, for one it does not, and draws
# a byte at a time after.

# jab.rng.seed state, value: the state word at the address in state
# becomes value, an integer register, or 0x2545f4914f6cdd1d when value
# is 0, since zero is the xorshift's fixed point and would give zero
# forever. 4 instructions, up to 11 when the default is loaded.
.macro jab.rng.seed state, value
    mv t0, \value
    bnez t0, .Ljab_rng_seed_set\@
    li t0, 0x2545f4914f6cdd1d
.Ljab_rng_seed_set\@:
    sd t0, 0(\state)
.endm

# jab.rng.byte dst, state: the state word at the address in state
# stepped once, x ^= x << 13, x ^= x >> 7, x ^= x << 17, the xorshift64
# of Marsaglia's, and dst, an integer register, becomes bits 24 to 31
# of the new word, a byte of chance. The sequence from a seed is fixed
# and test/math pins one. 10 instructions.
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
