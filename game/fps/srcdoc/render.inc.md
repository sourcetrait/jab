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

`u64`: a POLY_TEXTURED, POLY_MASKED, or POLY_SKY, with POLY_LIT over it.

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

## .set POLY_SURFACE

`u64`: the surface the polygon is, for the span record, the tile pool's directory, and the owner build.

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

A polygon's record's bytes, and a command's in a packet: 232 from the tile pool on, 312 while the record carried its tile bindings and its material.

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

A span the fill records into the frame's packet, which the packet's render
draws in order. SPAN_RECORDS of them a packet; a full packet is rendered
whole and emptied before the fill goes on, so a frame of more spans is
several packets and every span is drawn, never a prefix.

The span record is the fill's output, its row and ends in sixteen bits with
the mode beside them and the surface and the command's index in a word
each.

## .set SPAN_X0

`u16`: the span's first pixel.

## .set SPAN_X1

`u16`: the pixel past its last.

## .set SPAN_MODE

`u16`: the polygon's mode.

## .set SPAN_SURFACE

`u32`: the surface, the stable index.

## .set SPAN_POLY

`u32`: the span's command, its index in the packet's table, telling a masked opening's fill from its wall's pieces.

## .set SPAN_RECORD_SIZE

A span record's bytes.

## .set SPAN_RECORDS

The records a packet holds.

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

## .set MIP_LEVELS

A chain's levels at most.

A material's mip chain: the texels of each level from 1, level 0 the
record's own, each level half a side of the one before, built at load by the
tile shrink's rule under the level's alpha scale (mip.S), so a lit or unlit
span reads the level a block's footprint asks for and the lit loop and a tile
at one level hold the same texel. A level is added while both sides of the
one before are two texels or more and the arena holds it, so a side can end
at one texel, the fence's 1 by 4 at level 8; MIP_LEVELS is a cap of its own
apart from that limit.

The mip constants: MIP_LEVELS is the chain's depth at most, ten taking a
512-texel side to one; the entry is a level's texels eight bytes a level; the
arena is 32 MiB in bss, free until touched, where Render Zero's chains take
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

## .set BLOCK_SHIFT

BLOCK's power of two: a full block's steps are shifted by it.

## .set BLOCK

A span block's pixels.

## .set IZ_MIN

`u32`: the least 1/z a divide takes, a smaller one clamped to it.

## .set SKY_DEPTH

`u32`: the depth a sky pixel stores, so anything drawn later overwrites it.

## .set WORKERS_MAX

The raster's workers at most, each on a secondary hart of its own.

The raster's workers (workers.S): started once after the load on the
lowest online secondaries, each with its mailbox (`jab_jobs.inc`), a
context, and a stack; a frame renders each packet in a round, the frame's
workers each rendering whole bands of rows. Two, harts 1 and 2 on the
specification's four, the third secondary left for the game and its
services.

## .set WORKER_STACK

A worker's stack's bytes.

## .set GRAIN_DEFAULT

`u32`: the rows a band until a console W chooses, 0 for a band a worker.

Thirty-two, the screen's 1080 rows in 34 bands, the last 24 rows. Measured
with the program's gauge on its settled route, two workers drew the still
views in the least raster time taken together at 32 rows, against a band
a worker and bands of 16, 64, and 128 rows. A band a worker left the
slowest worker up to a millisecond and a quarter a frame past the
workers' mean; at 32 rows it stayed within a tenth of one.

## .set ROUND_COMMANDS

`u32`: the round's packet's commands.

The round record, hart 0's, published with each job of the round: what
the packet holds, the workers, the grain and the bands it makes, and the
clear. A worker reads it after its await and nothing else hart 0 keeps.

## .set ROUND_SPANS

`u32`: the packet's spans.

## .set ROUND_WORKERS

`u32`: the round's workers, the frame's.

## .set ROUND_GRAIN

`u32`: the rows a band, 0 for a band a worker.

## .set ROUND_BANDS

`u32`: the bands, the workers for a band a worker, else the screen's rows over the grain, the last band short.

## .set ROUND_FLAGS

`u32`: ROUND_CLEAR on the frame's first round.

## .set ROUND_DELAY_WORKER

`u32`: on a debug build, the J frame's held worker's index plus one, 0 for none.

## .set ROUND_DELAY_US

`u32`: its hold before each band in microseconds.

## .set ROUND_FAULT_WORKER

`u32`: on a debug build, the J frame's faulting worker's index plus one for this round alone, 0 for none.

## .set ROUND_SIZE

The round record's bytes, a line.

## .set ROUND_CLEAR

`u32`: the round clears each band's depth before its spans, and on a debug build prepaints its pixels.

