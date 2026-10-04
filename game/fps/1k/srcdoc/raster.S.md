# raster.S

The polygon rasteriser: world points into the camera's basis, clipped and
projected into edges, the even-odd fill within a rectangle, the span record,
the integer span.

The pixel-centre rule everywhere, ceil(v - 0.5), so surfaces sharing an edge
meet without a crack. Walking by rows matters under TCG: a column walk
touches a new cache line of each 8 MB buffer per pixel and measured 180 ms
for a million pixels against 16 by rows.

## k_half_d

`f64`.

## k_one_d

`f64`.

## k_depth_scale_d

`f64`: 2^26, 1/z into 6.26.

## k_uv_scale_d

`f64`: 2^16, u/z and v/z into 48.16.

## k_hx_d

`f64`: the projection's centre column.

## k_hy_d

`f64`: the projection's centre row.

## k_hz_d

`f64`: the focal length in pixels.

## k_lane_bias

`u64`: a brightness word's three lanes each biased past zero for the interval step.

The bias and the masks step a brightness word's three lanes at once by 16,
32, or 64 pixels: the end less the start, each lane biased past zero, its low
4, 5, or 6 bits cleared by the shift's mask so none spill into the lane
below, the word shifted, and the bias's share taken back.

## k_lane_masks

`3 u64`: each lane's low 4, 5, or 6 bits cleared, for a step over 16, 32, or 64 pixels.

## k_near

`f32`: the near plane's depth.

## k_hx

`f32`: the projection's centre column.

## k_hy

`f32`: the projection's centre row.

## k_hz

`f32`: the focal length in pixels.

## k_half

`f32`.

## k_big

`f32`: a row past any edge's, an empty list's bound.

## poly_project

Into the camera's basis, down being the negative of up; clipped to the near
plane, a point in front kept and an edge that crosses adding its crossing;
projected, x = hx + right * hz / depth and y = hy + down * hz / depth; the
edges each from its higher end, a level one dropped.

## surface_setup

The surface's 1/z, u/z, and v/z are affine over the screen for any camera
basis: with n the plane's normal, q a point on it, p the eye, and dir the
pixel's ray right (x - hx) + down (y - hy) + forward hz, 1/z = n.dir /
(hz n.(q - p)), so A x + B y + C; u/z = (a.p + u0) / z + a.dir / hz with a the
world gradient of u in repeats and the texture's size folded in, and v the
same. surface_setup computes the nine coefficients in double once a polygon,
the half pixel folded into each C, and stores them as 64-bit integers, 1/z in
6.26 and u/z and v/z in 48.16. The plane is widened into plane_d first, since
the dot macros read doubles from memory; the normal is loaded from it into
ft8 to ft10, made unit by jab.f64.vec3.reg.norm there, and flipped to face
the camera by the sign of n.(q - p).

The plane goes into plane_d a float at a time; then n.right, n.down,
n.forward, and n.(q - p); the unit normal facing the camera, for the light;
1/z into the polygon, 6.26, the half pixel in C; then u/z, K = (a.p + u0) *
w, the coefficients K A + a.r / hz and on, and v/z the same, through
surface_axis.

## surface_axis

UA = K A + a.r / hz; UB = K B + a.d / hz; UC = K C + a.f - (a.r hx + a.d hy) /
hz, the half pixel added.

## lumap_bind

A lit polygon with a map has the map's texel origin folded into its u/z and
v/z coefficients once a polygon: u/z less U0/z on A, B, and C, which is U0
times the 6.26 1/z coefficient shifted down ten for the 48.16 u/z, and v the
same. The span's texel coordinates then count from the map's first node, so
the read is a shift; the origin is a multiple of the texture's size, so the
wrap by the mask is unchanged and the texel loop needs no change. U0 times
1/z stays under 2^46 across the factory. The read's one word packs the
lumels' offset into the arena in 24 bits, a row's bytes in 16 from bit 24,
the rows in 16 from bit 40, and k from bit 56, so the read can bound itself
from the word alone; the offset rather than the address because a window
on an 8 GB machine can sit past 2^32 and the rows need the bits.

## row_crossings

