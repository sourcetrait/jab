# gauge/measure/validity

What makes a complete window invalid, schema by schema, the tile pool's
rules from schema 5 and the harts' at 6 among them.

## NO_BATCH

the batch source of the first boundary, which consumes none

## WORKERS_MAX_TO_FIVE

the raster's workers a frame may have through schema 5, render.inc's
bound then; from schema 6 a frame's workers are its active harts, a
slot a secondary (GFX_SLOTS, the ABI's JAB_HARTS_MAX less hart 0); the
screen's rows, a grain's bound

## RESIDUAL_US

a frame's next start less its start less its critical path, wait, and
await: the microseconds the conversions drop, at most this

## COMMAND_BYTES

a command's bytes in a packet by schema, the polygon's record copied
whole, 312 while it carried its tile bindings and 232 from the pool on,
schema 8's too, and a span record's (render.inc's POLY_SIZE and
SPAN_RECORD_SIZE)

## PACKET_RESIDUAL_US

a frame's drawing less its preparation and its raster: the microsecond
the three conversions drop, at most this

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