## .set JOB_START

`u64`: a worker's clock when its await took the round's job, in its mailbox's own words.

## .set JOB_END

`u64`: its clock before its completion.

## .set JOB_BANDS

`u64`: the bands it rendered in the round.

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

`u64`: the depth clear's ticks on hart 0, 0 when the workers' first round clears each band.

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

`u64`: the whole tiles the frame's boundary published, at any level.

## .set STAT_TILED_PIXELS

`u64`: the pixels read from tiles.

## .set STAT_TILE_RESETS

`u64`: the pool's forgets since the load, the console's L alone, never zeroed by the frame.

## .set STAT_TILE_TICKS

`u64`: the tile pool's boundary's ticks, the whole of it, a part of the drawing apart from every phase.

## .set STAT_RASTER_TICKS

`u64`: the packets' renders' ticks, a flush's with the last's, no preparation phase's.

The spans', pixels', lit, rejected, samples', and tiled counts are the
contexts' summed after each render; the phases before the raster are
preparation's, the planes', the walls', and the sprites' marked so a flush
inside one is no part of it (world.S's phase_mark).

## .set STAT_COMMANDS

`u64`: the commands the frame's packets held, a polygon's again after a flush in its spans.

## .set STAT_FLUSHES

`u64`: the packets rendered before preparation ended, full of commands or spans.

## .set STAT_DISPATCH

`u64`: the rounds' dispatch, each the latest worker's start less hart 0's clock before its first publish.

The rounds' times are the jobs' bench's definitions (kernel FourHarts'
JobCosts), each summed over the frame's rounds, 0 on a frame the serial
backend drew.

## .set STAT_BARRIER

`u64`: the rounds' barrier, each hart 0's clock after its joins less the latest worker's end.

## .set STAT_SLOWEST

`u64`: the rounds' slowest workers, each round's greatest time from a worker's start to its end.

## .set STAT_BUSY

`u64`: every worker's time from its start to its end, every round's.

## .set STAT_ROUNDS

`u64`: the rounds, the renders the workers took.

## .set STAT_CANCELLED

`u64`: the rounds a job of was cancelled, their left bands finished on hart 0.

## .set STAT_TILE_ADMITTED

`u64`: the tile requests the frame's contexts admitted while it rendered, summed after each render.

## .set STAT_TILE_DROPPED

`u64`: the requests a full open ring dropped.

## .set STAT_TILE_FILTERED

`u64`: the requests the repeat filter or a surface's own tier turned away as asked already.

## .set STAT_TILE_HITS

`u64`: the blocks read from a READY tile.

## .set STAT_TILE_STRADDLING

`u64`: the blocks with tiles whose first and last sampled pixels lie in two tiles, which ask for none.

## .set STAT_TILE_MISSES

`u64`: the blocks eligible for one tile inside the grid drawn without it, not READY, each asking for it; a block drawing no pixel is counted nowhere.

## .set STAT_TILE_BUILD_TICKS

`u64`: the boundary's construction, within STAT_TILE_TICKS.

## .set STAT_TILE_OVERRUN

`u64`: the boundary's ticks past its allowance, 0 under the L's lift.

## .set STAT_TILE_EVICTED

`u64`: the slots CLOCK retired at the boundary.

## .set STAT_TILE_MERGED

`u64`: the batch's requests merged at the boundary, each tile once.

## .set STAT_TILE_UNPROCESSED

`u64`: the batch's requests the merge never took, past its share or its list's end, or a stalled frame's batch whole.

## .set STAT_BANDS

`WORKERS_MAX u64`: the bands each worker rendered over the frame's rounds.

## .set STAT_SIZE

The stats' bytes.

## .set COUNT_DIVIDES

`u64`: on a COUNT build, the divides span_fill made this frame.

The count record, count_stats in raster.S, the instrument of MapperDivides'
proof: zeroed in world_draw beside the stats, raised by count_add, and
printed by count_report after the frame line, on a COUNT build alone. The
divides span_fill made before a change are the made plus the avoided.

## .set COUNT_AVOIDED

`u64`: the divides a change avoided, each recomputed for its comparison.

## .set COUNT_SHIFTED

`u64`: the full blocks whose steps were shifted.

## .set COUNT_SHORT

`u64`: the short last blocks, which divide.

## .set COUNT_NEGATIVE_U

`u64`: the full blocks whose u difference was negative and not a multiple of 16.

## .set COUNT_NEGATIVE_V

`u64`: the same for v.

## .set COUNT_FLAT

`u64`: the spans whose 1/z held along the row, POLY_IZA zero.

## .set COUNT_MISMATCHES

`u64`: the results that differed from their references, which must stay 0.

