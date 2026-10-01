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

span_fill counts every span it fills and the pixels it enters, the lit ones
beside, and times the two span_light evaluations of a lit stride row with
rdtime, into the frame's stats for the frame line: the instrument that
splits the light's cost between the evaluation and the lit pixel loop, and
that reads the overdraw as pixels entered against the screen's.

span_fill and poly_shows are page-aligned and kept under a page: QEMU's
translator ends a block at a page boundary and chains blocks within a page
only, so a loop straddling one leaves the translated code every iteration,
measured seven times slower. The test holds the alignment through the SDK's
`jab hot`.

## poly_shows

The portal test over the same edges: every fourth row's spans sampled every
second column with 1/z stepped; a sample whose buffer depth is under the
surface's means the opening shows.
