# render.inc

The engine's own records and limits beyond the map's, read after map.inc.

## .set SCREEN_W

The screen's width in pixels.

## .set SCREEN_H

The screen's height in pixels.

## .set SCREEN_PITCH

A screen row's bytes.

## .set ZBUF_BYTES

The depth buffer's bytes, a word a pixel.

## .set CODE_PAGE

A page of code under QEMU, the alignment and the bound of a function whose loops run a pixel or a sample.

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

## .set SECTION_AT

`addr`: a section's address in the map buffer.

## .set SECTION_COUNT

`u64`: the section's record count.

## .set SECTION_ENTRY

A sections entry's bytes, an entry a kind from 1.

## .set CAM_X

`f32`: the eye's x.

## .set CAM_Y

`f32`: the eye's y.

## .set CAM_Z

`f32`: the eye's z.

## .set CAM_YAW

`f32`: the yaw in radians.

## .set CAM_PITCH

`f32`: the pitch in radians.

## .set CAM_ROLL

`f32`: the roll in radians.

## .set CAM_RIGHT

`3 f32`: the basis's right, derived from the angles each frame.

## .set CAM_UP

`3 f32`: the basis's up.

## .set CAM_FORWARD

`3 f32`: the basis's forward.

## .set CAM_SIZE

The camera's bytes.

## .set CAMD_X

`3 f64`: the eye as doubles.

camera_d and plane_d exist because the type libraries' vector macros read
doubles from memory: the camera's doubles are written once a frame with the
basis, the plane's once a polygon in surface_setup, each at twice the float
record's offsets.

## .set CAMD_RIGHT

`3 f64`: the right as doubles.

## .set CAMD_UP

`3 f64`: the up as doubles.

## .set CAMD_FORWARD

`3 f64`: the forward as doubles.

## .set CAMD_SIZE

camera_d's bytes, at twice the camera's offsets.

## .set MAX_VERTS

A polygon's world points before clipping at most.

A polygon's points are world positions of three floats. A sector's loop is
one polygon, so a polygon holds a room's whole ring; clipping against the
near plane can add one point an edge.

## .set MAX_CLIPPED

Its points after the near plane at most, which can add one an edge.

## .set VERT_SIZE

A world point's bytes, three floats.

## .set PVERT_SIZE

A projected point's bytes, x and y floats.

## .set MAX_EDGES

The edge list's edges at most.

A sector's planes put every loop's edges in one list.

## .set EDGE_Y0

`f32`: an edge's top y.

## .set EDGE_Y1

`f32`: its bottom y.

## .set EDGE_X0

`f32`: its x at the top.

## .set EDGE_DXDY

`f32`: x's change a row.

## .set EDGE_SIZE

An edge's bytes.

## .set POLY_TEX

`addr`: the surface in hand's texture pixels.

## .set POLY_UMASK

`u64`: u's wrap mask.

## .set POLY_VMASK

`u64`: v's wrap mask.

## .set POLY_WSHIFT

`u64`: a texture row's bytes as a shift.

## .set POLY_IZA

`i64`: 1/z's change a column, 6.26.

The surface in hand as the rasteriser reads it: the affine coefficients of
1/z (6.26), u/z and v/z (48.16) over the screen as 64-bit fixed point, each C
carrying the half-pixel offsets so a value at a pixel is C + A * column + B *
row.

## .set POLY_IZB

`i64`: 1/z's change a row.

## .set POLY_IZC

`i64`: 1/z at the screen's origin with the half pixel.

## .set POLY_UZA

`i64`: u/z's change a column, 48.16.

## .set POLY_UZB

`i64`: u/z's change a row.

## .set POLY_UZC

`i64`: u/z at the screen's origin with the half pixel.

## .set POLY_VZA

`i64`: v/z's change a column, 48.16.

## .set POLY_VZB

`i64`: v/z's change a row.

## .set POLY_VZC

`i64`: v/z at the screen's origin with the half pixel.

## .set POLY_MODE

`u64`: a POLY_TEXTURED, POLY_MASKED, or POLY_SKY, with POLY_LIT and POLY_TILED over it.

