# main.S

feature: a synthetic optional feature on hart ownership by role, a line
a step on the UART and a record a frame over the API for the test to hold
against the machine's harts and the manifest's counts. It reserves
JAB_RESERVED_GFX_HARTS, the grant every online secondary, and renders
frames of ROWS rows on its graphics workers, one a granted hart, each
on its own mailbox. The feature takes JAB_FEATURE_SYNTHETIC_IO_HARTS, the
grant's highest, admitted by the program's own check only while the grant
past them keeps JAB_RESERVED_GFX_HARTS, a check made before any claim or
stop. Both counts come from the generated jab_manifest.inc, never a
literal, so a wrong constant shows in what the program does.

At startup the feature is asked for before graphics starts: admitted, its
claim, then a second claim of a hart of the grant left, which the kernel
refuses at the floor with no worker there to answer busy first, then
graphics on the grant left and the feature's run; refused, the kernel's
own word on the same claim, then graphics on the whole grant.

At the mode transition graphics runs on the whole grant. Admitted, the
feature's harts are taken at a safe boundary: a frame is published whose
first band on the feature's first hart is held after its first row, the
worker acknowledging the hold from inside the band before hart 0 asks for
the claim, which the kernel refuses busy; the hold is released only on the
join's path, the frame joined whole, and only then are the harts' workers
stopped while they wait in their mailboxes, the stop's interrupted mask
held empty as the boundary's witness. Every stop's mask is checked before
anything joins, since jab.job.join waits on a completion a forced worker
never publishes. The hold's word goes out on the stop's line on every
path, so an expiry is seen whether or not the held frame is ever sent.
Refused, the claim of a running hart is refused busy, nothing stopped.

The feature's run, the same at both points: its worker under the claim's
id, four frames on the grant left beside it, its release refused busy
while its worker waits on its hart, its result joined, its harts stopped,
the release, the stale id's start refused for its owner and its release
unknown, graphics back on its harts, and four frames on the whole grant.
The feature's worker waits on its hart after its work until hart 0 stops
it, so the busy release is refused every run and never by a race with
the worker's exit.

## .macro start_worker

The sixth operand of jab.sys.worker.start carries the owner, so a5 is
loaded first and nothing between the operands' moves overwrites it; the
stack is the hart's own STACK_BYTES in stacks, which keeps every running
worker's stack apart.

## .set ROWS
## .set BAND_ROWS
## .set BANDS

`u64`: a frame's rows, 64, its bands of eight rows, eight of them, dealt
by index over the frame's graphics workers in ascending hart order, the
k-th band to the worker of index k mod the workers' count.

## .set ROW_STEPS

`u64`: the xorshift64 steps of a row's word, 4096, from a seed of the
frame's number shifted by eight, or the row's, plus one, so no seed is 0.

## .set FEATURE_STEPS
## .set FEATURE_SEED

`u64`: the feature's bounded work, an xorshift64 run of 2^20 steps, and
its seed; the test recomputes the result on the host.

## .set FRAMES

`u64`: the frames of a stretch, four.

## .set STACK_BYTES

`u64`: a worker's stack, 16 KiB; stacks holds one a secondary, hart n's at
n - 1.

## .set HOLD_TICKS

`u64`: the hold's watchdog, two seconds of the time counter, forty times
the stop's 50 ms bound (the kernel's WORK_STOP_TICKS), so a stop placed
ahead of the release meets the worker still held and forces it. An expiry
lets the band go on and marks the word, which the test reads as the
transfer unexercised.

## .set HOLD_IDLE
## .set HOLD_HELD
## .set HOLD_RELEASED
## .set HOLD_EXPIRED

`u32`: hold_word's values: idle before the held frame; held, written by
the worker from inside its band; released, by hart 0's compare-and-swap
from held; expired, by the worker's from held at its watchdog.

## .set ARG_INDEX
## .set ARG_COUNT
## .set ARG_HOLD

`u64`: a job's arguments in its mailbox's JAB_JOB_ARGS: the worker's index
among the frame's workers, their count, and 1 where its first band is
held; the frame's number rides JAB_JOB_FRAME.

## .set FEAT_DONE
## .set FEAT_PARK
## .set FEAT_RESULT
## .set FEAT_HART
## .set FEAT_BYTES

A feature record's fields: `u32` the mark its worker sets once its result
is kept, and the word it waits on, which stays 0; `u64` the result and
the hart that made it; `u64` the record's size, 32.

## .set REC_FRAME
## .set REC_GFX
## .set REC_FEATURE
## .set REC_SUM
## .set REC_ROWS
## .set RECORD_BYTES

A frame's record over the API: `u64` its number, its graphics workers'
mask, the feature's harts, and its rows' words summed with a wrapping add;
`ROWS u8` each row's renderer, 0 for none; `u64` its size, 96.

## word_harts
## word_reserve
## word_space
## word_owned
## word_startup_check
## word_transition_check
## word_want
## word_admit
## word_startup_claim
## word_transition_claim
## word_id
## word_left
## word_startup_second
## word_startup_graphics
## word_refused
## word_feature_start
## word_feature_release
## word_feature_result
## word_feature_stop
## word_interrupted
## word_feature_released
## word_feature_stale
## word_feature_return
## word_transition_busy
## word_transition_stop
## word_hold
## word_transition_owner
## word_end_stop
## word_frames

`u8`: the lines' words.

## mailboxes

`JAB_HARTS_MAX * JAB_JOB_BYTES u8`: a graphics worker's mailbox a hart,
hart n's at n times JAB_JOB_BYTES; they outlive a worker, so a worker
started again on a hart awaits the next job there.

## feature_records

`JAB_HARTS_MAX * FEAT_BYTES u8`: a feature worker's record a hart.

## words
## renderers

`ROWS u64`, `ROWS u8`: the frame's rows' words and each row's renderer,
cleared before every publish, written by the hart that renders the row.

## record

`RECORD_BYTES u8`: the frame's record being sent.

## frame_next
## frame_gfx
## frame_feature

`u64`: the next frame's number, and the published frame's graphics and
feature masks.

## hold_word

`u32`: the hold's word, 8 bytes kept for its alignment.

## line

`200 u8`: the line being built.

## digits

`32 u8`: put_dec's digits, built backward.

## stacks

`(JAB_HARTS_MAX - 1) * STACK_BYTES u8`: the workers' stacks.
