# render.inc

CODE_PAGE: QEMU's translator ends a block at a page boundary and chains
blocks within a page only, so a loop straddling one leaves and re-enters the
translator every iteration, seven times the loop; the sky fill measured 8 ms
in a page and 54 across one. A function whose loops run a pixel or a sample
is aligned to a page and kept under one, which the test holds from the ELF's
symbols; a loop of that kind inside a larger function is aligned to a power
of two past its length. The toolchain emits compressed instructions, so the
layout moves by bytes with any edit and the guard is structural.

camera_d and plane_d exist because the type libraries' vector macros read
doubles from memory: the camera's doubles are written once a frame with the
basis, the plane's once a polygon in surface_setup, each at twice the float
record's offsets.

The stats record grew its span, pixel, and light-tick fields for the light's
instrument, then the rejected-pixel count; a field is added by extending the
record, zeroed in world_draw, and printed by frame_report, with the test's
frame template extended to match, since the template names every field.

The brightness word packs three 16.16 channels CHANNEL_BITS apart, which
integer addition steps exactly while every channel stays in range; the lit
pixel loops unpack each channel to 8.8 by two shifts. A lumel packs the same
channels in 256ths, so a lane holds the channel times the weight that sums
over four lumels to 256: 256 times 256 is 17 bits, a lane 21, and the four
products add back to a 16.16 lane with no unpacking. A packed word halved by
an arithmetic shift does not step, since each channel's odd bit lands in the
lane below; the block step clears each lane's low four bits under a bias
before shifting (raster.S).

POLY_LUMAP and POLY_SIZE are written as literals because the light list's
size is defined below them and an immediate offset needs its value at the
load; the comment carries the sum.

The lumel map record keeps the texel-to-lumel map as a multiply and a shift
rather than a divide: RU is 2^32 over the texels in a lumel, so u RU >> 32 is
u over that, and OU the texel origin's lumel coordinate, both signed so a
mirrored mapping holds. The clamps are ((W - 1) << 16) - 1, one short of the
last node, so a clamped sample's fraction stays under one and the lumel past
it is the last.