## .set COUNT_SIZE

The count record's bytes.

## .set MAX_COMMANDS

The commands a packet holds, a packet full of them rendered and emptied before the next.

The packet is the frame's draw commands and spans as preparation publishes
them (raster.S): a command a polygon's record copied whole, POLY_SIZE bytes,
a span record its row, ends, mode, surface, and command. A frame fills a
polygon a plane, a wall piece, an opening, and a sprite in view; the bound
is the table's, and a frame past it flushes.

## .set CTX_COMMAND

`addr`: the raster context's command in hand, which span_fill reads in place of the polygon.

A raster context is a renderer's own: the command in hand and the counts
span_fill keeps, so contexts share nothing span_fill writes but the pixels
and the depths of the rows each owns. Hart 0's is raster_context and a
worker's its own of worker_contexts, each reached through tp.

## .set CTX_SPANS

`u64`: the context's spans since its counts were last summed.

## .set CTX_PIXELS

`u64`: the pixels they entered.

## .set CTX_LIT_SPANS

`u64`: the lit spans among them.

## .set CTX_LIT_PIXELS

`u64`: the lit pixels among them.

## .set CTX_REJECTED

`u64`: the pixels the depth test rejected.

## .set CTX_SAMPLES

`u64`: the lumel samples read.

## .set CTX_TILED_PIXELS

`u64`: the pixels read from tiles.

## .set CTX_TILE_ADMIT

`addr`: the context's admission block in tile_admission, set at load (tiles_init).

## .set CTX_TILE_TOUCHED

`addr`: the context's touched-slot bitmap, within its admission block.

## .set CTX_TILE_ADMITTED

`u64`: the requests the context admitted since its counts were last summed.

## .set CTX_TILE_DROPPED

`u64`: the requests its full open ring dropped.

## .set CTX_TILE_FILTERED

`u64`: the requests it turned away as asked already.

## .set CTX_TILE_HITS

`u64`: its blocks read from a READY tile.

## .set CTX_TILE_STRADDLING

`u64`: its straddling blocks with tiles.

## .set CTX_TILE_MISSES

`u64`: its eligible blocks drawn without their tile, each asking for it.

## .set CTX_COUNT

`COUNT_SIZE u8`: a COUNT build's counts, COUNT_* fields, the context's.

## .set CTX_SHIFT

`u64`: a raster context's bytes as a shift, so a worker's context is its index shifted, where its mailbox, JAB_JOB_BYTES apart, is its index shifted by seven.

## .set CTX_SIZE

A raster context's bytes, the counts span_fill keeps, the tile pool's fields, and a COUNT build's counts.

## .set TILE_SHIFT

## .set TILE_SIDE

`u64`: a tile's texels a side as a shift, and the side, 64.

The tile pool (tile.S) caches the lit texture a tile at a time: a tile is
TILE_SIDE texels square at one level of the material's chain, in the surface's
lumel frame. The census shortlisted 32 and 64 from the tiles each would ask
and the pixels each would leave straddling. On release batteries interleaved
between the two, 64 drew every settled view and every played leg of the
factory route faster, by 0.14 to 0.86 ms at the median, its boundary half
32's on a steady frame, its cold under an L's lift up to 3 ms longer on five
views of seven.

## .set TILE_ROW_SHIFT

`u64`: a tile row's bytes as a shift, four bytes a texel.

## .set TILE_BYTES_SHIFT

## .set TILE_BYTES

`u64`: a tile's bytes as a shift, and the bytes, 16 KiB at 64.

## .set TILE_POOL_BYTES

`u64`: the pool's bytes, every slot a tile.

32 MiB holds the census's 30-frame working set of the walls with their
openings at its 95th percentile, 1,750 tiles at 64 at two workers, in 2,048
slots; the working set's peaks, 2,650, pass them, so eviction stays in play,
and in play the pool fills. The cap is read again from measured occupancy.

## .set TILE_SLOTS

`u64`: the pool's slots; a directory entry holds a slot plus one in sixteen bits, so they stay under 65,536.

## .set TILE_DIRECTORY_ENTRIES

`u64`: the directory's entries, a u32 each, every mapped surface's grid at every level of its chain; a surface whose grids would pass them stays uncached, counted. Render Zero takes 98,445 at 64.

## .set TILE_GUARANTEE

`u64`: the requests a context admits for one surface in a frame before its open ring takes them.

8 at 64: the census's median requesting surface asked 6 distinct tiles in a
context's frame, rounded up to a power of two, so the typical surface's frame
is guaranteed whole. The admission measured on the census's routes at two
workers and none dropped no request.

## .set TILE_RING

`u64`: a context's open ring, the requests past the guaranteed tiers.

