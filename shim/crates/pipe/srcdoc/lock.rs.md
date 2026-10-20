# lock.rs

The host's launch lock: one supervised bounded launch at a time on a
host, across every checkout, export, and worktree, since each launches
through an SDK that reads the same path. It lives outside every build
and retirement tree: `jab/launch/` under the state home,
`$XDG_STATE_HOME` or `~/.local/state`, on Windows `%LOCALAPPDATA%`, the
state home checked and never made, its `jab/launch` made; or the
directory `JAB_LAUNCH_LOCK` names, which a test gives its own.

Two files there. `lock` is the coordination object, made when absent and
never removed, renamed, or replaced, so every caller locks one file.
`owner.nuon` is the run's ownership record, JSON, which is NUON, each
write a temporary name renamed over it. Every read and write of the
record is one call's transaction under `lock`'s exclusive lock
(`File::try_lock`: flock on Unix, LockFileEx on Windows), held across the
read, the decision, and the write and never across a run; the operating
system releases it when its holder exits.

## const LOCK_BOUND

A call tries the lock every 10 ms for at most a second, then answers
`busy`; a stalled holder costs a waiter its second and no more.

## const LOCK_RETRY

## const LOCK

## const OWNER

## struct Holder

## struct Owner

`starting` once taken, `running` once the caller holds the readiness and
has copied it in, `cleanup` once a cleanup has begun that could not end
the run's group, `released` once released: the release marks the record,
which the next acquisition reads as free, and nothing is unlinked.

## struct Answer

Each call prints one line of JSON: `ok`, `busy`, `refused`, `late`, or
`error`, why, and the record named; its exit is 0 for `ok` alone.

### fn ok

### fn refused

## fn lock

## fn lock_home

## fn state_home

## fn lock_answered

## fn transaction

## enum Record

## fn read_record

A record whose state is `released` reads as free.

## fn write_owner

## fn stale

A record's run is gone when its caller and its supervisor are both gone,
each by its pid and start, and its group, when it names one, runs
nothing. A record whose standing cannot be settled refuses the launch.

## fn lock_acquire

A free record is taken; a live one refuses at once, its owner named; a
stale one is replaced, kept whole in the new record's `replaced`. Two
callers that saw one stale record take the lock in turn, and the second
finds the first's live record and is refused.

## fn lock_set_state

Written only while the record carries the launch's token; a readiness
copied in names the same token.

## fn lock_release

Only while the record carries the launch's token; a successor's record
is left whole and the release answered `late`.