## .set POLY_TEXW

`f32`: the texture's width.

## .set POLY_TEXH

`f32`: the texture's height.

## .set POLY_TEXWI

`u32`: the texture's width as an integer.

## .set POLY_TEXHI

`u32`: the texture's height as an integer.

## .set POLY_LNX

`f32`: the unit normal facing the camera, its x, for the light.

## .set POLY_LNY

`f32`: the normal's y.

## .set POLY_LNZ

`f32`: the normal's z.

## .set POLY_SECTOR

`u32`: the surface's sector, for the light.

## .set POLY_FLAT_LIT

`u64`: set for a surface lit at no angle, a sprite facing the camera, every light within reach lighting it by its falloff alone.

## .set POLY_LIGHTS

`32 u8`: the polygon's own light list, a count byte then that many light indices.

The sector's list culled to the lights whose sphere meets the polygon's
world box and which lie ahead of its plane, shaped as a sector's list is,
SECTOR_LIGHTS_SIZE bytes.

## .set POLY_LUMAP

`addr`: the surface's lumel map record, 0 for a polygon with no map, a sprite lit flat by POLY_FLAT_BRIGHT.

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

`u64`: the read's one word for a mapped polygon, packed by the LUMEL_* shifts.

The lumels' offset into the arena in the low LUMEL_OFFSET_BITS, a row's
bytes from LUMEL_ROWBYTES_SHIFT, the rows from LUMEL_ROWS_SHIFT, and k, the
lumel's texels as a power of two, from LUMEL_K_SHIFT; the columns and rows
bound the read, a texel coordinate past the map's last node or before its
first reading the node there.

## .set POLY_FLAT_BRIGHT

`u64`: the brightness word of a polygon with no map.

## .set POLY_TILES

`4 addr`: each level's atlas, TILE_LEVEL_COUNT of them.

The atlases sit eight bytes apart, one a level.

## .set POLY_TILE_READY

`u64`: the levels built whole, which a span's levels stay under.

## .set POLY_TILE_COLS_SHIFT

`u64`: a cell row's tiles as a shift, the columns padded to a power of two.

## .set POLY_TILE_COLS

`u64`: the cells across, which a span's ends lie within.

## .set POLY_TILE_ROWS

`u64`: the cells down, which a span's ends lie within.

## .set POLY_MATERIAL

`u32`: the material bound, for the level's alpha scale at a tile's build.

## .set POLY_SURFACE

`u64`: the surface the polygon is, for the span record and the owner build.

A plane at twice its sector's index and its ceiling after and a wall at
LUMAP_PLANES past them, as the lumel maps are indexed, a map sprite at
SURFACE_SPRITES plus its entity, an actor at SURFACE_ACTORS plus its index.

POLY_SURFACE names the polygon as a surface in one index space: the lumel
maps' order for planes and walls, then the map sprites by entity, then the
actors by index, so the span record and the owner build name a surface in
one word and a reader of either can tell a wall from a sprite.

## .set POLY_MIPS

`addr`: the material's chain, its table of a level's texels eight bytes a level.

The chain's table is mip.S's.

## .set POLY_MIP_COUNT

`u64`: the levels the chain has, which a block's level is held under.

## .set POLY_SIZE

The polygon in hand's bytes.

## .set LUMEL_OFFSET_BITS

The read's word's low bits holding the lumels' offset into the arena.

## .set LUMEL_ROWBYTES_SHIFT

The place of a row's bytes in the read's word.

## .set LUMEL_ROWS_SHIFT

The place of the rows in the read's word.

## .set LUMEL_K_SHIFT

The place of k in the read's word.

## .set LUMEL_K_MAX

K at most.

## .set CHANNEL_BITS

The distance between a brightness word's three 16.16 channels.

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

`addr`: a lumel map's lumels in the arena, 0 for none.

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

## .set LUMAP_W

`u64`: its columns.

## .set LUMAP_H

`u64`: its rows.

## .set LUMAP_U0

`i64`: the texel u of its first node.

## .set LUMAP_V0

`i64`: the texel v of its first node.