1,024 at 64, the census's size for 64 from its distinct tiles past the
guarantee, rounded up to a power of two. The admission measured on the
census's routes, repeats and all, filled it to 403 at most and dropped no
request.

## .set TILE_RECENT_SHIFT
## .set TILE_RECENT

`u64`: a context's repeat filter's keys as a shift, and the keys, direct-mapped by their low bits, so a key that displaces another lets the other's repeat in again, a duplicate and never a loss.

## .set TILE_CONTEXTS

`u64`: the raster contexts that request tiles, hart 0's and the workers'.

## .set TILE_MERGE

`u64`: the boundary's merged list, a key a slot, since one boundary builds no more tiles than the pool has slots.

## .set TILE_QUOTA

`u64`: the texels a boundary's construction may build, 96 tiles.

## .set TILE_ALLOWANCE_US

`u64`: the boundary's allowance in microseconds, merge, eviction, and construction included, about a millisecond on the critical path to start, a proposal and not a measured cost.

## .set TILE_MERGE_US

`u64`: the merge's share of the allowance in microseconds; a merge past it stops where it stands.

## .set TILE_UNLIMITED

`u64`: a deadline and a quota no boundary reaches, the lift's.

## .set TILE_TRACE_ITEMS

`u64`: the items on a line of a debug build's trace of the pool, under the line's 512 bytes.

## .set TILE_CLASS_PLANES
## .set TILE_CLASS_WALLS

`u64`: the surface classes the pool may cache, the planes and the walls with their masked openings.

## .set TILE_CLASSES

`u64`: the classes cached, the walls with their openings.

On release batteries at a side of 64, interleaved, the walls alone drew the
factory route with the fewest frames at or over 15 ms, 618 of 19,914, against
733 with the planes cached too and 674 with no tile drawn. The planes' tiles
lowered the raster's time on most legs, but their working set doubled the tiles
evicted from the same pool and more than doubled the boundary's runs past its
allowance, and the pressure leg's frames at or over 15 ms rose by half. Without
tiles the view looking up drew 0.66 ms slower settled and its leg gathered
nearly twice the frames at or over 15 ms, while the yard drew faster.

## .set SLOT_FREE

## .set SLOT_BUILDING

## .set SLOT_READY

`u64`: a slot's states, the low bits of its tag, the slot's generation above them: free, a tile in construction, a tile published whole.

## .set SLOT_KEY

`u32`: the slot's tile, its directory entry's index.

## .set SLOT_SURFACE

`u32`: the tile's surface, the lumel maps' index.

## .set SLOT_TX

## .set SLOT_TY

`u32`: the tile's column and row in its level's grid.

## .set SLOT_LEVEL

`u8`: the tile's level of the chain.

## .set SLOT_REFERENCE

`u8`: CLOCK's reference bit.

## .set SLOT_ROW

`u16`: the next row to build while the slot is BUILDING.

## .set SLOT_BUILT

`u32`: the boundary that published the tile.

## .set SLOT_SIZE

A slot record's bytes.

## .set TS_LEVELS

`u8`: the levels of the surface's chain its directory holds, 0 for a surface the pool leaves uncached.

A tile surface record, one a surface at the lumel maps' index (tile_surfaces),
holds what the builder and the span's lookup need beyond the lumel map: the
chain's levels, k, the texture's masks and row shift as material_bind takes
them, and a grid a level, its first directory entry and its tiles across and
down. A tile at level m covers TILE_SIDE << m texels of level 0 a side, over
the map's W << k by H << k texels, the last cell past the last node included,
the census's sizing at one side.

## .set TS_K

`u8`: the map's k, a lumel cell's level 0 texels a side as a shift.

## .set TS_WSHIFT

`u8`: the texture's row bytes at level 0 as a shift, POLY_WSHIFT's.

## .set TS_MATERIAL

`u32`: the surface's material.

## .set TS_UMASK

## .set TS_VMASK

`u32`: the texture's masks at level 0, POLY_UMASK's and POLY_VMASK's.

## .set TS_GRIDS

`MIP_LEVELS*TS_GRID_SIZE u8`: the grids by level.

## .set TS_GRID_BASE

`u32`: the level's first directory entry.

## .set TS_GRID_W

## .set TS_GRID_H

`u16`: the level's tiles across and down.

## .set TS_GRID_SIZE

A grid's bytes.

## .set TS_SIZE

A tile surface record's bytes.

## .set TT_STAMP

`u32`: a guaranteed tier's frame stamp, the frame's number plus one, 0 never.

A guaranteed tier holds one surface's requests in one context's frame, up to
TILE_GUARANTEE of them, so no surface's demand takes another's.

