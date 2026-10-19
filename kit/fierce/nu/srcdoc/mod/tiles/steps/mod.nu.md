# tiles/steps

The lit loop's continuity (`nu bin/nuance/tiles.nu lit-steps <capture> <rect>
<crosshair> <out>`): the most a held-off picture of a white wall steps between
two pixels side by side along its rows.

## main

The lit loop's picture held continuous along its rows: over every row
of `rect`, [x0, y0, x1, y1] with the pixel past the last, the
crosshair's square of half side `crosshair` left out, the most any
channel of two pixels side by side differs, with its row and the left
pixel's column, and the rows read, saved to out as NUON. A lit span
steps its brightness a pixel at a time and starts each interval from
the one before's exact end sample, so on a white wall its steps are the
light's change over a pixel and the rounding, where an interval
starting from the light a block before steps by the light's change over
a block.
