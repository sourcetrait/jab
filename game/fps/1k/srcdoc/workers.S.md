# workers.S

The raster's workers: started once after the load on the secondary harts,
each rendering whole bands of rows of every packet the frame's rounds hand
it, while hart 0 prepares and keeps the devices (kernel `11_Harts.md`, the
jobs library `jab_jobs.inc`).

A worker lives for the run. Its argument is its mailbox, whose place in
`mailboxes` is its index, which gives it its context in `worker_contexts`,
kept in tp, and its stack; it awaits a job, renders the round's bands
assigned or claimed, writes its times and bands into its mailbox's own
words, completes, and wakes hart 0. Between rounds it sleeps in the
kernel's wait. The program's exit stops it through the kernel. A worker
calls only the jobs' wait and wake, and the exit on a stop.

A round is one render of a packet (raster.S's packet_render) at the
frame's workers above 0. Hart 0 writes the round record, publishes one job a
worker, wakes them in one call, joins every mailbox in index order, then
sums each worker's counts into the frame's stats and its times into
STAT_DISPATCH, STAT_BARRIER, STAT_SLOWEST, and STAT_BUSY, the definitions
the kernel's jobs bench measures (FourHarts' JobCosts). The join's acquire
orders the workers' pixels, depths, and counts before anything hart 0 does
after it, the HUD and the flip among them; a wake alone proves nothing.

Bands: with a grain of 0 a band a worker, worker k's rows k*H/W to
(k+1)*H/W; with a grain B the screen's rows in bands of B, the last short,
claimed one at a time from `round_next` by `amoadd.w` until the bands run
out, so a worker held up leaves its share to the other. A claim is a
band's, never a pixel's. A worker reads its mailbox's cancel before its band
or each claim and completes as cancelled when it is set.

The clear is owned: the frame's first round carries ROUND_CLEAR and each
band's renderer zeroes its own depth rows, and on a debug build paints its
pixels magenta, before its spans, so every row is cleared once a frame,
before its first span, by one renderer. A packet with no spans after the
frame's first round takes no round.

## workers_start

The workers are taken from the lowest online secondaries `jab.sys.harts`
reports, WORKERS_MAX at most; a start the kernel refuses leaves that
worker out, the next hart taking its index, and a debug build names the
hart and the code. A debug build reports the workers and their harts. The
console's W starts at every worker started and the grain at
GRAIN_DEFAULT.

## round_run

The record's fields are written, the claims zeroed, then each worker's
job published, the publishes' fence ordering all of it before the
generation a worker awaits. Each job's frame is the frame's snapshot. The
dispatch is the latest worker's start less hart 0's clock before its first
publish, the barrier hart 0's clock after its joins less the latest
worker's end. A debug build checks that the bands rendered are the round's
and exits 13 with `fps: round lost bands` when they are not.

A cancelled round is finished on hart 0: a job read its cancel at a band's
boundary and completed as cancelled, so after the joins round_finish
renders on hart 0's context the bands the jobs left, the clear with them
on a first round, and the round is counted in STAT_CANCELLED. The game
cancels nothing; a debug build's J frame cancels every round while it
stands, so the path is the jobs library's cancellation exercised, and a
frame is whole, never a prefix.

## raster_worker

The fixed band is the worker's index of the round's workers; a claimed
band's rows end at the screen's last. On a debug build the J frame's
fault loads SCRATCH_POISON's address before the band, and its hold spins
on rdtime before each band and claim (job_delay).

## round_finish

At a band a worker, a worker whose job holds no band read its cancel
before its band, and its rows are rendered here; at a grain the counter
hands on the bands no worker claimed, every band once.

## job_delay

A debug build's: the hold spins on rdtime, calling nothing, a worker's
calls being the jobs' alone.

## msg_workers

`14 u8`.

## word_on_harts

`10 u8`.

## msg_refused

`29 u8`.

## msg_lost_bands

`23 u8`.

The debug lines' text, msg_workers to msg_lost_bands, is in a debug build
alone.

## mailboxes

`WORKERS_MAX*JAB_JOB_BYTES u8`: a mailbox a worker, `jab_jobs.inc`'s, on a line's boundary, zeroed at the start; the worker's own words JOB_START, JOB_END, and JOB_BANDS.

## worker_contexts

`WORKERS_MAX*CTX_SIZE u8`: a raster context a worker, CTX_* fields, each on lines of its own.

## round

`ROUND_SIZE u8`: the round record, ROUND_* fields, hart 0's, published with the jobs.

## round_next

`u32`: the round's next band to claim, on a line of its own; past the bands every band is claimed.

## worker_hart

`WORKERS_MAX u64`: each worker's hart.

## workers_started

`u32`: the workers started.

## workers_active

`u32`: the workers the next frame draws with, a W's, 0 for the serial backend.

## band_grain

`u32`: the rows a band the next frame draws with, a W's, 0 for a band a worker.

## round_workers

`u32`: the frame's workers, taken at its start.

## round_grain

`u32`: the frame's grain, taken at its start.

## round_first

`u8`: 1 until the frame's first round takes it, the round that clears.

## job_delay_worker

`u8`: on a debug build, the J frame's held worker, its index plus one, 0 for none; the knobs after it are a debug build's too.

## job_cancel

`u8`: 1 while every round is cancelled after its publish.

## job_fault_worker

`u8`: the worker to fault on the next round, its index plus one, cleared by that round.

## job_delay_us

`u32`: the hold before each band in microseconds.

## worker_stacks

`WORKERS_MAX*WORKER_STACK u8`: a stack a worker, below the main stack's reservation.
