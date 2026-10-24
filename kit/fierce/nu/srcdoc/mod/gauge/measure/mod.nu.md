# gauge/measure

A capture measured, `main`, over its parts, the child modules below, and
their api a consumer outside fierce's tree calls through it: a `use` of
`kit/fierce/nu/mod/gauge` by its path, then `gauge measure <verb>`. The
measurement's own `main` stays here, since nushell names a re-exported
child's `main` by the child (`sdl log`) and refuses to export an alias as
`main`; the rest of the concept lies in the children. No child imports it;
each imports its siblings by path, and fierce's own modules import a child
directly.

- `measure contract-of`: measure/receipt's `contract-of`.
- `measure flips`: measure/receipt's `flips`.
- `measure screen-frame`: measure/screen's `screen-frame`.
- `measure stats`: measure/summary's `stats`.
- `measure total`: measure/summary's `total`.
- `measure wake-delays`: measure/receipt's `wake-delays`.

Its children: measure/presentation, the flip statuses, the cadences, the
cap, and eps's bound that the parts and their consumers share;
measure/completeness, what keeps a window from complete; measure/validity,
what makes a complete window invalid, schema by schema, its tile pool and
its harts among them; measure/receipt, the receipt stage, the acceptance
intervals, the presentation contract, and the presents in order;
measure/service, a SERVICE build's service read; measure/rows, every frame
as a row; measure/summary, the legs' summaries, their statistics, the
outliers, and the outcomes; measure/screen, the frame a screen's stamp
names, held to the picture contract.

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
7 its receipts break the receipt stage (receipt-invalidity), and from
schema 8 their recorded calls' bounds (bracket-invalidity); complete at
8 besides holds exactly one bounds record, after the load record and
before the first state. The
measurement carries `nonce_set` and `late_nonce`, an I answered before
the first state or after it, `load`, the load record, `acceptance`,
whether its rows' acceptance intervals stand and why not where not
(acceptance-of, accepted), and `contract`, the presentation contract
read on its receipts at `eps`, 1 to EPS_CAP ticks, 10,000 unless given
(contract-of). A valid
window is under the ceiling when its critical path's median is under
CEILING_US, `under` null for one not valid; its frames at or over the
ceiling, each row's `over`, are its tail, counted in any clocked
capture. A frame is fast when its critical path is under the period of
`cap`, whatever its cadence. A capture with no record of the clock's
kinds, 7 to 10, 12 to 15, and 18, is a build older than them: its rows
are its state records' alone and it holds no window. Any one of them
marks the capture clocked and holds it to its window. The measurement
carries the grants and the active masks its frames hold. A SERVICE
build's capture carries `service`, its service read (service-of), null
for any other; a complete window whose service breaks is invalid for it,
its problems among the measurement's invalidities.
