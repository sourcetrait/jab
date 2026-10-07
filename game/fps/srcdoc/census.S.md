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
straddlers' with them. A tile is uniformly lit when every lumel node over its
cells, the far node and the map's clamp included, holds one value, which
counts a tile whose texels all read one brightness only through zero
weights as not uniform. The working set over 1, 30, and 120 frames is the
distinct tiles demanded in that many frames to this one, kept by a window of
per-frame counts: a tile's first demand of a frame takes it out of the
frame it was last demanded in and into this one. Per context, the requests
made, the distinct tiles among them, and each requesting surface's distinct
tiles in the order first requested, which size TILE_GUARANTEE and TILE_RING.

The lines, every frame:

    fps: census frame F: blocks B, passing P, dropped D
    fps: census T: eligible E blocks EP pixels, straddling S blocks SP pixels, outside O; demand D: planes a, walls b, openings c; sampled A, uniform U, surfaces N; working W1, W30, W120
    fps: census T context C: requests R, distinct Q; surfaces q1 q2 ...

and once after the load the directory's: its maps and each side's entries
and bytes, a u32 an entry as the pool's directory holds them. Dropped counts
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

## .set CENSUS_ENTRIES

`u64`: the directory's capacity in entries over every side.

## .set CENSUS_SAMPLED_SHIFT

`u64`: an entry's sampled stamp's first bit; its demand stamp holds bits 0 to 23, each the frame plus one.

## .set CENSUS_CONTEXT_SHIFT

`u64`: an entry's contexts' bits, one a context that requested it this frame.

## .set CENSUS_CLASS_SHIFT

`u64`: an entry's classes' bits, one a class that requested it this frame.

## .set CENSUS_KNOWN_BIT
## .set CENSUS_UNIFORM_BIT

`u64`: whether the tile's uniformity is known, and it.

## .set CENSUS_PLANE
## .set CENSUS_WALL
## .set CENSUS_OPENING

`u64`: the classes.

## .set CENSUS_LINE_BYTES

`u64`: the census's line buffer, room for a context's every surface.

## .set CS_LEVELS
## .set CS_K

`u8`: a surface's census record's chain levels and its lumel's k.

## .set CS_W
## .set CS_H

`u32`: its map's columns and rows, the cells across and down.

## .set CS_LUMELS

`addr`: its lumels.

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
## word_census_semicolon
## word_census_entries
## word_census_bytes
## msg_census_frame
## word_census_blocks
## word_census_passing
## word_census_dropped
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
## word_census_surfaces
## word_census_working
## word_census_comma
## word_census_context
## word_census_requests
## word_census_distinct
## word_census_listed
## word_census_space

The census lines' text, NUL-terminated.

## census_totals

`CENSUS_SIZES*CT_SIZE u8`: the frame's totals by side.

## census_blocks

`3 u64`: the frame's blocks, those with a pixel past the depth test, and those dropped.

## census_used

`CENSUS_SIZES u64`: each side's directory entries.

## census_maps

`u64`: the lumel maps the directory holds.

## census_ring

`CENSUS_SIZES*CENSUS_WINDOW u64`: each side's tiles last demanded in each frame of the window.

## census_surfaces

`LUMAP_COUNT*CS_SIZE u8`: every surface's census record, CS_* fields.

## census_surface_seen

`CENSUS_SIZES*LUMAP_COUNT u32`: each side's surfaces' stamp of their last frame with a demand.

## census_context_counts

`CENSUS_SIZES*CENSUS_CONTEXTS*LUMAP_COUNT*2 u32`: each side, context, and surface's stamp and distinct tiles requested that frame.

## census_context_lists

`CENSUS_SIZES*CENSUS_CONTEXTS*LUMAP_COUNT u32`: each side and context's requesting surfaces in the order first requested.

## census_line

`CENSUS_LINE_BYTES u8`: the line in hand.

## census_entries

`CENSUS_ENTRIES u64`: the directory, an entry a tile: the demand and sampled stamps, the frame's contexts and classes, the uniformity.

## census_slots

`CENSUS_CONTEXTS*CENSUS_SLOTS*CENSUS_RECORD u8`: each context's census slots, CENSUS_* fields.
