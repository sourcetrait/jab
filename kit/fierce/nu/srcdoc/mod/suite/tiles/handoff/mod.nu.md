# suite/tiles/handoff

The handoff's measurement: the handoff fixture's wall tiled against lit
by level and light, head-on and oblique, partial residency among its runs,
and the count lines a COUNT build reports.

## HANDOFF_BOUNDS

The head-on wall's tiled picture against its lit one at levels 0 to k,
the most a channel differs as measured plus one, under each light: this
fixture's regression limits, the ramp's and the checkerboard's; above k
a block takes the lit loop and the two pictures are one

## HANDOFF_EARLY

The live fixture's placement due just before the screen

## HANDOFF_OBLIQUE

The oblique pose (IntervalPhase): the eye `off` the long wall into the
room and `along` it from its east end, turned `turn` degrees from
head-on toward its west end, so every span's 1/z changes and each row
runs from one-block intervals at the far end to four-block ones at the
near end, the screen's right edge, where a level-0 tile's boundary
(x = 11) falls in a span's last block, its straddle ending a span's
intervals cut short; ONCE construction on HANDOFF_OBLIQUE_SLOTS slots
builds the near tiles first, leaving resident tiles beside missing
ones in the four-block part; levels 0 to HANDOFF_OBLIQUE_LEVELS - 1

## COUNT_LINE

a COUNT build's count line, every count the reported frame's own

## handoff-unsettled

What keeps a handoff run's window as its kind requires, each problem
naming its frame: `rows`, the frames from the second placement's
through the marker's, `kind` tiled (the full settling predicate: no
block drawn without its tile, no BUILDING tile, nothing admitted,
dropped, filtered, or built), held (nothing read from a tile, nothing
built, no BUILDING tile), or partial (nothing built, no BUILDING tile,
`slots` slots in use, nothing evicted, the tiled pixels one count
throughout, and requests admitted and filtered every frame).

## count-of

A count line's counts, COUNT_LINE's; a line of another form refused.

## handoff-holds

The handoff's measurement on the handoff fixture's tree, the wall posed
head-on: under each of HANDOFF_LIGHTINGS and at every level of its
chain by the M frame, the wall settled on its tiles under the lift, and
with the tiles held off, the lit loop's picture; at the levels whose
tiles the wall's spans cross on the screen, under partial residency
too, the O frame's ONCE construction on HANDOFF_PARTIAL_SLOTS slots on
the serial backend; and posed obliquely (HANDOFF_OBLIQUE), every span's
1/z changing, held off, settled, and under partial residency on
HANDOFF_OBLIQUE_SLOTS slots at levels 0 to HANDOFF_OBLIQUE_LEVELS - 1,
compared over the whole screen. The set runs on a handoff,count build.
Each run's frame line, the second placement's, held:
the wall drawn from settled tiles, from none held off, and under partial
residency from the slots built once, fewer blocks than settled. Each
run read by gauge measure, complete and valid at CLOCK_SCHEMA, its window
from the second placement's frame through the marker's held to its
kind (handoff-unsettled); its screen, taken while the run goes on,
whole, its stamp a frame of that window before the marker's; and its E
written after the screen completed. The dispatch held on synthetic
late wakes (jab due-order); and two live fixtures: the placement due
HANDOFF_EARLY before the screen, written before it was asked, its
screen judged by its stamp alone; and the screen and the E due
together, the E after the screen. Each picture
held to the lit one over the wall's rows and columns on the screen
inset by FIXTURE_INSET, the crosshair's square and the stamp's cells
left out, by the tiles bin's handoff in a nu of its own: each pixel's
greatest channel difference, of 255, as its pixels, those differing,
the most, the 99th, and the mean, the pixels whose texel's light is
clamped at the last node apart; under partial residency each pixel's
difference from the nearer of the tiled and the lit pictures, 0 at
every pixel, the lit intervals keeping the all-lit span's knots, and
rows taking pixels nearer each, the spans alternating hits and misses.
Head-on, through k the tiled picture lies within HANDOFF_BOUNDS of the
lit one under each light; above k a block takes the lit loop, the
tiled run reading no tile and its picture the lit one.
Every case of a lit block re-entering an interval on a span whose 1/z
changes, two blocks, four, and cut short, counted on some oblique
partial run's reported frame under each light. Returns every
comparison, every run's window, its first and last frames and its
stamp, the early fixture's reading, and the oblique runs' re-entries.

- the dispatch on late wakes (jab due-order): a poll past the overdue
  second placement, the screen, and the E takes the placement, the
  screen, then the E, which waits on the screen; the three due at one
  time take the screen first
- head-on at yaw 90 a pixel's column is a world x on the wall's line
  and its row a height, each a texel coordinate from the map's first
  node linear in the pixel
- a run: the view of `times`'s `placed` placed at PLACE_AT and again at
  its `second`, the screen taken at its `screen` while the run goes
  on, and the E sent at its `end`; read whole, its window the second
  leg's rows, the frames from the second placement's through the
  marker's, and its re-entries from its last count line, the second
  placement's frame's
- a run's window held to its kind on `slots` slots, its screen a frame
  of the window before the marker's, and its E written after the screen
  completed
- loops, so a failing assertion is the error raised, not an each's
- the O after the placement, never with it: two writes at
  one time can land in two console reads, and an O read
  first builds its one construction from the view before
- the oblique pose (HANDOFF_OBLIQUE): every span's 1/z changing, held
  off, settled, and under partial residency on HANDOFF_OBLIQUE_SLOTS
  slots at the first levels of the chain, each compared over the whole
  screen, the pose needing no texel map; the re-entries counted on each
  partial run's reported frame, the second placement's, whose drawing
  its window holds through the screen
- the live fixtures, settled on the gradient's tiles at level 0
- the placement due just before the screen, written before the screen
  was asked; its screen accepted or refused by its stamp alone
- the screen and the E due together, the E after the screen
- a pair a nu, the nus side by side, each comparison's per-pixel work
  in a nu of its own; held in a loop after, so a failing assertion is
  the error raised
- every lit pixel under partial residency the all-lit span's, its
  intervals' knots kept whatever the tiles beside them: each pixel the
  tiled picture's or the lit one's exactly
- the handoff head-on: through k the tiled picture within this
  fixture's bounds of the lit one, above k the lit one itself
- and the re-entries those pictures hold: every case of a lit block
  entering an interval mid-way on a span whose 1/z changes, on some
  oblique run's reported frame under each light, a whole interval of
  two blocks, of four, and one cut short by the span's end, whose step
  is the per-lane division's
