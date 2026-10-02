# tile.S

The lit loop's cost over the unlit loop's is its three channel
multiplies and the unpacking around them, about twenty ops a pixel, and
its sampling of the lumel map once an interval; a tile pays them once.
The tile is one lumel cell at the texture's resolution, 2^k texels
square, because the brightness across a cell is one bilinear patch of
the map's four nodes, so a tile is exactly what the lit loop would store
for that cell if every texel of it were drawn at one texel a pixel, and
because a cell is the grain at which a surface comes into view a piece
at a time; a per-surface cache at texel resolution is the same memory
laid out as an atlas, which is what this is.

The prize is bounded and measured: on a build with no binds the gauge's
seven views read 0 to 4.5 ms a view less when the lit loop's multiplies
and its sampling were both cut in one build, the lighting being under a
fifth of the lit frame, the rest the rasterizer's. Every cut of the
cache is read against that ceiling, and seven cuts have been.

The cuts before this one, each measured on the gauge against a build
with no binds in the same batch: a whole-surface build read for every
block, the settled planes phase near twice the lit loop's; a hybrid
reading near blocks only, judged after the lighting setup, 8 to 13 ms
worse on plane views; the block judged before the lighting setup with
every cell of its box covered, level on walls and 5 to 10 worse on
planes; planes in four-by-four blocks, no better; levels chosen from
both gradients, the garage from 10 ms worse to 6; the level's atlas as
one image with a six-op address, 65 and 78 ms, since a plane's
consecutive rows then sit an image row apart, kilobytes and a page
each; and the measurement that decided this cut, the frame after a
reset with nothing tiled costing 3 to 6 ms a view over no binds, the
per-block judgement and marking alone.

## tiles_reset

The arena is a bump allocator with one policy, a reset of the whole when
an atlas does not fit: every record forgotten, the next frames
rebuilding what they see. No eviction, since a tile's cost is its build
and the arena, 1 GiB of a nearly 4 GiB window, holds most of the
factory's level 0 (1,011 MiB at 64-texel cells before the columns'
padding); the program's bss costs nothing until touched, RAM being zero
at QEMU's start and the kernel zeroing only its own. The frame line
counts the resets since the load; the gauge's views read none.

## tiles_bind

A surface is built whole, a level at a time from the finest, the cells
in index order under the frame's budget, and the polygon takes the tiled
flag once level 0 is whole, with the count of levels whole for the span
to hold its levels under. No cell is ever checked by a span: the second
to sixth cuts tracked built and wanted cells in bit maps and judged
every block's or every span's cells, and that judgement cost 3 to 6 ms
a view, more than the lighting's whole, where the whole-surface build
costs a big floor some hundreds of frames on the lit loop at first
sight and nothing after. The budget is in the texture's texels read: a
level 0 cell its square, a coarser cell four reads a texel of its own,
and a cell the budget cannot hold whole waits for the next frame.

The cursor steps over the padding columns. The atlas keeps them so a
cell row is a shift, and the seventh cut walked the cursor through them
and built them, tile_build addressing the lumel map with the padded
column, so the nodes it read were the next row's, or past the map's end
on the last row, inside the zeroed lumel arena; the span never read one
back, since its prologue rejects an end in a padding column, so the
cost was the budget alone. The factory's 64,726 cells pad to 88,568, 27
percent over the map, and the bay view's L frame, which builds every
surface in view whole under no budget, built 73,888 cells before the
skip and 53,704 after, with the tiled pixel count unchanged at
2,423,311. The skip is two loads and a mask at the cursor's step, off
the pixel path.

## tiles_alloc

