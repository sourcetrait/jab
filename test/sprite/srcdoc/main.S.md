# main.S

sprite: the draw call. Two sprites written straight into the program
as native pixels, no PNG at all, drawn onto a painted background in
every way jab.sys.sprite.draw can: plain, hanging off the top left and the
bottom right corners, tinted, at twice and at half its size, a frame
of a two-frame sprite, mirrored each way and both, turned a quarter,
an eighth, and a twelfth, a spanned sprite six ways, solid draws
four ways, and the refusals, a frame past the sprite and a scale
past the most; each call's code goes to the UART as `draw <code>`.
Then one flip, and idle for the test to take the screen.

## .set BACKGROUND

`u32`: the painted background's colour.

## .set TINT

`u32`: the tinted draw's colour.

## _start

The background is painted two pixels a store. The draws, in order, each
reported: plain, whole, over the background; hanging off the top left, two
columns and a row lost; hanging off the bottom right, two columns and a row
kept; tinted, the tint in a register; twice the size, plain; half the size,
which keeps every other source pixel; the second frame of the sheet;
mirrored left to right; mirrored top to bottom; both, at twice the size; a
quarter turn at four times; an eighth turn at four times; mirrored and
turned a twelfth, at three times.

Then the spanned sprite, whose table says where each row's pixels are:
plain, mirrored, at three times, at half, mirrored at three times, and
turned an eighth at four times.

Then solid: the spanned sprite's rows filled between their spans, plain and
mirrored at three times; the unspanned one's whole box; and the spanned one
turned an eighth at four times.

Then the refusals: a frame the sheet does not have, and a scale past the
most. Last, a draw wholly off the screen: nothing drawn, and no complaint.

## blend

`16 u32`: one frame of 4 by 3, every kind of alpha, no flags, so it is drawn whole.

## sheet

`12 u32`: two frames of 2 by 2, one after the other.

## thin

`32 u32`: one frame of 6 by 4, mostly clear, its span table of 16-bit columns last.

Its rows: one with nothing, a run, two apart with a clear pixel that carries
a colour between them, and one at the far edge.

## msg_no_display

`20 u8`: the line for a machine with no display.

## line

`16 u8`: the report line.
