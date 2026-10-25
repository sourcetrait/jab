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

The cadences a capture may hold, the reader's set: 0 awaits after its
flip, 1 waits only while early, 2 holds a frame ready after its tick to
the next. The program plays 1 alone (CadenceCleanup), and the reader
keeps all three, so a capture made at 0 or 2 reads under its own rules as
before: its validity, its pairing, and CADENCE_AFTER_FLIP's rules for 0.

## LAUNCHABLE

The cadences a run may ask, the program's own: 1 alone. `gauge run` and
`gauge play` refuse any other, apart from CADENCES, which the reader keeps.

## FLIP_NONE

the status a frame's flip is preset to, 255, kept by a frame that made no
attempt, whose receipt carries no call to bound
