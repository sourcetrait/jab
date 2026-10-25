# console

## SEED_AT

when a run's seed goes in, before the program's first frame

## CONSOLE_P

A console record carries the command's byte, a u32 word, where the
state's sector sits; the P frame's, the H frame's, and the J frame's

## CLOCK_SEED

The clock over Render Zero's walk: the seed and the cadence sent before
the first frame, the cadence the program's own, 1, the E closing the
measurement a second before the
capture, and the records' schema; a frame's next start less its
start less its critical path, wait, and await, the microseconds the
conversions drop, at most CLOCK_RESIDUAL

## RECEIPT_NONCE

the capture nonce the Render One launch sends in its I

## PLACE_AT

A view read from the tile pool is placed twice: the pool builds at a
frame's boundary what the frame before asked for, so the first
placement's frame draws the view at first sight and the second's
draws it settled, and the frame line read is the second's

## SPAWN_POSE

Render Zero's spawn view, the spawn's eye and yaw, for one level a
block: the bay's floor runs to some twenty metres from it, where a
block asks a level past the tiles' four

## seed

The console's R frame: the seed as 64 bits in bytes 4 to 11.

## cadence

The console's C frame: the cadence in byte 4, which the program, playing
one cadence, answers as an unknown kind.

## nonce

The console's I frame: the run's capture nonce as 64 bits in bytes 4 to
11, which the program echoes in its load record (CaptureBundle).

## run-sends

A run's sends before its route's: an R with its seed, a C with its
cadence, and an I with its capture nonce at SEED_AT, then the W its
asked workers send (console workers-sends); every run's alike, probed or not, so
the shim is a probed run's one difference.

## workers

The console's W frame: the raster's workers in byte 4, 0 for the serial
backend, and the rows a band in bytes 8 to 11, 0 for a band a worker.

## workers-sends

The W a run's asked workers and grain send beside the seed, none when
it asks none.

## level

The console's L frame: every tile forgotten at the next boundary,
every lumel set full bright first when `bright`, construction frozen
when `held` so every span takes the lit loop, else the quota and the
allowance lifted, and on a debug build every lumel set by its node's
parity after the bright with `--parity`, and by linear functions of
its column and row after those with `--gradient` (byte 6).

## build

The console's B frame, a debug build's: every tile of the surface in
bytes 4 to 7 built at the next boundary, at every level of its chain.

## dump

The console's D frame, a debug build's: every READY tile of the surface
in bytes 4 to 7, all ones for every surface, written to the API at once,
and with `--building` (byte 8) the BUILDING tile beside them.

## raise

The console's M frame, a debug build's: every block's level raised by
byte 4 from the frame's drawing on, the chain's last at most, 0 for
the block's own; byte 5 set (`--stamp`) the HUD stamping each frame's
number from then on (picture stamp).

## settled

A view placed at PLACE_AT and again at SETTLE_AT, so the frame line
read, the second placement's, draws it settled on its tiles.

## jobs

The console's J frame, a debug build's: the delayed worker's hart in
byte 4, 0 for none, and its delay before each band in microseconds
from byte 8; byte 12 set cancels every round after its publish; byte 13
the faulting worker's hart, its next round; byte 14 set (`--hold`)
holds the delayed worker in fixed bands until the round's join reaches
its position, JOB_HOLD_US at most.

## harts

The console's H frame, a debug build's: byte 4 the harts to take, the
grant's highest, held idle under the program's claim; 0 gives the
claim's harts back to the raster.

## census

The console's Q frame, a CENSUS build's: a census context line's chunk
in bytes, a word from byte 4, 0 for the build's own bound.

## packet

The console's K frame, a debug build's: the commands and the spans a
packet holds, 0 for the engine's own bounds, each a word from byte 4.

## pool

The console's O frame, a debug build's knobs on the tile pool, in force
from the next boundary: byte 4 the modes, POOL_LIFTED, POOL_FROZEN,
POOL_STALE, and POOL_ONCE together, every one replaced, POOL_ONCE
building tiles at the first boundary that merged a key and at none
after; byte 5 every pass's surfaces
on the UART while set (`--trace`, pool-trace reads them); byte 6 a cold
start at the next boundary, every tile forgotten and the frame before's
requests discarded (`--cold`), so a view placed with it is drawn at
first sight; then words from byte 8, the slots the pool may use, a
tier's requests, an open ring's entries, the merge's share in
microseconds, and a boundary's work in texels under every mode, the
lift's among them (`--quota`), each 0 for the build's own. A change of
the slots forgets the pool too.

## service

The console's V frame, a SERVICE build's (SceneOwnership): byte 4 set
starts the service, clear stops it; byte 5 LOCKSTEP, a debug build's; the
total messages and the quota frames as words from byte 8, frames 0 for the
total every frame unbounded; the corrupted sequence plus one as a 64-bit
word from byte 16, 0 for none, and the hold's microseconds before each
message as a word from byte 24, both a debug build's knobs.

## stall

The console's S frame, a debug build's alone: byte 4 the standing stall
on, byte 5 the reading frame's flip tried before its wait, then the
standing stall, the reading frame's own stall, and the spin inside
every consume, words in microseconds from byte 8.
