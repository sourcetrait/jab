# lib.rs

Dead code and unused imports are allowed off Windows: the relay's own
mode, `run`'s `duplex`, connects and relays on Windows alone, so
elsewhere the relay's core is reached by the tests and the supervisor's
in-process relays, and `relay`'s glob import goes unused there.

Every module's crate-visible items come into global scope here, so each
name is the crate's one, and every module imports `crate::*` alone; the
`r` hub carries the long external paths by family: tokio's `mpsc`,
mach2's timebase (`mach`), tokio's named pipes (`np`), and windows-sys's
calls (`win`).

The modules by concern: `connect`, `relay`, and `run` the relay's mode;
`supervise` the supervisor, with `control` its control files, `schedule`
and `receipt` its input and its record, `child` the child it owns,
`gate` the Unix child's inert start, `payload` a timed action's way
into a pipe, `link` its in-process relays, `helper` the processes it
runs beside the child, and `table` the process table it reads; `lock`
the host's launch lock and `group` a caller's forced end of a run's
group, each a mode of the same binary.
