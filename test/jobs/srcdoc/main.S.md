# main.S

jobs: jab_jobs.inc's mailboxes over the worker calls, one scenario a
launch, its letter over the API a second in: f the fixture, a line a step
for the test to read line by line, and c the costs, their samples sent
over the API for costs.nu to read. Every online secondary up to
MAX_WORKERS runs a worker, job_worker, on a mailbox and a stack of its
own; worker k is the k-th online secondary, so on four harts the workers
are harts 1, 2, and 3.

## .set SELECT_WAIT

`u64`: how long the program waits for the scenario's letter, two seconds of
the time counter.

## .set STACK_BYTES

`u64`: a worker's stack, 16 KiB.

## .set MAX_WORKERS

`u64`: the workers at most, one a secondary of the four-hart machine.

## .set OUTPUT_BYTES

`u64`: a worker's output slot, a line of its own.

## .set HOLD_TICKS

`u64`: the display ticks of the idle hold, two seconds, while every worker
sleeps in its await.

## .set ROUNDS

`u64`: the rounds a race runs, a job a worker and a join each.

## .set DELAY

`u64`: the lingering a race's side does, 200 us of the time counter.

## .set OUT_FACTOR

`u64`: a job's output is its size times this plus its worker's hart.

## .set EMPTY_SIZE

`u64`: the size of the empty-and-full step's job.

## .set WRAP_START
## .set WRAP_JOBS

`u32`: the generation the wrap step starts its mailbox at, two short of the
wrap, and its jobs, which carry it through to 1.

## .set BAND_TICKS
## .set CANCEL_BANDS
## .set CANCEL_AFTER

`u64`: the cancel step's job, CANCEL_BANDS bands of 1 ms each, and when the
producer cancels it, 5 ms in.

## .set SIZES
## .set COST_ROUNDS
## .set COST_BYTES

`u64`: the costs' job sizes, their rounds a size, and the samples' bytes at
most: per round a dispatch a worker and the barrier, as 32-bit ticks, for
one worker and then MAX_WORKERS.

## .set ARG_TICKS
## .set ARG_BANDS
## .set ARG_DELAY

`u64`: a job's own arguments in its mailbox's JAB_JOB_ARGS: the ticks a band
of its work, its bands, and how long its worker lingers after completing
it.

## .set OWN_TAKEN
## .set OWN_DONE
## .set OWN_BANDS

`u64`: the worker's own words in its JAB_JOB_OWN: when it took the job,
when it completed it, and the bands it ran.

## fixture

`jobs: scenario fixture, workers W`, then every worker started on a fresh
mailbox.

## idle_hold

Every worker asleep in its await while hart 0 awaits HOLD_TICKS ticks; the
test reads the workers' vCPU threads inside it.

## race_rounds

Four races of ROUNDS rounds, each a job a worker, a wake, and a join, every
output checked and the completions counted. before: each worker lingers
DELAY past its completion, so the next job is published before it waits;
during: hart 0 lingers before publishing, so every worker sleeps first;
spurious: a wake with nothing published, then the job; after: hart 0
lingers before its join, so every job is done before the join looks.

## empty_full

Worker 0's mailbox fresh and free; a job published with no worker running,
so the mailbox holds a job in flight; the worker started, its await finding
the job at its first look; the join, after which the mailbox is free and
the output the job's.

## wrap

Worker 0's mailbox at WRAP_START, three jobs through the wrap, each joined
and its output checked.

## cancel

A job of CANCEL_BANDS bands cancelled CANCEL_AFTER in: done as cancelled,
short of its bands. Then the next generation cancelled before its job is
published: done as cancelled with no band run.

## costs

One worker, then every worker: at each size a hundred rounds, hart 0's
clock before the publish, each worker's after its await took the job and
before its completion, and hart 0's after the join, kept as 32-bit
dispatches and barriers, then sent over the API whole.

## job_worker

A worker's loop: await a job, its bands of work with a cancel check
between, its output when it has a payload, its completion and a wake of
hart 0, then any lingering the job asks for; a stop ends it.

## find_workers

The online secondaries from jab.sys.harts, the first MAX_WORKERS of them,
by hart id.

## start_worker

A start refused ends the run with `jobs: a start refused` and exit 3.

## cost_sizes

`SIZES u64`: the costs' job sizes in ticks, 10 us, 100 us, 1 ms, and 10 ms.

## variant_words

`4 addr`: the races' names, in their order.

## word_none
## word_no_workers
## word_refused
## word_fixture
## word_idle
## word_idle_tail
## word_before
## word_during
## word_spurious
## word_after
## word_rounds
## word_wrong
## word_wrong_comma
## word_completions
## word_free
## word_then
## word_out
## word_wrap
## word_jobs_generation
## word_comma
## word_cancel_during
## word_under
## word_cancel_before
## word_bands
## word_done
## word_costs
## word_costs_tail

`u8`: the lines' words.

## mailboxes

`MAX_WORKERS * JAB_JOB_BYTES u8`: a mailbox a worker, on a 64-byte boundary.

## outputs

`MAX_WORKERS * OUTPUT_BYTES u8`: a worker's job's output, a line each.

## worker_hart

`MAX_WORKERS u64`: each worker's hart.

## workers_n

`u64`: the workers.

## selector

`8 u8`: the scenario's letter.

## line

`160 u8`: the line being built.

## digits

`32 u8`: put_dec's digits, built backward.

## cost_samples

`COST_BYTES u8`: the costs' samples.

## stacks

`MAX_WORKERS * STACK_BYTES u8`: the workers' stacks.
