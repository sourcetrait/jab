# gauge/bench

## WORKSPACE

The workspace's root, the checkout this module lies in, from the module's own
file at parse time.

## presented-calls

A run's frames in order, each with the interval from the presenting
call before it to its own, both read at the call's start, the flip's
end less the call: null for a frame not presented and for the first
presented; null with `call_unknown` set for a frame presented after a
retried flip, whose `flip_us` sums every attempt so its call's start
is unknown, and for the next frame presented after it; and with
whether the frame before it ran past the period. The clocked frames
alone.

## completion-of

Each row's completion interval, read from `flip_interval_us` in a report
written before AcceptanceInterval renamed it, the same flip end to flip
end.

## bench-frames

Frames pooled: the counts; the acceptance interval, between consecutive
presents' acceptance stamps, and the completion interval, between their
flips' ends, kept apart (AcceptanceInterval); the interval
between presenting calls, the submission age, the critical path, the
drawing, the wait, the pacing, and the await by nearest rank (stats);
the presenting calls' known intervals on the tick grid, within a
millisecond of a whole number of periods, counted by that number, the
rest off it, and the intervals unknown after a retried flip apart
(presented-calls); the wakes, attempts, and refusals; the flips early
and failed; the frames at or over the ceiling, the tail; the fast
frames, under the period, and those of them that waited; and the
catch-up intervals, under half a period after a frame past it, of the
known.

## column-of

A column of rows, null in a row that lacks it, as a capture older than
a field leaves it.

## bench-step

One step of a bench's run as its gauge.nuon holds it, its label, state,
and file, and every run of it as its own identity asks it
(gauge identity request), never the report's summary: a play when that identity
names the host's own pad, an audio run when it names the pad table (gauge
play audio), else a batch of the route; its selection, its
cadence, workers, and grain asked, and its period from its cap; the
machine and the QEMU it records; its standing and reasons as a
comparison classifies it (standing-of); its CPU seconds over wall
seconds, or null with `cpu_why` saying why it cannot be taken
(cpu-why); its outcomes; a SERVICE build's service reading; an audio run's
reading; and its frames (presented-calls). A step with no gauge.nuon holds
no runs.

## service-text

A run's service in a bench report's words: each window's offered count and
rate, its applied, dropped, rejected, and discarded, the quotas skipped, its
handoff, and its apply phase in microseconds, a reduced load named; or the
start's refusal; held, or broken with its problems.

## cpu-why

Why a run's CPU over wall cannot be taken, null when it can: a run
record older than its wall time; no wall time, its launch having left no
receipt, with what ended it (the outcome's `incomplete`); a wall time not
past zero; or no CPU seconds. A missing wall time is never read as zero,
so a ratio is never made of a run whose end went unrecorded.

## bench-cadence

A group of a bench's runs, one kind's at one cadence and period: the
valid runs (standing-of) pooled, their CPU seconds over wall seconds and
their frames (bench-frames) at the group's period, a pooled run whose
ratio cannot be taken named in `cpu_left` with why (cpu-why); every
other run, one on a diagnostic machine among them, kept apart with its
standing, its reasons, and its own frames, a diagnostic outside the
pool; and each run's standing and outcomes.

## bench-cadence-text

A cadence's lines in a bench's report, milliseconds to a tenth as
least, median, 95th, 99th, and greatest, the pool's critical path at
the median against the ceiling leading, its tail beside. The head's CPU
figure says how many of the pooled runs it covers and names each run
left out of it with why, so a figure over fewer runs never reads as the
pool's.

## bench-text

A bench's report as text: the steps, each machine and QEMU with the runs
that ran on it, `<step> run <n>` each once, each kind's cadences, the
comparisons, then each SERVICE run's window (service-text) and each audio
run's reading, a diagnostic (gauge audio line).

## doc

A bench's report over the steps a run of the bench wrote in `dir`,
each a directory holding its gauge.nuon, in the order bench.nuon lists
them, else every directory's by name: each step's runs as their own
identities ask them (bench-step); the runs, never the steps, grouped by
their own kind, the plays on the host's own pad apart from the route's
batches, their cadence, and their period, each run in one group, its
valid runs pooled, untrimmed, and every other run kept apart as a
diagnostic (bench-cadence); every run listed once with its settings;
then the reports whose runs are all the route's compared at 50 cm on
critical_us and draw_us, a build a cadence, its batches its steps
(compare), and when the comparison refuses a run, compared again as a
diagnostic admitting it, marked. A report mixing plays and route runs
refuses the route comparison on every field, even as a diagnostic,
naming the report and its kinds, since compare reads a report whole.
Audio runs join no group and no comparison; the runs carrying a service
reading and the audio runs are listed apart, each with its reading.

## report

A bench's report, `nu nuance.nu gauge bench-report <dir>` (`gauge bench doc`):
report.nuon and report.txt written in `dir`, any there before retired,
and the text printed.