## .set LUMAP_K

`u64`: k, a lumel being 2^k texels along both axes.

## .set LUMAP_SIZE

A lumel map record's bytes.

## .set LUMAP_PLANES

The planes' maps, a sector's floor at twice its index and its ceiling after.

The maps by surface: a sector's floor at twice its index and its ceiling
after, then the walls; a lumel is one word, the grid's spacing in metres is
near k_lumel_d, and the arena holds every map.

## .set LUMAP_COUNT

Every surface's map, the walls after the planes.

## .set LUMEL_BYTES

A lumel's bytes.

## .set LUMEL_ARENA_BYTES

The arena holding every map's lumels.

## .set SURFACE_SPRITES

The first map sprite's surface index, a map sprite at it plus its entity.

## .set SURFACE_ACTORS

The first actor's surface index, an actor at it plus its index.

## .set RECT_X0

`i32`: a screen rectangle's first column.

The screen rectangle is four words with its ends past the last, as the fill
bounds its rows and spans.

## .set RECT_X1

`i32`: the column past its last.

## .set RECT_Y0

`i32`: its first row.

## .set RECT_Y1

`i32`: the row past its last.

## .set RECT_SIZE

A rectangle's bytes, empty when an end is at or before its start.

## .set FLOW_RING

The flow's queue, a ring of sector indices twice the sectors long.

The ring is twice the sectors long so its read and its write never meet
while sectors wait, the most that can wait being every sector once.

## .set FLOW_RING_MASK

The ring's index mask.

## .set SPAN_ROW

`u16`: a span record's row.

A span the fill emits before drawing it. SPAN_RECORDS of them a frame; the
count runs on past the table when a frame has more, and a reader of a frame
whose count passed the table falls back, since the prefix it holds is not the
frame.

The span record is the fill's output before drawing, its row and ends in
sixteen bits with the mode beside them and the surface and the polygon's
serial in a word each, sized for the frames measured and counted past its
end rather than stopped, the count past the table meaning a reader falls
back for that frame.

## .set SPAN_X0

`u16`: the span's first pixel.

## .set SPAN_X1

`u16`: the pixel past its last.

## .set SPAN_MODE

`u16`: the polygon's mode.

## .set SPAN_SURFACE

`u32`: the surface, the stable index.

## .set SPAN_POLY

`u32`: the polygon's serial in the frame, telling a masked opening's fill from its wall's pieces.

## .set SPAN_RECORD_SIZE

A span record's bytes.

## .set SPAN_RECORDS

The records a frame holds, the count running on past them.

## .set GRID_O

`3 f64`: the world point at texel (0, 0) of the surface's mapping.

The frame a map is baked over, in texels. A node's point is the origin plus
its texel coordinate along each step.

## .set GRID_U

`3 f64`: the world step a texel along u.

## .set GRID_V

`3 f64`: the world step a texel along v.

## .set GRID_N

`3 f32`: the unit normal into the room.

## .set GRID_SIZE

The bake's frame's bytes.

## .set INTERVAL_SHIFT_MAX

The shift of a lit span's longest sample interval, four blocks.

A lit span samples its map at the ends of intervals of 1, 2, or 4 blocks,
the shift of the interval's pixels 4 to INTERVAL_SHIFT_MAX, chosen so a lumel
spans at least two samples: the longest whose pixels times the texel step a
pixel stay within half a lumel.

The interval constants size the cadence: a lit span samples at the ends of
one, two, or four blocks, INTERVAL_SHIFT_MAX being four blocks' shift, by the
texel step a pixel against the lumel's 2^k texels.

## .set POLY_TEXTURED

`u64`: the mode textured.

## .set POLY_MASKED

`u64`: the mode masked.

## .set POLY_SKY

`u64`: the mode the sky.

## .set POLY_LIT

`u64`: a flag over the textured and masked modes, the span lit.

## .set POLY_TILED

`u64`: a flag over a lit mode, the surface's tiles read.

The surface has tiles, the lit texture cached, which a near block of the span
reads in place of the texture and the lumel map when its cells are built.

## .set TILE_LEVEL_COUNT

