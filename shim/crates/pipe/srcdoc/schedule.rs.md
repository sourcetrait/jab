# schedule.rs

A supervised launch's schedule: everything the supervisor does, written
by the SDK before the spawn (`launch schedule-of`, held to
`nu/type/launch/Schedule.nutype`), a binary payload carried as JSON's
array of its byte values as nushell's `to json` writes one. Every time is
nanoseconds from the go, every bound nanoseconds.

## enum Mode

`bounded`: the child is the measured command, the resolved `timeout`
running QEMU, in a process group of its own, its stdin empty and its
stdout and stderr files. `interactive`: the child is QEMU itself in the
terminal's foreground group with the terminal's stdio, no bound, its go
the supervisor's own.

## struct Schedule

`command` is what the gate runs in its place; `env` the child's
environment beside the caller's, the shims' preloads among it, applied
to the child alone, since a preload in the supervisor would take its own
writes (the evdev shim swallows every write to the pad's fifo); `pipes`
each pipe an action writes, by name, its end a fifo's path off Windows
or a relay's endpoint on Windows; `header` the pad port's header, which
goes in once QEMU lives and ahead of every action; `actions` in their
order; `readings` each thread reading asked; `relays` the pipes the
launch holds the one client of; `helpers` the processes run beside the
child; `bounds` its timings.

## struct Variable

## struct PipeEnd

## struct PipeBytes

## struct Action

`kind` is `key`, `send`, `pad`, `screen`, or `quit`; `index` its row in
its own table, the keys', the sends', or the pad's groups'.

## struct Screen

The screen's file, its expected header, and the whole file's size, the
header and three bytes a pixel.

## struct Reading

`held`, the two readings of `--threads`, or `at`, one of `--threads-at`.

## struct Relay

## struct Helper

## struct Bounds

`startup_ns` bounds the startup from the supervisor's start: its
readiness, the caller's go, and every relay's connection. `retry_ns` is
how often a waiting payload is tried again; `screen_ns` and
`screen_poll_ns` how long and how often a screen is looked for whole;
`cpu_ns` the CPU's sample; `grace_ns` the grace a relay's clean end, a
broken pipe, or a helper's failure gets for QEMU's own exit; `term_ns`
the wait between TERM and KILL.

### fn load

### fn problems

What keeps a schedule from being run, each named: a token not of the
form; no command; a bounded launch without its stdout's and stderr's
files; an action or the header on a pipe the schedule names no end of;
a screen with no file; an interactive launch with timed actions or
readings; a relay endpoint twice; a helper with no command or no file
for its stderr.

### fn pipe

## fn from_ns
