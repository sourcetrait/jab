# raster.S

The polygon rasteriser: world points into the camera's basis, clipped and
projected into edges, the even-odd fill within a rectangle into the frame's
packet, a command a polygon and a record a span, the packet rendered on a
raster context, the integer span.

Preparation and rendering are apart. Preparation, hart 0's, walks the flow,
sets up each polygon in `poly` and its edges, and fills it into the packet:
at its first span the polygon is copied whole into the packet's command
table, POLY_SIZE bytes, and each span is recorded with its command's index.
The packet is immutable once published: a command's coefficients, modes,
texture, chain, lumel word, flat brightness, and tile binding are its own
copy, never a pointer into `poly`, whose next polygon overwrites it.
packet_render then resolves every command's tile binding against the
arena's generation and renders the spans in the order they were recorded
through span_fill on a raster context, which holds the command in hand and
the span's counters, so the depth test meets the surfaces in the order the
immediate fill met them and the picture is the same. A packet full of
commands or spans is rendered whole and emptied before preparation goes on,
so a frame is never drawn short. The serial backend is one context, hart
0's, the spans in their order; with workers the frame's each render is a
round (workers.S), each worker rendering whole bands of rows through
band_render on a context of its own, the same record. On a debug build the
producer's scratch is poisoned once the packet is published, so a read of
it from the raster draws wrong or faults.

A band renders the serial picture of its rows: a command's spans are
contiguous in its packet and ascend by row, since poly_fill fills one
polygon's rows in order and a flush emits the polygon in hand again as the
emptied packet's command 0, so a pixel's writes come from the commands in
their order, one span a command, whichever renderer owns its row. The run
table, `command_runs`, holds each command's first span, so a band finds its
spans of each command by a binary search on the row.

The context rides tp: user mode's own register, which the kernel saves and
restores across a trap and sets to zero entering the program and a worker,
and which nothing else in the program uses. packet_render sets it; span_fill
and its macros read the command and the counters through it.

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
1/z stays under 2^46 across Render Zero. The read's one word packs the
lumels' offset into the arena in 24 bits, a row's bytes in 16 from bit 24,
the rows in 16 from bit 40, and k from bit 56, so the read can bound itself
from the word alone; the offset rather than the address because a window
on an 8 GB machine can sit past 2^32 and the rows need the bits.

## .macro span_cap

The span loop asks it once a span, so a release build pays one load
immediate for SPAN_RECORDS and a debug build the console's cap besides.

## row_crossings

The span loop's family, row_crossings through span_record, shares one page
for the same reason as span_fill at a smaller scale: poly_fill's inner loop
runs once a span, sixteen thousand times a frame on the up flight, and calls
span_bound twice a span, so a page boundary inside the loop or between it
and its helpers costs a block lookup each way per span. The eighteen bytes of
a polygon serial's increment at poly_fill's entry, since gone, once moved
the loop's head to two bytes short of the boundary at 0x80a03000 and cost
the up flight 1.2 ms a frame, read on two batteries against the build before
and confirmed by an interleaved probe; the family on its own page returned
the wall phase to 24.2 ms from 25.5, where poly_fill aligned alone, its
helpers still across the boundary, returned half of that. The family is 580
bytes from the directive, so the page holds it with room; the test guards
each member as it guards span_fill and the five together on one page, since
five members each within a page of its own would pass the first guard with
the calls crossing again.

## poly_fill

The rows and every span are held within the rectangle in hand, the
sector's from the flow (world.S), before the span is recorded: the row
range against the rectangle's rows once a polygon, each span's ends
against its columns. A span clipped starts its blocks at a different
pixel from the whole span's, and its texel bytes can move by a rounding,
which is why a clipped frame is compared by the surface each pixel
belongs to rather than byte for byte. The portal test that sampled an
opening's spans every fourth row and second column against the depth
buffer is gone: a sampled test can miss an opening narrower than its
stride, so it could order sectors but never reject one, and the flow's
rectangles reject nothing either, the depth buffer resolving every pixel.

A span goes into the packet against the polygon's command, which the
first span emits; a polygon with no span emits none. Before a span the
loop holds room for it in its own frame, one compare a span: the command
held and the spans under the cap, else packet_room renders the full
packet and emits the command again in the empty one, so the polygon's
remaining spans follow it there. Its frame keeps the command at 32, the
span's ends across the call at 0 and 24.