The span loop's family, row_crossings through span_record, shares one page
for the same reason as span_fill at a smaller scale: poly_fill's inner loop
runs once a span, sixteen thousand times a frame on the up flight, and calls
span_bound twice a span, so a page boundary inside the loop or between it
and its helpers costs a block lookup each way per span. The eighteen bytes of
the polygon serial's increment at poly_fill's entry moved the loop's head to
two bytes short of the boundary at 0x80a03000 and cost the up flight 1.2 ms
a frame, read on two batteries against the build before and confirmed by
an interleaved probe; the family on its own page returned the wall phase to
24.2 ms from 25.5, where poly_fill aligned alone, its helpers still across
the boundary, returned half of that. The family is 554 bytes from the
directive, so the page holds it with room; the test guards each member as
it guards span_fill and the five together on one page, since five members
each within a page of its own would pass the first guard with the calls
crossing again.

## poly_fill

The rows and every span are held within the rectangle in hand, the
sector's from the flow (world.S), before the span is recorded and drawn:
the row range against the rectangle's rows once a polygon, each span's
ends against its columns. A span clipped starts its blocks at a different
pixel from the whole span's, and its texel bytes can move by a rounding,
which is why a clipped frame is compared by the surface each pixel
belongs to rather than byte for byte. The portal test that sampled an
opening's spans every fourth row and second column against the depth
buffer is gone: a sampled test can miss an opening narrower than its
stride, so it could order sectors but never reject one, and the flow's
rectangles reject nothing either, the depth buffer resolving every pixel.

## span_record

The span record, sixteen bytes a span in a table of SPAN_RECORDS, is the
interface the tile pool and a sorted span renderer share: the pool will
read the frame's records to learn which cells its spans touch, and a
span sorter produces the same records from its own machinery. A record
carries the row and the span's two ends in sixteen bits each, the
polygon's mode, the surface index, and the polygon's serial in the
frame: the surface is the stable identity the owner build shares, and
the serial tells a masked opening's fill from its wall's solid pieces,
which carry the same surface, so a consumer that orders primitives has
each submission apart. The count runs past the table on a frame with
more spans, and the contract is that a reader of such a frame falls back
rather than reading the prefix as the frame, since the prefix is not the
frame; the gauge's views run to twenty thousand spans against the
table's sixty-five thousand.

## poly_rect

The pixel-centre rule, as the fill bounds a span and its rows, a pixel of
slack against the fill's rounding.

## .macro lumel_sample

The read, about 60 integer ops and five loads a sample, one of them the
packed word: the coordinates are held within the map first, a negative one
to 0 and one past the last column or row to the greatest coordinate under
it, both from the word's columns and rows; then the column and the row are
the texel coordinate shifted by k plus 16, the fractions the next eight
bits down, the address the arena plus the offset plus the row times the
row's bytes plus the column times eight, the lumel below one row's bytes
on; the four lumels about the coordinate are summed under weights from the
fractions in 256ths, the below-right one the product shifted, the other
three by subtraction so the four sum to 256 exactly, since four truncated
products summed to as little as 253 and darkened a fully lit lumel by a
visible percent; the products are summed on the packed lanes whole, 256
times 256 being 17 bits and a lane 21. The clamp is load-bearing: a
sample is taken at a block's or an interval's end, the pixel past its last,
which at a span's last block lies beyond the polygon's edge by up to one
pixel's texel step, several texels on a wall seen nearly edge-on; a first
form read with no clamp on the claim that a span's coordinate lies within
the surface by construction, and a coordinate before the map's first node
shifted logically became a huge column and a load outside the program.
Bilinear, since a lumel close up is hundreds of pixels wide and nearest
sampling would show every one as a step.

The coordinates are held within the map because a pixel past a span's edge
can lie before the first node or past the last, and a read past the map
would fault.

The read it replaced did 13 loads and eight multiplies a sample, nine of
the loads the map's record and its fields reloaded every block, and
converted the texel coordinate by a multiply, a shift, an offset, and a
clamp on each axis; this mirror had counted nine loads and claimed the read
more than paid for the evaluation it replaced, both written before the
gauge came back, and the gauge showed the read costing about what the
evaluation had on the views that enter the most pixels.

