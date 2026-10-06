# console.S

The console, a test channel over the API's input: CONSOLE_FRAME-byte frames by
kind, P placing the camera, T a trace, F a round, N a noise, L the tiles reset
with the lumels bright or set by parity, the tiles held off, or the levels built
capped, R the generator seeded, E the gauge's measurement closed, C the
cadence chosen, W the raster's workers and grain chosen, S on a debug build the
cadence fixture's stalls, K on a debug build the packet's bounds and a forced
reset, each reported back as REPORT_CONSOLE.

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
flush many times (raster.S's command_emit and span_cap); bytes 12 to 15 the
binds each frame after which the tile arena is reset, poisoned first, 0
for none (tile.S), the stale binding's fixture. The test's `packet-frame`
builds it.

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

L is the test's hand on the tile cache. Byte 4 set runs `lumels_bright` first,
so a capture after it reads every texel as the texture holds it, times one,
and the lit reading over the bright one is the light alone. The reset and the
budget come after in every case. Byte 5 set leaves the frame's budget at zero
in place of unbound, so no surface ever completes level 0 and every span takes
the lit loop: the lit loop's picture from the same build, which the alpha
fixture reads against the tiled one. Byte 6, on a debug build alone, caps the
levels a surface builds, 0 for every level: at 1 a surface builds level 0 and
stops, so a block asking a coarser level takes the chain at it, which the
alpha fixture reads against the lit loop's picture too. Byte 7, on a debug
build alone, runs `lumels_parity` after the bright, every lumel a quarter or
one by its node's parity, so the light across a cell is a gradient the
texel-centre fixture computes for itself. The bytes exist for the test; play
never sends the frame.

## .set CONSOLE_FRAME

A console frame's bytes.

## .set CONSOLE_CAPACITY

The console buffer's bytes.

## console_read

The partial frame is moved to the front of the buffer.

## console_frame

L: the tiles forgotten and rebuilt under no budget from the next frame, every
lumel set full bright first when the frame's byte 4 is 1, so a capture reads
the texture sampled as the lit one is; under a budget of nothing instead when
byte 5 is 1, so every surface stays on the lit loop; and on a debug build
every lumel set by its node's parity when byte 7 is 1, before the reset, and
the levels a surface builds held to byte 6 when it is not 0.

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