The levels of a surface's tiles at most.

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

## .set TILE_BASE

`4 addr`: each level's atlas, 0 before it is reserved and -1 for a surface past TILE_ATLAS_MAX.

## .set TILE_READY

`u64`: the levels built whole.

## .set TILE_CURSOR

`u64`: the next cell to build at the level in hand.

## .set TILE_LEVELS

`u64`: the levels the surface has, TILE_LEVEL_COUNT or k + 1, the fewer.

## .set TILE_COLS_SHIFT

`u64`: a cell row's tiles as a shift.

## .set TILE_COLS

`u64`: the cells across, the map's nodes.

## .set TILE_ROWS

`u64`: the cells down, the map's nodes.

## .set TILE_CELLS

`u64`: the cells, the rows by the padded columns.

## .set TILE_SIZE

A tile record's bytes.

## .set TILE_ARENA_BYTES

The tile arena's bytes.

## .set TILE_ATLAS_MAX

The largest level 0 atlas, a surface past it staying on the lit loop.

## .set TILE_BUDGET

The texture's texels a frame's builds may read.

## .set TILE_BUDGET_UNBOUND

A budget no frame reaches.

## .set MIP_LEVELS

A chain's levels at most.

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

## .set MIP_ENTRY

A material's chain table's bytes, a level's texels eight bytes a level.

## .set MIP_ARENA_BYTES

The chains' arena's bytes.

## .set ALPHA_PASS

`u8`: the alpha at or above which a masked texel passes, at every level.

A material's alpha scale a level, 16.16, by which a coarser level's mean
alpha is scaled at a tile's or a chain level's build so the level's share of
texels passing stays near the texture's: ceil(2^23 / T) for the threshold T
the load's search chose, which lands a mean at or above T at or above the
pass and nothing under T there; one, ALPHA_SCALE_ONE, where the levels pass
as the texture does; a scale a level of the chain.

## .set ALPHA_SCALE_BITS

An alpha scale's fraction bits.

## .set ALPHA_SCALE_ONE

`u32`: a scale of one, the levels passing as the texture does.

## .set ALPHA_SCALE_TOP

`u32`: 2^23, a scale being ceil(ALPHA_SCALE_TOP / T).

## .set ALPHA_LEVEL_SIZE

A level's scale's bytes.

## .set ALPHA_MATERIAL_SIZE

A material's scales' bytes, a scale a level of the chain.

## .set ALPHA_PLANE_BYTES

The scratch a level's alphas take at the search, a texture past it left at one.

## .set ALPHA_SHARE

The unit the debug line reports a share in.

## .set MAX_LIGHTS

The lights the engine holds at most.

## .set LIGHT_X

`f32`: a light's x.

## .set LIGHT_Y

`f32`: its y.

## .set LIGHT_Z

`f32`: its z.

## .set LIGHT_R

`f32`: its colour's red.

## .set LIGHT_G

`f32`: its colour's green.

## .set LIGHT_B

`f32`: its colour's blue.

## .set LIGHT_RADIUS2

`f32`: its radius squared.

## .set LIGHT_AXIS

`3 f32`: a spotlight's unit axis.

## .set LIGHT_COS

`f32`: the cosine of its spread, under -1 for a point light.

## .set LIGHT_OVER_RADIUS

`f32`: one over its radius.

## .set LIGHT_SIZE

A light's bytes.

## .set SECTOR_LIGHTS_MAX

A sector's lights at most.

## .set SECTOR_LIGHTS_SIZE

A sector's list's bytes, a count byte then that many light indices.

## .set PLANE_N

`3 f32`: the plane in hand's normal.

## .set PLANE_Q

`3 f32`: a point on it.

## .set PLANE_AU

`3 f32`: u's world gradient in texture repeats.

## .set PLANE_U0

`f32`: u's offset in texture repeats.

## .set PLANE_AV

`3 f32`: v's world gradient in texture repeats.

## .set PLANE_V0

`f32`: v's offset in texture repeats.

## .set PLANE_SIZE

The plane in hand's bytes.

## .set PLANED_N

