# tile.S

The lit texture cached a surface at a time, in levels: a surface's atlas a
level, a tile one lumel cell at the texture's resolution at level 0 and half a
side each level after, each level 0 texel the texture's times the lumel
brightness bilinear across the cell and each coarser texel the average of
four below it; a surface is built whole, a level at a time from the finest,
under a budget a frame, and a lit span reads the levels built whole in place
of the texture and the map; the arena reset whole when an atlas does not fit.

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

### The levels

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

### What the data costs

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

## tiles_init

The tile pool's load, once, after the lumel maps are baked and the chains
built: a directory for every surface with a lumel map and a texture, a grid
for each level of its material's chain, sized from the map's extent, W << k by
H << k texels of level 0, a tile at level m covering TILE_SIDE << m of them a
side, the census's sizing at one side, so the entries equal the census
directory line's at 32. A surface whose grid passes sixteen bits a side or
whose grids would pass TILE_DIRECTORY_ENTRIES stays uncached, counted, and
the next surface is tried. Every slot starts free, slot 0 on top of the free
stack, the effective slots all of them, no tile in construction; each
context gets its admission block and its touched-slot bitmap.

TILE_MEMORY is every table of the pool and the pool itself, tile_tables_end
less tile_pool, read once here; the memory in use counts the tables with the
directory at this map's entries, and later the slots in use. A debug build
prints both with the side, the slots, the directory's entries, and the maps
held and left uncached:

    fps: tile pool: side 32, slots 8192 of 4096 bytes, directory 384445 entries over 228 maps and 0 uncached, memory 5703860 of 41914816 bytes

The material's masks, row shift, and chain come through material_bind, the
producer's polygon its scratch at load as lumaps_bake's is.

## tile_context

The raster context of index 0 is hart 0's, raster_context, and index n the
worker n - 1's in worker_contexts, CTX_SHIFT apart.

## tiles_reset

The arena is a bump allocator with one policy, a reset of the whole when
an atlas does not fit: every record forgotten, the next frames
rebuilding what they see. No eviction, since a tile's cost is its build
and the arena, 1 GiB of a nearly 4 GiB window, holds most of Render
Zero's level 0 (1,011 MiB at 64-texel cells before the columns'
padding); the program's bss costs nothing until touched, RAM being zero
at QEMU's start and the kernel zeroing only its own. The frame line
counts the resets since the load; the gauge's views read none.

