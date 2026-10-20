# timer.S

The frame clock and the wait: a tick every 1/JAB_DISPLAY_FPS_CAP of a
second, kept as the time of the next tick. jab.sys.display.flip moves it,
jab.sys.display.ready reads it, and jab.sys.await halts the hart until it,
or until a key arrives, through the supervisor timer (stimecmp) and the
interrupt file (aia.S), with the interrupts enabled only while waiting and taken by wfi
rather than by the trap vector. A tick that has passed is reported by the
next wait as it stands and moved on by the flip, so a program that woke on
an input and comes back after the tick loses nothing; the wait moves a
passed tick itself only when it reported that tick already and no flip has
answered it (frame_reported).

Every global here is hart 0's: hart 0's calls alone touch it. A worker's
calls are jab.sys.harts and the worker calls (trap.S's worker_call), and its
waits are workers.S's, so no path a worker takes reaches a routine or the
data of this file; test/owners holds that on the built kernels.

## .set TICK

`u64`: a frame period in time ticks.

## .set SOUND_POLL

`u64`: how often a sound-only wait looks for a stall.

A device that stops returning raises no line (sound.S), so a wait on the
sound stream alone wakes on this timer to look.

## .set FRAME_EPS

`u64`, under the build symbol P2 alone: P2's on-time tolerance in ticks, a
multiple of 100 from 100 to 10,000, an assembly `.error` otherwise. Its value
is JointTiming's calibration, the wake delays' 99.9th percentile on the
baseline's P0 runs rounded up to 100 ticks; until that lands it is the
contract's cap, 10,000 (1 ms).

## frame_ready

Beside the readiness it answers the `rdtime` it read in a1 and the tick it
held it against in a2, the flips' receipt.

## frame_flipped

The flip's acceptance in a0, its receipt's own stamp, which the caller kept;
the present's end read here. The next tick is `frame_next`'s, so the flip and
the DEBUG step call run one rule. The tick the program was told of is
answered by this flip, so the wait no longer owes it a move.

## frame_next

The rule, one routine for every build: P0 by default, a period on from the
tick while the present ended within a period of it, so a punctual program
keeps an exact cadence and a slow one is never refused, else a period from
the present's end; under the build symbol P2, a period on from the tick while
the acceptance is under FRAME_EPS past it, else a period from the
acceptance, so no two presented flips stand nearer than a period less the
tolerance (JointTiming's K) and the present's own length stays out of the
grid. The lateness is taken unsigned; a presented flip's acceptance is never
before its tick, the ready rule's.

## sys_frame_step

DEBUG alone (JointTiming's function cases): the rule over a tick, an
acceptance, and an end the program gives, nothing presented and the clock
untouched, so the arithmetic is tested at exact ticks. An acceptance before
the tick is refused as an early flip is, 1 with the tick as it stood.

## sys_await

The wait is for the mask's events and nothing else, since a program claims
the inputs it reads: the display's next tick (JAB_AWAIT_DISPLAY); a key
event (JAB_AWAIT_KEYBOARD), which brings the keyboard up and is dropped
from the mask when there is none; bytes from the host over the API
(JAB_AWAIT_API), dropped when the machine has no API port; a pad event
(JAB_AWAIT_PAD), which brings the pad up and is dropped when there is none;
and room in the sound stream (JAB_AWAIT_SOUND), which brings the sound
device up and is dropped when there is none. A source in the mask that a
program never drains holds every wait at once, which is why nothing is in
the mask but what it names.

The display's tick: a tick the program was told of and has not flipped on
(frame_reported) moves forward past now, period by period, so a program
that only idles wakes once a period; a tick that passed since the last
flip stays where it is, so the wait reports it at once, while the program
was handling a key or a pad event, and the flip after it lands one period
on from the tick rather than a period late; then the timer is armed, and a
tick already past ends the wait before it halts.

A source masked as stuck during the wait sends the wait back to its start,
where each device's open answers again and one whose source stuck drops
out of the mask, so no wait holds on a device that will never answer.

A stream that has stopped returning is declared dead and its bit dropped;
with nothing else in the mask the wait ends with 0. The sound line raises
nothing from a stalled device, so with no display tick armed the timer
wakes the wait to look. Every exit goes through the teardown, the timer's
enable cleared, the external enable cleared without a live stream, and
stimecmp set to all ones: a mask a stuck pass emptied included, which would
otherwise leave a sound-only wait's poll timer armed to fire in user mode
as a program fault.

The display's tick, once reported, is moved on by the next wait unless a
flip answers it first. The external lines stay enabled while the sound
stream is live, so its interrupt keeps reaching the vector as the program
runs.

While workers run (workers.S's workers_live) the external enable is set for
every wait, whatever the mask, so a worker's fault reaches hart 0 here. A
claimed shutdown is checked before each wfi and sends the wait out through
its teardown, and the boundary it returns through parks the hart; the wake
that announced the shutdown stays pending in the hart's file until the wfi
if it lands after the check, so the wait never sleeps past it.

## frame_tick

`u64`: the time of the next tick.

## frame_reported

`u64`: 1 once a wait reported the tick, 0 once a flip answered it.
