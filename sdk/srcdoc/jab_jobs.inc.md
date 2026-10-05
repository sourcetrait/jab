# jab_jobs.inc

Jobs for workers as macros expanded in place, after jab.inc: a mailbox a
worker, which the program declares, JAB_JOB_BYTES on a 64-byte boundary,
and passes by address in an integer register. One producer writes it,
hart 0 in the coordinator's role, and one consumer, the worker the program
started with the mailbox's address as its argument. One job is in flight a
mailbox at a time.

The mailbox is two cache lines, one a side, so the two harts never write
the same line. The producer's line holds the job: its generation, the
generation to cancel, a frame id, a payload's address and size, and 32
bytes the job's own. The worker's line holds the completion: the generation
it last completed, that job's status, the jobs it has completed, and 48
bytes the worker's own, its counters among them, which the program sums
after a join, so no counter is shared while workers run.

Generations are 32 bits and count up from whatever the mailbox starts with.
The mailbox is free when the completion equals the generation, and holds a
job in flight when the generation is one ahead. Both are equality tests, so
the count wraps from 0xffffffff to 0 and a generation's value comes back
after 2^32 jobs without either being misread.

The ordering is RISC-V's memory model's release and acquire. To publish:
the descriptor's stores, `fence rw, w`, then the generation's store. To take
it: the generation's load, `fence r, rw`, then the descriptor's loads. To
complete: every output store, the framebuffer's and the depth's included,
the status, `fence rw, w`, then the completion's store. To join: the
completion's load, `fence r, rw`, then the outputs' loads. So a worker
never reads a descriptor older than its generation, and the producer never
reads an output older than its completion. A plain flag set without the
fences is not the contract: the store before it can land after it.

The waits sleep in the kernel, jab.sys.worker.wait on the mailbox's own
words, and a wait never consumes a wake meant for the check it follows:
the kernel marks the sleeper before it reads the word, and the waker
stores the word before it reads the mark, each side fencing between, so
either the sleeper sees the new word or the waker sees it asleep and wakes
it. A publish is followed by jab.sys.worker.wake for the workers it fed,
one call for many mailboxes, and a completion by a wake of the producer,
hart 0. Neither touches the display's tick or an input; jab.sys.await is
for those.

A job is bounded, and a long one checks for its cancel at the boundaries
of its bands, then completes as cancelled. A mailbox, a stack, or a buffer
a worker owns is the program's again only once its job's completion is
joined or the worker is stopped (jab.sys.worker.stop).

## .set JAB_JOB_BYTES

`u64`: a mailbox, two 64-byte lines.

## .set JAB_JOB_GEN

`u32`: the producer's line's generation, the job last published.

## .set JAB_JOB_CANCEL

`u32`: the generation the producer cancels, the job checking it between
its bands.

## .set JAB_JOB_FRAME

`u64`: the frame the job belongs to.

## .set JAB_JOB_PAYLOAD

`addr`: the job's payload.

## .set JAB_JOB_SIZE

`u64`: the payload's size, or an index the program validates.

## .set JAB_JOB_ARGS

`32 u8`: the rest of the producer's line, the job's own.

## .set JAB_JOB_DONE

`u32`: the worker's line's completion, the generation it last completed.

## .set JAB_JOB_STATUS

`u32`: the completed job's status, JAB_JOB_OK or JAB_JOB_CANCELLED, or the
program's own codes past them.

## .set JAB_JOB_COUNT

`u64`: the jobs the worker has completed.

## .set JAB_JOB_OWN

`48 u8`: the rest of the worker's line, the worker's own.

## .set JAB_JOB_OK
## .set JAB_JOB_CANCELLED

`u32`: a job's statuses: done, and cancelled at a band's boundary.

## .macro jab.job.free

The producer's: whether it may publish. A job in flight is never
published over, since the worker may be reading its descriptor.

## .macro jab.job.publish

The producer's, onto a free mailbox only. The job's own arguments at
JAB_JOB_ARGS are stored before it, so its fence covers them; a wake of the
worker follows.

## .macro jab.job.cancel

A plain store: the worker reads it at its next band's boundary, and a
cancel is never lost, since the worker's completion of the job, cancelled
or not, is what the producer joins.

## .macro jab.job.join

The producer's: a wait on the completion while it holds what it held, so a
completion before the wait ends it at once and one after it wakes it. The
mailbox is any register but t0, t1, a0, a1, and a7, which it changes.

## .macro jab.job.await

The worker's: a wait on the generation while it holds the last completion,
so a job published before the wait is taken at once. a0 1 is a stop asked
of the worker, which then ends with jab.sys.worker.exit. The mailbox and
the generation are any registers but t0, a0, a1, and a7.

## .macro jab.job.complete

The worker's: the status and its count written, then every store before
it, then the completion. A wake of hart 0 follows.
