# render.inc

CODE_PAGE: QEMU's translator ends a block at a page boundary and chains
blocks within a page only, so a loop straddling one leaves and re-enters the
translator every iteration, seven times the loop; the sky fill measured 8 ms
in a page and 54 across one. A function whose loops run a pixel or a sample
is aligned to a page and kept under one, which the test holds from the ELF's
symbols; a loop of that kind inside a larger function is aligned to a power
of two past its length. The toolchain emits compressed instructions, so the
layout moves by bytes with any edit and the guard is structural. A loop that
runs a span is in the class too, with the helpers it calls in its page: the
span loop of poly_fill runs sixteen thousand times a frame on the up flight
and calls span_bound twice a span, and a call across the boundary costs a
lookup each way, so row_crossings through span_record share one page
(raster.S).

camera_d and plane_d exist because the type libraries' vector macros read
doubles from memory: the camera's doubles are written once a frame with the
basis, the plane's once a polygon in surface_setup, each at twice the float
record's offsets.

The stats record grew its span, pixel, and light-tick fields for the light's
instrument, then the rejected-pixel count, then the lumel samples; a field
is added by extending the record, zeroed in world_draw, and printed by
frame_report, with the test's frame template extended to match, since the
template names every field.

The brightness word packs three 16.16 channels CHANNEL_BITS apart, which
integer addition steps exactly while every channel stays in range; the lit
pixel loops unpack each channel to 8.8 by two shifts. A lumel packs the same
channels in 256ths, so a lane holds the channel times the weight that sums
over four lumels to 256: 256 times 256 is 17 bits, a lane 21, and the four
products add back to a 16.16 lane with no unpacking. A packed word halved by
an arithmetic shift does not step, since each channel's odd bit lands in the
lane below; the interval step clears each lane's low bits under a bias
before shifting, the mask built from a one in each lane for the shift in
hand (raster.S).

POLY_LUMAP, POLY_LUMEL, POLY_FLAT_BRIGHT, and POLY_SIZE are written as
literals because the light list's size is defined below them and an
immediate offset needs its value at the load; the comment carries the sum.
POLY_LUMAP is 0 for a polygon with no map, which the fill lights flat by
POLY_FLAT_BRIGHT and the mode treats as lit whenever the map has lights;
a mapped polygon whose record has no base, the bake having left it, draws
unlit. POLY_LUMEL is the read's one word, the lumels' offset into the arena
in 24 bits, a row's bytes in 16, the rows in 16, and k in the top byte, so
a sample loads one word for the map where the record's fields cost nine
loads before, and bounds itself from that word.

The lumel map record is in texels: the first node's texel coordinate on
each axis, a multiple of the texture's size below the surface's least
texel, and k, the lumel's texels as a power of two. The read is then two
shifts an axis after a clamp to the map, since a sample at a block's end
can lie a pixel past the polygon's edge (raster.S); the texel-to-lumel
scales and offsets the record carried before are gone.

The interval constants size the cadence: a lit span samples at the ends of
one, two, or four blocks, INTERVAL_SHIFT_MAX being four blocks' shift, by
the texel step a pixel against the lumel's 2^k texels.

POLY_SURFACE names the polygon as a surface in one index space: the lumel
maps' order for planes and walls, then the map sprites by entity, then
the actors by index, so the span record and the owner build name a
surface in one word and a reader of either can tell a wall from a sprite.
The screen rectangle is four words with its ends past the last, as the
fill bounds its rows and spans; the flow's ring is twice the sectors long
so its read and write never meet while sectors wait, the most that can
wait being every sector once; the span record is the fill's output before
drawing, its row and ends in sixteen bits with the mode beside them and
the surface and the polygon's serial in a word each, sized for the
frames measured and counted past its end rather than stopped, the count
past the table meaning a reader falls back for that frame. The owner_pixel macro is a
load from span_fill's slot under OWNER and nothing otherwise, so the
pixel loops carry the instrument at no cost to a normal build.

The mip constants: MIP_LEVELS is the chain's depth at most, ten taking a
512-texel side to one; the entry is a level's texels eight bytes a level;
the arena is 32 MiB in bss, free until touched, where the factory's
chains take about six, a chain being a third of its texture. POLY_MIPS
and POLY_MIP_COUNT carry the material's table and its levels for the
block's bind (raster.S). ALPHA_MATERIAL_SIZE grew to a scale a chain
level, since the chain is built under the same scales as the tiles.

The tile record and the polygon's six tile fields carry what the span's
block judgement and its tile loop need beyond the map's word: the atlas,
the column shift, the cells across and down that a block's box must lie
within, and the two bit maps, built and wanted, which the span reads and
marks per block (tile.S). The arena's size, the largest atlas, the
frame's build budget, and the near step are one constant each, the
budget in texels so a carpet's 128-texel cell counts four of a brick's,
the step in 16.16 texels a pixel at two, where a block's pixels start to
lie a texel apart and the texture's cache line serves them better than a
tile's. The budget's first reading on the whole-surface cut, 48 cells of
64 texels, cost about three milliseconds on the spawn's first frame,
26.7 against 23 ms.