## .set TT_COUNT

`u32`: the tier's requests.

## .set TT_KEYS

`TILE_GUARANTEE u32`: their keys.

## .set TT_SIZE

A tier's bytes.

## .set TA_RING_FILL

`u32`: an admission block's open ring's fill.

An admission block is a context's own (tile_admission): the open ring, the
repeat filter, the frame's requesting surfaces, a guaranteed tier a surface,
and the touched-slot bitmap, so the render path stores nothing another
context writes.

## .set TA_LISTED

`u32`: the requesting surfaces listed.

## .set TA_RING

`TILE_RING u64`: the open ring, a key in the low word and its surface in the high.

## .set TA_FILTER

`TILE_RECENT u64`: the repeat filter, a key in the low word and its frame's stamp in the high.

## .set TA_LIST

`LUMAP_COUNT u32`: the frame's requesting surfaces, in their first request's order.

## .set TA_TIERS

`LUMAP_COUNT*TT_SIZE u8`: the guaranteed tiers, one a surface.

## .set TA_TOUCHED

`TILE_SLOTS/8 u8`: the touched-slot bitmap, a bit for each slot the context's blocks read.

## .set TA_SIZE

An admission block's bytes, rounded up to 64.

## .set CTX_CENSUS_NEXT

`addr`: on a CENSUS build, the context's next census slot, in the counts' words, which is why CENSUS refuses COUNT; and CENSUS refuses a build without DEBUG, its lines a debug build's.

## .set CTX_CENSUS_END

`addr`: past the context's last census slot.

## .set CTX_CENSUS_DROPPED

`u64`: the frame's lit mapped blocks the context's full slots could not keep.

## .set CTX_CENSUS_BASE

`addr`: the context's first census slot.

## .set CENSUS_U

## .set CENSUS_V

`i64`: a census slot's block's first pixel's u and v, 16.16 level 0 texels from the lumel map's origin, as span_fill steps them.

## .set CENSUS_DU

## .set CENSUS_DV

`i64`: the block's u and v steps a pixel, 16.16, so its last pixel samples the start plus the step times the pixels less one.

## .set CENSUS_SURFACE

`u32`: the block's surface, the lumel maps' index.

## .set CENSUS_LEVEL

`u8`: the block's level, the chain's last at most.

## .set CENSUS_PIXELS

`u8`: the block's pixels, 16 but a span's last.

## .set CENSUS_PASSED

`u8`: its pixels past the depth test.

## .set CENSUS_MASKED

`u8`: 1 for a masked fill, an opening, else 0.

## .set CENSUS_RECORD

A census slot's bytes.

## .set CENSUS_SLOTS

`u64`: a context's census slots, room for every block of a frame drawn on one context: a settled view enters about 140,000 lit mapped blocks.

## .set CENSUS_CONTEXTS

`u64`: the raster contexts the census reads, hart 0's and the workers'.

## .set SCRATCH_POISON

`u64`: the word a debug build writes over the producer's scratch once the packet is published, an address no page maps.

## .set REPORT_KIND

`u32`: a record's kind over the API, a REPORT_*.

The records over the API are 64 bytes each. An event carries the state's
fields and its own from REPORT_FIELD0.