The cells across and down are the map's nodes, not the nodes less one:
the last cell's far nodes read the greatest, as lumel_sample clamps, so a
texel coordinate up to the lumel past the surface's end, which the span
can reach by a block's interpolation at a grazing edge, has a cell of
its own. The columns are padded to a power of two so a cell row is a
shift, the padding reserved and never built; the rows are the map's,
since a span reads tiles only when its ends lie inside the map. The
levels are TILE_LEVEL_COUNT or k + 1, the fewer, each atlas a quarter
of the one before, reserved together on first sight. An atlas past
TILE_ATLAS_MAX marks the surface never, the lit loop for good.

## The levels

A tile is built at one of the levels, each half a side of the one
before. The block picks its level from its texel step a pixel, the
largest of the step along the span and the step down a row on each
axis, so a block reads about a texel a pixel from its level and the
spans a row apart read the same lines: the fourth cut judged nearness
along the span alone, and a receding floor whose rows sat four texels
apart along the screen's rows still read level 0, so the spans a row
apart shared no cache lines and every pixel fetched one, Astra's point.
The step down a row is measured at the span's two ends, a divide each,
and interpolated along it, so a block's level costs about twenty-five
ops, and the only bound on it is the levels the surface has whole. The
seventh cut bounded it further by two levels taken at the span's ends,
each the larger of the row step there and the step along the span, the
end's coordinate less the start's over the pixels, an average over the
whole span; where the row steps at both ends sat under that average,
the common case on a wall receding into the distance, the two bounds
met at the average's level and every block of the span took it, near
blocks blurred and far blocks read a finer level than their step and
missed the cache for it, Astra's finding on the seventh cut. The bounds
added nothing a correct level needs and cost two divides a span. A
level 1 tile and up is built from the level below by averaging two by
two at four reads a texel, the colour weighted by alpha and the alpha
scaled for its coverage (tile_shrink); the fifth cut box-filtered the
texture at every level from the full square, which read every source
texel for every level.

## tile_build

A row's brightness is the two side nodes weighted by the row's fraction,
the lanes whole as in lumel_sample, and steps along the row by each
lane's change over the cell's texels, divided toward zero so no lane runs
past its end into a negative value, which would borrow from the lane
above; a shift would floor a negative change and overshoot. The texel is
scaled as the lit loop scales one, the same two shifts a channel, so the
tile holds the same bytes the loop would have stored, the brightness at
the texel's own position rather than the block's step. Page-aligned and
under a page, since its inner loop runs a texel, which the test holds.

## tile_shrink

The level below's tile of the same cell is four times the texels, so
each coarser texel is the mean of a two-by-two square under it. The
finer tile is TILE_BASE a level back in the record, the level fields
eight bytes apart.

The seventh cut averaged the colour channels plainly and kept the
upper-left texel's alpha, so a square with one opaque texel was either
an opaque dark texel or nothing by which corner the opaque one sat in,
and the fence and the grate changed density and darkened with distance
by sampling phase, Astra's finding. Now the colour is weighted by the
four alphas, so a transparent texel's colour, black in the content's
PNGs, counts for nothing, and the alpha is the mean of the four, scaled
by the material's factor for the level (alphas_measure) and capped at
255. The weighting divides once a texel by one reciprocal of the alpha
sum in 8.24, three multiplies in place of three divides, the error
under a sixtieth of a level; the four texels are loaded unsigned, since
a sign-extended word's top byte is not its alpha. The alike case, four
equal alphas, which is every texel of an opaque texture and most of a
masked one, takes the plain mean and the alpha as it is, with no divide,
so an opaque texture's shrink costs what it did.

The scale lands a mean at or above the chosen threshold T at or above
the pass and nothing under T there, which an 8.8 scale, ceil(32768 / T),
fails above T 194 (brute force over every T and alpha: T 195 with alpha
194 passes, and twenty more pairs up to T 254); ceil(2^23 / T) in 16.16
holds for every T to 2896, so every T. The masked loops then test the
word's top bit, the alpha at or above 128, in place of any nonzero
alpha, the same op count.

## alphas_measure

