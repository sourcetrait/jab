# console.S

The console, a test channel over the API's input: CONSOLE_FRAME-byte frames by
kind, P placing the camera, T a trace, F a round, N a noise, L the tiles
forgotten with the lumels bright or set by parity and construction lifted or
frozen, R the generator seeded, E the gauge's measurement closed, C the
cadence chosen, W the raster's workers and grain chosen, S on a debug build the
cadence fixture's stalls, K on a debug build the packet's bounds, O on a debug
build the tile pool's knobs, B on a debug build every tile of a surface built
at the next boundary, D on a debug build a surface's tiles read back over the
API, M on a debug build every block's level raised, J on a debug build the
jobs' hold, cancel, and fault, Q on a CENSUS build the census's chunk, each
reported back as REPORT_CONSOLE.

B and D are the builder's assertion's hands, a debug build's alone. B takes
bytes 4 to 7 as a surface, kept plus one in tile_build_surface, and the next
boundary builds every tile of it at every level of its chain before its
construction (tile.S's tile_build_all), under the L's lift where the test
wants them whole. D takes bytes 4 to 7 as a surface, all ones for every
one, and writes every READY tile of it to the API at once, a dump record
and its texel records (tile.S's tile_dump), the pool standing still
between boundaries, and with byte 8 set the BUILDING tile beside them,
held unfinished; its answer after the records closes the dump. The
test's `build-frame` and `dump-frame` build them and tiles.nu's `dumps`
reads the records.

M is the handoff's hand, a debug build's alone: byte 4 the levels every
block's level is raised by, the chain's last at most, 0 for the block's
own, kept in level_raise and standing from the drawing of the frame that
reads it (raster.S's The chain's level), so a wall posed head-on at level
0 is drawn at every level of its chain; byte 5 set, the HUD stamping each
frame's number from the frame that reads it on (hud.S's hud_stamp), so a
screen names the frame it shows. The test's `raise-frame` builds it, its
`--stamp` setting byte 5.

Q is the census's knob, on a CENSUS build alone: bytes 4 to 7 the bytes a
census context line holds before its continuation, 0 for the build's own
bound (census.S's CENSUS_CHUNK), standing from the frame's census lines on,
so a fixture splits every context's list. The test's `census-frame` builds
it.

J is the jobs' knob, on a debug build alone, read by the rounds after it
(workers.S): byte 4 the worker to delay, its index plus one, 0 for none,
and bytes 8 to 11 its delay before each band in microseconds, standing;
byte 12 set cancels every round after its publish while it stands, the
bands its jobs left finished on hart 0; byte 13 the worker to fault, its
index plus one, which on the next round alone loads SCRATCH_POISON's
address and ends the run through the kernel; byte 14 set holds the
delayed worker, in fixed bands, until the round's join reaches its
index, JOB_HOLD_US at most (workers.S's job_hold_wait). The test's
`jobs-frame` builds it, its `--hold` setting byte 14.

W takes byte 4 as the frame's workers, 0 for the serial backend, held to the
workers started (workers.S), and bytes 8 to 11 as the rows a band, 0 for a
band a worker, held to the screen's rows; both from the next drawing on,
since world_draw takes them at its start, in release and debug alike, so one
image draws by the serial backend, one worker, or two.

C takes byte 4 as the cadence, render.inc's CADENCE_*, from the reading
frame's flip on (main.S's CLOCK_CADENCE); a value past the three leaves the
cadence as it was. The gauge sends one beside R before the first frame, and
every presentation record carries the cadence the frame presented under, the
proof that it took.

S is the cadence fixture's knob, on a debug build alone, acting on the frame
that reads it, whose drawing and pacing follow console_read: byte 4 set
stands the stall of bytes 8 to 11, in microseconds, in place of world_draw
from this frame on, and clear puts the drawing back; bytes 12 to 15 are this
frame's own stall in its place, 0 for none; byte 5 set has this frame's
pacing step try its flip once before waiting; bytes 16 to 19 are a spin in
microseconds inside every consume from this frame on (main.S's
draw_or_stall, pacing_step, and pad_consume). An S sets every knob at once,
so a fixture carries the standing stall and the spin in each.

K is the packet's knob, on a debug build alone, standing from the frame
that reads it: bytes 4 to 7 the commands a packet holds and bytes 8 to 11
the spans, each 0 for the engine's own bound, so a fixture makes a frame
flush many times (raster.S's command_emit and span_cap). The test's
`packet-frame` builds it.

O is the tile pool's knob, on a debug build alone, a configuration of its
own the next boundary puts in force and records (tile.S's The knobs): byte
4 the modes, every one replaced, CONFIG_UNLIMITED the quota, the
allowance, and the merge's share lifted, CONFIG_FROZEN construction
frozen, CONFIG_STALE an eviction leaving its entries, CONFIG_ONCE
construction at the first boundary that merged a key and at none after
while the configuration stands; bytes 8 to 11 the
slots the pool may use, a change forgetting the pool; bytes 12 to 15 a
tier's requests and 16 to 19 an open ring's entries, each held to the
build's; bytes 20 to 23 the merge's share in microseconds; bytes 24 to 27
a boundary's work in texels, in force under every mode, the lift's among
them; each 0 for the build's own. Byte 5 set traces the pool's passes on
the UART while it stands; byte 6 set is a cold start at the next
boundary, every tile forgotten and the frame before's requests
discarded. The test's `pool-frame` builds it and `pool-trace` reads the
trace.

R takes the 64 bits in bytes 4 to 11 as the seed of the generator the
androids draw from, so runs sent one seed before their first frame start
alike; its answer before the first state record is the proof it came in
time. E closes the measurement on the frame that reads it: that frame's
records go out at the next frame's start and the end marker right after
them (main.S's frame_records), the game going on.

A frame is 64 bytes: a kind byte, three of padding, the rest by the kind, zero
to the end; a partial frame is kept until the rest arrives. P carries six
floats from byte 4, the eye's x, y, z then the yaw, pitch, and roll in
degrees; its sector is found from the whole map and its basis derived at
once, so a command in the same batch reads the placed camera, and the next
frame is reported on the UART as the first was. The console's record carries
the command's byte where the state's sector sits, which is how a test counts
the placements apart from the traces.

L is the test's hand on the tile pool. Byte 4 set runs `lumels_bright` first,
so a capture after it reads every texel as the texture holds it, times one,
and the lit reading over the bright one is the light alone. The forget and
the configuration come after in every case: every tile is forgotten at the
next boundary, whose light came from the lumels before, and the quota, the
allowance, and the merge's share are lifted from that boundary on, so the
frame after a view's first sight draws it from its tiles; an O's stale mode
is kept. Byte 5 set freezes construction in place of
the lift, so no tile is built and every span takes the lit loop: the lit
loop's picture from the same build, which the fixtures read against the
tiled one. Byte 7, on a debug build alone, runs
`lumels_parity` after the bright, every lumel a quarter or one by its node's
parity, so the light across a cell is a gradient the texel-centre fixture
computes for itself. Byte 6, on a debug build alone, runs `lumels_gradient`
after those, every node by linear functions of its column and row, a lane
each, so the builder's assertion holds the light along u, along v, and
along both apart. The configuration's change goes out as a
configuration record from that boundary (tile.S's tile_configure). On a
CENSUS build an L that rewrites the lumels, by byte 4, 6, or 7, marks the
census's uniformity stale (census.S's census_stale), so its next frame
judges every tile again. The bytes exist for the test; play never sends the
frame.

## .set CONSOLE_FRAME

A console frame's bytes.

## .set CONSOLE_CAPACITY

The console buffer's bytes.

## console_read

The partial frame is moved to the front of the buffer.

## console_frame

L: every lumel set full bright first when the frame's byte 4 is 1, so a
capture reads the texture sampled as the lit one is, and on a debug build by
its node's parity when byte 7 is 1 and by its column and row when byte 6 is
1, in that order; then the pool's forget asked of the next
boundary and its flags pending, the lift, or construction frozen when byte 5
is 1, beside the stale mode as it stood, the configuration marked changed;
on a CENSUS build either rewrite marks the census stale. O: every value
pending, a 0 or one past the build's the build's own, the configuration
marked changed, the trace set or cleared, and a cold start asked when byte
6 is set. B: the surface plus one pending for the next boundary's build. D:
the dump written before the answer. M: byte 4 into raster.S's level_raise
and byte 5 into hud.S's hud_stamp at once, the frame's drawing after the
read taking them. Q: the census's
chunk from
bytes 4 to 7, a CENSUS build's alone; under CENSUS the J branch jumps past
it, where a build without the symbol falls through to the answer.

## k_thousand_d

`f64`: millimetres a metre.

## console_buf

`CONSOLE_CAPACITY u8`: the bytes from the host, a partial frame at the front.

## console_record

`REPORT_SIZE u8`: the console's answer.

## console_pending

`u32`: the bytes kept.

## report_pending

`u8`: 1 when the next frame is reported on the UART.

## measure_end

`u8`: set by an E, cleared once the end marker has gone out.

## stall_on

`u8`: an S's byte 4, the standing stall in place of the drawing while set; a debug build's alone, as are the knobs after it.

## flip_first

`u8`: an S's byte 5, the reading frame's flip tried before its wait, cleared by that frame.

## stall_us

`u32`: the standing stall in microseconds, an S's bytes 8 to 11.

## stall_once

`u32`: the reading frame's own stall in microseconds, an S's bytes 12 to 15, taken once.

## consume_spin

`u32`: the spin inside every consume in microseconds, an S's bytes 16 to 19.