The clock records, REPORT_FRAME, REPORT_DRAW, REPORT_PRESENT,
REPORT_PACKET, REPORT_TILE, and REPORT_STORAGE, and the end marker,
REPORT_END, put the frame's number where the state puts its sector and the
schema's version in the last word, so a reader refuses a layout it does not
know; the state record keeps its layout and meanings. The six clock records
of a frame go out in one write at the next frame's start, and a
configuration record, REPORT_CONFIG, ahead of the first frame it governs.
The frame record's start and flip's end are 64 bits on 8-byte
boundaries and every other field 32. Its critical path runs from the frame's
start to its reporting's end less the wait, the time a frame waits before
its flip so it presents no earlier than the cap allows. Its phases are
exclusive, the game, the drawing, the crosshair, the mix, the flip, and the
reporting, with the presentation record's pacing beside them, and the
critical path less their sum is time no phase holds; the flip is every
attempt's call and its status the final attempt's, FLIP_NONE when the frame
reached no flip (main.S). The drawing's parts are exclusive within the
drawing, the clear, the portals, the planes, the walls, the sprites, the
packet record's raster, and DRAW_TILES, the tile pool's boundary, which
below schema 5 lay inside the planes and the walls: the planes, the walls,
and the sprites are their preparation alone,
since a packet flushed among them renders apart from their marks (world.S's
phase_mark), and the raster is every render of the frame's packets. The
packet record splits the drawing in two, its preparation and its raster,
each converted once, so the drawing less the two is 0 or 1 microsecond.
The await runs from the
reporting's end to the next frame's start, the time inside the call
whatever the kernel does there. So the next start less the start is the
critical path, the wait, and the await, to the microseconds each
conversion drops. The presentation record carries what presenting the
frame took: the simulation's time, camera_look's start, and the next
frame's start as frame_records was handed it, both 64 bits from the
program's start; the wait and the pacing, each converted once from its
ticks; the pad's wakes during the wait and the presses they drained; the
flip's attempts and the refusals among them; and the frame's cadence. Under
CADENCE_AFTER_FLIP the frame awaits after its flip, so its wait, pacing,
wakes, and presses are 0 and its attempts 1, a refusal among them when the
flip came early. Under CADENCE_IF_EARLY and CADENCE_ON_GRID the frame waits
before its flip only when presenting would be early, the second also when
it came after its tick, and flips again after a refusal, so its final flip
presents and its await is the loop's few instructions to the next start.
The pixel counts are candidates before the
depth test and the masked pass: DRAW_TILED_PIXELS the blocks read from
tiles, DRAW_LIT_PIXELS every lit span's, their difference the lit pixels the
fallback loop took: blocks straddling two tiles, off a grid, missing their
tile, or of a class or surface the pool leaves uncached. DRAW_TILE_BYTES is
the pool's bytes in use at the boundary's end and DRAW_TILE_PEAK their
high-water since the load, which an L lowers the first and never the
second. DRAW_SPANS counts every span the frame drew, over all its packets.

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

## .set REPORT_PRESENT

`u32`: the frame before's presentation, PRESENT_* fields, beside its clock.

## .set REPORT_CONSOLE

`u32`: the console's answer, the command's byte.

## .set REPORT_PACKET

`u32`: the frame before's packets, PACKET_* fields, beside its clock.

## .set REPORT_TILE

`u32`: the frame before's tile pool activity, TILES_* fields, beside its clock.

## .set REPORT_CONFIG

`u32`: the tile pool's configuration, CONFIG_* fields, ahead of the first frame it governs.

## .set REPORT_STORAGE

`u32`: the frame before's tile pool at its boundary's end, STORE_* fields, beside its clock.

## .set REPORT_TILE_DUMP

`u32`: on a debug build, a tile the console's D frame reads back, DUMP_* fields, its texels after it.

## .set REPORT_TILE_TEXELS

`u32`: on a debug build, DUMP_TEXELS texels of the tile the dump record before it names, TEXELS_* fields; the clock's readers pass both kinds over.

## .set REPORT_FRAME_RECORDS

`u32`: the clock records a frame sends in one write, the frame, draw, presentation, packet, tile, and storage records.

## .set REPORT_SCHEMA_VERSION

`u32`: the clock records' layout as this source lays them out, 5 with the tile pool's records.

## .set TIME_START

`u64`: the frame's start, microseconds since the program's.

## .set TIME_CRITICAL

`u32`: its start to the end of its reporting, the wait and the await apart.

## .set TIME_GAME

`u32`: the game's phases, as REPORT_GAME_US.

## .set TIME_DRAW

`u32`: world_draw, as REPORT_FRAME_US.

## .set TIME_HUD

`u32`: the crosshair.

## .set TIME_MIX

`u32`: mixer_update.

## .set TIME_FLIP

`u32`: every flip attempt's call, the device's wait in each.

## .set TIME_REPORT

`u32`: the reporting, the frame before's records and its own state's.

## .set TIME_AWAIT

`u32`: the reporting's end to the next frame's start, the await call.

## .set TIME_FLIP_DONE

`u64`: the flip's return, microseconds since the program's start.

## .set TIME_FLIP_STATUS

`u32`: the final attempt's jab.sys.display.flip code, 0 presented, FLIP_NONE with no attempt.

## .set DRAW_CLEAR

`u32`: the depth clear on hart 0, 0 when the workers clear.

## .set DRAW_PORTALS

`u32`: the flow through the portals.

## .set DRAW_PLANES

`u32`: the planes' preparation; below schema 5 their tiles' construction within.

## .set DRAW_WALLS

`u32`: the walls' preparation; below schema 5 their tiles' construction within.

## .set DRAW_SPRITES

`u32`: the sprites' and the actors' preparation.

## .set DRAW_TILES

`u32`: the tile pool's boundary, STAT_TILE_TICKS, a part of the drawing of its own; below schema 5 the atlases' time within the planes and the walls.

## .set DRAW_TILES_BUILT

`u32`: the whole tiles of TILE_SIDE the frame's boundary published, at any level, a row resumed no build; below schema 5 the cells built at a level.

