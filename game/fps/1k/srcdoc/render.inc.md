# render.inc

The engine's own records and limits beyond the map's, read after map.inc.

## .set CODE_PAGE

QEMU's translator ends a block at a page boundary and chains blocks within a
page only, so a loop straddling one leaves and re-enters the translator every
iteration, seven times the loop; the sky fill measured 8 ms in a page and 54
across one. A function whose loops run a pixel or a sample is aligned to a
page and kept under one, which the test holds from the ELF's symbols; a loop
of that kind inside a larger function is aligned to a power of two past its
length. The toolchain emits compressed instructions, so the layout moves by
bytes with any edit and the guard is structural. A loop that runs a span is
in the class too, with the helpers it calls in its page: the span loop of
poly_fill runs sixteen thousand times a frame on the up flight and calls
span_bound twice a span, and a call across the boundary costs a lookup each
way, so row_crossings through span_record share one page (raster.S).

## .set CAMD_X

camera_d and plane_d exist because the type libraries' vector macros read
doubles from memory: the camera's doubles are written once a frame with the
basis, the plane's once a polygon in surface_setup, each at twice the float
record's offsets.

## .set MAX_VERTS

A polygon's points are world positions of three floats. A sector's loop is
one polygon, so a polygon holds a room's whole ring; clipping against the
near plane can add one point an edge.

## .set MAX_EDGES

A sector's planes put every loop's edges in one list.

## .set POLY_IZA

The surface in hand as the rasteriser reads it: the affine coefficients of
1/z (6.26), u/z and v/z (48.16) over the screen as 64-bit fixed point, each C
carrying the half-pixel offsets so a value at a pixel is C + A * column + B *
row.

## .set POLY_LIGHTS

The sector's list culled to the lights whose sphere meets the polygon's
world box and which lie ahead of its plane, shaped as a sector's list is,
SECTOR_LIGHTS_SIZE bytes.

## .set POLY_LUMAP

POLY_LUMAP, POLY_LUMEL, POLY_FLAT_BRIGHT, and POLY_SIZE are written as
literals because the light list's size is defined below them and an
immediate offset needs its value at the load; the comment carries the sum.
POLY_LUMAP is 0 for a polygon with no map, which the fill lights flat by
POLY_FLAT_BRIGHT over its whole extent and the mode treats as lit whenever
the map has lights; a mapped polygon whose record has no base, the bake
having left it, draws unlit. POLY_LUMEL is the read's one word, the lumels'
offset into the arena in 24 bits, a row's bytes in 16, the rows in 16, and k
in the top byte, so a sample loads one word for the map where the record's
fields cost nine loads before, and bounds itself from that word.

## .set POLY_LUMEL

The lumels' offset into the arena in the low LUMEL_OFFSET_BITS, a row's
bytes from LUMEL_ROWBYTES_SHIFT, the rows from LUMEL_ROWS_SHIFT, and k, the
lumel's texels as a power of two, from LUMEL_K_SHIFT; the columns and rows
bound the read, a texel coordinate past the map's last node or before its
first reading the node there.

## .set POLY_TILES

The atlases sit eight bytes apart, one a level.

## .set POLY_SURFACE

A plane at twice its sector's index and its ceiling after and a wall at
LUMAP_PLANES past them, as the lumel maps are indexed, a map sprite at
SURFACE_SPRITES plus its entity, an actor at SURFACE_ACTORS plus its index.

POLY_SURFACE names the polygon as a surface in one index space: the lumel
maps' order for planes and walls, then the map sprites by entity, then the
actors by index, so the span record and the owner build name a surface in
one word and a reader of either can tell a wall from a sprite.

## .set POLY_MIPS

The chain's table is mip.S's.

## .set CHANNEL_BITS

A brightness word packs three 16.16 channels CHANNEL_BITS apart, which
integer addition steps exactly while every lane stays in range; a lumel packs
the same three channels in 256ths, 0 to 256, so four lumels summed under
weights adding to 256 are a brightness word.

The lit pixel loops unpack each channel to 8.8 by two shifts. A lane holds
the channel times the weight that sums over four lumels to 256: 256 times 256
is 17 bits, a lane 21, and the four products add back to a 16.16 lane with no
unpacking. A packed word halved by an arithmetic shift does not step, since
each channel's odd bit lands in the lane below; the interval step clears each
lane's low bits under a bias before shifting, the mask built from a one in
each lane for the shift in hand (raster.S).

