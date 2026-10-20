# supervise.rs

The launch's supervisor, `jabpipe supervise --token <token> --schedule
<file>`: the owner of a launch's child from its spawn to its reap, the
one decision of its startup, the timed actions, the readings, the
relays and helpers, and the receipt. Every bound and grace it keeps is on
its own monotonic clock (`Instant`), every time it records is sampled
with its operation, and no time crosses to its caller but as a recorded
number.

The flow: the child spawned inert (child.rs, the gate on Unix, a
suspended child in a Job Object on Windows); the readiness published,
the run's ownership record; the startup decided once and the outcome
published before it is acted on; on a go the child released, the relays
and the helpers started; then the loop until the child is reaped; then
the receipt, and the supervisor's exit.

## const ENDED_EARLY

A startup that did not go, or a run its caller cancelled.

## const ABORTED

## const TICK

The longest the loop sleeps; it wakes sooner for the next action due,
reading, screen look, or CPU sample.

## const RELAY_END

## fn supervise

## fn parsed

## fn pause

A test's switch: `JABPIPE_TEST_PAUSE=<point>:<ms>` holds the supervisor
unresponsive for that long at `readiness` (before publishing it),
`outcome` (after deciding the startup, before publishing it), or `run`
(after releasing the child). It does nothing unset.

## fn requested

## fn startup

The allowance runs from the supervisor's start and bounds the readiness,
the caller's go, and the decision: past it no authorization is read, so
an expired startup never takes a late one. The cancel is read ahead of
the authorization. The go's instant is sampled as it is decided, ahead
of the outcome's publication and the child's release, and is the origin
of every time the receipt records. An interactive launch authorizes its
own go.

## fn supervised

A startup that does not go abandons the child, which exits having run
nothing, and writes a receipt with its outcome and no run.

## fn abandoned

## fn connector

## struct Run

### fn new

Each action's payload routed by its pipe's end: a relay's endpoint takes
the relay's connection, any other end is a fifo's path.

### fn until_end

Each turn: the child's state, and once it has exited and nothing it owns
runs, the end; QEMU's pid, from its pidfile at the first read finding it
alive; the CPU sample; the readings due; the relays' and helpers' ends;
the actions; a grace's end; a bounded launch's cancel; the termination's
escalation. A child that exits while members of its group run on is given
the grace, then terminated.

### fn idle

### fn find_qemu

### fn qemu_live

Actions go in only while QEMU runs: its pid live, or with no pidfile the
child itself, so an action due before QEMU is up waits and is never
counted taken with nothing written.

### fn sample

### fn read_threads

Readings run beside the actions and never behind one, each at its time
while QEMU runs, its start and end timed around the reading itself.

### fn watch_links

A relay's failure, a connection never made within the allowance or an
I/O failure, aborts the launch at once. A clean end while QEMU's exit is
not yet seen starts the grace, since QEMU can close a pipe before its
process exits; QEMU's own exit inside it is a normal end.

### fn act

The header goes in first, ahead of every action, then each action once
due and whole before the next, so due order holds and a late start drops
nothing. A screen's line written, its file is looked at by its size and
then its header at each look until the allowance; a file of the whole
size under another header is no whole screen. A screen that fails holds
every action after it, as a `quit` does by ending the run.

### fn broke

A pipe broken once bytes are in, while QEMU runs, starts the grace: QEMU
ending inside it is a normal end with the action left incomplete; past it
the launch fails, the pipe named.

### fn hold

### fn fail

### fn terminate

TERM to what the child owns, KILL at `term_ns` past it while anything
runs; the child is reaped only once nothing it owns runs.

### fn next_wake

### fn close_links

### fn watch_helpers

A helper that never started fails the launch at once; one failing while
QEMU runs starts the grace, as a relay's clean end does, so a bridge that
fails as QEMU ends is no failure of the launch.

### fn close_helpers

### fn receipt

### fn exit

A failure names itself on stderr beside the child's end and exits 1; a
cancel exits 3; otherwise the child's status, or 128 and the signal that
ended it.

## fn whole
