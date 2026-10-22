# gauge

The gauge: the game's frames measured over play. At each frame's start
the program sends the frame before's records over the API, the frame's
clock (kind 7), its drawing with the tile cache (kind 8), from schema 2
its presentation (kind 10): the simulation's time, the next frame's
start, the wait before the flip and the pacing around it, the pad's
wakes and presses in the wait, the flip's attempts and refusals, and
the cadence; and at schema 3 its packets (kind 12): the preparation and
the raster apart, the commands, the flushes, the bindings invalidated,
the bytes the packets held, and the frame whose simulation they were
prepared from, the drawing's planes, walls, and sprites then
preparation alone; and at schema 4 the raster's workers that drew them,
0 the serial backend, the grain, and the rounds' slowest worker, every
worker's busy time, the dispatch, and the barrier; and at schema 5 the
tile pool: the drawing's tiles_us its boundary's own part, no longer
within the planes and walls, the packets' bindings invalidated 0, its
tile record (kind 13), the requests the frame admitted, dropped, and
filtered, the batch its boundary consumed, the merge, the eviction, the
construction, and the blocks hit, straddling, and missed, its storage
record (kind 15), the slots and memory at the boundary's end, and a
configuration record (kind 14) ahead of the first frame it governs; and
at schema 6 its harts record (kind 18), masks by hart: the online
secondaries, the count reserved, the grant at the frame's latch, the
harts under the program's claims, those holding a raster worker, those
the frame dispatched to, and those whose workers completed its jobs; and
at schema 7 its receipt record (kind 20), its flips as the kernel
answered them, beside one load record (kind 21) before the first state,
the load's two presents and the run's capture nonce, which the console's
I hands the program. After the console's E
the end marker (kind 9) names the final frame of the measurement, which
the frames from 0 to it make up. render.inc lays the records out; this
reader takes schemas 1 to 7. `run` plays a route on a build `--runs`
times, headless or with `--host` in the host's window and audio, each
run seeded by the console's R, asking its cadence by the console's C and
with `--workers` its workers and grain by the console's W before its
first frame; `play` puts the build in the host's window, audio, and gamepad
for a person to play and closes the measurement after `--seconds`;
`read` reads a capture either made; `compare` sets builds' captures
side by side, a build being an image at the cadence it played on the
machine and the route it ran on, a walked leg per stretch of its path,
refusing a run measured incomplete, invalid, or before validity was
recorded, one that cannot be paired, one on a diagnostic machine or
with QEMU words of its launch's own, one missing a leg its route names,
or runs on more than one machine or route, unless `--diagnostic` admits
it, and a run with nothing to compare in it or not on the route its
identity recorded outright, every run's standing, route, and missing
legs kept. Each run keeps the route it played and
its identity beside its capture, then gauge.nuon and the summary. The
measurement is the capture read in order through the first end marker;
what follows it counts for nothing. A frame's critical path is its start
to the end of its reporting, the wait and the await apart; a measurement
is valid when it is complete, every flip presented or refused as its
cadence allows, every phase within its frame, every frame's clock
agreeing with its state, from schema 2 every frame's start, critical
path, wait, and await adding up to the next frame's start and its start,
simulation, flip end, and next start in that order, from schema 3 every
frame's drawing its preparation and its raster, the bytes its packets
held its commands' and its span records', and its packets prepared from
its own simulation, from schema 4 every frame's workers, below 6 at
most WORKERS_MAX_TO_FIVE, at a grain within the screen's rows, its round
times none under the serial backend and its slowest worker, dispatch,
and barrier within its raster, its busy time at least its slowest
worker's and at most W times it with the W - 1 microseconds its
conversions drop, from schema 5 every frame's tile pool within its slots
and memory, its batch the frame before's and accounted, its records
agreeing with each other and with the configuration in force, and at
schema 6 every frame's workers its active harts, inside its started
harts, inside its grant, inside the online secondaries, its reporting
harts its active, its claims outside its grant, and its grant at least
its floor (invalidity). The ceiling is judged on the critical path's
median: a valid measurement is under the ceiling when its median is
under 15 ms, and its frames at or over 15 ms are its tail, counted
beside the median.
A capture holding no record of the clock's kinds, 7 to 10, 12 to 15,
and 18, is a build older than them: it holds no measurement and is read from
its state records alone, the drawing's and the game's microseconds.
`bench-report` reads a run of a bench whose steps are the gauge's,
every cadence's frames pooled. fierce's `nuance.nu gauge run`, `gauge
play`, `gauge read`, `gauge compare`, and `gauge bench-report` run
them, and its cadence bench runs `gauge play`, `gauge run`, and `gauge
bench-report`.
A run's identity is read through one reader (gauge identity of): the run's
identity.nuon, its directory found beside its report before the path
the report recorded, with an audited correction beside it applied
(gauge identity corrected); else the copy its report embedded; else the report's
one identity; a comparison names each run's source and corrections.
`run` and `play` refuse an image whose build flags contradict the tree
asked. `run --cpu` reads every QEMU thread's CPU at 5 s, at each
placement, and at the route's end, kept whole in run.nuon and reported
as host-time windows (gauge cpu windows). A SERVICE build's capture carries
its service's records, outside the clock kinds (SceneOwnership), one a
frame held complete beside the clock's; `run --service` runs the synthetic
service through the route, and the measurement reads its windows
(gauge/measure/service's service-of), a broken window making the run
invalid. `audio`, the
`nuance.nu gauge audio` step, runs RegressionSuite's fixture as a bench
step and keeps its reading.

The gauge parts in one import for a consumer: a `use` of
`kit/fierce/nu/mod/gauge` by its path from the consumer, then
`gauge <part> <verb>`, a part's `main` by the part's name. No part
imports it; each imports its siblings by path.

- `gauge audio`: gauge/audio.
- `gauge bench`: gauge/bench.
- `gauge compare`: gauge/compare.
- `gauge identity`: gauge/identity.
- `gauge measure`: gauge/measure.
- `gauge play`: gauge/play.
- `gauge read`: gauge/read.
- `gauge report`: gauge/report.
- `gauge stream`: gauge/stream.
