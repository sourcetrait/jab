# suite/clock

## cadence-holds

The program's three cadences on its own clock records, one
launch a cadence of each fixture, the debug build's S frames standing
stalls in place of the drawing, each window held complete and valid at
the program's schema before anything is read from it. CadenceSchedule,
on Render One: R and C at 200 ms; from 1.5 s a 4 ms standing stall and a
500 us spin inside every consume; ten trigger reports from 1.8 s, 400
ms apart, each pressed and released in one report; at 5.9 s a frame
whose flip is tried before its wait; at 6.3 s a frame stalled 38 ms;
from 7 s a 25 ms standing stall; the E at 9 s. A sustained stage sets
its first five frames aside; a one-off is read at the frame its S
answer names, the first state after it, and the frames after it as they
come. The fast
stage presents every period under 1 and 2, which wait for the tick, a
period after its simulation, and under 0 a period plus its wake and
drawing apart, soon after its simulation, every presented flip late by
its drawing; every frame with wakes holding the consume's spin in its
pacing and its critical path, never its wait; the forced frame under 1
and 2 is refused once and presents on the tick; the stalled frame's
intervals are each cadence's recovery; the slow stage presents a period
plus its wake and drawing apart under 0, as soon as ready with no wait
under 1, and every second period on the tick grid under 2; ten rounds under every
cadence, presses taken in waits under 1 and 2, and few wakes a frame.
MotionByTime, on the still copy of Render Zero: placed on the bay's east side
facing north, a 25 ms standing stall, the stick held forward from 2 to
5 s; over the frames the body moved in a metre or more from every wall
of their sector, the distance from the first to the last over the
difference of their simulation times is 4 m/s within 2 percent under
every cadence.

Each schedule's receipts are held to the frame rule (rule-holds) at
FRAME_EPS as timer.S sets it, and its contract is read at that eps.
Cadence 0 is the order that awaits, then draws, then flips, so its flips
land late by their wake and drawing and re-anchor, each a period plus
those after the one before; cadences 1 and 2 prepare first and wait for
the tick, which the rule keeps on its grid.

- the fast stage
- the frame whose flip is tried before its wait
- the frame stalled once and the two after it: under 0 its flip a
  period and its stall past the flip before, the next two a period and
  the standing stall past theirs; under 1 presented
  once ready, the next held to the tick a period past its flip, then
  the period; under 2 held to the third tick, then the period
- the slow stage
- the rounds, the presses taken in waits, and the wakes a frame

## TIMER

The kernel's timer.S, which sets the frame rule's tolerance FRAME_EPS
(frame-eps).

## TICK

The kernel's TICK, 166,666: the period at the cap of 60 in the guest
clock's 10 MHz ticks, the unit the rule steps a receipt's tick by.

## frame-eps

FRAME_EPS as timer.S sets it, in ticks, the workspace's own: the eps the
kernel under test was built with when the suite builds it.

## rule-holds

The frame rule on a schedule's receipts: for each two presented flips in
order, the later one's tick is the earlier's tick a period on when the
earlier was accepted under eps past its tick, else its acceptance a
period on; exactly that at cadences 0 and 1, which never let a reported
tick move the clock between two presents, and that or whole periods past
it at cadence 2, whose late frames wait for a fresh tick. The read is
exact, every tick and stamp a receipt's. K holds at eps over every
acceptance, the contract's count none.

## submitted

A capture's rows each with the interval from the presented flip before
its own to its own, both read at the call's start, the flip's end less
its calls: the call that presents takes 0.5 to 2 ms here as the device
answers, so intervals between flip ends carry that spread, where a call
starts on the display's tick. Null for a frame whose flip did not
present and for the first that did.

## receipts

the receipts on Render One (ProbeRuns, PairBracket): the load record
before the first state with the title's ordinal 2, the cleared screen's
3, and the nonce the I sent; its bounds record after it, before the
first state, at the program's schema, each load decision inside its
recorded call, the two calls in order after the origin; a receipt a
frame, the presented frames' ordinals one past the last from 4 (jab
ordinal-violations); each presented frame's decision at or past its tick
and inside its final attempt's recorded call

## walk

the frame's clock over the walk: the seed and the cadence answered
before the first frame, the E closing the measurement with the end
marker after its final frame's records, every frame from 0 to it
with a frame, a draw, a presentation, and a packet record in order
at the schema, each at cadence 0, awaiting after its flip: no wait
and no pacing, one flip attempt, a refusal only when it came early;
each frame's start, critical path, wait, and await adding up to its
next start, the next frame's start; each frame's phases within its
critical path and the drawing's parts, the raster and the tile
pool's boundary among them, within the drawing, the tiled pixels
within the lit, the pool's peak at or past what it holds, and its
tile and storage records at the schema; each frame's drawing its
preparation and its raster, the
bytes its packets held its commands' and span records', and its
packets prepared from its own simulation, its workers' round times
within its raster, and its harts within their grant, the gauge's
rules at schema 6 which its validity holds; commands and spans in
every frame; every frame drawn by the default, every worker started
in bands of GRAIN_DEFAULT rows, with a slowest worker's time, on its
grant's two harts, both started and active; and the game going on past
the measurement

## cadences

the three cadences on a schedule of stalls and trigger reports and
on a timed walk (cadence-holds)
