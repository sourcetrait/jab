# raster.S

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
any surface overwrites it.

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

The pixel-centre rule everywhere, ceil(v - 0.5), so surfaces sharing an edge
meet without a crack. Walking by rows matters under TCG: a column walk
touches a new cache line of each 8 MB buffer per pixel and measured 180 ms
for a million pixels against 16 by rows.

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

## lumel_sample

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

The read it replaced did 13 loads and eight multiplies a sample, nine of
the loads the map's record and its fields reloaded every block, and
converted the texel coordinate by a multiply, a shift, an offset, and a
clamp on each axis; this mirror had counted nine loads and claimed the read
more than paid for the evaluation it replaced, both written before the
gauge came back, and the gauge showed the read costing about what the
evaluation had on the views that enter the most pixels.

## The cadence

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

## The lit texture cache, tried and rejected

The lit loop's three multiplies and their unpacking are about twenty
integer ops a pixel over the unlit loop's eight, and a cache of the lit
texture would pay them once: a tile per lumel cell at the texture's
resolution, the texel times the brightness bilinear across the cell,
read by a loop of fifteen ops and one load. Built and measured twice. A
whole-surface build read every block from tiles and measured the
settled planes phase near twice the lit loop's; a hybrid built cells on
demand from a per-block wanted map and read tiles only for near blocks,
the texel step a pixel under two, and still lost 8 to 13 ms on every
plane-heavy view of the gauge, level on the wall-heavy ones. A probe
that pinned every tiled read to one tile, cache-hot, read the planes
phase level with the lit loop's. So the loop's arithmetic is not the
frame's cost on this lane: under TCG the integer ops are near free and
the loads are the price, and the texture of 64 KiB stays in cache where
an atlas of megabytes misses on any walk off its rows; a wall span
walks a row and costs the same from either, a floor span walks a
diagonal and misses a line a pixel. No layout of the tiles beats a
level reading, so the renderer keeps the lit loop and the texture.

## The flat path

A polygon with no lumel map, a sprite, is lit flat: its one brightness
word, point_light at the quad's centre into POLY_FLAT_BRIGHT, is the span's
brightness with a zero step and no sample, the interval the whole span. The
read before put the sprite's one brightness into a map of four lumels alike
and read it per block through the general path, converting and weighting a
constant.

span_fill counts every span it fills, the pixels it enters, the lit ones
beside, and the lumel samples it reads, into the frame's stats for the frame
line, which reads the overdraw as pixels entered against the screen's and
the cadence as samples against blocks; the light's microseconds on that
line are the sprites' evaluations alone.

span_fill and poly_shows are page-aligned and kept under a page: QEMU's
translator ends a block at a page boundary and chains blocks within a page
only, so a loop straddling one leaves the translated code every iteration,
measured seven times slower. The test holds the alignment through the SDK's
`jab hot`.

## poly_shows

The portal test over the same edges: every fourth row's spans sampled every
second column with 1/z stepped; a sample whose buffer depth is under the
surface's means the opening shows.
