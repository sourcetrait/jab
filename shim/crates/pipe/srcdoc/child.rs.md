# child.rs

The supervised child, owned from its spawn: its creation, its go, its
end, and its reap, one implementation a host family behind one surface.

## enum Signal

## struct Ended

## fn fresh

A file the child writes is made fresh: one already there, a previous
run's left unretired, refuses the launch rather than being written over.

## mod unix

### struct Terminal

#### fn save

#### fn restore

### struct Child

The gate's process, its group, its start, its control pipe until the
word, and an interactive launch's terminal attributes.

#### fn spawn

The gate spawned over the schedule's command with the child's
environment. Bounded: a process group of its own made at the spawn
(`process_group(0)`, so the gate's pid is the group's), stdin empty,
stdout and stderr the schedule's fresh files. Interactive: the terminal's
attributes saved first, the gate left in the caller's group with the
terminal's stdio, so the foreground group never changes. The control
pipe's reading end is placed at the gate's descriptor before its exec
(`place`); the writing end, close-on-exec, stays the supervisor's.

#### fn pid

#### fn group

#### fn start

#### fn release

#### fn abandon

#### fn exited

The child exited when the table no longer shows it running: a zombie
awaiting this supervisor's reap, whose pid and group no other process can
take meanwhile.

#### fn running

A bounded child's group's running members; an interactive child, itself.

#### fn signal

A bounded child's group, signalled as a group; an interactive child's
pid alone, never the caller's group.

#### fn reap

The child reaped, then the terminal's attributes put back, on every
path: a killed QEMU leaves the raw mode its stdio chardev set.

#### fn restore

### fn place

`dup2` onto the descriptor clears its close-on-exec flag; a pipe end
that already is that descriptor has the flag cleared outright.

### fn ignore_interrupts

The supervisor of an interactive launch ignores the interrupt and the
quit keys, which reach the whole foreground group: QEMU ends on them, and
the supervisor reaps it and reports.

## mod windows

Compiled on Windows alone; not compiled on this repository's own hosts.

### struct Child

The command created suspended (`CREATE_SUSPENDED`), assigned to a Job
Object that kills every process in it when its last handle closes, then
resumed on the go, so every descendant is the job's from the start and a
supervisor killed takes its child with it.

#### fn spawn

A child the job cannot take is killed and reaped and the launch refused.

#### fn pid

#### fn group

#### fn start

#### fn release

The main thread resumed (`main_thread_handle`).

#### fn abandon

The job terminated, the suspended child with it.

#### fn exited

#### fn running

The job's active processes by its accounting, a count with no pids.

#### fn signal

The job terminated: Windows has no asking signal.

#### fn reap

#### fn restore

#### fn drop

The job's handle closed, which ends every process left in it.

### fn ignore_interrupts

A console handler taking Ctrl-C, which the console's other processes,
QEMU among them, still receive; a handler routine is not inherited, where
the ignore flag would be.

#### fn taken

The handler: every control event answered as handled.
