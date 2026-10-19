# tiles/handoff

The handoff's statistics (`nu bin/nuance/tiles.nu handoff <spec> <index>
<out>`): captures of a wall seen head-on compared pixel by pixel over its rows
and columns on the screen, each pixel's greatest channel difference, the pixels
whose texel's light is clamped at the last node apart, and under partial
residency each pixel's difference from the nearer of the tiled and the lit
pictures. Its row and run helpers serve tiles/steps.

## row-of

A capture's pixels from x0 to x1 of row y, three bytes each.

## apart

The most any channel differs, of 255, between each two pixels of two
runs of pixels, three bytes each: the runs as integers at once and the
arithmetic in one closure, a command called a pixel costing several
times its work.

## apart-ints

apart over two lists of pixels as integers, red in the low byte.

## apart3

Each pixel of a run of `a` against the same of `b` and of `t`, three
bytes a pixel, as one code: its difference from `b` (apart's) in bits 0
to 7, its difference from the nearer of `t` and `b` in bits 8 to 15, and
in bits 16 and up 1 where it lies nearer `t`, 2 where nearer `b`, 0
where they tie or `t` and `b` are one colour there.

## total

The sum of a list of counts, 0 for none.

## spread-of

A histogram's statistics, each difference with its pixels: the pixels,
those differing, and the most, the 99th, and the mean of the
differences.

## merged

Histograms merged, each difference with its pixels.

## lines-of

The class of each pixel line from `from` to `to`, a column or a row of
a wall seen head-on, whose texel coordinate of level 0 from the map's
first node is `line.0 + line.1 i` at its centre: 1 where the texel of
`level` holding it is centred past the node `last`, the light clamped
there, 2 within a texel of level 0 of the first such texel's start,
left out, and 0 before.

## runs-of

The runs of equal values in a list whose first is at `base`: each run's
first index, the index past its last, and its value.

## cut-run

A run with the pixels from c0 to c1 taken out of it, none, one, or two
runs.

## segment

A run of a row compared: its class, the histogram of its pixels'
differences between `a` and `b`; and with `t`, a third capture, the
histogram of each pixel's difference from the nearer of `t` and `b`,
and its pixels nearer `t` and nearer `b` where those two differ.

## main

The handoff's differences, the spec a NUON file: the `rect` compared,
[x0, y0, x1, y1] with the pixel past the last, the wall's own rows and
columns on the screen; the `crosshair`'s half side, its square left
out; the `stamp`'s cells, [x0, y0, x1, y1] as `rect`, left out; the
map's `k`, `w`, and `h`; the texel coordinate of level 0 from
the map's first node at the centre of pixel column x, `u.0 + u.1 x`,
and of row y, `v.0 + v.1 y`, the wall head-on; and `pairs`, each a
`name`, `lighting`, `kind`, and `level`, a capture `a` held to a
capture `b`, and for partial residency a third, `t`, else empty; a pair
with `whole` set reads its own `rect` with no texel map, every pixel
of it inner, for a pose the wall's lines do not describe. The
pair at `index`, its statistics saved to out as NUON with its own
fields: the statistics of each pixel's greatest channel difference
(spread-of) over the pixels whose texel lies wholly before the last
node, `inner`, and over those whose texel is centred past it,
`clamped`; the pixels left out, within a texel of level 0 of the
boundary between those two, under the crosshair, or under the stamp;
and with `t`, the
statistics of each pixel's difference from the nearer of `t` and `b`,
`residual`, and the rows taking pixels nearer each, `mixed_rows`. A pair
a nu, the caller running them side by side: par-each within one nu
under the system's build ran this work three times slower than each,
all its threads busy.