## .set LUMAP_BASE

U0 and V0 are each a multiple of the texture's size at or below the
surface's least texel less one, so a texel coordinate counted from them is
never negative and wraps by the mask unchanged; k is the power of two nearest
half a metre along u. A node sits at every (U0 + i 2^k, V0 + j 2^k), one past
each end of the surface, so a sample within the surface and the lumel past it
both lie in the map.

The lumel map record is in texels: the first node's texel coordinate on each
axis, a multiple of the texture's size below the surface's least texel, and
k, the lumel's texels as a power of two. The read is then two shifts an axis
after a clamp to the map, since a sample at a block's end can lie a pixel
past the polygon's edge (raster.S); the texel-to-lumel scales and offsets the
record carried before are gone.

## .set LUMAP_PLANES

The maps by surface: a sector's floor at twice its index and its ceiling
after, then the walls; a lumel is one word, the grid's spacing in metres is
near k_lumel_d, and the arena holds every map.

## .set RECT_X0

The screen rectangle is four words with its ends past the last, as the fill
bounds its rows and spans.

## .set FLOW_RING

The ring is twice the sectors long so its read and its write never meet
while sectors wait, the most that can wait being every sector once.

## .set SPAN_ROW

A span the fill emits before drawing it. SPAN_RECORDS of them a frame; the
count runs on past the table when a frame has more, and a reader of a frame
whose count passed the table falls back, since the prefix it holds is not the
frame.

The span record is the fill's output before drawing, its row and ends in
sixteen bits with the mode beside them and the surface and the polygon's
serial in a word each, sized for the frames measured and counted past its
end rather than stopped, the count past the table meaning a reader falls
back for that frame.

## .set GRID_O

The frame a map is baked over, in texels. A node's point is the origin plus
its texel coordinate along each step.

## .set INTERVAL_SHIFT_MAX

A lit span samples its map at the ends of intervals of 1, 2, or 4 blocks,
the shift of the interval's pixels 4 to INTERVAL_SHIFT_MAX, chosen so a lumel
spans at least two samples: the longest whose pixels times the texel step a
pixel stay within half a lumel.

The interval constants size the cadence: a lit span samples at the ends of
one, two, or four blocks, INTERVAL_SHIFT_MAX being four blocks' shift, by the
texel step a pixel against the lumel's 2^k texels.

## .set POLY_TILED

The surface has tiles, the lit texture cached, which a near block of the span
reads in place of the texture and the lumel map when its cells are built.

## .set TILE_LEVEL_COUNT

A surface's tiles: the lit texture cached a cell at a time, a cell a lumel's
2^k texels square, each texel the texture's times the lumel brightness
bilinear across the cell; the cells across and down are the map's nodes, a
node past each end of the surface, the last cell's far nodes the greatest, so
a texel coordinate the span can reach has a cell. The atlas holds the cells
row-major with the columns padded to a power of two, TILE_COLS_SHIFT, the
rows as they are, reserved whole on first sight, which costs no memory until
a cell is written; the padding columns are never built, the build's cursor
stepping over them to the next row. The record's base is 0 before the atlas
is reserved and -1 for a surface whose atlas is larger than TILE_ATLAS_MAX,
which stays on the lit loop. The arena is reset whole, every surface
forgotten, when an atlas does not fit. The tiles come in levels, a surface's
atlases one a level: level 0 a cell at the texture's resolution, each level
after it half a side, built from the level before by averaging two by two,
the colour weighted by alpha and the alpha scaled for its coverage
(alphas_measure), TILE_LEVEL_COUNT levels or k + 1 if fewer. A surface is
built whole, a level at a time from the finest, under the frame's budget in
texels read, and a span reads tiles only from the levels built whole, so no
cell is ever checked; until level 0 is whole the surface draws on the lit
loop. A block takes its own level from its texel step a pixel, the largest of
the steps along the span and down a row on each axis, 16.16, level m where
the step is under 2^(m + 1) texels, the last level for any step beyond, held
under the levels whole alone, so a block reads about a texel a pixel and the
spans a row apart read the same lines; a span whose ends lie past the map's
edge keeps the lit loop, which clamps. The records' and the polygon's level
fields sit eight bytes apart.