The coverage policy is coverage-preserving alpha scaling, the technique
of NVIDIA Texture Tools, a best effort and not a guarantee, from outside
the engine archive, where Quake 3 and Doom 3 BFG average alpha like a
colour and Doom 3 BFG blurs alpha-tested textures with a level bias
instead. Averaging alpha and testing against a fixed pass does not
preserve coverage: a checkerboard of two opaque and two transparent
texels averages to 127 and vanishes at the next level under a pass of
128, or fills under rounding up. So the texture's share at or above the
pass is the target, and each coarser level's threshold is searched for
the share nearest it. The coverage is measured with the engine's own
rule, the loops' point sample against the pass, not NVIDIA's bilinear
subsamples.

The chain is the tile build's exactly: the means are integer means of
the level before, and the level before is the scaled plane, as the tile
of level L is shrunk from the stored tile of level L - 1, whose alphas
are already scaled; so the analysis runs the same arithmetic over the
whole texture once, and the cells, aligned to the texture by the map's
origin, meet the same values. The search walks T from 256, which passes
nothing, down to 1, the count at or above T accumulating from the
histogram, and compares the share against the target as cov times the
texture's texels against the target count times the level's, exact in
integers; the least error wins, an equal error at a greater share loses
to the lower one already held, the transparent side, since the walk
meets the lower share first, and an equal error at the same share, the
plateau of thresholds between two alpha values, goes to the T nearest
the pass, so a texture whose levels pass as the texture does keeps a
scale of one rather than the plateau's end, where an opaque texture
would have had its alpha scaled to 128 for nothing. A texture full or
empty at level 0 is left at one without the levels, since a mean of
values at or above the pass stays at or above it and a mean of values
under it stays under.

Measured on the factory: the fence's share by level 7.33, 6.06, 9.47,
and 9.22 percent, with scales 1.008, 1.455, and 1.103, where the plain
average fell to 5.7, 4.0, and 1.9; the hazard sign 44.8, 44.7, 44.7,
46.1; the other signs within a quarter of a percent of full, with
scales near one; the proof map's grate 60.9 at every level but the
coarsest, which reads 50.0 at a scale of one, the step above it
further from the target. The lines equal, to the digit, a reading of
the same rule in python over the PNG files for the fence, the grate,
the hazard sign, and the proof's sign, and the test holds the engine's
lines for four textures of its own equal to a nushell reading. The share moves in jumps where many means share one
value, the 127 of a half-covered square among them, so the nearest
reachable share can sit two points from the target, as the fence's
coarser levels do. The far fence in the yard view keeps its mesh where
the seventh cut thinned it.

The two scratch planes bound a level at a quarter of a megabyte, a
1024-texel-square texture's level 1; a texture past that or under eight
a side keeps one. The analysis runs once at load over the map's
materials, the engine's images never tiling.

## lumels_bright

The console's L frame with its byte 4 set rewrites every lumel at one on
each lane, in a lumel's 256ths, which lumel_pack packs from a 16.16
brightness word by a shift of eight; a first version wrote 1 << 16 and
drew black. The test's bright capture then samples the texture as the
lit one does, tile for tile, so the lit over the bright is the light
alone; a dark copy on the unlit loop point-samples where a tile at a
level averages, and read 8 of 256 of view dependence that was the
texture's.

## What the data costs

With the hit path's work under what it saves, measured by pinning every
tile read to one cache-hot tile (the garage 19.9 ms against 20 to 21
with no binds), the garage's remaining 7 ms is the tile data: a floor's
spans at yaw 0 walk across the tile rows and read sixteen lines a
block, the spans a row apart reading the same lines, so the lines come
from the second-level cache, about 4 ns each, where the 64 KiB
texture's come from the first; a frame's tiles at the right level are
the screen's pixels, 8 MB, whatever the layout. Four-by-four blocks or
Morton order would cut a block's lines to four on any walk, about a
quarter of the loss and about what the hit saves, the floor views being
where the next cuts work; a wall's spans walk along the rows and read
level to a millisecond better.
