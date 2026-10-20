# group.rs

A caller's forced path, `jabpipe group terminate --group <g> --leader
<pid> --start <start>`: a bounded run's group ended by the readiness
record the caller kept before its go, when the supervisor has gone
silent. The supervisor reaps the group's leader last, so the leader and
its group stay identified, live or awaiting the reap, through every
cleanup and no pidfile stands in. No command line is searched.

## const TERM_GRACE

## const KILL_BOUND

## const LOOK

## fn group

One line of JSON: `ok`, the group running nothing; `refused`, a group
the record does not name; `left`, members still running past their KILL;
or `error`; its exit 0 for `ok` alone.

## fn parsed

## fn group_terminate

The leader is held to the record first, its start and its group, a gone
or reused leader refusing; then TERM to the group, a second's grace,
KILL, and the group read until it runs nothing, a zombie leader awaiting
its reap not counted.