The tile record and the polygon's six tile fields carry what the span's
block judgement and its tile loop need beyond the map's word: the atlas, the
column shift, the cells across and down that a block's box must lie within,
and the two bit maps, built and wanted, which the span reads and marks per
block (tile.S). The arena's size, the largest atlas, the frame's build
budget, and the near step are one constant each, the budget in texels so a
carpet's 128-texel cell counts four of a brick's, the step in 16.16 texels a
pixel at two, where a block's pixels start to lie a texel apart and the
texture's cache line serves them better than a tile's. The budget's first
reading on the whole-surface cut, 48 cells of 64 texels, cost about three
milliseconds on the spawn's first frame, 26.7 against 23 ms.

## .set MIP_LEVELS

A material's mip chain: the texels of each level from 1, level 0 the
record's own, each level half a side of the one before, built at load by the
tile shrink's rule under the level's alpha scale (mip.S), so a lit or unlit
span reads the level a block's footprint asks for and the lit loop and a tile
at one level hold the same texel; MIP_LEVELS deep at most, a level while both
sides stay two texels or more and the arena holds it.

The mip constants: MIP_LEVELS is the chain's depth at most, ten taking a
512-texel side to one; the entry is a level's texels eight bytes a level; the
arena is 32 MiB in bss, free until touched, where the factory's chains take
about six, a chain being a third of its texture. POLY_MIPS and POLY_MIP_COUNT
carry the material's table and its levels for the block's bind (raster.S).
ALPHA_MATERIAL_SIZE grew to a scale a chain level, since the chain is built
under the same scales as the tiles.

## .set ALPHA_PASS

A material's alpha scale a level, 16.16, by which a coarser level's mean
alpha is scaled at a tile's or a chain level's build so the level's share of
texels passing stays near the texture's: ceil(2^23 / T) for the threshold T
the load's search chose, which lands a mean at or above T at or above the
pass and nothing under T there; one, ALPHA_SCALE_ONE, where the levels pass
as the texture does; a scale a level of the chain.

## .set STAT_SECTORS

The frame's counts and its ticks by phase, 64 bits each.

The stats record grew its span, pixel, and light-tick fields for the light's
instrument, then the rejected-pixel count, then the lumel samples; a field is
added by extending the record, zeroed in world_draw, and printed by
frame_report, with the test's frame template extended to match, since the
template names every field. STAT_TILE_TICKS is the tiles' time inside the
planes' and the walls' phases, a reservation with any reset it makes and
each cell built or shrunk, and is never added to them.

## .set REPORT_KIND

The records over the API are 64 bytes each. An event carries the state's
fields and its own from REPORT_FIELD0.

The clock records, REPORT_FRAME and REPORT_DRAW, and the end marker,
REPORT_END, put the frame's number where the state puts its sector and the
schema's version in the last word, so a reader refuses a layout it does not
know; the state record keeps its layout and meanings. The frame record's
start and flip's end are 64 bits on 8-byte boundaries and every other field
32. Its phases are exclusive, the game, the drawing, the crosshair, the mix,
the flip, and the reporting, and the critical path less their sum is time no
phase holds; the drawing's parts are exclusive within the drawing, the
clear, the portals, the planes, the walls, and the sprites, with DRAW_TILES
inside the planes and the walls. The await is the time inside the call,
whatever the kernel does there. The pixel counts are candidates before the
depth test and the masked pass: DRAW_TILED_PIXELS the blocks read from
tiles, DRAW_LIT_PIXELS every lit span's, their difference the lit pixels the
fallback loop took, which holds blocks off the tile grid as well as cells
not yet built. DRAW_TILE_BYTES is the arena in use at the frame's end and
DRAW_TILE_PEAK the most it has held since the load, which a reset lowers
the first and never the second. DRAW_SPANS counts every span, recorded or
not past SPAN_RECORDS.

## .set SET_STAND

The engine's images by frame index: the android's eight rotating sets of
eight, then the fallen frame, the three sparks, and the magazine; a frame's
material index is frame_base plus its frame index.

## .macro owner_pixel

Under OWNER a pixel loop stores the surface's index in place of its colour,
from the slot span_fill's prologue fills, so a capture reads which surface
won each pixel; the crosshair stays off. The owner_pixel macro is a load from
span_fill's slot under OWNER and nothing otherwise, so the pixel loops carry
the instrument at no cost to a normal build.
