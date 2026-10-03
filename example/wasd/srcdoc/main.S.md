# main.S

wasd: a sphere you drive and a sphere that bounces, Jab's input
example with simple physics. W, A, S, and D push your sphere, harder
the longer a key is held, up to three times the bouncing sphere's
speed; with no key held it slows to a stop; the space bar stops it
at once; the walls bounce it back at the speed it hit them, and so
does the other sphere. The other sphere starts somewhere and bounces
off the walls as in bounce, and off your sphere too. The two never
overlap. Positions and speeds carry FIX fractional bits, and the
physics runs on the clock: each frame reads the time since the frame
before and moves and pushes by that, never by a count of frames, so
the frame cap and a late frame change when a sphere is seen and not
where it is.

Over the API, records both ways, little-endian, each field at its own
width. The host drives with key events of CMD_SIZE bytes, the shape
the keyboard delivers (a JAB_KEY_* code, then pressed or released),
which go through the same held-flag path as the keys. wasd reports in
records of REPORT_SIZE bytes: a velocity record for a sphere when its
velocity changes, an acceleration record when the drive vector the
held keys apply changes, and a hit record per sphere per collision
with the contact point, a wall or the other sphere. Values are the
program's own fixed point. With no API port on the machine (`just run
example wasd` without `--api`) the reads find nothing and the writes
are refused, and the example runs on the keyboard alone.

A command in: code u16, value u16. A report out: kind u8, sphere u8,
against u8 (a hit's other party), a pad byte, then x i32 and y i32 in
fixed point.

## .set TOP_SPEED

The driven sphere's top speed is nearly four times the bouncing sphere's on
each axis.

## .set DT_MAX

A frame's time is held to a tenth of a second, so a stall moves nothing
further than that.

## .set APART

Two more than touching, so the drawn discs, at whole pixels, never share
one.

## .set REPORT_MAX

Two velocities, an acceleration, and a hit on each axis and with the other
sphere for each of the two.

## _start

Your sphere starts at the centre, still, on the black the framebuffer starts
with. The other starts somewhere, from the clock: its centre across is the
clock's reading modulo the room across, and down the reading over 7919
modulo the room down, each kept a radius from the edges. The two are then
set apart by collide in case they overlap, and remembered for the first
erase.

## read_api

Bytes arrive as a stream, so a record may come in two pieces; the piece in
hand waits in cmd_partial for the rest. A whole record goes to apply_key.

## collide

From your centre to the other: dx, dy, and the distance squared. A meeting
is noted with where, midway between the centres. The other sphere, if
closing, has its speed's part along the line taken away twice, as off a
wall; yours, if closing, the same way. Then apart: half the shortfall each,
along the line, each centre kept on the screen. With the centres together
they go apart along x.

## report

The records go into report_buffer in this order: your velocity, the other's
velocity, the drive vector the held keys apply, the wall hits, and a meeting,
one record for each sphere with the same point. A wall hit's contact point is
the centre moved a radius toward the wall it is against.

## toward_side

The wall is the left one when the centre sits at LEFT exactly, as wall leaves
it on a hit, and the right one otherwise.

## toward_edge

The wall is the top one when the centre sits at TOP exactly, as wall leaves
it on a hit, and the bottom one otherwise.

## render

The rectangle runs from the least of the four centres less the radius to the
greatest plus it, on each axis.
