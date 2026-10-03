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

## thin

Its rows: one with nothing, a run, two apart with a clear pixel that carries
a colour between them, and one at the far edge.
