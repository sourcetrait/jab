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

## .set DURATION

`u64`: a mode's run, three seconds of the clock.

## .set PIXELS

The screen's pixels.

## .set ZBUF_BYTES

The depth buffer's bytes, a word a pixel.

## .set POLY_X

`f32`: a vertex's screen x.

The polygon is four vertices of six floats, every attribute affine across
the quad.

## .set POLY_Y

`f32`: its screen y.

## .set POLY_IZ

`f32`: its 1/z.

## .set POLY_UZ

`f32`: its u/z.

## .set POLY_VZ

`f32`: its v/z.

## .set POLY_BR

`f32`: its brightness.

## .set POLY_VERTEX

A vertex's bytes, six floats.

## .set POLY_VERTICES

The quad's vertices.

## .set BLOCK

A span block's pixels, the texture coordinates exact at each block's ends and stepped within.

## .set POLY_FIXED

`u64`: a polygon mode's flag, the depth an integer.

The integer forms: 1/z in 6.26, u/z and v/z in 48.16, z in 48.16 as 2^42
over 1/z, u and v in 16.16.

## .set POLY_LIT

`u64`: the flag for the pixels lit.

## .set POLY_INTEGER

`u64`: the flag for the blocks' ends in fixed point.

## .set DEPTH_BITS

1/z's fraction bits, 6.26.

## .set Z_SHIFT

Z as 2^Z_SHIFT over 1/z, 48.16.

## .set TEX_BITS

The texture's side as a power of two.

## .set TEX_SIDE

The texture's side in pixels.

## .set TEX_MASK

A texture coordinate's wrap.

## .set TEX_ROW_BYTES

A texture row's bytes.

## .set TEX_ROW_SHIFT

A texture row's offset as a shift of its index.

## .set TEX_STEP

`u32`: a drawn pixel's step across the texture, half a texel in 16.16.

## .set SPAN

A perspective span's pixels.

## .set SPANS

The spans in a row.

## .set LINE_BYTES

The UART line's buffer.

## .set DIGITS_BYTES

append_dec's scratch.

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

## frames

`u64`: the frame count, for the routines.

## elapsed

`u64`: the mode's ticks.

## digits

`DIGITS_BYTES u8`: append_dec's scratch, the digits built backwards from its end.

## line

`LINE_BYTES u8`: the UART line.

## texture

`TEX_SIDE*TEX_SIDE u32`: the texture.

## cross

`12 f32`: a row's two crossings of the quad, an attribute set each.

## zbuf

`PIXELS u32`: the depth buffer, 1/z a pixel as a float or in 6.26.

## name_fill

`5 u8`.

## name_texture

`8 u8`.

## name_perspective

`12 u8`.

## name_polygon

`8 u8`.

## name_fixed

`6 u8`.

## name_integer

`8 u8`.

## name_lit

`4 u8`.

## name_vector

`7 u8`.

## name_textureflip

`12 u8`.

## word_frames

`9 u8`.

## word_shown

`8 u8`.

## word_ticks

`8 u8`.

## word_pixels

`9 u8`.

## msg_no_display

`22 u8`.

## poly

`24 f32`: the quad, at each vertex the screen x and y, 1/z, u/z, v/z, and the brightness.

A wall from z 2 at the screen's left edge to z 8 at its right, 9 units tall
and 12 long at 64 texels a unit, whose projection through a 960 focal length
covers the screen and beyond, so every pixel is inside it; the brightness is
1 at the near edge and a quarter at the far.

## k_half

`f32`.

## k_one

`f32`.

## k_sixty_four_k

`f32`: one in 16.16.

## k_depth_scale

`f32`: 2^26, 1/z into 6.26.

1/z as an integer in 6.26: two to the 26th, so 1/z reaches 32 and z a
thirty-second, and z at 50 units still resolves under a tenth of a
millimetre.
