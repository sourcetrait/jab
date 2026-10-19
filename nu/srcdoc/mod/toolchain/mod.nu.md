# toolchain

## triples

The riscv64 binutils prefixes: the official toolchain's triple first,
then the names distributions package the tools under.

## main

The toolchain's install directory, or null for the tools on PATH.

## tool-prefix

The tools' command prefix: under a toolchain directory, `bin/<triple>`
for the first triple whose `as` is there, `as.exe` on Windows; on PATH,
the first triple whose `as` `which` finds. Untyped because it ends in
an error.

## march-check

Whether the assembler takes the RVA23 profile `march` names, tried on an
empty source under `dir`'s march/ before a build assembles anything,
the probe left there for the next; one that does not, binutils before
2.45, is refused with its version, since no other ISA will do. Untyped
because it can end in an error.
