# main.S

fillrate: what the hart draws a second at 1080p. Opens the display, then runs
each mode for three seconds of the clock, rendering frame after frame with no
wait: fill, a 64-bit store of two pixels at a time; texture, an affine
textured span a row, a texel read and a store a pixel; perspective, the same
with a divide every sixteen pixels; polygon, a convex quad receding into the
screen filled by scanlines with perspective-correct texture coordinates, a
divide every sixteen pixels and a depth compare and store a pixel over a
depth buffer cleared each frame, the depth 1/z as a float; fixed, the same
with the depth a 32-bit integer, 1/z in 6.26; integer, the same with the
blocks' ends worked in 64-bit fixed point as well, no float in the span; lit,
the integer polygon with a brightness interpolated across it and multiplied
into every pixel; vector, built with --set vector, a vector store over the
framebuffer; then textureflip, the texture with a whole flip after every
frame, which the cap refuses when early. Each mode reports its frames, the
flips shown, the clock's ticks, and the pixels a frame on the UART, and the
test works out the rates. Only the last mode reaches the window, and its last
frame stays up until the window closes.

## .set POLY_X

The polygon is four vertices of six floats, every attribute affine across
the quad.

## .set POLY_FIXED

The integer forms: 1/z in 6.26, u/z and v/z in 48.16, z in 48.16 as 2^42
over 1/z, u and v in 16.16.

## idle

The last frame stays up, so a capture reads what the stores wrote.

## mode_run

The line reads `<name> frames=N shown=M ticks=T pixels=P`. The frame count
is in `frames` for the routines.

## poly_frame

The quad's edges are crossed at the row's centre for the two ends of its
span, each end's attributes interpolated along its edge, the span clipped to
the screen and its attributes stepped a pixel; the span in blocks of BLOCK
pixels, u and v exact at each block's ends from one divide of 1/z and two
multiplies, stepped in 16.16 within; a pixel a texel read, a depth compare,
and a pixel and depth store when nearer. The depth is 1/z stepped a pixel: a
float, or with POLY_FIXED a 32-bit integer in 6.26, compared and stepped as
integers; with POLY_INTEGER the blocks' ends are worked in 64-bit fixed point
too, z as 2^42 over 1/z and u and v as u/z and v/z times z, so the span holds
no float at all; with POLY_LIT the brightness is stepped a pixel in 16.16 and
each channel multiplied by it.

In order: the depth buffer cleared; the crossings of the row with the quad's
edges; the pixels the span covers, the first centre at or past each end,
within the screen; the steps a pixel, over the span's width on the screen;
the attributes at the first pixel's centre; u and v at the span's start,
16.16; the depth as an integer, 6.26, and its step a pixel; the brightness,
16.16, and its step a pixel; the pointers and the count; u/z and v/z as
integers, 48.16, and their steps a pixel, in the registers the span's ends
and bounds no longer need. The block: its length, its end's attributes, u
and v there, in float one divide and two multiplies, in fixed point the same
over 64-bit integers. The pixel loops: unlit with a float depth, the texel,
the depth test, the stores; unlit with an integer depth, the same with the
depth compared and stepped as integers; lit with an integer depth, the
texel's channels multiplied by the brightness in 256ths. The block's end is
the next block's start, in float and in fixed point alike; the integer depth
and the brightness are carried on by the pixel loop.

## frame_vector

As many elements a store as the machine's vector length gives at e32 with
eight registers grouped, v8 to v15. RVA23 mandates vectors, and the assembler
takes them from the program's profile, so no `.option` is needed; built only
with --set vector.

## poly

A wall from z 2 at the screen's left edge to z 8 at its right, 9 units tall
and 12 long at 64 texels a unit, whose projection through a 960 focal length
covers the screen and beyond, so every pixel is inside it; the brightness is
1 at the near edge and a quarter at the far.

## k_depth_scale

1/z as an integer in 6.26: two to the 26th, so 1/z reaches 32 and z a
thirty-second, and z at 50 units still resolves under a tenth of a
millimetre.