## .macro mip_bind

The lumel map has been sampled at level 0 before the bind; the block's end
reloads level 0's exact coordinates for the next.

## span_fill

span_fill holds no float: a float helper under TCG costs about 5 ns, and the
probe measured the float span at 12 to 14 ms a megapixel against 5.4 for the
integer one. 1/z, u/z, and v/z at the span's first pixel are a multiply and
an add each; blocks of 16 pixels, at whose end one divide gives z as 2^42
over 1/z, clamped to IZ_MIN for it, and two multiplies give u and v exact
there, the steps within by two divides; a pixel is a depth load and a skip
when the buffer's 1/z is at or past the surface's, else the texel at (v &
vmask) << wshift + (u & umask) << 2 and the pixel and the depth stored. The
lit modes unpack each channel of the stepped brightness to 8.8 by two shifts
and scale the texel's byte by it; a framebuffer pixel's bytes are blue, green,
red from the low end. The sky mode takes the texel by screen position, offset
by the camera's yaw and pitch at four repeats a turn, and stores SKY_DEPTH so
any surface overwrites it. A lit surface reads its lumel map at the lumel's
own cadence.

The depth test comes before the texel's address in every pixel loop, so a
rejected pixel costs the depth load, the compare, and the steps. It changes
no stored pixel: the seven gauge captures on the androidless factory are byte
for byte the same before and after. It saves little: the up flight's walls
phase moved from a minimum of 28.8 to 27.3 ms over five runs and the other
views within their noise, because a texel address is eight integer ops and a
load that mostly hits the host's cache, and because the rejected share was
smaller than the overdraw suggested, below.

The pixels the depth test rejects are counted on the pass path, one add per
pixel that passes, so a block's rejected count is its length less the passes
and the span's lands in the frame's stats; the frame line prints it. The
count sat on the reject path first, behind a label and a jump over it, and
that jump cost every stored pixel a translation-block hop under QEMU, about
a millisecond on the yard view, which is why it moved: a loop body that falls
through into its step is one block, and a branch target in the middle splits
it. The count is what separates overdraw into its two kinds, since pixels
entered less the screen counts both the rejected and the stored-then-
overwritten, and only the first kind is what an early depth test saves. On
the stairwell views the up flight enters 3.9 M pixels, rejects 1.2 M, and
overwrites 0.6 M; the down flight enters 3.3 M, rejects 0.59 M, and
overwrites 0.65 M. The overwritten share is the walk's order between sectors
(world.S).

span_fill counts every span it fills, the pixels it enters, the lit ones
beside, and the lumel samples it reads, into the frame's stats for the frame
line, which reads the overdraw as pixels entered against the screen's and
the cadence as samples against blocks; the light's microseconds on that
line are the sprites' evaluations alone.

span_fill is page-aligned and kept under a page: QEMU's translator ends a
block at a page boundary and chains blocks within a page only, so a loop
straddling one leaves the translated code every iteration, measured seven
times slower. The test holds the alignment through the SDK's `jab hot`.

### The prologue and the blocks

Lit spans are counted. u and v at the start are 16.16. Every span's
footprint, for its blocks' levels: the end's texel coordinates at one
divide, the step down a row at each end at a divide each, and the row step's
change a pixel, which ride the frame for the blocks; the texture's four
registers serve as scratch and are reloaded after. A tiled surface's span is
judged once for its tiles: its ends inside the map, else the lit loop, which
clamps; the levels the surface has whole bound every block's level. Lit: a
polygon with no map takes its one brightness over the whole span, no step
and no sample; a mapped one samples its map at the span's start, an interval
starting at the first block.

