# gauge/measure

## NO_BATCH

the batch source of the first boundary, which consumes none

## WORKERS_MAX_TO_FIVE

the raster's workers a frame may have through schema 5, render.inc's
bound then; from schema 6 a frame's workers are its active harts, a
slot a secondary (GFX_SLOTS, the ABI's JAB_HARTS_MAX less hart 0); the
screen's rows, a grain's bound

## CAP

the cap a frame's period comes from when a capture's identity names none

## RESIDUAL_US

a frame's next start less its start less its critical path, wait, and
await: the microseconds the conversions drop, at most this

## SPAN_RECORDS

the span records a frame holds before its spans go unrecorded

## COMMAND_BYTES

a command's bytes in a packet by schema, the polygon's record copied
whole, 312 while it carried its tile bindings and 232 from the pool on,
and a span record's (render.inc's POLY_SIZE and SPAN_RECORD_SIZE)

## PACKET_RESIDUAL_US

a frame's drawing less its preparation and its raster: the microsecond
the three conversions drop, at most this

## OUTLIER_RATIO

an unexplained phase outlier: a phase past OUTLIER_RATIO times its
leg's median and OUTLIER_US over it, in a frame whose tile work stayed
within twice the larger of its leg's median and 100 us, the first
frame after a placement apart

## FLIP_PRESENTED

a flip's status: 0 presented, 1 refused before the tick, 2 no display,
3 the device refused it

## FLIP_VALID

the statuses a valid measurement holds; 2, 3, or any other is a frame
never shown

## TICKS_PER_US

the guest clock's ticks a microsecond, its 10 MHz, the unit of a
receipt's acceptance stamps; an acceptance interval keeps the tenth of a
microsecond

## ANDROID_EVENTS

the android events and what a round met, as the program reports them

## CADENCES

The cadence fixtures (cadence-holds): the cadences, the period at the
cap of 60 in microseconds, the S frame's command byte as a console
record carries it, and a sustained stage's first frames set aside.
CadenceSchedule on Render One: the standing stall and the consume's
spin from 1.5 s, ten trigger reports, the frame whose flip is tried
before its wait, the frame stalled once, the slow stage's standing
stall, and the E. The once stall stands well past two periods: from the
tick before it to its flip's end run two present calls, 0.3 to 4 ms
each here, and the kernel sets the next tick from the grid when a flip
lands within a period of its tick and from the flip when later, so a
stall near two periods falls either side of that edge by chance; at 38
ms every cadence's frames stand 5 ms or more clear of every edge they
meet. Every timed action stands 300 ms or more from the
next: a launch writes its actions on the turns of its loop, about 220
ms apart here, so two reports nearer than that go in together and fire
once in a frame, as two S frames would act on one. The wakes a frame
stays under: a consume that takes nothing spins its 500 us again on
every wake, twenty or more in a period's wait. MotionByTime on the
still copy of Render Zero: the placement, north along the bay's east
side clear of the pillars, the standing stall, the stick held forward,
the E, the
body's speed, and the clearance from every wall of a frame's sector its
frames keep

## main

A capture measured: its window, every frame in it as a row with its
leg, the leg's summaries, the outliers, and the outcomes. The window is
the capture read in order through its first end marker (stream): it is
complete when its clock records sit at one schema this reader takes,
the marker names the final frame, and every frame from 0 to it has its
state, its frame record, its draw record, from schema 2 its
presentation record, from schema 3 its packet record, and at schema 5
its tile and storage records and a configuration in force before the
marker, numbered in order with none twice; what follows the marker
counts for nothing, a record sent late or a second marker alike. A
complete window is valid unless a flip was never shown or not presented
as its cadence requires, a phase or a part sums past its whole, a
frame's clock disagrees with its state, or from schema 2 a frame's
presentation, from schema 3 its packets, from schema 4 its workers, or
at schema 5 its tile pool break their rules (invalidity), or from schema
7 its receipts break the receipt stage (receipt-invalidity). The
measurement carries `nonce_set` and `late_nonce`, an I answered before
the first state or after it, `load`, the load record, and `acceptance`,
whether its rows' acceptance intervals stand and why not where not
(acceptance-of, accepted). A valid
window is under the ceiling when its critical path's median is under
CEILING_US, `under` null for one not valid; its frames at or over the
ceiling, each row's `over`, are its tail, counted in any clocked
capture. A frame is fast when its critical path is under the period of
`cap`, whatever its cadence. A capture with no record of the clock's
kinds, 7 to 10, 12 to 15, and 18, is a build older than them: its rows
are its state records' alone and it holds no window. Any one of them
marks the capture clocked and holds it to its window. The measurement
carries the grants and the active masks its frames hold.

## screen-frame