## .set DRAW_TILE_RESETS

`u32`: the pool's forgets since the load, the console's L alone; below schema 5 the arena's resets.

## .set DRAW_TILED_PIXELS

`u32`: the pixels of blocks read from tiles.

## .set DRAW_LIT_PIXELS

`u32`: the pixels of lit spans.

## .set DRAW_TILE_BYTES

`u32`: the pool's bytes in use at the boundary's end, the slots in use times TILE_BYTES, a BUILDING slot counted; below schema 5 the arena in use.

## .set DRAW_TILE_PEAK

`u32`: their high-water since the load.

## .set DRAW_SPANS

`u32`: the spans drawn, every packet's.

## .set PRESENT_SIMULATION

`u64`: the simulation's time, camera_look's start, microseconds since the program's start.

## .set PRESENT_NEXT_START

`u64`: the next frame's start, the tick frame_records was handed, microseconds since the program's start.

## .set PRESENT_WAIT

`u32`: the time the frame waited before its flip, apart from its critical path.

## .set PRESENT_PACING

`u32`: the work around that wait, a phase of the critical path.

## .set PRESENT_WAKES

`u32`: the pad's wakes during the wait.

## .set PRESENT_WAIT_PRESSES

`u32`: the gamepad presses those wakes drained.

## .set PRESENT_FLIP_ATTEMPTS

`u32`: the flip's attempts.

## .set PRESENT_REFUSALS

`u32`: the attempts answered as early, FLIP_EARLY.

## .set PRESENT_CADENCE

`u32`: the frame's cadence, a CADENCE_*.

## .set PACKET_PREPARATION

`u32`: the drawing less its raster, the frame's preparation, converted once from ticks.

## .set PACKET_RASTER

`u32`: every render of the frame's packets, the flushes' and the last, each with its counts.

## .set PACKET_COMMANDS

`u32`: the commands the frame emitted over its packets, STAT_COMMANDS.

## .set PACKET_FLUSHES

`u32`: the packets rendered full before the frame's last, STAT_FLUSHES.

## .set PACKET_INVALIDATED

`u32`: 0 from schema 5, a command carrying no tile binding to invalidate; below it the bindings a reset took off their tiles before their render.

## .set PACKET_BYTES

`u32`: the bytes the frame's packets held, the commands at POLY_SIZE and the spans at SPAN_RECORD_SIZE.

## .set PACKET_SNAPSHOT

`u32`: the frame whose simulation the packets were prepared from, the record's own while one owner prepares and renders in turn.

## .set PACKET_WORKERS

`u32`: the raster's workers the frame drew with, 0 for the serial backend, world_draw's latch.

