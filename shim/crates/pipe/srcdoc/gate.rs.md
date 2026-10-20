# gate.rs

The gate: a supervised launch's child on Unix before its go. The
supervisor spawns this binary in the measured command's place, so the
child's pid, its group, and its start exist and are published before
anything measured runs, and nothing runs until the caller has kept them.
The gate blocks reading its control pipe; on the go it execs the command
in its own place, keeping its pid and its group, and on the pipe's close
with no go, the supervisor having abandoned it or died, it exits having
run nothing.

## const CONTROL_FD

The pipe's reading end, placed at 3 in the child before its exec, the
one descriptor the gate inherits past its standard three.

## const GO

## const ABANDONED

## const UNRUN

A command that cannot be run, as a shell answers one.

## fn gate

## fn gated

## fn released

## fn defaults

The dispositions the gate's command starts with put back to their
defaults, the signal mask cleared: an ignored signal survives an exec,
and the supervisor of an interactive launch ignores the interrupt and the
quit keys, while the runtime the gate itself starts under ignores
SIGPIPE.
