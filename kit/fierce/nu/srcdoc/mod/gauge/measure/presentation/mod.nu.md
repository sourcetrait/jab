# gauge/measure/presentation

The codes the measurement's parts and their consumers share: a flip's
statuses, the cadences, the cap a frame's period comes from, and eps's
bound.

## CAP

the cap a frame's period comes from when a capture's identity names none

## FLIP_PRESENTED

a flip's status: 0 presented, 1 refused before the tick, 2 no display,
3 the device refused it

## FLIP_VALID

the statuses a valid measurement holds; 2, 3, or any other is a frame
never shown

## EPS_CAP

the presentation contract's on-time tolerance at most, 10,000 ticks, 1
ms (JointTiming): eps is above 0 and at most this, so `--eps` outside it
is refused

## CADENCE_IF_EARLY

the cadence that waits only while presenting would be early, 1: its
frames that waited end their wait on the display's bit and flip at once,
so a receipt's acceptance less its tick is a wake delay alone
(wake-delays)

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

## FLIP_NONE

the status a frame's flip is preset to, 255, kept by a frame that made no
attempt, whose receipt carries no call to bound