The record's workers and their rounds, from schema 4: the frame's workers
and grain as world_draw took them, and the rounds' times summed over the
frame's rounds, each converted once, 0 under the serial backend and on a
frame that took no round, a stall's. The slowest worker, the dispatch, and
the barrier each lie within the raster, and the busy time is every
worker's, at least the slowest's (test/gauge.nu's rules).

## .set PACKET_GRAIN

`u32`: the rows a band, 0 for a band a worker.

## .set PACKET_SLOWEST

`u32`: the rounds' slowest workers, STAT_SLOWEST.

## .set PACKET_BUSY

`u32`: every worker's time in the rounds, STAT_BUSY.

## .set PACKET_DISPATCH

`u32`: the rounds' dispatch, STAT_DISPATCH.

## .set PACKET_BARRIER

`u32`: the rounds' barrier, STAT_BARRIER.

## .set TILES_ADMITTED

`u32`: the requests the frame admitted while it rendered.

The tile record keeps the admissions with the frame that made them and the
merge with the batch it consumed, its source the frame before, all ones at
the first boundary with nothing admitted, merged, or left. The duplicates
among the processed requests follow: the batch's admitted less its
unprocessed less its merged.

## .set TILES_DROPPED

`u32`: the requests a full open ring dropped.

## .set TILES_FILTERED

`u32`: the repeats turned away.

## .set TILES_SOURCE

`u32`: the frame whose requests the boundary merged, the frame before, all ones at the first boundary.

## .set TILES_BATCH

`u32`: that batch's admitted requests, by its own counts.

## .set TILES_MERGED

`u32`: the batch's requests merged, each tile once.

## .set TILES_UNPROCESSED

`u32`: the batch's requests left past the merge's share or its list's end.

## .set TILES_EVICTED

`u32`: the slots CLOCK retired.

## .set TILES_BUILD

`u32`: the construction's microseconds, within DRAW_TILES.

## .set TILES_OVERRUN

`u32`: the boundary's microseconds past its allowance.

## .set TILES_HITS

`u32`: the blocks read from a READY tile.

## .set TILES_STRADDLING

`u32`: the blocks with tiles that straddle two.

## .set TILES_MISSES

`u32`: the eligible blocks drawn without their tile, each asking for it, so the requests admitted, dropped, and filtered.

## .set CONFIG_MERGE

`u32`: the merge's share in force in microseconds.

## .set CONFIG_FRAME

`u32`: the frame whose boundary first uses the configuration.

A configuration record goes out whenever the configuration is set, after
the load and when the console changes it, ahead of the first frame it
governs, so a capture carries what each frame ran under and a reader
consults no checkout. A changed capacity governs the admissions after it.

## .set CONFIG_SHIFT

`u32`: TILE_SHIFT.

## .set CONFIG_BYTES

`u32`: TILE_BYTES.

## .set CONFIG_SLOTS

`u32`: the physical slots, TILE_SLOTS.

## .set CONFIG_EFFECTIVE

`u32`: the slots the pool may use.

## .set CONFIG_QUOTA

`u32`: TILE_QUOTA in texels.

## .set CONFIG_ALLOWANCE

`u32`: TILE_ALLOWANCE_US.

## .set CONFIG_FLAGS

`u32`: CONFIG_UNLIMITED, CONFIG_FROZEN, and CONFIG_STALE.

## .set CONFIG_GUARANTEE

`u32`: the guarantee in force.

## .set CONFIG_RING

`u32`: the open ring in force.

## .set CONFIG_RECENT

`u32`: TILE_RECENT.

## .set CONFIG_DIRECTORY

`u32`: the directory's bytes, this map's entries.

## .set CONFIG_MEMORY

`u32`: TILE_MEMORY's bytes.

## .set CONFIG_UNLIMITED

`u32`: the flag of a boundary under no quota, allowance, or merge's share, the lift an L or an O sets.

## .set CONFIG_FROZEN

`u32`: the flag of construction frozen, the L's byte 5 or an O's.

## .set CONFIG_STALE

`u32`: the flag of a debug build's eviction leaving its entries, an O's.

## .set STORE_USED

`u32`: the slots in use at the boundary's end, a BUILDING slot counted.

## .set STORE_EFFECTIVE

`u32`: the effective slots.

## .set STORE_BUILDING

`u32`: the BUILDING slots, one at most.

## .set STORE_RING

`u32`: the greatest open ring of the batch the boundary consumed.

## .set STORE_SURFACES

`u32`: that batch's requesting surfaces.

## .set STORE_MERGED

`u32`: the merged list's entries.

## .set STORE_MEMORY

`u32`: the pool's memory in use, the tables with this map's directory and the slots in use.

## .set STORE_PEAK

`u32`: its high-water since the load.

## .set DUMP_SLOT

`u32`: the dumped tile's slot.

## .set DUMP_KEY

`u32`: its key, the tile's directory entry.

## .set DUMP_SURFACE

`u32`: its surface.

## .set DUMP_LEVEL

`u32`: its level of the material's chain.

## .set DUMP_TX
## .set DUMP_TY

`u32`: its column and row in the level's grid.

## .set DUMP_K

`u32`: its map's k, a lumel cell's texels of level 0 as a shift.

## .set DUMP_W
## .set DUMP_H

`u32`: its map's columns and rows of nodes.

## .set DUMP_FRAME

`u32`: the frame whose console read the D.

## .set DUMP_GENERATION

`u32`: the slot's generation.

## .set TEXELS_SLOT

`u32`: the slot whose texels a texel record carries, the dump record's before it.

## .set TEXELS_FIRST

`u32`: the tile's texel the record's first is, in rows of TILE_SIDE.

## .set TEXELS_AT

`DUMP_TEXELS u32`: the texels, each as the tile holds it, those past the tile's last zero.

## .set DUMP_TEXELS

`u64`: the texels a texel record carries, from TEXELS_AT to the schema.

## .set DUMP_RECORDS

`u64`: the texel records a tile takes.

## .set CADENCE_AFTER_FLIP

`u32`: the cadence awaiting the display's tick or the pad after each flip.

## .set CADENCE_IF_EARLY

`u32`: the cadence flipping as soon as presenting is no longer early, the display's tick or the pad awaited before the flip only when it would be.

## .set CADENCE_ON_GRID

`u32`: the cadence holding every flip to the display's tick grid, a frame ready after its tick waiting for the next.

## .set CADENCE_COUNT

`u32`: the cadences; a C past them leaves the cadence as it was.

## .set CADENCE_DEFAULT

`u32`: the image's cadence until a C, CADENCE_IF_EARLY, until the cadences' measurements choose the shipped one.

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
