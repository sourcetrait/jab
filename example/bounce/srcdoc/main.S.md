# main.S

bounce: a ball bouncing around the display, Jab's display example.
Opens the display, black as the framebuffer starts, then each frame
waits for the tick, reads the clock, erases the ball, moves it by its
speed over the time since the frame before, draws it, and flips the
one rectangle holding where it was and where it is. The ball moves
by time, never by frames, so the frame cap and a late frame change
when it is seen and never where it is. Runs until the window closes.

## .set DT_MAX

A frame's time is held to a tenth of a second, so a stall moves the ball no
further than that.

## _start

The ball's centre and its speed are set in s0 to s3, the centre at 200, 200
pixels, and the clock is noted in last_time before the first frame.

## frame

Where the ball was, in pixels, is kept in s4 and s5 and erased. The ball goes
on by its speed over the frame's time, then off the walls: a centre past a
limit is put back on it and that speed turned. Once drawn, the rectangle
holding the old square and the new is flipped: from the lesser centre less
the radius to the greater plus it, inclusive.
