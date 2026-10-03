# jab_rng.inc

A byte generator as macros expanded in place: Marsaglia's xorshift64 with
shifts 13, 7, 17, over a state word the program declares and passes by
address in an integer register, so the library carries no data and two
generators can run side by side. The byte is bits 24 to 31 of the new word.
Zero is the generator's fixed point and would give zero forever, so a zero
seed takes 0x2545f4914f6cdd1d instead. The sequence from a seed is fixed and
test/math pins it, computing the same shifts on the host.

A program seeds once: from a fixed word for a run it wants repeated, or from
jab.sys.random, the kernel's entropy device, for one it does not.

## .macro jab.rng.seed

4 instructions, 11 when the default is loaded.

## .macro jab.rng.byte

10 instructions.
