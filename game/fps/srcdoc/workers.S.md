# workers.S

The raster's workers: started once after the load on the harts the
reservation grants, each rendering whole bands of rows of every packet the
frame's rounds hand it, while hart 0 prepares and keeps the devices (kernel
`11_Harts.md`, the jobs library `jab_jobs.inc`).

The storage is sized by the ABI's bound, GFX_SLOTS, JAB_HARTS_MAX less hart
0: slot s is hart s + 1's, and a worker's mailbox, context, stack, and
STAT_BANDS counter are its slot's, so a raised bound is a rebuild and no
change here. Three things are kept apart: the storage, the bound's; the
harts owned, the reservation's grant; and the workers a frame draws with,
the lowest W of the harts started.

A worker lives for the run. Its argument is its mailbox, whose place in
`mailboxes` is its slot, which gives it its context in `worker_contexts`,
kept in tp, and its stack; the kernel's a1 is its hart. It awaits a job,
renders the band at its position or the bands it claims, writes its times,
bands, and hart into its mailbox's own words, completes, and wakes hart 0.
Between rounds it sleeps in the kernel's wait. The program's exit stops it
through the kernel. A worker calls only the jobs' wait and wake, and the
exit on a stop.

A round is one render of a packet (raster.S's packet_render) at the
frame's workers above 0. Hart 0 writes the round record, the round's harts
(ROUND_HARTS) among it, publishes a job to each of those harts in ascending
order with its position among them (JOB_POSITION), wakes them in one call,
joins every mailbox in the same order, on a debug build setting
ROUND_RELEASE to each position plus one as it reaches it, then sums each
worker's counts into the frame's stats, its bands into its slot's
STAT_BANDS, and its times into STAT_DISPATCH, STAT_BARRIER, STAT_SLOWEST,
and STAT_BUSY, the definitions the kernel's jobs bench measures (FourHarts'
JobCosts), and ORs the hart its job names (JOB_HART) into the frame's
reporting mask. The join's acquire orders the workers' pixels, depths,
counts, and words before anything hart 0 does after it, the HUD and the
flip among them; a wake alone proves nothing.

Bands: with a grain of 0 a band a worker, the worker at position k's rows
k*H/W to (k+1)*H/W, so the workers of a sparse grant still tile the
screen; with a grain B the screen's rows in bands of B, the last short,
claimed one at a time from `round_next` by `amoadd.w` until the bands run
out, so a worker held up leaves its share to the others. A claim is a
band's, never a pixel's. A worker reads its mailbox's cancel before its
band or each claim and completes as cancelled when it is set.

The clear is owned: the frame's first round carries ROUND_CLEAR and each
band's renderer zeroes its own depth rows, and on a debug build paints its
pixels magenta, before its spans, so every row is cleared once a frame,
before its first span, by one renderer. A packet with no spans after the
frame's first round takes no round.

## workers_start

`jab.sys.harts` gives the online harts, workers_online their secondaries.
`jab.sys.harts.reserve JAB_RESERVED_GFX_HARTS`, the build's constant from
the manifest's `[reserved] gfx_harts` (`jab_manifest.inc`), takes every
online secondary into the reservation with that count its floor and
returns the grant. A raster worker starts on each hart of the grant, in
its slot, under JAB_OWNER_RESERVED, the start macro's sixth operand, which
the kernel holds to the hart's owner once a reservation stands; a start
the kernel refuses leaves its slot empty, and a debug build names the hart
and the code. workers_mask holds the harts started, workers_started their
count, and workers_floor the count reserved. The console's W starts at
every worker started and the grain at GRAIN_DEFAULT. A debug build reports
`fps: harts reserved M, grant <harts>` and `fps: workers N on harts
<harts>`.

A refused reservation ends the run on every build, exit 17: JAB_RESERVE_SHORT
with `fps: harts short: N secondaries online for the M reserved`, any other
status with `fps: harts reserve refused <status>`. A machine short of the
reservation is one the build does not run on.

## append_harts

A debug build's: a mask's harts in ascending order, each after a space,
for the reserved and workers lines.

## workers_latch

world_draw's, at the frame's start: the W asked, held to the workers
started, is the frame's round_workers, its grain round_grain; round_harts
takes the lowest round_workers harts of workers_mask; frame_reported is
zeroed for the joins to fill; frame_grant is `jab.sys.harts.owned
JAB_OWNER_RESERVED`, read once a frame for the harts record. The program
claims no harts, so the grant read is the reservation's whole.

## round_run

The record's fields are written, the claims zeroed, then each job's
position stored in its descriptor and the job published, the publish's
fence ordering all of it before the generation a worker awaits. Each job's
frame is the frame's snapshot. One wake carries the round's harts. The
joins walk ROUND_HARTS ascending, the positions in order. The dispatch is
the latest worker's start less hart 0's clock before its first publish,
the barrier hart 0's clock after its joins less the latest worker's end.
A worker's JOB_HART, written before its completion and ordered by the
completion's fence, goes into frame_reported, so the frame reports the
harts that completed its jobs, read from the jobs themselves. A debug
build checks after the joins that every job's completion is its
generation, the round's, and exits 13 with `fps: round unjoined` when one
is not, the join's own invariant, since a round read before a worker
completes would still find its bands from the round before; then that the
bands rendered are the round's, exiting 13 with `fps: round lost bands`
when they are not.

