# census.S

TileCensus (FrameCeiling's TilePool): a CENSUS debug build (`--set
debug,census`) that counts what a bounded tile pool would be asked for, never
timed, the pixels unchanged. span_fill's hooks (raster.S's census_start and
census_end) keep a slot for every block of a lit, mapped surface, whichever
path drew it, on the raster context that drew it; after the frame's state
report, every round joined, hart 0 takes every context's slots into a dense
directory at three tile sides, 32, 64, and 128 texels at the block's level,
and prints the frame's lines on the UART. The release and debug images are
byte for byte the same without the symbol.

A tile (m, tx, ty) at side T covers level-m texels from tx times T to the
next, in the lumel map's frame, the map's first node the origin as
lumap_bind folds U0 and V0 into the coefficients; the grid at a level holds
the map's W by H cells of 2^k level 0 texels, rounded up to whole tiles. A
block's sampled coordinates are exact: the first pixel the start, the last
the start plus the step times the pixels less one. The walk is linear, so a
block whose first and last pixels share a tile samples that tile alone; one
inside the grid is eligible for the one-tile path, one past it outside. A
block across tiles is straddling, and its pixels are walked one by one for
every tile it samples in the order it meets them, a block crossing both axes
counting its middle tile by the order of its crossings.

A request is an eligible block with a pixel past the depth test. The demand
is the distinct tiles requested in the frame, by class: planes, walls, and
openings, a tile requested by two classes counted in each. The sampled tiles
are the distinct tiles any block with a passing pixel samples, the
straddlers' with them. The working set over 1, 30, and 120 frames is the
distinct tiles demanded in that many frames to this one, kept by a window of
per-frame counts: a tile's first demand of a frame takes it out of the
frame it was last demanded in and into this one. The window is kept for two
classes by the surface's index, planes below LUMAP_PLANES and walls with
their openings from it, the classes a pool caches apart (TILE_CLASSES's
walls and openings first); a tile is one surface's, so the two partition the
tiles and the combined working set is their sum. Per context, the requests
made, the distinct tiles among them, and each requesting surface with its
distinct tiles in the order first requested, which size TILE_GUARANTEE and
TILE_RING.

A tile is uniformly lit when every lumel node its texel centres read holds
one value. The nodes come from the sampler's own clamp: a level-m texel i's
centre in level 0's 16.16 coordinates is (2 i + 1) shifted by m plus 15,
held under the last column and row as lumel_sample holds a coordinate, so a
tile past the map's last node reads the penultimate cell and its nodes lie
in the range, where a range clamped to the last column alone calls it
uniform while the penultimate nodes shade it. A tile whose texels all read
one brightness only through zero weights counts as not uniform. The verdict
is taken on a tile's first demand in a lighting revision and kept until the
lighting changes: an L that rewrites the lumels (console.S) marks the census
stale, and the next census_frame makes every tile's uniformity unknown again
and counts a revision, the demand, sampling, and window state left whole;
each verdict replaces the one before it. A uniform verdict is checked at
once (census_verify) by lumel_sample itself, the macro expanded over a
scratch command bearing the surface's read word, tp pointed at a scratch
context, at every texel centre of the tile, apart from the nodes' range so
the two share no mistake; the sampler's verdict is the one kept, and a tile
the nodes call uniform that the sampler does not counts a mismatch. A check
costs the tile's side squared samples, so a full bright revision's first
frame, every demanded tile uniform, runs long.

The clamped edge's case runs once at the load (census_edge): a 3 by 3 map
with k 5 in the lumel arena's tail, past every map, its nodes at 127 of 256
in every lane but the penultimate column's last at 126, and the 32-texel
tile at level 1 past the last node, whose texels lumel_sample reads through
the penultimate cell at u's fraction of 255, a below-left weight of one 256th
on every texel: the first cell's rows read 127 and the second's 127 less a
256th, so the tile is shaded. The nodes from the sampler's clamp and the
sampler itself both find it so; nodes clamped to the last column alone read
it uniform. The tail is zeroed again after; a map reaching it skips the case
with its line.

The lines, every frame:

    fps: census frame F: blocks B, passing P, dropped D, lighting R, chunk C
    fps: census T: eligible E blocks EP pixels, straddling S blocks SP pixels, outside O; demand D: planes a, walls b, openings c; sampled A, uniform U, checked K, mismatches M, surfaces N; working W1, W30, W120: planes P1, P30, P120, walls Q1, Q30, Q120
    fps: census T context C: requests R, distinct Q, surfaces L; s1:q1 s2:q2 ...
    fps: census T context C more: sN:qN ...
    fps: census end F

the end line closing the frame's lines, so a frame without it was cut by the
run's end, and once after the load the directory's, its maps, the surface index the
walls start at, the surfaces in all, and each side's entries and bytes, a
u32 an entry as the pool's directory holds them, then the edge's:

    fps: census directory: M maps, planes below LP of LC; 32: entries E, bytes B; 64: ...; 128: ...
    fps: census edge: nodes N, sampler S

R is the lighting's revision and C the chunk in force; K counts the tiles
checked by the sampler this frame and M the mismatches among them. A
context's list goes in chunks: before each surface past a line's first, the
line ends and a continuation begins when its bytes with the longest item
would pass the chunk, CENSUS_CHUNK or the console's Q frame's smaller one,
so no line passes the buffer whatever the surfaces a frame lists; a reader
joins a context's chunks in order, as many surfaces as its head lists, their
counts summing to its distinct tiles (the test's `census.nu`). Dropped counts
the blocks the slots could not keep and any record the directory cannot
place; a frame with any is incomplete evidence.

The census's own cost lands in the frame's reporting and slows the build's
frames, so its windows of 30 and 120 frames span more play than a release
build's.

## .set CENSUS_SIZES

`u64`: the tile sides counted, 32, 64, and 128.

## .set CENSUS_SIDE_SHIFT

`u64`: the smallest side's shift, 32 texels; each size doubles it.

## .set CENSUS_WINDOW

`u64`: the frames the working set's window holds, its longest span.

## .set CENSUS_SHORT

`u64`: the shorter span's frames.

## .set CENSUS_WINDOW_CLASSES

`u64`: the window's classes by the surface's index.

## .set CENSUS_WINDOW_PLANES
## .set CENSUS_WINDOW_WALLS

`u64`: the window's classes: planes, and walls with their openings.

## .set CENSUS_ENTRIES

`u64`: the directory's capacity in entries over every side.

## .set CENSUS_SAMPLED_SHIFT

`u64`: an entry's sampled stamp's first bit; its demand stamp holds bits 0 to 23, each the frame plus one.

## .set CENSUS_CONTEXT_SHIFT

`u64`: an entry's contexts' bits, one a context that requested it this frame.

## .set CENSUS_CLASS_SHIFT

`u64`: an entry's classes' bits, one a demand class that requested it this frame.

## .set CENSUS_KNOWN_BIT
## .set CENSUS_UNIFORM_BIT

`u64`: whether the tile's uniformity is known in the lighting's revision, and it.

## .set CENSUS_PLANE
## .set CENSUS_WALL
## .set CENSUS_OPENING

`u64`: the demand's classes.

## .set CENSUS_LINE_BYTES

`u64`: the census's line buffer.

## .set CENSUS_ITEM_BYTES

`u64`: the longest item of a context's list, a space, a surface and a count each a u32's ten digits at most, and the colon between.

## .set CENSUS_CHUNK

`u64`: a context line's bytes at most before a continuation, the buffer less the longest item and the line's end.

## .set CENSUS_EDGE_SIDE
## .set CENSUS_EDGE_K

`u64`: the clamped edge's map, its nodes a side and its lumel's k.

## .set CENSUS_EDGE_NODES

`u64`: its nodes.

## .set CENSUS_EDGE_LIGHT
## .set CENSUS_EDGE_SHADE

`u64`: its nodes' light in 256ths in every lane, and the shaded node's.

## .set CENSUS_EDGE_SHADED

`u64`: the shaded node in row-major order, the penultimate column's last row.

## .set CENSUS_EDGE_LEVEL
## .set CENSUS_EDGE_TX

`u64`: its tile's level and column at the smallest side, past the last node.

## .set CS_LEVELS
## .set CS_K

`u8`: a surface's census record's chain levels and its lumel's k.

## .set CS_W
## .set CS_H

`u32`: its map's columns and rows, the cells across and down.

## .set CS_LUMELS

`addr`: its lumels.

## .set CS_WORD

`u64`: its read word, as lumap_bind packs POLY_LUMEL: the lumels' offset into the arena, a row's bytes, the rows, k.

## .set CS_GRIDS

`CENSUS_SIZES*MIP_LEVELS*CS_GRID_SIZE u8`: its grids, a side's levels in order.

## .set CS_GRID_BASE
## .set CS_GRID_W
## .set CS_GRID_H

`u32`: a grid's first entry in census_entries and its tiles across and down.

## .set CS_GRID_SIZE
## .set CS_SIZE

A grid's bytes and a surface's census record's.

## .set CT_ELIGIBLE
## .set CT_ELIGIBLE_PIXELS
## .set CT_STRADDLING
## .set CT_STRADDLING_PIXELS
## .set CT_OUTSIDE
## .set CT_DEMAND
## .set CT_SAMPLED
## .set CT_UNIFORM
## .set CT_CHECKED
## .set CT_MISMATCHES
## .set CT_SURFACES

`u64`: a side's frame totals, as the lines name them.

## .set CT_CLASSES

`3 u64`: the demand by class.

## .set CT_REQUESTS
## .set CT_DISTINCT
## .set CT_LISTED

`CENSUS_CONTEXTS u64`: each context's requests, distinct tiles, and requesting surfaces listed.

## .set CT_SIZE

A side's totals' bytes.

## msg_census_full
## msg_census_directory
## word_census_maps
## word_census_planes_below
## word_census_of
## word_census_semicolon
## word_census_entries
## word_census_bytes
## msg_census_edge
## word_census_sampler
## msg_census_edge_skipped
## msg_census_frame
## word_census_blocks
## word_census_passing
## word_census_dropped
## word_census_lighting
## word_census_chunk
## msg_census
## word_census_eligible
## word_census_blocks_of
## word_census_straddling
## word_census_outside
## word_census_demand
## word_census_planes
## word_census_walls
## word_census_openings
## word_census_sampled
## word_census_uniform
## word_census_checked
## word_census_mismatches
## word_census_surfaces
## word_census_working
## word_census_comma
## word_census_context
## word_census_requests
## word_census_distinct
## word_census_listed
## word_census_items
## word_census_more
## word_census_space
## word_census_colon

The census lines' text, NUL-terminated.

## census_totals

`CENSUS_SIZES*CT_SIZE u8`: the frame's totals by side.

## census_blocks

`3 u64`: the frame's blocks, those with a pixel past the depth test, and those dropped.

## census_used

`CENSUS_SIZES u64`: each side's directory entries.

## census_maps

`u64`: the lumel maps the directory holds.

## census_revision

`u64`: the lighting's revisions since the load, one an L that rewrites the lumels.

## census_ring

`CENSUS_SIZES*CENSUS_WINDOW_CLASSES*CENSUS_WINDOW u64`: each side and window class's tiles last demanded in each frame of the window.

## census_surfaces

`LUMAP_COUNT*CS_SIZE u8`: every surface's census record, CS_* fields.

## census_edge_record

`CS_SIZE u8`: the clamped edge's map's census record.

## census_sample_context

`CTX_SIZE u8`: the scratch raster context census_verify points tp at, its command the scratch command.

## census_sample_command

`POLY_SIZE u8`: the scratch command bearing a surface's read word at POLY_LUMEL for lumel_sample.

## census_surface_seen

`CENSUS_SIZES*LUMAP_COUNT u32`: each side's surfaces' stamp of their last frame with a demand.

## census_context_counts

`CENSUS_SIZES*CENSUS_CONTEXTS*LUMAP_COUNT*2 u32`: each side, context, and surface's stamp and distinct tiles requested that frame.

## census_context_lists

`CENSUS_SIZES*CENSUS_CONTEXTS*LUMAP_COUNT u32`: each side and context's requesting surfaces in the order first requested.

## census_chunk

`u32`: the Q frame's chunk in bytes, 0 for CENSUS_CHUNK.

## census_stale

`u8`: 1 once an L has rewritten the lumels, cleared by the next census_frame.

## census_line

`CENSUS_LINE_BYTES u8`: the line in hand.

## census_entries

`CENSUS_ENTRIES u64`: the directory, an entry a tile: the demand and sampled stamps, the frame's contexts and classes, the uniformity.

## census_slots

`CENSUS_CONTEXTS*CENSUS_SLOTS*CENSUS_RECORD u8`: each context's census slots, CENSUS_* fields.