`3 f64`: the normal as doubles.

## .set PLANED_Q

`3 f64`: the point as doubles.

## .set PLANED_AU

`3 f64`: u's gradient as doubles.

## .set PLANED_U0

`f64`: u's offset as a double.

## .set PLANED_AV

`3 f64`: v's gradient as doubles.

## .set PLANED_V0

`f64`: v's offset as a double.

## .set PLANED_SIZE

plane_d's bytes, at twice the plane's offsets.

## .set DEPTH_BITS

1/z's fraction bits, 6.26.

## .set Z_SHIFT

Z as 2^Z_SHIFT over 1/z, 48.16.

## .set BLOCK

A span block's pixels.

## .set IZ_MIN

`u32`: the least 1/z a divide takes, a smaller one clamped to it.

## .set SKY_DEPTH

`u32`: the depth a sky pixel stores, so anything drawn later overwrites it.

## .set STAT_SECTORS

`u64`: the frame's sectors drawn.

The frame's counts and its ticks by phase, 64 bits each.

The stats record grew its span, pixel, and light-tick fields for the light's
instrument, then the rejected-pixel count, then the lumel samples; a field is
added by extending the record, zeroed in world_draw, and printed by
frame_report, with the test's frame template extended to match, since the
template names every field. STAT_TILE_TICKS is the tiles' time inside the
planes' and the walls' phases, a reservation with any reset it makes and
each cell built or shrunk, and is never added to them.

## .set STAT_WALLS

`u64`: its walls drawn.

## .set STAT_PIECES

`u64`: its wall pieces filled.

## .set STAT_PLANES

`u64`: its planes filled.

## .set STAT_OPENINGS

`u64`: its openings flowed.

## .set STAT_CLEAR_TICKS

`u64`: the depth clear's ticks.

## .set STAT_PLANE_TICKS

`u64`: the planes' ticks.

## .set STAT_WALL_TICKS

`u64`: the walls' ticks.

## .set STAT_PORTAL_TICKS

`u64`: the flow's ticks.

## .set STAT_SPRITES

`u64`: the sprites filled.

## .set STAT_SPRITE_TICKS

`u64`: the sprites' and actors' ticks.

## .set STAT_SPANS

`u64`: the spans filled.

## .set STAT_PIXELS

`u64`: the pixels they entered.

## .set STAT_LIT_SPANS

`u64`: the lit spans among them.

## .set STAT_LIT_PIXELS

`u64`: the lit pixels among them.

## .set STAT_LIGHT_TICKS

`u64`: the ticks the light's evaluation took.

## .set STAT_REJECTED

`u64`: the pixels the depth test rejected.

## .set STAT_SAMPLES

`u64`: the lumel samples the lit spans read.

## .set STAT_TILES_BUILT

`u64`: the tiles built this frame.

## .set STAT_TILED_PIXELS

`u64`: the pixels read from tiles.

## .set STAT_TILE_RESETS

`u64`: the tile arena's resets since the load, never zeroed by the frame.

## .set STAT_TILE_TICKS

`u64`: the tiles' ticks, reserving, building, and shrinking, within the planes' and the walls'.

## .set STAT_SIZE

The stats' bytes.

## .set REPORT_KIND

`u32`: a record's kind over the API, a REPORT_*.

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

## .set REPORT_SECTOR

`i32`: the camera's sector, or the console's command byte.

## .set REPORT_FRAME_NUMBER

`u32`: a clock record's frame, from 0.

## .set REPORT_X

`f32`: the eye's x.

## .set REPORT_Y

`f32`: the eye's y.

## .set REPORT_Z

`f32`: the eye's z.

## .set REPORT_YAW

`f32`: the yaw in degrees.

## .set REPORT_PITCH

`f32`: the pitch in degrees.

## .set REPORT_ROLL

`f32`: the roll in degrees.

## .set REPORT_FRAME_US

`u32`: the last frame's drawing in microseconds.

## .set REPORT_GAME_US

`u32`: the last frame's game in microseconds.

## .set REPORT_FIELD0

`i32`: an event's first field.

## .set REPORT_FIELD1

