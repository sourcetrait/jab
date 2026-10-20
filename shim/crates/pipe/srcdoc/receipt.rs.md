# receipt.rs

What a supervised launch leaves as JSON: its readiness, its startup's
outcome, and its exit receipt, the receipt held by the SDK to
`nu/type/launch/Receipt.nutype` and kept whole in the run's
`launch.nuon`. Every time of the receipt is nanoseconds from the go on
the supervisor's monotonic clock, `clock` saying so.

## struct Outcome

The startup's one decision, published before the supervisor acts on it:
`go`, the caller's authorization read within the allowance; `cancelled`,
its cancel read first; `expired`, the allowance spent with neither.
`go_utc` is the realtime clock as the go was decided, for dates alone.

## struct Readiness

The run's ownership record: the supervisor's pid and start, and the
gate's pid, group, and start, from the process table. The caller keeps
it before it authorizes, and ends a silent supervisor's run by it.

## struct Process

## struct Gate

A start is the process table's: clock ticks since the boot on Linux,
microseconds since the epoch on macOS, 100 ns units since 1601 on
Windows. A bounded gate's group is its own pid; an interactive one's is
the caller's.

## struct Authorization

The caller's go, and its cancel, each naming the launch's token.

## struct Done

A payload's account: its length and the bytes its pipe accepted;
`complete` with its first attempt's time and its completion's,
`incomplete` with its first attempt's time and the bytes accepted, or
`unattempted`; a screen's time found whole and whether it was.

## struct Held

The action the run's actions stopped at, and why: a screen that never
came whole or came under another header, or a pipe that broke.

## struct Thread

## struct Taken

A reading's requested time, its start and end, and every thread's id,
name, and cumulative CPU seconds; one never taken keeps its request
alone.

## struct RelayEnd

`clean`, its pipe closed; `failed`, with what it said; `stopped` once the
run ended; `never`, stopped before it connected.

## struct HelperEnd

## struct Clock

## struct Receipt

`end_ns` is the run's end: the child reaped once nothing it owns runs,
null when nothing ran. `status` is the measured command's exit status,
`signal` the signal that ended it instead; `failure` names what failed
the launch, null for a run that ended as it should; `cancelled_ns` when
the caller's cancel was read after the go; `startup_ns` the startup's
length, from the supervisor's start to its decision.
