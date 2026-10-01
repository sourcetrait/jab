# jab.inc

Every kernel call is a `jab.sys.*` macro so the trap boundary is visible at
each site in the name: a program reads where it leaves its own code and
enters the kernel. The mathematics beside this file, jab_f32.inc,
jab_f64.inc, and jab_rng.inc, is carried code expanded in place, never a call
and never a trap, and jab.inc includes none of it: a program includes what it
names and pays for what it uses.