`i32`: an event's second field.

## .set REPORT_FIELD2

`i32`: an event's third field.

## .set REPORT_FIELD3

`i32`: an event's fourth field.

## .set REPORT_FIELD4

`i32`: an event's fifth field.

## .set REPORT_SCHEMA

`u32`: a clock record's layout, REPORT_SCHEMA_VERSION.

## .set REPORT_SIZE

A record's bytes, zero to the end.

## .set REPORT_STATE

`u32`: the state, a record a frame.

## .set REPORT_ROUND

`u32`: a round of the player's, what it met, the actor, its health after.

## .set REPORT_ANDROID

`u32`: an android's event, the event, the actor, its row.

## .set REPORT_HURT

`u32`: the player struck, the damage, the health after.

## .set REPORT_PICKUP

`u32`: a pickup, the rounds after.

## .set REPORT_TRACE

`u32`: a trace's answer, the kind met, the distance and the point in millimetres.

## .set REPORT_FRAME

`u32`: the frame before's clock, TIME_* fields, at each frame's start.

## .set REPORT_DRAW

`u32`: the frame before's drawing and tile cache, DRAW_* fields, beside it.

## .set REPORT_END

`u32`: the measurement's end, its final frame, after that frame's records.

## .set REPORT_CONSOLE

`u32`: the console's answer, the command's byte.

## .set REPORT_SCHEMA_VERSION

`u32`: the clock records' layout as this source lays them out.

## .set TIME_START

`u64`: the frame's start, microseconds since the program's.

## .set TIME_CRITICAL

`u32`: its start to the end of its reporting, the await apart.

## .set TIME_GAME

`u32`: the game's phases, as REPORT_GAME_US.

## .set TIME_DRAW

`u32`: world_draw, as REPORT_FRAME_US.

## .set TIME_HUD

`u32`: the crosshair.

## .set TIME_MIX

`u32`: mixer_update.

## .set TIME_FLIP

`u32`: the flip call, the device's wait in it.

## .set TIME_REPORT

`u32`: the reporting, the frame before's records and its own state's.

## .set TIME_AWAIT

`u32`: the time inside the await call.

## .set TIME_FLIP_DONE

`u64`: the flip's return, microseconds since the program's start.

## .set TIME_FLIP_STATUS

`u32`: jab.sys.display.flip's code, 0 presented.

## .set DRAW_CLEAR

`u32`: the depth clear.

## .set DRAW_PORTALS

`u32`: the flow through the portals.

## .set DRAW_PLANES

`u32`: the planes, their tiles' time within.

## .set DRAW_WALLS

`u32`: the walls, their tiles' time within.

## .set DRAW_SPRITES

`u32`: the sprites and the actors.

## .set DRAW_TILES

`u32`: the tiles' time, STAT_TILE_TICKS.

## .set DRAW_TILES_BUILT

`u32`: the cells built or shrunk.

## .set DRAW_TILE_RESETS

`u32`: the arena's resets since the load.

## .set DRAW_TILED_PIXELS

`u32`: the pixels of blocks read from tiles.

## .set DRAW_LIT_PIXELS

`u32`: the pixels of lit spans.

## .set DRAW_TILE_BYTES

`u32`: the arena in use at the frame's end.

## .set DRAW_TILE_PEAK

`u32`: the most the arena has held since the load.

## .set DRAW_SPANS

`u32`: the spans drawn, against SPAN_RECORDS.

## .set EVENT_ROUSED

`u32`: an android roused.

## .set EVENT_FIRED

`u32`: an android's round fired.

## .set EVENT_STRUCK

`u32`: an android struck.

## .set EVENT_DESTROYED

`u32`: an android destroyed.

## .set EVENT_FALLEN

`u32`: an android fallen, its magazine dropped.

## .set EVENT_WAYPOINT

`u32`: an android at its waypoint.

## .set MAX_ACTORS

The actors in play at most.

## .set ACTOR_CLASS

`u32`: an actor's class, an ACTOR_*, ACTOR_NONE free.

## .set ACTOR_FLAGS