A cancelled round is finished on hart 0: a job read its cancel at a band's
boundary and completed as cancelled, so after the joins round_finish
renders on hart 0's context the bands the jobs left, the clear with them
on a first round, and the round is counted in STAT_CANCELLED. The game
cancels nothing; a debug build's J frame cancels every round while it
stands, so the path is the jobs library's cancellation exercised, and a
frame is whole, never a prefix.

The J frame's hold, a debug build's, makes an unjoined round observable:
the worker on the delayed hart, in fixed bands, holds its band until the
join loop passes its position, so with W 2 the worker on hart 2, position
1, the last the loop reaches, renders the round's last band only once
position 0 is joined and completes before its own join returns. A round
whose join is gone leaves that job incomplete at the next boundary, whose
entry check (round_joined) exits 15; a hold no release reaches in
JOB_HOLD_US marks job_hold_expired and goes on, since a worker can print
and end nothing, and the next boundary's entry exits 16 on it.

## raster_worker

The fixed band is the worker's position among the round's harts, so the
bands follow the round's order whatever harts the grant holds; a claimed
band's rows end at the screen's last. JOB_HART is the kernel's a1. On a
debug build the J frame's fault, keyed to the hart, loads SCRATCH_POISON's
address before the band, its delay spins on rdtime before each band and
claim (job_delay), and in fixed bands its hold waits for the join's
release past its position (job_hold_wait).

## round_finish

At a band a worker, ROUND_HARTS walked ascending gives each position's
band: a worker whose job holds no band read its cancel before its band,
and its rows are rendered here; at a grain the counter hands on the bands
no worker claimed, every band once. A debug build checks the tile pool
frozen first (tile.S's tile_check), the cancelled round's renders held to
the boundary's pool as the round's own are.

## job_delay

A debug build's: the delay spins on rdtime when the J frame names the
worker's hart, calling nothing, a worker's calls being the jobs' alone.

## job_hold_wait

A debug build's: the worker on the J frame's delayed hart, under its hold,
spins on the record's ROUND_RELEASE until it passes the worker's position,
the join's progress, or JOB_HOLD_US pass, the watchdog marking
job_hold_expired for hart 0's next boundary to report; either way the band
follows, so a coordinator waiting in the join returns.

## round_joined

A debug build's, hart 0's, first in tile.S's tile_boundary before any
write: an expired hold exits 16 with `fps: held job never released`, the
fixture's case unexercised; then every mailbox of the last round's harts
must hold its completion equal to its generation, else `fps: tile boundary
before the round joined` and exit 15, the boundary run before the round
joined. The kernel's exit halts the workers, a second at most, then
flushes the sound: its wait for the ring and the voices is three seconds
at most, and its return wait and drain end normally when their work
completes, or on a no-progress timeout, so the exit has no fixed bound.
The machine ended about 3 to 4 s after the line in the join probes, and a
run its screen ends sooner carries the line with status 0.

## msg_short

`19 u8`.

## word_short_online

`29 u8`.

## word_short_reserved

`10 u8`.

## msg_reserve_refused

`28 u8`.

The refusals' text, msg_short to msg_reserve_refused, is in every build.

## msg_reserved

`21 u8`.

## word_grant

`8 u8`.

## msg_workers

`14 u8`.

## word_on_harts

`10 u8`.

## msg_refused

`29 u8`.

## msg_lost_bands

`23 u8`.

## msg_unjoined

`21 u8`.

## msg_boundary_unjoined

`44 u8`.

## msg_hold_expired

`30 u8`.

The debug lines' text, msg_reserved to msg_hold_expired, is in a debug
build alone.

## mailboxes

`GFX_SLOTS*JAB_JOB_BYTES u8`: a mailbox a slot, `jab_jobs.inc`'s, on a line's boundary, zeroed at the start; JOB_POSITION in the job's arguments, hart 0's, and the worker's own words JOB_START, JOB_END, JOB_BANDS, and JOB_HART.

## worker_contexts

`GFX_SLOTS*CTX_SIZE u8`: a raster context a slot, CTX_* fields, each on lines of its own.

## round

`ROUND_SIZE u8`: the round record, ROUND_* fields, hart 0's, published with the jobs.

## round_next

`u32`: the round's next band to claim, on a line of its own; past the bands every band is claimed.

## workers_online

`u64`: the online secondaries at the start, by hart.

## workers_mask

`u64`: the harts holding a raster worker, by hart.

## round_harts

`u64`: the frame's harts, the lowest round_workers of workers_mask, a hart a worker.

## frame_grant

`u64`: the reservation's grant read at the frame's start, by hart.

## frame_reported

`u64`: the harts whose jobs completed the frame's rounds, by their JOB_HART, zeroed at the frame's start.

## workers_floor

`u32`: the count reserved, JAB_RESERVED_GFX_HARTS.

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

`u8`: on a debug build, the J frame's delayed worker's hart, 0 for none; the knobs after it are a debug build's too.

## job_cancel

`u8`: 1 while every round is cancelled after its publish.

## job_fault_worker

`u8`: the hart whose worker faults on the next round, 0 for none, cleared by that round.

## job_hold

`u8`: the J frame's byte 14, 1 while the delayed worker holds its fixed band until the join releases it.

## job_hold_expired

`u8`: 1 once a hold's watchdog passed unreleased, read by the next boundary's entry; never cleared, the run ending there.

## job_delay_us

`u32`: the delay before each band in microseconds.

## worker_stacks

`GFX_SLOTS*WORKER_STACK u8`: a stack a slot, below the main stack's reservation.
