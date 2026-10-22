# main.S

bounce: a ball bouncing around the display, Jab's display example.
Opens the display, black as the framebuffer starts, then each frame
works first and waits after: it reads the clock, erases the ball,
moves it by its speed over the time since the frame before, draws it,
keeps the one rectangle holding where it was and where it is, waits
for the tick, and flips that rectangle, waiting again if the flip
comes back early. Drawn before its wait, each frame flips on its tick,
every period. The ball moves by time, never by frames, so the frame
cap and a late frame change when it is seen and never where it is.
Runs until the window closes.

## .set RADIUS

`i64`: the ball's radius in pixels.

## .set BACKGROUND

`u32`: the screen's colour, black.

## .set BALL

`u32`: the ball's colour, the logo's, LowKick's own.

## .set LEFT

`i64`: the least the centre may be across, keeping the whole ball on the screen.

## .set RIGHT

`i64`: the most the centre may be across.

## .set TOP

`i64`: the least the centre may be down.

## .set BOTTOM

`i64`: the most the centre may be down.

## .set FIX

`u8`: the fraction bits of a position or a speed.

## .set ONE

`i64`: one pixel in 256ths.

## .set SPEED_X

`i64`: 210 pixels a second across, in 256ths.

## .set SPEED_Y

`i64`: 150 pixels a second down, in 256ths.

## .set DT_MAX

`u64`: the most time one frame moves the ball, a tenth of a second in ticks.

A frame's time is held to a tenth of a second, so a stall moves the ball no
further than that.

## _start

The ball's centre and its speed are set in s0 to s3, the centre at 200, 200
pixels, and the clock is noted in last_time before the first frame.

## frame

Where the ball was, in pixels, is kept in s4 and s5 and erased. The ball goes
on by its speed over the frame's time, then off the walls: a centre past a
limit is put back on it and that speed turned. Once drawn, the rectangle
holding the old square and the new goes to present: from the lesser centre
less the radius to the greater plus it, inclusive.

## present

The rectangle goes to flip_rect before the wait, since the wait's answer
lands in a0, and the flip reads it back from there.

## last_time

`u64`: the clock at the frame before, in ticks.

## dt

`u64`: the frame's time in ticks, at most DT_MAX.

## flip_rect

`4 u32`: the rectangle the frame flips once its wait is over, x, y, width,
and height.

## msg_no_display

`20 u8`: the line for a machine with no display.