`u32`: the flags, ACTOR_SOLID, ACTOR_SHOOTABLE, ACTOR_ROUSED, ACTOR_SIGHTED, and ACTOR_FIRST.

## .set ACTOR_X

`f64`: the feet's x.

## .set ACTOR_Y

`f64`: the feet's y.

## .set ACTOR_Z

`f64`: the feet's z.

## .set ACTOR_YAW

`f32`: the yaw in radians.

## .set ACTOR_SECTOR

`i32`: the sector.

## .set ACTOR_ROW

`u32`: the row.

## .set ACTOR_TIMER

`f32`: the row's timer in seconds.

## .set ACTOR_HEALTH

`i32`: the health.

## .set ACTOR_TARGET

`i32`: the target waypoint entity or -1.

## .set ACTOR_FALL

`f64`: the fall speed.

## .set ACTOR_SEEN_X

`f64`: the last sight's x, the player's feet.

## .set ACTOR_SEEN_Y

`f64`: the last sight's y.

## .set ACTOR_SEEN_Z

`f64`: the last sight's z.

## .set ACTOR_BLOCKED

`f32`: the seconds blocked.

## .set ACTOR_FRAME

`u32`: a spark's frame.

## .set ACTOR_LOST

`f32`: the seconds since the sight was lost.

## .set ACTOR_ENTITY

`u32`: the entity it came from.

## .set ACTOR_SIZE

An actor's bytes.

## .set ACTOR_NONE

`u32`: free.

## .set ACTOR_ANDROID

`u32`: an android.

## .set ACTOR_MAGAZINE

`u32`: a magazine.

## .set ACTOR_SPARK

`u32`: a spark.

## .set ACTOR_SOLID

`u32`: a body the others are pushed out of.

## .set ACTOR_SHOOTABLE

`u32`: a round can strike it.

## .set ACTOR_ROUSED

`u32`: roused.

## .set ACTOR_SIGHTED

`u32`: the player sighted.

## .set ACTOR_FIRST

`u32`: the first round after rousing, which is certain, the rest by chance.

## .set FIRE_CHANCE

A round's chance in 256 after the first.

## .set SET_STAND

`u32`: the android's standing set.

The engine's images by frame index: the android's eight rotating sets of
eight, then the fallen frame, the three sparks, and the magazine; a frame's
material index is frame_base plus its frame index.

## .set SET_WALK1

`u32`: its walk's first set.

## .set SET_WALK2

`u32`: its walk's second set.

## .set SET_WALK3

`u32`: its walk's third set.

## .set SET_WALK4

`u32`: its walk's fourth set.

## .set SET_AIM

`u32`: its aiming set.

## .set SET_FIRE

`u32`: its firing set.

## .set SET_STRUCK

`u32`: its struck set.

## .set SET_FALLEN

`u32`: the fallen frame, a set of one.

## .set FRAME_FALLEN

The fallen frame's index, after the eight rotating sets of eight.

## .set FRAME_SPARK1

The first of the three sparks' frames.

## .set FRAME_MAGAZINE

The magazine's frame.

## .set FRAME_COUNT

The engine's images.

## .set SPARK_FRAMES

A spark's frames.

## .set ROW_SET

`u32`: a row's frame set.

## .set ROW_MS

`i32`: the milliseconds it lasts, -1 for a held row.

## .set ROW_ACTION

`u32`: the action on entry, an ACT_*.

## .set ROW_NEXT

`u32`: the row next.

## .set ROW_SIZE

A row's bytes.

## .set ROW_STAND

`u32`: standing.

## .set ROW_PATROL1

`u32`: a patrol's first step.

## .set ROW_PATROL2

`u32`: a patrol's second step.

## .set ROW_PATROL3

`u32`: a patrol's third step.

## .set ROW_PATROL4

`u32`: a patrol's fourth step.

## .set ROW_ALERT

`u32`: alerted.

## .set ROW_AIM

`u32`: aiming.

## .set ROW_FIRE

`u32`: firing.

## .set ROW_SEARCH1

`u32`: a search's first step.

## .set ROW_SEARCH2

`u32`: a search's second step.

## .set ROW_SEARCH3