## span_record

The span record, sixteen bytes a span, is the packet's work list and the
interface the tile pool and a sorted span renderer share: packet_render
draws the records in order, the pool will read them to learn which cells
the spans touch, and a span sorter produces the same records from its own
machinery. A record carries the row and the span's two ends in sixteen bits
each, the polygon's mode, the surface index, and its command's index in the
packet: the surface is the stable identity the owner build shares, and the
command tells a masked opening's fill from its wall's solid pieces, which
carry the same surface, so a consumer that orders primitives has each
submission apart. The caller holds room for the record, so the table never
runs past SPAN_RECORDS; a frame with more spans renders a full packet and
goes on in the next, every span drawn. The mode and the surface are read
from `poly`, the producer's own.

## packet_room

The cold path of the span loop, taken at a polygon's first span and when
the packet's spans are full: a full packet is rendered and emptied, which
takes the polygon's command with it, and a polygon with no command in the
packet emits it there.

## command_emit

The whole record copied, thirty-nine words, so a command holds every field
span_fill reads at its POLY_* offset, the tile binding's generation
(POLY_TILE_GENERATION) among them, and fields only preparation reads
besides; the frame line counts the frame's commands. A packet full of
commands is rendered whole first. The command's index is its record's
position in the table, and its run's first span, the packet's span count
then, goes into the run table at the same index; the run ends at the next
command's first or the packet's last span.

## packet_flush

A flush is a packet rendered before preparation ends, the commands or the
spans full; STAT_FLUSHES counts them, the final render being none. The
phases around it subtract its render's ticks (world.S's phase_mark).

## packet_resolve

A command bound to tiles in a generation of the arena before the last
reset holds atlases the reset took back, which later binds may have
rebuilt with other surfaces' cells: its tiled flag is cleared, so its
blocks take the chain at their own level, the same-level fallback, and it
is counted in STAT_INVALIDATED. A frame with no reset resolves nothing.
The resolve runs at every render, so a flush before a reset keeps its
commands' tiles, which were still the arena's.

## context_counts

span_fill counts into the context, so contexts never share a counter; the
frame's stats take the sum after each render. A COUNT build's counts go the
same way, the context's into count_stats.

## scratch_poison

A debug build's guard on the packet's contract: after preparation and
before the frame's last render every word from `poly` to scratch_end, the
polygon, the plane, the points, the edges, and the crossings, is
SCRATCH_POISON, an address no page maps, so a stale `la poly` in the raster
faults on its first pointer and reads garbage on any other field; the
frame's next preparation writes every field it reads before reading it. A
flush mid-polygon leaves the scratch whole, since preparation goes on with
it.

## poly_rect

The pixel-centre rule, as the fill bounds a span and its rows, a pixel of
slack against the fill's rounding.

## .macro lumel_sample

The read, about 60 integer ops and six loads a sample, one of them the
command's address from the context and one the packed word: the
coordinates are held within the map first, a negative one
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
reloads level 0's exact coordinates for the next. The level arrives held
under the chain's last: span_fill holds it once where it computes it, so the
tiles and the chain read one level and the bind holds nothing of its own.

The coordinates and their steps stay at level 0 and each pixel shifts its
coordinate by the level plus 16, in s5, the address the tile loop computes
for the same point, so a tile and the chain at one level read the same
texel at every pixel: one coordinate rule for the cache and the chain. The
bind shifted u, v, and their steps by the level before and the loops
stepped the shifted values, which drops the step's low bits every pixel; the
tile loop steps the full value, so near a texel's edge the two read
neighbouring texels, which the spawn view of Render Zero's still copy read
as 33 pixels of 2.07 million differing under the full-bright frame, by up
to 49 of 255.
The shift by a register costs what the shift by 16 did; s5, v/z, rides 40(sp)
for the block, as the tile loop spills it, and the block's end takes it
back for every path.

## .macro count_add

The COUNT build's one instrument, MapperDivides' proof: a counter in the
raster context's counts raised where span_fill divides, avoids a divide, or
meets a case the proof must see exercised, summed into count_stats after
each render. The two registers it takes are the ones the site has free,
each site's read off the code that follows it, since a count must change
nothing the drawing reads; no build but COUNT assembles a line of it.

## packet_render