The frame a screen shows, bound under FrameCeiling's picture contract:
`m` the capture measured, complete and valid or refused; the window the
rows from `from`, the frame that answered the window's opening command,
to before the final frame the marker names, its length the final less
`from`, shorter than 2^STAMP_BITS frames by the contract so its frames'
stamps differ, a window of that many frames or more refused before any
stamp is read; `stamp` the frame number the screen's stamp carries
(`picture stamp`), its low STAMP_BITS bits, null refused; the stamp
naming one frame N of the window, a stamp naming a frame before the
opening and one naming the final frame or none each refused; N settled
by the pool's rule, its missed blocks,
building, admitted, dropped, filtered, and tiles built all 0; N's state
at `expect.pose`, x, y, and z within POSE_SLACK_M and the yaw, pitch,
and roll within POSE_SLACK_DEGREES, the yaw modulo a turn; N's packet
record drawn by `expect.workers` at `expect.grain`; N's harts record
holding every mask `expect.masks` names, none when null; and with
`expect.witness` "worker" or "serial", the J's cancel standing, exactly
one witness naming N, a missing one refused and a repeated one whether
its counts agree or conflict, a worker mode's reading rounds above 0 and
cancelled equal to rounds, the serial backend's rounds and cancelled 0.
N, null when no frame of the window is named, and every refusal, each
named.

## window-problems

What keeps a window from being complete, read from the records before
its end marker alone: no marker, a capture whose schema this reader
does not take, a clock record at a schema other than the capture's, a
record numbered out of order or twice, and a frame short of a record or
one too many, the presentation records counted from schema 2, the
packet records from schema 3, the tile and storage records from schema
5, the harts records from schema 6, and the receipt records from schema
7, beside which a load record, one and before the first state, is held;
from 5 a frame with no configuration in force, none from it
or before, leaves the window incomplete too, as does a configuration
arriving other than after exactly `from` state records and `from` frame
records: the program writes one at the boundary of the first frame it
governs, after the frame before's records and before that frame's state
record, so a later one governed frames it followed and an earlier one
names a frame not begun.

## invalidity

What makes a complete window invalid. At any schema: a flip at a status
other than presented or refused as early, which is a frame never shown;
a frame whose phases or whose drawing's parts sum past their whole; a
frame whose clock record's drawing or game time differs from its
state's. From schema 2: a frame without its presentation record, which
the rest are read without; a cadence outside 0 to 2; under cadence 0 a wait
or a pacing, or attempts other than one; under 1 and 2 a final flip not
presented, since those cadences flip again on a refusal; attempts other
than the refusals and the final attempt, which is a refusal itself only
when its status says so; a frame whose next start less its start is not
its critical path, its wait, and its await to within RESIDUAL_US; a
frame whose start, simulation, flip end, and next start do not come in
that order, so no submission age is negative, a frame that reached no
flip keeping a flip end from before its start; and a next start that is
not the next frame's start. From schema 3: a frame without its packet
record, which the rest are read without; a frame whose drawing less its
preparation and its raster is not 0 to PACKET_RESIDUAL_US, so the raster
lies within the drawing; a frame whose packets' bytes are not its
commands' and its span records'; and a frame whose packets were
prepared from another frame's simulation, a stale snapshot drawn. From
schema 4: below 6 a frame drawn by more than WORKERS_MAX_TO_FIVE
workers; one at a grain past the screen's rows; one of the serial
backend, 0 workers, carrying a round's time; one whose slowest worker,
dispatch, or barrier is past its raster, each a part of the raster's
span on hart 0; and one whose workers' busy time is less than its
slowest worker's, which it sums, or past W times it with the W - 1
microseconds the conversions drop, since each round's busy time is at
most W times its slowest and each total is converted once. From schema
5 the tile pool (pool-invalidity), and at 6 the harts (harts-invalidity).

## receipt-invalidity

What makes a complete window at schema 7 invalid in its receipts, the
receipt stage (ProbeRuns), past the cadence's status, attempt, and
refusal rules from schema 2, which stand: a frame without its receipt
record; the present sequence broken (jab ordinal-violations) from
`anchor`, the load record's cleared screen's ordinal, over every frame, a
presented one, status 0, one past the last and every other the last, so
frame 0's first present reads the anchor plus one; a presented frame
whose first attempt's ordinal is not its own where it presented at once,
its one attempt, nor the last before it where a refusal came first; and
a presented frame whose decision's stamp comes before its eligibility
tick. Each broken sequence a present the records do not hold. With no
anchor, no load record before the frames, the sequence is named
unanchored and read no further; the window's completeness refuses such
a capture first.

## acceptance-of

Whether a measurement's acceptance intervals stand (AcceptanceInterval):
only at schema 7 or later, the capture complete and its receipt stage
passed; else unavailable, its reason the schema carrying no receipt, the
present sequence not whole, or the receipt sequence invalid. An
unavailable acceptance leaves every row's `acceptance_interval_us` null,
never filled from the completions, so a comparison on it refuses the run
as holding no number in the field.

## accepted