The block: its length, its end's u and v, the steps. The block's level by
its footprint: the largest of its texel steps along the span and down a row,
the row's interpolated along the span; level m where the step is under 2^(m
+ 1) texels, the chain's last at most, which the tiles and the loops each
hold under what they have. Lit: a span judged for its tiles (the prologue)
takes them block by block at the block's level held under the levels the
surface has whole; a block read from tiles pays no sample, no interval, and
no brightness carry. A span with no tiles takes the lit loop at the chain's
level. The texel step a pixel, the larger of |du| and |dv|, against the
lumel's 2^k texels: four blocks when they stay within half a lumel over 64
pixels, two when within it over 32, else one, so a lumel spans at least two
samples wherever one block allows it. The end's u and v: the block's own
when the interval is one block, else from one divide at the interval's
pixels on. A whole interval of one, two, or four blocks steps the lanes at
once by its shift: the end less the start, each lane biased past zero and
its low bits cleared under the shift's mask so nothing spills into the lane
below, shifted, the bias's share taken back; any other length, the span
cutting the interval short, divides each lane's change by it and packs the
quotients again.

Textured and lit: the depth first, then the texel, each channel scaled by
its brightness, the texel's bytes blue, green, red from the low end. Masked
and lit: the depth, the texel, its alpha at or above the pass. A lit block's
brightness is carried into the next block of its interval; where the
interval ended, the exact end sample is there. A block on its tiles at its
level: the depth first, then the texel read from the level's atlas, the cell
from the coordinate shifted by k, the texel within the cell at the level's
resolution; no multiply, no sample, no brightness. The constants ride the
texture's four registers, the brightness's two, and one spilled saved
register, all free here. Masked, on its tiles: the tile's texel, whose alpha
under the pass leaves the pixel. The tiled block's end: the pixels counted as
read from tiles, the spilled register back, the interval over and the
brightness entering the next block marked stale, so a lit block after
samples its own start. Textured: the depth test, then the texel and the
stores. Masked: the depth test, then the texel, whose alpha under the pass
leaves the pixel. The block's end is the next block's start; its rejected
pixels, the block's less those past the depth test, are kept.

Sky: the texel by screen position, the texture's width across the screen's
and its height down the same count of rows, offset by the sky's yaw and
pitch in repeats, 16.16; drawn where nothing has.

### The cadence

A lit span samples at its start, then at the ends of intervals of one,
two, or four blocks, the interval chosen at its start from the block just
computed: with step the larger of |du| and |dv| in 16.16 texels a pixel and
a lumel 2^k texels, four blocks when 64 pixels times the step stay within
half a lumel, two when 32 do, else one, so a lumel spans at least two
samples wherever the floor of one block allows it. The criterion is the
world's, not the screen's: a fixed pixel interval between samples bounds
nothing in the world, which the scheme before the bake showed. Far surfaces
sample every block, the floor; near surfaces, where the pixels are, every
two or four. The interval's end coordinates come from one divide at its
pixels on, or from the block's own end when the interval is one block, and
its pixels are capped at the span's remaining. The sample's brightness is
stepped across the interval's blocks and the exact end sample becomes the
next interval's start so nothing drifts. The decision is a shift and two
compares: the step shifted down by k plus 9 reads 0 for four blocks, 1 for
two, more for one.

The step over a whole interval of 16, 32, or 64 pixels is the lane trick
shifted by 4, 5, or 6: the end less the start, each lane biased past zero
by 2^20, each lane's low bits cleared under the shift's mask, one of three
constants, so the shift spills nothing into the lane below, the word
shifted, and the bias's share taken back; a lane at a time was near thirty
ops. An interval the span cuts short divides each lane's change by its
pixels, the three quotients packed again, which also fixes the short last
block: the read before stepped every block by a sixteenth whatever its
length, so an eight-pixel block got half its gradient.

The span's state across the pixel loops lives in two stack slots, the
interval's pixels left and the brightness, and the interval's length rides
the loop's count register until the loop needs it, since every register is
taken in the pixel loops: a first form kept the interval's length and shift
and a masked flag in slots too, and the no-read probe priced the read at
1.8 to 2.9 ms a view, nearly all of it that traffic rather than the
samples, since a build sampling every block cost the same as the cadence
within the gauge's noise. A lit block ends by carrying its brightness into
the slot only while its interval continues; where the interval ended the
slot already holds the exact end sample.

### The chain's level

