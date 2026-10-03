# sprite.S

Sprites: frames of native pixels the program owns, blended onto the
framebuffer (jab.inc for the record). A draw walks the drawn rectangle,
clipped to the screen, and for each of its pixels samples the nearest
source pixel of the frame at the scale asked, so scaling up repeats pixels
and scaling down skips them; a step from one drawn pixel to the next source
one is fixed per draw in 16.16 fixed point, and at JAB_SPRITE_SCALE_ONE it
is exactly one, so an unscaled draw is a plain copy of the frame. A spanned
record, one the kernel decoded, carries each row's first and last opaque
column, and the unturned draw walks only the drawn columns those map to, so
a thin figure in a wide frame costs its own pixels rather than the frame's.
The pose mirrors and turns: a flip reads the frame's columns or rows from
the far end, and an angle turns the scaled frame about its centre, the draw
then walking the turned rectangle's bounding box and mapping each pixel of
it back through the inverse turn, in 16.16 with a sine table, to the source
pixel under it or to nothing. Per pixel the alpha decides: 0 is skipped,
255 copied, and anything between blended, each channel becoming
(s * a + d * (255 - a)) / 255, rounded; the tint multiplies each of the
sprite's channels by its own, over 255, first, and a white pixel takes the
tint outright, which is the same number. Division by 255 is the exact shift
form (x + 128 + ((x + 128) >> 8)) >> 8. A solid draw writes the tint over
every pixel the frame covers, a row's span or the whole row, reading no
source pixel at all, which is how a program clears the shape it drew a
frame ago. The record and its pixels are read a byte at a time, so a sprite
may sit anywhere.

## .set SPRITE_SIDE_MAX

The PNG decoder's own limit (png.S), so the products of the sizes fit 64
bits; a record past it is no sprite the kernel handed out, and ending the
run keeps every size product inside 64 bits before the bounds see it.

## sys_sprite_draw

The span table sits after every frame's pixels. The source position runs
along with the drawn one as a 16.16 accumulator, a step a pixel; a flip
runs it backwards from the frame's far edge, since
(last + 1) * 65536 - 1 - n * step, shifted down, is last - (n * step
shifted down) for every n.

The unturned rows: s6 left, s2 the screen row, s1 the source row's
position, s11 the source row, s7 the first drawn column and s3 how many;
the pixels: s8 left, a2 the screen pixel, a3 the source column's position,
a1 the source pixel. A row's span, its first and last opaque columns,
mirrored for a flip, gives the drawn columns whose source columns fall
inside it, the first at or past the span's first and the end past its
last, clipped to what is on the screen. A solid row writes the tint over
every pixel of its stretch, no source read at all.

## sprite_turned

The scaled frame's centre in 16.16, the sine and cosine of the angle, the
half sizes and the size of the drawn rectangle, then how far the turned
corners reach from the centre, which gives its bounding box on the screen;
each pixel of the box is taken back through the inverse turn to where it
sits on the unturned frame, and sampled when that is inside it. The rows:
s7 the drawn row, s6 its end, s2 and s3 the columns; s0 and s1 the centre;
s11 the row's offset from the centre, 16.16.

## sprite_blend

A white pixel under a tint is the tint, exactly what the multiplies would
give, and the recolour rule makes every pixel of such a sprite white, so
the multiplies are skipped for it.

## sprite_spans

Two 16-bit columns per row of every frame, the first and the last with any
alpha, the first past the last for a row with none. What png.S calls once a
decode is done. Its t registers live across sound_tick, which keeps every
register.

## sprite_trig

From the quarter-wave table, by quadrant.
