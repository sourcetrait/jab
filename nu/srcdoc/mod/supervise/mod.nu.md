# supervise

## types

The launch's models, `nu/type/launch`: Schedule, Receipt, and Launch, the
records a supervised launch writes and reads, each held to its model
before it is trusted.

## sdk

The SDK's own checkout, where `binary` builds the supervisor: every
launch runs the supervisor of the SDK it calls, never one a program's
workspace built.

## startup_allowance

The supervisor's startup allowance, from its own start: its readiness,
the caller's go, and every relay's connection land within it, and past
it no authorization is read, so an expired startup never takes a late
one.

## backstop

The caller's bound on a startup, from just before the spawn, past the
supervisor's allowance so a slow supervisor still decides first. Its
alarm firing with no go written means nothing measured ran: the cancel
is written, the supervisor's job ended, the lock released, and the
launch fails.

## kill_after

`timeout`'s `--kill-after` on the bound: a QEMU that outlives the bound's
TERM is killed this long after it.

## grace

The grace QEMU's own exit gets after a relay's clean end, a broken pipe,
or a helper's failure while QEMU runs (the schedule's `grace_ns`): QEMU
can close a pipe before its process exits, so its exit inside the grace
is a normal end. Part of the caller's completion alarm too.

## term_grace

The supervisor's wait between TERM and KILL when it ends what its child
owns (the schedule's `term_ns`).

## bounds

A schedule's bounds in nanoseconds, as Schedule.nutype holds them: the
startup allowance; a waiting payload tried again every 10 ms; a screen
looked for whole for 5 s, every 50 ms; QEMU's CPU sampled every 100 ms;
the grace; the wait between TERM and KILL.

## model

A launch model's text by its name, read from `types` at each call.

## held

A schedule held to Schedule.nutype (nutype problems) before anything is
written, each problem a line of the refusal.

## binary

The supervisor, `jabpipe`, built from the SDK's own checkout (tool shim
`--bin`).

## token

A launch's control token, fresh a launch, 1 to 2^63 - 1. `hex` writes
it as the supervisor takes it, and its value is the tag every message of
the launch's jobs travels on.

## control

A control file's path in `dir`: `launch-<token>.<kind>.json`, the kinds
schedule, readiness, authorization, cancel, outcome, and receipt, so
every file of a launch is named before the supervisor exists.

## write-whole

A value written whole as JSON: a temporary name beside the file, moved
into place, so the supervisor reads no file or the whole of one.

## read-control

A control file's value once it is there, null while it is not or its
text cannot be read; the supervisor writes each whole, so a reader never
holds part of one.

## retire-controls

Every control file of a token's moved into the retire home (target
retire) once the launch is done with it or fails, so a run's directory
keeps no control file a later launch could take for its own.

## lock-call

`jabpipe lock` under the bound's `timeout` of 2 s, its one line of JSON
the answer: a call the bound ended answers `timeout`, and one whose
output does not parse `error`, with what it said.

## alarm

The caller's timer, since nushell reads no monotonic clock and only
waits on one: a job that sleeps `after`, then sends `{token, source}` on
the launch's tag. An alarm is retired by its `job kill`, its source then
marked retired, so a message it sent before the kill is discarded as it
arrives (receive).

## receive

A launch's next message on its tag: a record whose token is the tag and
whose source is not retired. A retired alarm's late message, or anything
else on the tag, is discarded. With `wait`, the call ends with nothing at
the wait's end or at a discarded message, the caller's loop asking again;
with none it blocks until a message counts.

## drain

Every message left on a launch's tag discarded once each source has been
received or retired. A drain retires nothing: it takes whatever waits.

## forced

A run's group ended by the readiness record the caller kept, its
supervisor gone silent: `jabpipe group terminate` with the record's
group, leader, and start, its one line of JSON the answer; a record that
names no group or no start is refused. No command line is searched.

## bounded

A bounded launch run under its supervisor, the caller's whole side:

1. The schedule held to its model, a previous `launch.nuon` retired, the
   schedule written whole and its SHA-256 taken.
2. The host's launch lock taken for the token with the caller's pid
   (`lock acquire`); refused, the controls are retired and the launch
   fails naming the lock's answer.
3. The startup alarm armed at `backstop`; the supervisor started as a
   job that sends its whole result on the tag.
4. Every 10 ms until the outcome, the supervisor's result, or the alarm:
   the readiness read once it lands, copied into the lock's record
   (`lock state running --readiness`), and only then the authorization
   written; a copy the lock refuses writes the cancel instead. Under
   `JAB_LAUNCH_TEST=withhold`, a test's switch, the authorization is
   never written, so the supervisor's own allowance expires.
5. The startup alarm retired. Fired with no go written: the cancel
   written, the supervisor's job ended, the tag drained, the lock
   released, the controls retired, and the launch failed with nothing
   measured run.
6. The completion alarm armed: after a go, the run's seconds,
   `kill_after`, `grace`, and a second; otherwise the cancellation's,
   `grace` and a second.
7. The supervisor's result, or the alarm.
8. No result: `incomplete` names the alarm, the group is ended by the
   readiness record (forced), and the lock released once the group runs
   nothing, else its record marked `cleanup` and the group's end named
   in `incomplete`. A result: the lock released.
9. The tag drained; the receipt read. A result with no receipt fails the
   launch naming the supervisor's exit and stderr; a receipt that
   breaks Receipt.nutype is refused whole.
10. `launch.nuon` written once, never edited: the schedule's SHA-256, the
    receipt or null, and `incomplete`; the controls retired; the record
    returned with `launch` its path.

- the authorization goes in only once the readiness is held, so a run
  whose supervisor then goes silent is ended by the record
- every message travels on the launch's own tag, so a stale alarm or
  another launch's message is never read as this one's

## interactive

An interactive run in the terminal's foreground under its supervisor:
the schedule held, any control file left in the run's directory
retired, the schedule written, and `jabpipe supervise` run in place, its
exit the caller's, QEMU's status. No lock and no alarm: the person at
the terminal is the bound, and the supervisor authorizes its own go.

## hex

A control token as the supervisor takes it (nonce hex): sixteen
lowercase hex digits of its big-endian bytes.