`u32`: a search's third step.

## .set ROW_SEARCH4

`u32`: a search's fourth step.

## .set ROW_STRUCK

`u32`: struck.

## .set ROW_DESTROYED

`u32`: destroyed.

## .set ROW_FALLEN

`u32`: fallen, held.

## .set ACT_NONE

`u32`: nothing on entry, action_none.

## .set ACT_LOOK

`u32`: action_look.

## .set ACT_WALK

`u32`: action_walk.

## .set ACT_ALERT

`u32`: action_alert.

## .set ACT_AIM

`u32`: action_aim.

## .set ACT_FIRE

`u32`: action_fire.

## .set ACT_SEEK

`u32`: action_seek.

## .set ACT_STRUCK

`u32`: action_struck.

## .set ACT_DESTROY

`u32`: action_destroy.

## .set ACT_FALL

`u32`: action_fall.

## .set ANDROID_HEALTH

`i32`: an android's health at the start.

## .set AIM_OX

`f64`: the actor's eye's x.

## .set AIM_OY

`f64`: the actor's eye's y.

## .set AIM_OZ

`f64`: the actor's eye's z.

## .set AIM_DX

`f64`: the unit direction's x toward the player's eye.

## .set AIM_DY

`f64`: the unit direction's y.

## .set AIM_DZ

`f64`: the unit direction's z.

## .set AIM_DIST

`f64`: the distance.

## .set AIM_SIZE

The line's bytes.

## .set TRACE_NONE

`u64`: nothing met.

## .set TRACE_PLANE

`u64`: a plane met.

## .set TRACE_PIECE

`u64`: a wall piece met.

## .set TRACE_ANDROID

`u64`: an android met.

## .set TRACE_PLAYER

`u64`: the player met.

## .set TRACE_KIND

`u64`: what the ray met, a TRACE_*.

## .set TRACE_DIST

`f64`: the distance.

## .set TRACE_PX

`f64`: the point's x.

## .set TRACE_PY

`f64`: the point's y.

## .set TRACE_PZ

`f64`: the point's z.

## .set TRACE_ACTOR

`addr`: the actor met.

## .set TRACE_SECTOR

`u64`: the sector the ray ended in.

## .set TRACE_SIZE

A trace's answer's bytes.

## .set TRACE_TO_PLAYER

`u64`: the trace tests the player's capsule too.

## .set TRIGGER_BIT

`u32`: the pad's key that fires, the right trigger's button, as its bit in the state record's keys.

## .set ROUND_DAMAGE

`i32`: what the G-1's round takes from its target, on either side.

## .set SOUND_G1_SHOT

`u64`: the G-1's shot.

## .set SOUND_G1_RELOAD

`u64`: the G-1's reload.

## .set SOUND_G1_EMPTY

`u64`: the G-1 empty.

## .set SOUND_G1_BOLT

`u64`: the G-1's bolt.

## .set SOUND_FOOTSTEP1

`u64`: a footstep.

## .set SOUND_FOOTSTEP2

`u64`: the other footstep.

## .set SOUND_SERVO

`u64`: an android's servo.

## .set SOUND_ALERT

`u64`: an android's alert.

## .set SOUND_SPARK

`u64`: a spark.

## .set SOUND_STRUCK

`u64`: an android struck.

## .set SOUND_DESTROY

`u64`: an android destroyed.

## .set SOUND_PICKUP

`u64`: a pickup.

## .set SOUND_DOOR_OPEN

`u64`: a door opening.

## .set SOUND_DOOR_CLOSE

`u64`: a door closing.

## .set SOUND_GATE

`u64`: a gate.

## .set SOUND_RESPAWN

`u64`: a respawn.

## .set SOUND_COUNT

The engine's stems.

## .macro owner_pixel

Under OWNER a pixel loop stores the surface's index in place of its colour,
from the slot span_fill's prologue fills, so a capture reads which surface
won each pixel; the crosshair stays off. The owner_pixel macro is a load from
span_fill's slot under OWNER and nothing otherwise, so the pixel loops carry
the instrument at no cost to a normal build.
