# main.S

walk: a large busy sidewalk. The walker sprite, sixteen frames of a
walk cycle, loads off the romfs straight from its directory; then
eight horizontal lanes carry walkers, each entering from a random
side of the screen, in a random colour, at a random size from five
feet to seven if the frame is six, walking to the other side and
leaving. A lane holds up to a few walkers at once: when the side
chosen for a new one is clear, no walker in the lane within a stride
of that edge, one enters, at once for an empty lane and otherwise
after a random wait, so the crowd staggers. A walker entering from
the right is the same frames mirrored. The screen stays black, as
the framebuffer starts. Each frame tick the clock is read, and
everything moves by the time since the frame before, never by a
count of frames: every walker's last shape is cleared by drawing the
same frame solid in black, which touches its own pixels and not its
whole box, it is moved by its speed over that time and its animation
stepped by it, the area where it was and where it is noted as one
rectangle, then every one is drawn top lane to bottom so nearer
walkers cover farther ones, and the noted rectangles are flipped as
one, so the host copies and paints the walkers' own areas and not
the screen. Over the API, when a run has it, a record per walker
that enters and per walker that leaves, for the test.

## .set DISK

`u8`: the romfs disk's id.

## .set FRAME_W

`u32`: a walker frame's width in pixels.

## .set FRAME_H

`u32`: a walker frame's height in pixels.

## .set FRAMES

`u32`: the frames of the walk cycle.

## .set SPRITE_BYTES

`u64`: the sprite buffer jab.sys.sprite.load needs for the frames.

## .set LANES

`u64`: the lanes, top to bottom.

## .set LANE_H

`u64`: a lane's height in pixels.

## .set PER_LANE

`u64`: the most walkers a lane holds at once.

## .set SCALE_MIN

`u64`: the least a walker is drawn at, five feet, in 256ths.

A six-foot walker at a quarter of the frame is 160 pixels, so five feet to
seven is 53 to 75 in 256ths.

## .set SCALE_MAX

`u64`: the most a walker is drawn at, seven feet, in 256ths.

## .set STRIDE

`u64`: astra's stride, pixels of travel a walk cycle at the frame's own size.

A walker at the frame's own size covers the stride in a second, so a
walker's speed is the stride scaled to its size.

## .set ENTRY_GAP

`i64`: the pixels a new walker needs clear at its edge.

## .set ENTRY_WAIT

`u64`: the most a lane waits after an entry before another, four seconds in ticks.

## .set ANIM_TICKS

`u64`: the animation's step, sixteen frames a second in ticks.

## .set DT_MAX

`u64`: the most time one frame moves anybody, a tenth of a second in ticks.

A frame's time is held to a tenth of a second, so a stall moves nobody
further than that.

## .set BACKGROUND

`u32`: the screen's colour, black.

## .set W_X

`i64`: the left edge, in 256ths of a pixel.

## .set W_DIR

`i64`: 1 walking right, -1 walking left.

## .set W_SCALE

`u64`: the scale in 256ths.

## .set W_TINT

`u64`: the colour, 0x00RRGGBB.

## .set W_FRAME

`u64`: the animation's frame.

## .set W_TICK

`u64`: the animation's time since its last frame.

## .set W_DW

`u64`: the drawn width.

## .set W_DH

`u64`: the drawn height.

## .set W_Y

`i64`: the top, the feet on the lane's floor.

## .set W_ACTIVE

`u64`: 1 while the place holds a walker.

## .set W_SPEED

`u64`: 256ths of a pixel a second.

## .set W_SIZE

`u64`: a walker record's bytes.

## .set LANE_WAIT

`i64`: the ticks until the lane may take another, after its walkers.

## .set LANE_SIZE

`u64`: a lane's bytes.

## .set R_KIND

`u8`: 1 a walker entered, 2 one left.

## .set R_LANE

`u8`: the lane.

## .set R_SIDE

`u8`: the side it entered from, 0 the left, 0 for a leaving.

## .set R_SCALE

`u8`: its scale in 256ths, 0 for a leaving.

## .set R_TINT

`u32`: its colour, 0 for a leaving.

## .set R_SIZE

`u64`: an API record's bytes.

## _start

The seed, never zero, is the clock with its low bit set, and the clock is
noted for the first frame's time.

## frame

Every lane in turn: its walkers moved along, and one in when there is room.
For each walker, the shape it drew last tick is cleared: the same frame,
place, size, and pose, drawn solid in the background's colour, which touches
its own pixels and not its whole box. It moves by its speed over the frame's
time, and the animation steps when its own time has come. The area that
changed, where it was and where it is, is noted as one rectangle. Off the far
side, the place is free and the host is told.

Then every walker is drawn, top lane first, and the changed areas go as one
flip; with WHOLE set, the whole screen instead, for measuring the difference.
A frame with nothing noted flips nothing.

## bad_sprite

The code, one or two digits, is written after the message.

## admit

First a free place, and whether the lane is empty; an empty lane waits for
nothing. Then the side, and the edge must be clear: no walker within the gap
of it. In it comes, and the lane's wait starts again.

## enter

Its colour has every channel bright enough to see, 64 to 255.

## path_walker

`8 u8`: the romfs directory holding the walker's frames.

## msg_no_display

`18 u8`: the line for a machine with no display.

## msg_bad_sprite

`38 u8`: the line for a walker that would not load, its code following.

## msg_bad_sprite_code

`4 u8`: the code's digits, a newline, and the terminator, written by bad_sprite.

## seed

`u64`: the random sequence's state, never zero.

## last_time

`u64`: the clock at the frame before, in ticks.

## dt

`u64`: the frame's time in ticks, at most DT_MAX.

## record

`8 u8`: the API record being sent.

## rect_count

`u64`: the rectangles noted this frame.

## rects

`96 u32`: the rectangles to flip, one a walker at most.

## lanes

`272 u64`: the lanes' walker records and waits.

## sprite

`19701776 u8`: the walker sprite.