Every span but the sky's computes its footprint in the prologue: the
end's texel coordinates at one divide, the step down a row at each end
at a divide each from the coordinates a row below by the polygon's
gradients, and the row step's change a pixel, four divides a span where
the tiled spans alone paid them before. Every block then takes its level
from its own step along the span and the row step interpolated along the
span, the step's octave, under two texels level 0, under four 1, under
eight 2, and so on to the chain's last, about twenty-five ops a block; a
tiled span holds it under the levels the surface has whole and reads the
tile, any other span holds it under the material's chain and reads the
texture's level through mip_bind: the level's texels from the table the
bind named, the masks and the row shift shifted by the level, and u, v,
and their steps a pixel shifted to the level's resolution, so the pixel
loops are unchanged and the block's end reloads level 0's exact
coordinates for the next. The bind comes after the lumel sample, which
reads level 0 coordinates, and before the loop. So a block reads about a
texel a pixel at any distance, a far floor stops touching a cache line a
pixel, and the lit loop and a tile at one level hold the same texel under
one brightness, which the alpha fixture holds identical over the opening
at levels 0, 1, and 2 and which TilePool's handoff between the loop and
the cache rests on. The unlit loops pay the prologue's divides and the
level for the same picture; the sky reads its texture at level 0 by
screen position, under a texel a pixel.

### The tiled modes

A tiled surface's span is judged once in the prologue, after every
span's footprint (the chain's level, above): its ends inside the map,
and the bound on every block's level, the levels the surface has whole;
a span whose ends lie past the map takes the lit loop at the chain's
level, which clamps. Nothing else is checked, since a
surface is built whole a level at a time (tile.S): the second to sixth
cuts checked cells, per block or per span, and the measured cost of
that judgement was 3 to 6 ms a view, more than the lighting's whole,
with the per-span box of a diagonal line quadratic at a coarse level. A
block then takes the footprint's level held under the levels whole,
and its level's atlas, shifts, and
mask ride the texture's four registers, the brightness's two, and one
spilled saved register, since a hit needs no brightness: the cell shift
k + 16 and the texel shift m + 16 from a 16.16 coordinate. The seventh
cut held the block's level between two levels taken at the span's ends
as well, each the larger of the row step there and the step along the
span averaged over the whole span, which cost two divides a span and
clamped every block of a receding wall to the average's level wherever
the row steps sat under it (tile.S); the stack slots those bounds rode,
32 and 224, are free.

A hit pays nothing of the lighting: no sample, no interval, no brightness
carry. The tile loop ends by marking the interval over and the brightness
entering the next block stale, a -1 in its slot, and a lit block that
finds the slot stale samples its own start before its interval; the span
start no longer samples at all, so a span whose first block is tiled pays
no sample, and one whose first block is lit samples there instead. The
second cut decided after the lighting setup and carried the brightness
across every tiled block, so a hit still paid the sample and the
interval; the ceiling probe priced that bookkeeping at 0.2 to 3.0 ms a
view and the multiplies at 1.0 to 2.8, the whole prize of a cache 1.6 to
5.4 ms a view.

The tiled pixel is the depth load and compare, the cell's row and
column from the texel coordinates shifted by k, the row shifted by the
atlas's column shift and the two added, shifted to the tile's bytes, the
texel within the tile by the cell mask on each axis, one load, and the
two stores; fourteen integer ops and one load against the lit loop's
twenty-eight and one, and the unlit loop's eight. The texture's four
binding registers serve the decision as scratch and the tile loop as
constants, reloaded by the lit setup, so a lit block costs five loads it
did not before; one saved register is spilled for the tile shift. Far
blocks keep the lit loop because their sixteen pixels step texels apart
in the texture, 64 KiB and cache-resident, where the same pixels' tiles
lie a tile apart in an atlas of megabytes and miss: the whole-surface
first cut read every block from tiles and measured the settled planes
phase near twice the lit loop's. The masked tiled loop is the same with
the alpha test, the tile keeping the texel's alpha. Every masked loop,
lit, unlit, and tiled, passes a texel whose alpha is at or above 128,
read as the loaded word's top bit, where before any nonzero alpha drew:
the coarser tile levels scale their alphas to hold the texture's share
at that pass (tile.S), and a pass taken at the texture's level too keeps
the levels consistent with it; an antialiased edge thins by up to half
a texel. A sign-extended load puts copies of that bit above it, which a
logical shift by 31 leaves nonzero either way.

