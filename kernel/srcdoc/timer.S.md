# timer.S

The frame clock and the wait: a tick every 1/JAB_DISPLAY_FPS_CAP of a
second, kept as the time of the next tick. jab.sys.display.flip moves it,
jab.sys.display.ready reads it, and jab.sys.await halts the hart until it,
or until a key arrives, through the supervisor timer (stimecmp) and the
PLIC, with the interrupts enabled only while waiting and taken by wfi
rather than by the trap vector. A tick that has passed is reported by the
next wait as it stands and moved on by the flip, so a program that woke on
an input and comes back after the tick loses nothing; the wait moves a
passed tick itself only when it reported that tick already and no flip has
answered it (frame_reported).

## .set TICK

`u64`: a frame period in time ticks.

## .set SOUND_POLL

`u64`: how often a sound-only wait looks for a stall.

A device that stops returning raises no line (sound.S), so a wait on the
sound stream alone wakes on this timer to look.

## frame_flipped

A punctual program keeps an exact cadence and a slow one is never refused.
The tick the program was told of is answered by this flip, so the wait no
longer owes it a move.

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

A stream that has stopped returning is declared dead and its bit dropped;
with nothing else in the mask the wait ends with 0. The sound line raises
nothing from a stalled device, so with no display tick armed the timer
wakes the wait to look.

The display's tick, once reported, is moved on by the next wait unless a
flip answers it first. The external lines stay enabled while the sound
stream is live, so its interrupt keeps reaching the vector as the program
runs.

## frame_tick

`u64`: the time of the next tick.

## frame_reported

`u64`: 1 once a wait reported the tick, 0 once a flip answered it.
