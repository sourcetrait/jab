# gauge/measure/summary

The legs' summaries and the statistics they are made of, the unexplained
phase outliers, and the play's outcomes.

## OUTLIER_RATIO

an unexplained phase outlier: a phase past OUTLIER_RATIO times its
leg's median and OUTLIER_US over it, in a frame whose tile work stayed
within twice the larger of its leg's median and 100 us, the first
frame after a placement apart

## ANDROID_EVENTS

the android events and what a round met, as the program reports them

## stats

A value list's count, least, median, 95th and 99th percentiles where
twenty and a hundred values allow, and greatest, each by nearest rank.

## total

A sum that is 0 for no values.

## leg-summary

A leg's frames summed up: the counts, then with the clock records the
critical path and every phase, the flips, the acceptance and the
completion intervals apart, the unattributed time, the
drawing's parts, the tile cache, the presentation, the packets, and the
workers that drew them with their rounds' times, the fast frames, their
critical path under `period_us`, with those among them that waited
before their flip apart; with service columns the service phase's
statistics, the slots applied in all, the greatest depth, and the quotas
skipped; the drawing's and the game's times alone without them.

## greatest

A list's greatest value, null for no values.

## outliers

The unexplained phase outliers: in a frame no placement opened, a
phase past OUTLIER_RATIO times its leg's median and OUTLIER_US over
it, the frame's tile work within twice the larger of its leg's median
and 100 us. Kept in every statistic; a host stall is one explanation,
not the finding.

## outcomes-of

The play's outcomes within the window: the rounds by what they met,
the androids' events by kind, the times the frame was struck, the
pickups, and the sectors each leg's frames stood in.
