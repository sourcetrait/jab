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

## .set SCALE_MIN

A six-foot walker at a quarter of the frame is 160 pixels, so five feet to
seven is 53 to 75 in 256ths.

## .set STRIDE

A walker at the frame's own size covers the stride in a second, so a
walker's speed is the stride scaled to its size.

## .set DT_MAX

A frame's time is held to a tenth of a second, so a stall moves nobody
further than that.

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
