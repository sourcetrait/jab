# hud.S

What the player sees over the world: the crosshair, and on a debug build
the frame's stamp.

The crosshair is a semi-translucent white dot: each pixel under it halved and
added to half of white, srli 1, and 0x7f7f7f, add 0x808080, so the aim's mark
reads over anything; the player's G-1 is unseen. The pixel loop is aligned to
64 bytes inside the function. An OWNER build does not draw it, so the
capture carries surface indices alone (main.S).

The stamp ties a screen to the frame it shows: while the console's M frame
has its byte 5 set (console.S), a debug build draws the frame's number, as
its records carry it, over the world's top-left before the crosshair, its
low STAMP_BITS bits a cell of STAMP_CELL pixels square each, the n-th cell
from the left the n-th bit, STAMP_WHITE for a one and black for a zero. The
test's `stamp-of` reads it back from a capture, and the handoff's runs hold
the frame it names inside their records' window. It is the handoff's own
knob, so no other fixture's picture changes, and a release build carries
none of it.

## .set CROSSHAIR_RADIUS

`u32`: the disc's radius in pixels.

## .set CROSSHAIR_X

`u32`: the disc's centre column.

## .set CROSSHAIR_Y

`u32`: the disc's centre row.

## .set STAMP_BITS

`u32`: the stamp's cells, the frame number's low bits it carries.

## .set STAMP_CELL

`u32`: a cell's side in pixels.

## .set STAMP_WHITE

`u32`: a one's colour, white; a zero's is black.

## hud_draw

The stamp first, on a debug build with hud_stamp set: each bit of a0 drawn
as its cell, row by row. Then the crosshair, a row's half width the greatest
w with w * w within the radius's square less the row's.

## hud_stamp

`u8`: the M frame's byte 5, the frame's number stamped while it is nonzero;
a debug build's alone.