A reset advances the arena's generation, and a binding holds the
generation it was made in (POLY_TILE_GENERATION), so a command of the
frame's packet bound before a reset in the same frame is known stale when
the packet renders (raster.S's packet_resolve) and takes the chain at its
own level, never an atlas a later surface may have rebuilt over its own.
Nothing resets while a packet renders: construction and reservation are
preparation's.

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
cost was the budget alone. Render Zero's 64,726 cells pad to 88,568, 27
percent over the map, and the bay view's L frame, which builds every
surface in view whole under no budget, built 73,888 cells before the
skip and 53,704 after, with the tiled pixel count unchanged at
2,423,311. The skip is two loads and a mask at the cursor's step, off
the pixel path.

The record sits at the map's index. Cells are built at the level in hand
while the budget holds; a level whole moves the hand to the next. A column
at the map's width is padding: the cursor moves on to the next row's first
cell, so no padding tile is built.

The tiles' time is read around the reservation, with any reset it makes,
and around each cell built or shrunk, so a polygon whose surface is whole
reads no clock.

On a debug build the console's L frame caps the levels a surface builds
(its byte 6, tile_level_cap), so a fixture can hold a surface at level 0
alone while its blocks ask level 1, and read that they take the chain at
level 1 rather than a sharper tile; a release build carries none of it.

On a debug build the console's K frame resets the arena after the frame's
first binds, every frame (tile_reset_after, counted in tile_binds), the
arena in use poisoned first: the stale binding's fixture, whose commands
bound before the reset must draw the chain and never the poison. The
forced reset counts with the arena's own.

The binding takes the arena's generation with the tiled flag, so the
command copied from the polygon carries it.

## tiles_poison

TILE_POISON is written two a word over the arena up to its cursor, so a
stale read through an atlas the forced reset took back draws the poison
where the tiled and the lit pictures hold the surface's own colours; the
fixture counts such pixels.

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

The atlases' bytes are summed over the levels, each a quarter of the last.
With the arena full it is emptied, every surface forgotten, and this one
reserved at its start, counted for the frame line; each level's atlas comes
from the arena's cursor. tile_peak takes the cursor after each reservation,
so it holds the most the arena has held since the load; a reset lowers the
cursor and leaves the peak.

## tile_build

Each texel is lit at its centre. A row's brightness is the two side nodes
weighted by the fraction at the row's centre, (2 row + 1) 128 over the
cell's texels in 256ths, truncated as lumel_sample truncates its fraction,
the lanes whole as in lumel_sample; it steps along the row by each lane's
change over the cell's texels, and starts half a step in, each lane's
change over twice the texels, both divided toward zero so no lane runs past
its end into a negative value, which would borrow from the lane above; a
shift would floor a negative change and overshoot. The texel is scaled as
the lit loop scales one, the same two shifts a channel, so under one
brightness the tile holds the bytes the loop would store. The lit loop
lights a pixel's own coordinate, the half pixel in it, which lies within
half a texel of its texel's centre, and where the two points meet they
differ by their rounding alone: the bilinear read's eight-bit fraction and
the interval's stepped lanes against the row's stepped lanes here. A tile
lights its texel once for every pixel that reads it, where the loop's
light moves across the texel; at a coarser level the tile averages lit
texels where the loop lights an averaged one. Under the full-bright frame
every node is one and the two agree exactly, which the alpha fixture
holds; under real light the test reports how far they part. The build lit
each texel at the cell's corner before, half a texel off the loop's point
across every surface. Page-aligned and under a page, since its inner loop
runs a texel, which the test holds.

The four nodes are read first, the far ones the greatest at the map's end;
the tile is found by its index, with the cell's first texel; then each row's
brightness at its start and end, the nodes weighted by the fraction at the
row's centre in 256ths, the lanes whole, its step a texel and half a step
in, and the texture's row.

## tile_shrink

The level below's tile of the same cell is four times the texels, so
each coarser texel is the mean of a two-by-two square under it. The
finer tile is TILE_BASE a level back in the record, the level fields
eight bytes apart. The texel's rule is texel_shrink (mip.S), one macro
the tile and the texture's chain both expand, so the two cannot drift: a
tile at a level and the chain's level agree under one brightness, which
the alpha fixture holds identical over the opening at every level.

The seventh cut averaged the colour channels plainly and kept the
upper-left texel's alpha, so a square with one opaque texel was either
an opaque dark texel or nothing by which corner the opaque one sat in,
and the fence and the grate changed density and darkened with distance
by sampling phase, Astra's finding. Now the colour is weighted by the
four alphas, so a transparent texel's colour, black in the content's
PNGs, counts for nothing, and the alpha is the mean of the four, scaled
by the material's factor for the level (alphas_measure) and capped at
255. The weighting divides once a texel by one reciprocal of the alpha
sum in 8.24, three multiplies in place of three divides, each product
rounded to the nearest before its shift: the reciprocal's truncation
puts a product under the true mean by at most a sixtieth of a level,
so with the half added an exact mean, a constant colour under any
alphas among them, comes back exact, where a plain shift returned 254
for one opaque white texel among three transparent ones (Astra's
review), and a half-way case may fall by one. The four texels are
loaded unsigned, since a sign-extended word's top byte is not its
alpha. The alike case, four
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

The scale is the level's of the material bound.

## alphas_measure

Level 0's share of texels at or above the pass is the target; each coarser
level's alphas are the means of the level before, as tile_shrink makes them,
and the threshold T whose share at or above it lies nearest the target
becomes the level's scale, ceil(2^23 / T), so the scaled means pass exactly
where the raw ones reach T. The least error wins, a tie goes to the lower
share, and among equal shares to the T nearest the pass, so a texture whose
levels pass as the texture does keeps one. A texture full or empty at the
pass stays so at every level and keeps one, as does one whose chain has no
level past 0 or whose level 1 is past the scratch planes.

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

Measured on Render Zero: the fence's share by level 7.33, 6.06, 9.47,
and 9.22 percent, with scales 1.008, 1.455, and 1.103, where the plain
average fell to 5.7, 4.0, and 1.9; the hazard sign 44.8, 44.7, 44.7,
46.1; the other signs within a quarter of a percent of full, with
scales near one; Render One's grate 60.9 at every level but the
coarsest, which reads 50.0 at a scale of one, the step above it
further from the target. The lines equal, to the digit, a reading of
the same rule in python over the PNG files for the fence, the grate,
the hazard sign, and Render One's sign, and the test holds the engine's
lines for four textures of its own equal to a nushell reading. The share
moves in jumps where many means share one value, the 127 of a
half-covered square among them, so the nearest reachable share can sit
two points from the target, as the fence's coarser levels do. The far
fence in the yard view keeps its mesh where the seventh cut thinned it.

The two scratch planes bound a level at a quarter of a megabyte, a
1024-texel-square texture's level 1; a texture past that keeps one, as
does a chain with no level past 0. A texture under eight a side was left at
one before, which a 4 by 4 of three alphas at the pass and one a step under
in every 2 by 2 showed wrong: its level 1 means read 127 and vanish under
the pass unless the search lifts them, as it does, to 128. The analysis
runs once at load over every record, the map's materials and the engine's
images, after the images load, for the chain's levels of each
(mip_levels): the sprites' chains need the policy at their silhouettes as
the fence does, where before the images never tiled and were left out. The
line prints every level of the chain, the coverage of each and the scale
of each past 0, which the test's oracle holds to the digit; an image's line
names it by its frame.

Every scale starts at one. Level 0 counts its texels at or above the pass;
the levels' source is the texture's alphas, four bytes apart, then the plane
just made, a byte apart; each level's scale, ceil(2^23 / T), is stored with
its share, and the plane is scaled in place and capped as the next level's
source. The line carries the material's name, or the engine's image by its
frame, the shares by level, and the scales.

## lumels_bright

The console's L frame with its byte 4 set rewrites every lumel at one on
each lane, in a lumel's 256ths, which lumel_pack packs from a 16.16
brightness word by a shift of eight; a first version wrote 1 << 16 and
drew black. The test's bright capture then samples the texture as the
lit one does, tile for tile, so the lit over the bright is the light
alone; a dark copy on the unlit loop point-samples where a tile at a
level averages, and read 8 of 256 of view dependence that was the
texture's.

## lumels_parity

The console's L frame with its byte 7 set, on a debug build alone,
rewrites every lumel by its node's parity in its map, a quarter on each
lane where the column and the row sum even and one where they sum odd.
Every cell then holds a checkerboard of light, steepest beside its
corners and flat at its centre, a gradient the test computes for itself:
a tile's texel beside a node lit at the texel's centre reads apart from
one lit at its corner by more than the build's rounding, where the
room's light changes too little across a texel to tell the two.

## msg_alpha

`12 u8`.

## word_frame_name

`7 u8`.

## word_coverage

`12 u8`.

## word_of_share

`18 u8`.

## word_of_scale

`10 u8`.

## msg_tile_pool

`22 u8`.

## word_tile_slots

`9 u8`.

## word_tile_of

`5 u8`.

## word_tile_directory

`19 u8`.

## word_tile_entries_over

`15 u8`.

## word_tile_maps_and

`11 u8`.

## word_tile_uncached

`19 u8`.

## word_tile_bytes

`7 u8`.

## tile_cursor

`addr`: the arena's next free byte.

## tile_budget

`u64`: the frame's budget left, in texels.

## tile_budget_frame

`u64`: the budget a frame starts with, TILE_BUDGET until the console lifts it.

## tile_peak

`u64`: the most the arena has held since the load, in bytes.

## tile_generation

`u64`: the arena's generation, advanced by every reset.

## tile_entries

`u64`: the directory's entries in use, every surface's grids.

## tile_maps

`u64`: the surfaces with a directory.

## tile_uncached

`u64`: the mapped surfaces with a texture whose grids did not fit, left to the lit loop.

## tile_free_count

`u64`: the free stack's slots.

## tile_effective

`u64`: the slots the pool may use, TILE_SLOTS unless a debug cap holds fewer.

## tile_building

`i64`: the slot whose tile is in construction, -1 for none.

## tile_memory

`u64`: TILE_MEMORY, the pool's tables and the pool, in bytes.

## tile_fixed

`u64`: the tables' bytes in use, the directory at this map's entries.

## tile_memory_peak

`u64`: the most the pool's memory has held in use since the load.

## tile_level_cap

`u64`: on a debug build alone, the levels a surface builds, the console's L frame's byte 6, 0 for every level.

## tile_binds

`u64`: on a debug build alone, the frame's binds so far, for the console's forced reset.

## tile_reset_after

`u32`: on a debug build alone, the binds each frame before the forced reset, the console's K frame's, 0 for none.

## tilemaps

`LUMAP_COUNT*11 u64`: every surface's tiles at the map's index, TILE_* fields; eight-aligned past the debug build's four-byte tile_reset_after, as the tables after it need.

## material_alpha

`MAX_MATERIALS*MIP_LEVELS u32`: each material's alpha scale a level, 16.16.

## alpha_hist

`256 u64`: the search's counts of each alpha value.

## alpha_cover

`MIP_LEVELS u64`: the shares by level, for the line.

## alpha_chain_levels

`u64`: the chain's levels of the material in hand, the scales to find.

## alpha_plane_a

`ALPHA_PLANE_BYTES u8`: one of the two planes a level's alphas alternate between.

## alpha_plane_b

`ALPHA_PLANE_BYTES u8`: the other plane.

## tile_pool

`TILE_POOL_BYTES u8`: the slots' tiles, TILE_BYTES each, page-aligned so a tile is a page at 32.

## tile_tags

`TILE_SLOTS u32`: each slot's tag, its generation in the high sixteen bits and its state, SLOT_*, in the low.

## tile_slots

`TILE_SLOTS*SLOT_SIZE u8`: each slot's record, SLOT_* fields.

## tile_free

`TILE_SLOTS u32`: the free stack, its count tile_free_count.

## tile_surfaces

`LUMAP_COUNT*TS_SIZE u8`: each surface's record at the lumel maps' index, TS_* fields.

## tile_directory

`TILE_DIRECTORY_ENTRIES u32`: the entries, 0 for no tile, else the slot plus one in bits 0 to 15 and the slot's generation at publication in bits 16 to 31.

## tile_merge_bits

`TILE_DIRECTORY_ENTRIES/8 u8`: the boundary's merge bitmap, a bit an entry.

## tile_merged

`TILE_MERGE u64`: the boundary's merged keys.

## tile_merge_heads

`LUMAP_COUNT u64`: each surface's merged keys at the boundary.

## tile_merge_order

`LUMAP_COUNT u32`: the surfaces merged, in the merge's order.

## tile_requesting

`LUMAP_COUNT/8 u8`: the boundary's union of the contexts' requesting surfaces, a bit a surface.

## tile_admission

`TILE_CONTEXTS*TA_SIZE u8`: each raster context's admission block, TA_* fields.

## tile_tables_end

The end of the pool's tables from `tile_pool`, TILE_MEMORY's bound.

## tile_arena

`TILE_ARENA_BYTES u8`: the atlases.