Each presented frame's `acceptance_interval_us`: its receipt's
acceptance stamp less the present's before it, the first frame's from
the load record's cleared screen, consecutive by their present ordinals,
in microseconds to the tenth. A frame that refused its flip or made none
adds no present and breaks no adjacency: its field stays null and the
interval across it lands on the next present.

## popcount

The harts a mask holds.

## harts-invalidity

What makes a complete window at schema 6 invalid in its harts, each mask
a frame's, by hart: a frame without its harts record, which the rest are
read without; a frame dispatched to a hart holding no raster worker, its
active mask outside its started; a raster worker on a hart outside the
grant, its started outside its grant, the two together holding the
active mask inside the grant; a packet record's workers other than the
count of its active harts; reporting harts other than the active; a
claimed hart inside the grant; a grant or a claimed hart outside the
online secondaries; an online mask holding hart 0 or a hart at or past
the ABI's bound, every other mask lying within it by the rules before;
and a grant of fewer harts than its floor, the count reserved. The run's
eligible count bounds nothing: a claim leaves it above the grant.

## pool-invalidity

What makes a complete window at schema 5 invalid in its tile pool: a
frame without its tile record, its storage record, or a configuration
in force, which the rest are read without; slots in use or BUILDING
slots past the effective slots, the effective past the physical,
builds or evictions past the effective, more BUILDING slots than in
use; the construction's time past its boundary's; a batch merged past
its admitted count, or merged and left unprocessed past it; a batch
whose source is not the frame before, or at the first frame not the
sentinel with no request admitted, merged, or left; the memory in use
past TILE_MEMORY or past its high-water, the high-water past
TILE_MEMORY, or either high-water falling; the blocks drawn without
their tiles other than the requests admitted, dropped, and filtered,
since each such block asks once. Across the records: a
batch's admitted count other than the admissions its source frame
recorded, where that frame is in the window; the effective slots other
than the configuration's in force; and the tile bytes other than the
slots in use times the configuration's tile, BUILDING slots counted as
occupied. Each rule reads one copy of a quantity against another, so
two contradictory records cannot each pass alone.

## rows-of

Every frame from 0 to `last` as one row: its leg (by the placements
answered before it), whether a placement opened it, its state, and
with the clock records its phases, the time it left unattributed, its
completion interval, its flip's end less the presented one's before,
its acceptance interval null for accepted to fill, and its latency from
its start, the drawing's parts, and the tile cache's counts; from
schema 2 its presentation too, the submission age from its simulation
to its presented flip's end and the residual its next start leaves past
its start, critical path, wait, and await; from schema 3 its packets,
the preparation, the raster, the commands, the flushes, the bindings
invalidated, the bytes, the snapshot, and what its drawing leaves past
its preparation and its raster, from schema 4 the workers, the grain,
and the rounds' slowest worker, busy time, dispatch, and barrier, from
schema 5 the tile record's columns, the storage record's, and the
configuration's in force, the last whose first frame is at or before
the row's, and at schema 6 the harts record's masks. Without the clock
records the clock's columns are null, the presentation's below schema 2
or without its record, the packets' below schema 3 or without theirs,
the workers' below schema 4, the pool's below schema 5 or without
theirs, and the masks below schema 6 or without theirs.

## receiptless

The receipt record's columns of a row below schema 7 or without its
record, all null.

## hartsless

The harts record's masks of a row below schema 6 or without its record,
all null.

## clockless

The clock's columns of a row with no clock records, all null, the
presentation's and the packets' among them.

## presentationless

The presentation's columns of a row below schema 2, all null.

## packetless

The packets' columns of a row below schema 3, all null, the workers'
among them.

## tileless

The tile record's columns of a row below schema 5 or without its
record, all null.

## storageless

The storage record's columns of a row below schema 5 or without its
record, all null.

## configless

The configuration's columns of a row below schema 5 or with none in
force, all null.

## stats

A value list's count, least, median, 95th and 99th percentiles where
twenty and a hundred values allow, and greatest, each by nearest rank.

## total

A sum that is 0 for no values.

## leg-summary

A leg's frames summed up: the counts, then with the clock records the
critical path and every phase, the flips, the acceptance and the
completion intervals apart, the unattributed time, the
drawing's parts, the tile cache, the presentation, the packets, and the
workers that drew them with their rounds' times, the fast frames, their
critical path under `period_us`, with those among them that waited
before their flip apart; the drawing's and the game's times alone
without them.

## greatest

A list's greatest value, null for no values.

## outliers

The unexplained phase outliers: in a frame no placement opened, a
phase past OUTLIER_RATIO times its leg's median and OUTLIER_US over
it, the frame's tile work within twice the larger of its leg's median
and 100 us. Kept in every statistic; a host stall is one explanation,
not the finding.

## outcomes-of

The play's outcomes within the window: the rounds by what they met,
the androids' events by kind, the times the frame was struck, the
pickups, and the sectors each leg's frames stood in.
