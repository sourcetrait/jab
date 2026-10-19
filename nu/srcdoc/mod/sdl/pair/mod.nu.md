# sdl/pair

## pair_limits

The pairing's limits, printed with every reading (sdl-pair).

## main

A probed run's presents paired one for one with the host's flip uploads
(ProbeRuns), from the run's classified events, a validated paired
bundle's (sdl-bundle-check) or sdl-classify's on the host with the run's
binding checked there, and the guest's flips in its window in order,
each its status, its present ordinal, and its end in microseconds on the
guest's clock: 1, the presented flips' ordinals each one past the one
before (ordinal-violations), a gap refusing the run; 2, the host's flip
uploads numbered from the log's first, 1 on, the shim logging from
QEMU's start; 3, the present of ordinal k paired with upload k, the log
holding every ordinal through the window's last present and going on at
least 1 s of host time past its upload, uploads past the window read for
nothing; 4, the fit, least squares for the offset and the drift of the
paired uploads' stamps against the presents' ends, every residual under
half the period. Refused, each named and counted, all of them found: an
ordinal gap; the log short of an ordinal; a duplicated event, two in a
row alike in stamp, name, and chain; a stamp going backwards; a residual
past half the period; a device error in the window; the log ending under
1 s past the window's last upload; fewer than two presents to fit. A
refused run is unresolved and never trimmed to make counts agree. `ok`,
the refusals, the pairs with their residuals, the fit, the window's
ordinals, and the limits (pair_limits), printed with every reading.