The serial backend, and the reference a worker's backend scales against:
one context, the spans in their order, so the frame is the immediate
fill's to the byte wherever no reset invalidated a binding. Its per-span
loop, a record's fields, the command's address by a multiply, and the
call, shares span_fill's page, so the call chains within the page where
poly_fill's call to span_fill crossed one every span. The render's ticks
go to STAT_RASTER_TICKS, a flush's with the last render's. With the
frame's workers above 0 the resolve is followed by the round in place of
the loop (workers.S's round_run), which sums the workers' contexts; the
packet is emptied and the ticks taken the same way.

## band_render

A band's rows rendered on the caller's context, a worker's or hart 0's:
on a clearing round its depth rows zeroed first, and on a debug build its
pixels painted magenta, so each row is cleared once a frame by the band's
renderer before its first span; then for each command in order its run's
first span at or past the band's first row by a binary search over the
run's rows, and each span from there until one past the band, through
span_fill with the command in the context. It shares the packet's page
with packet_render and span_fill, so its call a span chains within the
page as the serial loop's does.

## span_fill

The polygon is the context's command, `CTX_COMMAND(tp)`, at every place
the fill once read `poly`: the prologue's coefficients and modes, the
lumel sample's word, the chain's bind, the tiled block's atlases, the
sky's texture size. Its counts, the spans, the pixels entered, the lit
ones, the rejected, the samples, and the tiled pixels, go to the context.
A load through tp costs about what the `la` it replaced did, once a span
or a block, never a pixel.

span_fill holds no float: a float helper under TCG costs about 5 ns, and the
probe measured the float span at 12 to 14 ms a megapixel against 5.4 for the
integer one. 1/z, u/z, and v/z at the span's first pixel are a multiply and
an add each; blocks of 16 pixels, at whose end one divide gives z as 2^42
over 1/z, clamped to IZ_MIN for it, and two multiplies give u and v exact
there, the steps within by a shift for a full block and by two divides for
a short last one; a pixel is a depth load and a skip
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
no stored pixel: the seven gauge captures on Render Zero without its androids
are byte for byte the same before and after. It saves little: the up flight's walls
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

A full block's steps are a shift by BLOCK_SHIFT, not a divide. RISC-V's
div rounds toward zero and an arithmetic shift rounds down, so a negative
difference takes BLOCK - 1 first, (d + ((d >> 63) & 15)) >> 4, which is d /
16 for every 64-bit d, the signed extremes included; a short last block
divides by its length. Quake shifts the full step bare (WinQuake
`d_scan.c`), a rounding that would move texels here, so the pictures stay
the divide's to the byte.

Where the polygon's 1/z holds along the row, POLY_IZA zero, z is one value
along the span: s2 steps by s3 a pixel and never moves. The prologue's z at
the first pixel, kept in slot 232 (the frame 240 bytes), then serves the
span's end, every block's end, and every lit interval's end, each a divide
whose input would be the same clamp of s2. The span's end keeps its
clamped 1/z in t3 all the same, since the row below the end reads it, and
that reciprocal keeps its divide: it adds B to the end's clamped 1/z where
the row below the start adds B to the raw s2, so with A zero the two part
whenever s2 is under IZ_MIN, past 16,384 m. Which spans qualify is A's
value alone: flat floors and ceilings under no camera roll, and any wall
or slope whose depth holds along the row, a wall seen square among them.

A COUNT build (`--set debug,count`) counts every divide span_fill makes,
site by site, into count_stats, which count_report prints after the frame
line. It is the instrument of MapperDivides' proof and is never timed: its
counters move the code after them, and the linker then shortens loads
differently, hud.S's code 542 bytes shorter on the first such build, the
images otherwise alike; without COUNT the release and debug images are
byte for byte the build's before the instrument.

span_fill shares a page with packet_render, the pair aligned to it and
kept under it: QEMU's translator ends a block at a page boundary and chains
blocks within a page only, so a loop straddling one leaves the translated
code every iteration, measured seven times slower. The test holds both
within their page, together, through the SDK's `jab hot`.

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
+ 1) texels, held once under the chain's last, which the prologue keeps in
slot 224. One level a block, chosen before the cache or the chain: lit, a
span judged for its tiles (the prologue) reads a block's tile only where the
block's level is built whole, and any other block takes the lit loop through
the chain at that same level, so a block never reads a sharper level than it
asks, while the cache builds or past its four levels; a block read from
tiles pays no sample, no interval, and no brightness carry. A span with no
tiles takes the lit loop at the chain's level. The texel step a pixel, the larger of |du| and |dv|, against the
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
eight 2, and so on, held under the chain's last, about twenty-five ops a
block; a tiled span reads the tile where the level is built whole, and
every other block reads the texture's level through mip_bind: the level's
texels from the table the bind named, the masks and the row shift shifted
by the level, and the shift from a 16.16 coordinate to its texel at the
level, the coordinates themselves staying at level 0 as the tile loop reads
them, so the two address one texel at every pixel and the block's end
reloads level 0's exact coordinates for the next. The bind comes after the
lumel sample, which reads level 0 coordinates, and before the loop. So a block
reads about a texel a pixel at any distance, a far floor stops touching a
cache line a pixel, and the lit loop and a tile at one level hold the same
texel under one brightness, which the alpha fixture holds identical over
the opening at levels 0, 1, and 2, and with level 0 alone built at the mid
pose's level 1, and which TilePool's handoff between the loop and the
cache rests on. The level was chosen after the path before: a tiled span
held its blocks under the levels whole, so a block asking level 2 read
the chain at 2 before the cache arrived, then tile 0, 1, and 2, and a
block past the cache's four levels read tile 3 where the chain read
deeper. The unlit loops pay the prologue's divides and the level for the
same picture; the sky reads its texture at level 0 by screen position,
under a texel a pixel.

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
block whose level is built whole then reads that level's atlas, its
shifts and mask riding the texture's four registers, the brightness's
two, and one spilled saved register, since a hit needs no brightness: the
cell shift k + 16 and the texel shift m + 16 from a 16.16 coordinate; a
block asking a level the tiles do not hold whole, one still building or
past the four, takes the lit loop at the chain's level instead. The
seventh cut held the block's level between two levels taken at the span's
ends as well, each the larger of the row step there and the step along
the span averaged over the whole span, which cost two divides a span and
clamped every block of a receding wall to the average's level wherever
the row steps sat under it (tile.S); of the stack slots those bounds
rode, 32 holds the owner build's surface and 224 the chain's last level.

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

