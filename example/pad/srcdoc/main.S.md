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

## .set RADIUS

`i64`: a sphere's radius in pixels.

## .set BACKGROUND

`u32`: the screen's colour, black.

## .set PLAYER

`u32`: your sphere's colour at the start.

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
each axis. The physics runs on the clock, by the time since the frame
before, never by a count of frames.

## .set ACCEL

`i64`: what a full push adds a second, 720 pixels a second squared.

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

`u8`: the kind, REPORT_VELOCITY, REPORT_ACCELERATION, REPORT_HIT, or REPORT_COLOR.

## .set REPORT_SPHERE

`u8`: the sphere, a SPHERE_*.

## .set REPORT_AGAINST

`u8`: a hit's other party, AGAINST_WALL or a SPHERE_*.

## .set REPORT_X

`i32`: x in fixed point after a pad byte, a colour record's colour.

## .set REPORT_Y

`i32`: y in fixed point, a colour record's button code.

## .set REPORT_VELOCITY

`u8`: a sphere's velocity changed.

## .set REPORT_ACCELERATION

`u8`: the drive vector changed.

## .set REPORT_HIT

`u8`: a collision, at the contact point.

## .set REPORT_COLOR

`u8`: a button painted your sphere.

## .set SPHERE_PLAYER

`u8`: your sphere.

## .set SPHERE_BALL

`u8`: the bouncing sphere.

## .set AGAINST_WALL

`u8`: a wall.

## .set REPORT_MAX

`u64`: the most reports a frame.

Two velocities, an acceleration, a hit on each axis and with the other
sphere for each of the two, and a colour.

## .set BUTTONS

`u64`: the pad's buttons given a colour, from JAB_BTN_GAMEPAD.

## .set COLOR_FLOOR

`u8`: the least a button colour's channel is, so it shows on black.

## .set COLOR_SPAN

`u8`: the range above COLOR_FLOOR a channel is drawn from.

## .set LABEL_SCALE

`u64`: one and a half times the console's font, in 256ths.

The label at the top of the screen is a strip the screen's width, cleared
before each name, the name centred in it in off-white at one and a half
times the font, bold.

## .set LABEL_CELL

`u64`: a label character's width in pixels.

## .set LABEL_HEIGHT

`u64`: the label strip's height in pixels.

## .set LABEL_Y

`i64`: the label strip's top.

## .set LABEL_COLOR

`u32`: the label's off-white.

## .set LABEL_TIME

`u64`: how long a name stays after its button is released, three seconds in ticks.

## .set NAMED_BUTTONS

`u64`: the entries of button_names, the last for a button with no name.

## .set NO_BUTTON

`i64`: label_code with no button announced.

## .set ACCEL_MAX

`i64`: the strongest push on an axis, which nothing exceeds.

The right stick drives by thirds of its throw, in quarters of ACCEL, so the
strongest push is ACCEL_MAX.

## .set BAND

`i64`: a third of the right stick's throw.

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

## drive_x

`i64`: this frame's drive vector across, a second.

## drive_y

`i64`: this frame's drive vector down, a second.

## meet_x

`i64`: where the spheres met across, in fixed point.

## meet_y

`i64`: where the spheres met down, in fixed point.

## report_count

`u64`: the reports in report_buffer this frame.

## cmd_pending

`u64`: the bytes of a command in cmd_partial.

## rand_state

`u64`: the colours' random sequence state, never zero.

## color_code

`u64`: the code of the button that last painted your sphere.

## label_code

`i64`: the button announced, NO_BUTTON for none.

## label_text

`addr`: the label's NUL-terminated text.

## label_left

`i64`: the ticks the label has left once its button is released, 0 while it stays.

## last_time

`u64`: the clock at the frame before, in ticks.

## dt

`u64`: the frame's time in ticks, at most DT_MAX.

## report_buffer

`120 u8`: this frame's reports.

## cmd_read

`64 u8`: one API read's bytes.

## cmd_partial

`4 u8`: a command arriving in pieces.

## right_x

`u64`: the right stick's axis across, a byte offset into pad_state.

## right_y

`u64`: the right stick's axis down, a byte offset into pad_state.

## pad_state

`132 u8`: the pad's state as jab.sys.pad.read last wrote it.

## axis_record

`5 i32`: the range jab.sys.pad.axis wrote while the right stick was found.

## button_colors

`32 u32`: every button's colour, from JAB_BTN_GAMEPAD.

## player_color

`u32`: your sphere's colour.

## rects

`8 u32`: the spheres' rectangle and the label strip, flipped together.

## pad_name

`128 u8`: the pad's name as the device reports it.

## color_changed

`bool`: a button painted your sphere, not yet reported.

## label_changed

`bool`: the label's text changed, not yet drawn.

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

`17 u8`: the line for a machine with no display.

## name_south

`6 u8`: evdev's name for JAB_BTN_SOUTH.

## name_east

`5 u8`: evdev's name for JAB_BTN_EAST.

## name_c

`2 u8`: evdev's name for JAB_BTN_C.

## name_north

`6 u8`: evdev's name for JAB_BTN_NORTH.

## name_west

`5 u8`: evdev's name for JAB_BTN_WEST.

## name_z

`2 u8`: evdev's name for JAB_BTN_Z.

## name_tl

`3 u8`: evdev's name for JAB_BTN_TL.

## name_tr

`3 u8`: evdev's name for JAB_BTN_TR.

## name_tl2

`4 u8`: evdev's name for JAB_BTN_TL2.

## name_tr2

`4 u8`: evdev's name for JAB_BTN_TR2.

## name_select

`7 u8`: evdev's name for JAB_BTN_SELECT.

## name_start

`6 u8`: evdev's name for JAB_BTN_START.

## name_mode

`5 u8`: evdev's name for JAB_BTN_MODE.

## name_thumbl

`7 u8`: evdev's name for JAB_BTN_THUMBL.

## name_thumbr

`7 u8`: evdev's name for JAB_BTN_THUMBR.

## name_none

`1 u8`: the empty name, for a button with none and for a clear strip.

## button_names

`16 addr`: every button's name from JAB_BTN_GAMEPAD, the last for a button with none.
