# suite/workers

## GFX_GUIDELINE

render.inc's GFX_GUIDELINE (GuidelineThree): the most workers the
default draws with, so eight harts with no W draw three

## STAMP_AT

The picture contract (FrameCeiling's GfxScaling): the stamp on from
STAMP_AT, a screen taken while the run goes on, the E after it; the
cancel cases' screen at JOB_SCREEN_AT, their bound past it

## JOB_CASES

The jobs' behaviours through the console's J frame, a debug build's,
its delay and fault keyed to a worker's hart, on the spawn view with two
workers: hart 2's worker held before each band at a band a worker, the
frame waiting for it, and at 16 rows, the other taking its bands; every
round cancelled after its publish, hart 2's worker held so its band is
left to hart 0, and at 16 rows; each the default's picture and counts.
Hart 1's worker faulting on its next round ends the run with its line;
an idle worker's thread under IDLE_RATE of a core over the span held
from IDLE_AT

## IDLE_READINGS

the same launches' readings at a list of times (`jab launch
--threads-at`), the last past the run's six-second bound and missing;
on eight harts a W of two leaves the five started past it asleep, and
with no W the default's GFX_GUIDELINE draw and harts 4 to 7 sleep

## TAKE_AT

The transitions through the console's H frame, a debug build's: on
four harts the spawn view settled, the grant's highest hart taken at
TAKE_AT under the program's claim, a placement read while it is held
(TAKEN_AT), the hart given back at GIVE_AT, and a placement read on the
three again (GIVEN_AT), the screen at TAKE_CAPTURE_AT and the E after
it; each frame's masks from the harts records, the grant, the claimed,
the started, the dispatched, and the reporting, against the frames that
answered the two H frames. Drawn by the default and by a W of three at
a band a worker asked before the take, its count held to the started
at each frame; the picture while taken, at GIVE_AT, and after the
give-back each bound to its frame and the stamped reference's. On three
harts the take is refused by the floor, nothing moved

## take-holds

The H frame's transitions on the still copy's spawn view settled, each
launch's moves the program's lines of them in order (MOVE_PREFIXES), and
no frame dispatched to a hart outside the started or the grant; every
launch under the picture contract, stamped from STAMP_AT, its screen
taken while the run goes on and the E after it, each picture compared
bound to the frame it shows (`gauge measure screen-frame`), the stamp's cells
skipped:
- reference: four harts, the same sends without the H frames, its screen
  at GIVE_AT, its window opening at the frame that answered the second
  placement, its frame drawn by three on the three harts at the
  default's grain at the spawn pose;
- taken: four harts, the take of one at TAKE_AT and a placement read at
  TAKEN_AT, the screen at GIVE_AT: hart 3's worker stopped, then the
  hart claimed; the frame read drawn by the two started, no band on hart
  3, every band of its rounds rendered once; the default's counts; its
  screen bound from the frame that answered the take, drawn by two on
  harts 1 2 with hart 3 claimed, the reference's picture;
- given, by the default and by a W of three at a band a worker asked
  before the take: the give-back at GIVE_AT and a placement read at
  GIVEN_AT too, the screen at TAKE_CAPTURE_AT and the E after it:
  complete and valid; each frame's masks, from the harts records, the
  three harts' before the frame that answered the take, the grant harts
  1 2 with 3 claimed and two drawing from it to the frame that answered
  the give-back, the three's again from it; the frame read while taken
  drawn by two, no band on hart 3, and the one after by three, a band a
  worker on each for the W; both the default's counts; its screen bound
  from the frame that answered the give-back, drawn by three on the
  three harts at the asked grain, the reference's picture;
- stale: the taken run's screen and the reference's, each bound against
  a window opening past the frame it shows, refused for its stamp;
- floor: three harts, the take refused under the floor with its line,
  nothing stopped or claimed, every frame on harts 1 2.
Returns the frames each given run drew while taken.

- a run's screen bound to the frame it shows, from the window's opening
- stale: each screen bound against a window opening past the frame it
  shows, refused for its stamp alone

## started

the program's start on the specification's three harts: the
reservation's grant, harts 1 and 2, a raster worker on each

## raster

the raster's workers: the default, every worker started in bands of
GRAIN_DEFAULT rows, drew the views above; the same spawn view drawn
again by the serial backend, by one worker, by two a band a worker,
and by two in bands of WORKER_GRAIN rows, each the default's picture
over the whole screen with the default's counts, every band rendered
in every round and the clear on hart 0 under the serial backend
alone, each with the pool's contents held: construction frozen once
the view settled (WORKER_FREEZE_AT), the frame read building nothing
on the default's slots

## machines

the workers on each machine (WORKER_MACHINES): the reservation's
grant every online secondary, a raster worker on each hart of it; a W
asking GFX_SLOTS held to those started, a band a worker and at the
default grain, every band rendered once by the harts started, each
the default's picture and counts; two harts and one refused

## grant

the grant moved through the H frame (take-holds): a hart taken and
given back on four harts, by the default and by a W of three, and
the take refused by the floor on three

## jobs

the jobs' behaviours (JOB_CASES): a held worker, the cancel, the
fault, and idle workers asleep; a cancel case under the picture
contract, stamped, its screen at JOB_SCREEN_AT with the E after it,
the bound past it so the final records land, its measurement complete
and valid with exactly one witness for every measured frame from the
J's answer through the final, rounds above 0 and cancelled equal to
rounds, and its screen bound to its frame, that frame's witness among
them; the cases without the cancel keep their launches