A plane's tiles are in blocks of four by four texels (tile.S), and its
block takes the swizzled pair of loops by the mode's flag: the tile as
above, then the texel's block row by a shift of k plus four, its block
along the row by a shift of six, and its row and place in the block from
the low two bits of each coordinate; ten more ops a pixel and a second
spilled saved register for the block row's shift. The third cut, with
every tile row-major, read the walls gaining 2.5 to 4.7 ms and the planes
losing 5 to 10 in their phase on every view but the yard, whose floor at
yaw 90 walks along the rows; the lit setup's reload of the texture's
four registers is skipped for a polygon with no tiles, since every lit
block of every polygon took it before. The fourth cut, blocks for
planes, measured against a build with no binds in the same batch: walls
level to the microsecond, planes 8 to 12 ms worse, the blocks no better
than rows; and with every tile read pinned to one cache-hot tile, the
judgement and the address work kept, the frame reads level with no
binds on every view, so the hit path's own work costs exactly what the
hit saves, and the tile data costs the rest. The combined ceiling, the
multiplies and the sampling both cut on a no-bind build, measures the
lighting's whole at 0 to 4.5 ms a view.

The tile loop's end jumps forward to the block's end, 60f. The numeric
local labels are shared across every file the program includes into its
one assembly, so a backward reference first written at the second cut's
exit, 61f for a label above it, resolved without a word from the
assembler to the next 61 in the unit, inside sector_draw's wall loop in
world.S, and the span landed there with its own frame and registers: a
fault at sector_draw's wall read through a garbage chain of saved
registers, deterministic at 1.2 s, that three probes placed in this block
before the disassembly of the jump named the target. A numeric label
referenced across a function's end is the suspect whenever a block's
exit lands in another routine.

### The flat path

A polygon with no lumel map, a sprite, is lit flat: its one brightness
word, point_light at the quad's centre into POLY_FLAT_BRIGHT, is the span's
brightness with a zero step and no sample, the interval the whole span. The
read before put the sprite's one brightness into a map of four lumels alike
and read it per block through the general path, converting and weighting a
constant.

### The owner build

Under OWNER every pixel loop stores the surface index from a slot the
prologue filled in place of the texel, the crosshair stays off, and a
capture then reads which surface won each pixel, the magenta prepaint
marking the uncovered. The index rides the slot rather than a register
because every register of the pixel loops is taken; the slot is read at
the store, where the colour register is dead. The instrument is the
acceptance measure of a change to what is drawn where: two builds posed
on the same views must own every pixel alike, which the colour captures
cannot say once a span's blocks shift.

## vert_count

`u64`: the polygon in hand's points.

## edge_count

`u64`: the edge list's edges.

## edge_ymin

`f32`: the edges' top.

## edge_ymax

`f32`: the edges' bottom.

## sky_uoff

`i64`: the sky's u offset from the camera's yaw, texture repeats in 16.16.

## sky_voff

`i64`: the sky's v offset from the camera's pitch, texture repeats in 16.16.

## poly

`POLY_SIZE u8`: the polygon in hand, POLY_* fields.

## plane

`14 f32`: the plane in hand, PLANE_* fields.

## plane_d

`14 f64`: the plane in hand as doubles, PLANED_* fields.

## verts

`MAX_VERTS*3 f32`: the polygon in hand's world points.

## vview

`MAX_VERTS*3 f32`: its points in the camera's basis.

## cverts

`MAX_CLIPPED*3 f32`: its points clipped to the near plane.

## pverts

`MAX_CLIPPED*2 f32`: its points projected.

## edges

`MAX_EDGES*4 f32`: the edge list, EDGE_* fields.

## crossings

`MAX_EDGES f32`: a row's crossings' x, ascending.

## span_records

`SPAN_RECORDS*SPAN_RECORD_SIZE u8`: the frame's spans as the fill emitted them.

## span_count

`u64`: the frame's spans, running on past the table.

## poly_serial

`u64`: the polygons submitted so far this frame, the serial a record carries.

## zbuf

`SCREEN_W*SCREEN_H u32`: the depth buffer, 1/z in 6.26 a pixel.