Every surface's tiles are row-major. The fourth cut laid a plane's tiles in
blocks of four by four texels with a swizzled pair of loops, the texel's
block row by a shift of k plus four, its block along the row by a shift of
six, and its row and place in the block from the low two bits of each
coordinate, ten more ops a pixel and a second spilled saved register. The
third cut, with every tile row-major, read the walls gaining 2.5 to 4.7 ms
and the planes losing 5 to 10 in their phase on every view but the yard,
whose floor at yaw 90 walks along the rows; the lit setup's reload of the
texture's four registers is skipped for a polygon with no tiles, since
every lit block of every polygon took it before. The fourth cut, blocks for
planes, measured against a build with no binds in the same batch: walls
level to the microsecond, planes 8 to 12 ms worse, the blocks no better
than rows, so they went; and with every tile read pinned to one cache-hot
tile, the judgement and the address work kept, the frame reads level with
no binds on every view, so the hit path's own work costs exactly what the
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

## count_stats

`COUNT_SIZE u8`: on a COUNT build alone, the frame's counts of span_fill's divides, the COUNT_* fields (render.inc), every context's summed after each render.

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

## scratch_end

The end of the producer's scratch from `poly`, the poison's bound.

## span_records

`SPAN_RECORDS*SPAN_RECORD_SIZE u8`: the packet's spans as the fill emitted them, SPAN_* fields.

## span_count

`u64`: the packet's spans.

## command_count

`u64`: the packet's commands.

## packet_command_cap
## packet_span_cap

`u32`: on a debug build alone, the console's K frame's caps on a packet, the commands and the spans it holds, 0 for MAX_COMMANDS and SPAN_RECORDS.

## raster_context

`CTX_SIZE u8`: hart 0's raster context, CTX_* fields.

## commands

`MAX_COMMANDS*POLY_SIZE u8`: the packet's commands, each a polygon's record as preparation published it, POLY_* fields.

## command_runs

`MAX_COMMANDS u32`: each command's first span in the packet, the run table a band searches.

## zbuf

`SCREEN_W*SCREEN_H u32`: the depth buffer, 1/z in 6.26 a pixel, on a line's boundary, so no line holds two rows and two renderers' rows never share one.
