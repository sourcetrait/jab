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

## .set RADIUS

`i64`: a sphere's radius in pixels.

## .set BACKGROUND

`u32`: the screen's colour, black.

## .set PLAYER

`u32`: your sphere's colour.

## .set BALL

`u32`: the bouncing sphere's colour, the logo's, LowKick's own.

## .set LEFT

`i64`: the least a centre may be across, keeping the whole sphere on the screen.

## .set RIGHT

`i64`: the most a centre may be across.

## .set TOP

`i64`: the least a centre may be down.

## .set BOTTOM

`i64`: the most a centre may be down.

## .set FIX

`u8`: the fraction bits of a position or a speed.

## .set ONE

`i64`: one pixel in fixed point.

## .set BALL_VX

`i64`: the bouncing sphere's speed across, bounce's 210 pixels a second.

## .set BALL_VY

`i64`: the bouncing sphere's speed down, bounce's 150 pixels a second.

## .set TOP_SPEED

`i64`: your sphere's top speed on each axis, 780 pixels a second.

The driven sphere's top speed is nearly four times the bouncing sphere's on
each axis.

## .set ACCEL

`i64`: what a held key adds a second, 720 pixels a second squared.

## .set DECEL

`i64`: what a free axis loses a second, 450 pixels a second squared.

## .set DT_MAX

`u64`: the most time one frame moves anything, a tenth of a second in ticks.

A frame's time is held to a tenth of a second, so a stall moves nothing
further than that.

## .set TOUCH_SQ

`i64`: the spheres have met when their centres are this close in pixels, squared.

## .set APART

`i64`: how far apart met spheres are set, two pixels more than touching.

Two more than touching, so the drawn discs, at whole pixels, never share
one.

## .set CMD_SIZE

`u64`: an API command's bytes.

## .set CMD_CODE

`u16`: the key's code, a JAB_KEY_*.

## .set CMD_VALUE

`u16`: pressed or released, a JAB_KEY_* value.

## .set CMD_READ_BYTES

`u64`: the most one API read takes.

## .set REPORT_SIZE

`u64`: a report's bytes.

## .set REPORT_KIND

`u8`: the kind, REPORT_VELOCITY, REPORT_ACCELERATION, or REPORT_HIT.

## .set REPORT_SPHERE

`u8`: the sphere, a SPHERE_*.

## .set REPORT_AGAINST

`u8`: a hit's other party, AGAINST_WALL or a SPHERE_*.

## .set REPORT_X

`i32`: x in fixed point, after a pad byte.

## .set REPORT_Y

`i32`: y in fixed point.

## .set REPORT_VELOCITY

`u8`: a sphere's velocity changed.

## .set REPORT_ACCELERATION

`u8`: the drive vector the held keys apply changed.

## .set REPORT_HIT

`u8`: a collision, at the contact point.

## .set SPHERE_PLAYER

`u8`: your sphere.

## .set SPHERE_BALL

`u8`: the bouncing sphere.

## .set AGAINST_WALL

`u8`: a wall.

## .set REPORT_MAX

`u64`: the most reports a frame.

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

## last_time

`u64`: the clock at the frame before, in ticks.

## dt

`u64`: the frame's time in ticks, at most DT_MAX.

## player_x

`i64`: your sphere's centre across, in fixed point.

## player_y

`i64`: your sphere's centre down, in fixed point.

## player_vx

`i64`: your sphere's speed across, in fixed point a second.

## player_vy

`i64`: your sphere's speed down, in fixed point a second.

## ball_x

`i64`: the other sphere's centre across, in fixed point.

## ball_y

`i64`: the other sphere's centre down, in fixed point.

## ball_vx

`i64`: the other sphere's speed across, in fixed point a second.

## ball_vy

`i64`: the other sphere's speed down, in fixed point a second.

## old_player_x

`i64`: your sphere's centre across in pixels, as last drawn.

## old_player_y

`i64`: your sphere's centre down in pixels, as last drawn.

## old_ball_x

`i64`: the other sphere's centre across in pixels, as last drawn.

## old_ball_y

`i64`: the other sphere's centre down in pixels, as last drawn.

## last_player_vx

`i64`: your sphere's speed across as last reported.

## last_player_vy

`i64`: your sphere's speed down as last reported.

## last_ball_vx

`i64`: the other sphere's speed across as last reported.

## last_ball_vy

`i64`: the other sphere's speed down as last reported.

## last_ax

`i64`: the drive vector across as last reported.

## last_ay

`i64`: the drive vector down as last reported.

## meet_x

`i64`: where the spheres met across, in fixed point.

## meet_y

`i64`: where the spheres met down, in fixed point.

## report_count

`u64`: the reports in report_buffer this frame.

## cmd_pending

`u64`: the bytes of a command in cmd_partial.

## report_buffer

`108 u8`: this frame's reports.

## cmd_read

`64 u8`: one API read's bytes.

## cmd_partial

`4 u8`: a command arriving in pieces.

## held_w

`bool`: 1 while W is held.

## held_a

`bool`: 1 while A is held.

## held_s

`bool`: 1 while S is held.

## held_d

`bool`: 1 while D is held.

## player_hit_x

`bool`: your sphere hit a side wall this frame.

## player_hit_y

`bool`: your sphere hit the top or the bottom this frame.

## ball_hit_x

`bool`: the other sphere hit a side wall this frame.

## ball_hit_y

`bool`: the other sphere hit the top or the bottom this frame.

## met

`bool`: the spheres met this frame.

## msg_no_display

`18 u8`: the line for a machine with no display.
