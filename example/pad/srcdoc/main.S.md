# main.S

pad: wasd on a gamepad. A sphere you drive and a sphere that bounces,
the graphics of bounce with simple physics; the left stick pushes
your sphere in any direction, harder the further it is pushed and
the longer it is held, up to three times the bouncing sphere's speed;
the dpad pushes at full strength along its eight directions; either
stick pressed in, THUMBL or THUMBR, stops it at once, as the space
bar does; W, A, S, D, and the space bar still work. Every other
button of the pad is given a colour of its own at startup, drawn at
random, and pressing it paints your sphere that colour. The buttons
announce themselves too: the button's evdev name, NORTH and the
rest, centred at the top of the screen in bold off-white at one and
a half times the console's font, staying while the button is held
and three seconds after it is released, or until another button
takes its place; at startup the pad's own name, as the device
reports it, shows there for three seconds. The stick and the dpad
show themselves by moving the sphere and say nothing. The right
stick paints your sphere a colour made from its exact position, red
from its x, green from its y, blue from how far it is pushed, so the
stick's precision is seen, and it drives the sphere too, in its own
direction at a strength by thirds of its throw past the dead zone:
a quarter of ACCEL, ACCEL, and twice it. With no push the sphere
slows to a stop; the walls bounce it back at the speed it hit them,
and so does the other sphere. The other sphere starts somewhere and
bounces off the walls as in bounce, and off your sphere too. The two
never overlap. Positions and speeds carry FIX fractional bits.

The pad is read as a state each tick: the sticks' axes come
normalised to -JAB_PAD_FULL through JAB_PAD_FULL, 0 at rest, and the
left stick's drive is ACCEL scaled by each over full scale; the hat's
axes at full scale add ACCEL outright. The stop is an event, THUMBL
or THUMBR pressed, taken from jab.sys.pad.input. With no pad on the
machine the state reads zero and the example runs on the keyboard
alone.

Over the API, wasd's records both ways, little-endian, each field at
its own width. The host drives with key events of CMD_SIZE bytes, the
shape the keyboard delivers (a JAB_KEY_* code, then pressed or
released), which go through the same held-flag path as the keys. The
reports are wasd's: a velocity record for a sphere when its velocity
changes, an acceleration record when the drive vector changes, from
the keys, the stick, and the hat together, and a hit record per
sphere per collision with the contact point, a wall or the other
sphere; and one of this example's own, a colour record when a button
paints your sphere, its x the colour and its y the button's code.
Values are the program's own fixed point. With no API port on the
machine (`just run example pad` without `--api`) the reads find
nothing and the writes are refused.

A command in: code u16, value u16. A report out: kind u8, sphere u8,
against u8 (a hit's other party), a pad byte, then x i32 and y i32 in
fixed point.

## .set TOP_SPEED

The driven sphere's top speed is nearly four times the bouncing sphere's on
each axis. The physics runs on the clock, by the time since the frame
before, never by a count of frames.

## .set DT_MAX

A frame's time is held to a tenth of a second, so a stall moves nothing
further than that.

## .set APART

Two more than touching, so the drawn discs, at whole pixels, never share
one.

## .set REPORT_MAX

Two velocities, an acceleration, a hit on each axis and with the other
sphere for each of the two, and a colour.

## .set LABEL_SCALE

The label at the top of the screen is a strip the screen's width, cleared
before each name, the name centred in it in off-white at one and a half
times the font, bold.

## .set ACCEL_MAX

The right stick drives by thirds of its throw, in quarters of ACCEL, so the
strongest push is ACCEL_MAX.

## _start

Your sphere's colour starts as PLAYER, and every button gets a colour of its
own. The colours' seed comes from the machine's entropy, the clock only on a
machine with no rng device, and never zero, which xorshift cannot leave.

The pad's own name goes at the top for three seconds, when there is one.

The right stick is found as byte offsets into the state: Z and RZ on this
pad, RX and RY on one laid out the other way, which jab.sys.pad.axis tells
apart by answering 2 for a pad with no Z.

Your sphere starts at the centre, still, on the black the framebuffer starts
with. The other starts somewhere, from the clock: its centre across is the
clock's reading modulo the room across, and down the reading over 7919
modulo the room down, each kept a radius from the edges. The two are then
set apart by collide in case they overlap, and remembered for the first
erase.

## read_api

Bytes arrive as a stream, so a record may come in two pieces; the piece in
hand waits in cmd_partial for the rest. A whole record goes to apply_key.

## read_pad

Only key events of the BUTTONS from JAB_BTN_GAMEPAD count; the axes are read
as state each tick. A held repeat brings nothing new. Released, the
announced button's name starts to go. Pressed, its name stays while it is
held.

## drive_vector

The held keys push at ACCEL each way, the left stick's axes at ACCEL scaled
by each over full scale, and the hat's at ACCEL outright. The right stick:
how far it is pushed, which third of the way that is, and that strength
along its direction, a quarter of ACCEL, ACCEL, or twice it. The sum is held
within ACCEL_MAX.

## collide

From your centre to the other: dx, dy, and the distance squared. A meeting
is noted with where, midway between the centres. The other sphere, if
closing, has its speed's part along the line taken away twice, as off a
wall; yours, if closing, the same way. Then apart: half the shortfall each,
along the line, each centre kept on the screen. With the centres together
they go apart along x.

## report

The records go into report_buffer in this order: your velocity, the other's
velocity, the drive vector the keys, the stick, and the hat apply, the wall
hits, a button's colour, once, and a meeting, one record for each sphere
with the same point. A wall hit's contact point is the centre moved a radius
toward the wall it is against.

## toward_side

The wall is the left one when the centre sits at LEFT exactly, as wall leaves
it on a hit, and the right one otherwise.

## toward_edge

The wall is the top one when the centre sits at TOP exactly, as wall leaves
it on a hit, and the bottom one otherwise.

## render

The rectangle runs from the least of the four centres less the radius to the
greatest plus it, on each axis. A button to announce puts its name into the
strip, and both rectangles are flipped as one.

## draw_label

Its width is a cell a character, and the bold strike; an empty text leaves
the strip clear.
