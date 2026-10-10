# tile.S

The tile pool: the lit texture cached a tile at a time in a bounded pool, a
tile TILE_SIDE texels square at one level of the material's chain, built on
hart 0 at the frame's boundary from what the frame before asked for, read
by the span's blocks through a directory, and evicted by CLOCK. Then the
alpha coverage policy the chains carry, and the console's lumel rewrites.

The lit loop's cost over the unlit loop's is its three channel multiplies
and the unpacking around them, about twenty ops a pixel, and its sampling
of the lumel map once an interval; a tile pays them once for every pixel
that reads it. The pool replaced whole-surface atlases in a 1 GiB arena,
reset whole when one did not fit, built finest level first under a budget
a frame: every surface in view was built whole before its first tile was
read, a distant surface's level 0 included, and the arena reset four or
five times over the factory route.

### The tile

Tile (m, tx, ty) of a surface covers the texels of level m from tx and ty
times TILE_SIDE to the next, in the surface's lumel frame: the map's first
node is the origin, as lumap_bind folds U0 and V0 into the coefficients, so
a block's coordinate from span_fill names its tile by a shift, 16 + m +
TILE_SHIFT. Every level of the chain has tiles, coarser than a lumel cell
included, so no shift is negative and no tile empty. A tile's texel is the
chain's at its level, mip_bind's addressing, lit at its centre by the
lumel map and scaled as the lit loop scales one, its alpha the chain's,
already scaled for coverage at that level (alphas_measure). Under the
bright frame every lumel is one and the tile equals the chain: the spawn
view settled on its tiles is the lit loop's picture byte for byte, which
the test holds.

### The directory and the slots

The pool holds TILE_SLOTS tiles of TILE_BYTES, four pages each at 64. A slot's
tag holds its generation and its state, FREE, BUILDING, or READY; PINNED is
the frame-wide rule that nothing changes between the boundary's end and the
frame's last join, so a READY tag read in the frame stays READY through it,
and RETIRED is eviction's step inside the boundary, never seen by a reader.
The directory holds an entry for every tile of every mapped surface at
every level of its chain, sized at load (tiles_init): 0 for no tile, else
the slot plus one and the slot's generation at publication. A lookup takes
the entry and holds its generation, with SLOT_READY, against the slot's
tag, so an entry left by a missed clear, its slot since retired and its
generation advanced, reads no tile. A retirement clears the entry naming
its slot before the generation advances, so a wrap of the sixteen-bit
generation cannot alias a live entry; the check guards the clear.

### Requests and admission

A block asks for its tile only when it could use it: its first sampled
pixel and its last, the start plus the step times the pixels less one, in
one tile inside the level's grid, a pixel of it past the depth test, the
tile not READY. A straddling block asks nothing. The request goes to the
block's raster context alone (tile_request), so the render path stores
nothing another context writes: a repeat filter of TILE_RECENT entries,
each a key under the frame's stamp, direct-mapped by the key's low bits,
so a displaced key's repeat is admitted again, a duplicate and never a
loss; then the surface's guaranteed tier, its first TILE_GUARANTEE
requests of the frame checked against its own keys, so no surface's
demand takes another's; then the context's open ring of TILE_RING
entries, its overflow dropped and counted. A request lives one frame:
every stamp is the frame's, and the boundary empties the rings and the
lists after the merge. A block counts as missed as it asks, so a frame's
missed blocks are its requests admitted, dropped, and filtered; a block
that draws no pixel asks nothing and is counted nowhere.

### The boundary

Hart 0 runs it at world_draw's start, after the frame before's last join
and before any bind (tile_boundary): the console's changes come in force,
an L's forget is done, then the frame before's batch is counted and
merged, deduplicated through the merge bitmap, the guaranteed tiers first
by surface, then the open rings by context and entry, stopping at the
merge's share of the allowance or the merged list's end, the rest counted
unprocessed, the next boundary resuming at the surface or the entry where
the merge stopped; the touched bitmaps folded into CLOCK's reference
bits; the tile in construction finished first; then construction
round-robin over the merged surfaces from a cursor kept between
boundaries, a tile a surface a pass, until TILE_ALLOWANCE or the quota;
the requests not served discarded. The allowance covers the whole
boundary, and the time past it is recorded. An L lifts the quota, the
allowance, and the merge's share, or freezes construction with its byte
5; a debug build's O frame sets the pool's knobs, its quota standing
under the lift.

### The knobs

A debug build's console O frame, in force from the next boundary as a
configuration of its own, recorded: the modes (CONFIG_UNLIMITED, the
lift; CONFIG_FROZEN, no construction; CONFIG_STALE, an eviction leaving
the entry that names its slot, the stale reference the generation check
exists for; CONFIG_ONCE, construction at the first boundary that merged a
key and at none after while the configuration stands, so a cap under a
view's demand leaves its residency fixed and partial, the handoff's
measurement), the effective slots, a change forgetting the pool so its free
slots are the cap's, the guarantee and the ring within the build's, the
merge's share in microseconds, and the quota, each 0 for the build's own.
The quota is a boundary's work in texels under every mode, so under the
lift the work is exact: charged a row's TILE_SIDE texels at a time, a row
begun finished, it stops at the row that spends it. From a boundary with
no tile in construction, while merged keys and slots last, a quota of k
tiles' texels and r rows' publishes k whole tiles and leaves one BUILDING
at row r, and one of k tiles alone leaves none; a boundary that starts
with a tile in construction finishes
it first out of the same quota, so a whole-tile quota after a partial
ends partial again. Its byte 6
is a cold start: every tile forgotten and the frame before's batch
discarded whole, unprocessed, so a view placed with it is drawn at first
sight even where the frames before drew it. Its byte 5 traces the pool.

### The trace

While a debug build's O frame sets it, each boundary notes the batch's
requesting surfaces and every merged surface with its keys before
construction takes them (tile_trace_note), and once its time is taken
prints three lists on the UART (tile_trace_print), TILE_TRACE_ITEMS a
line, a long list going on in lines of the same head:

    fps: tile pass 50 requesting: 2048 2052 2053
    fps: tile pass 50 merged: 2048:2
    fps: tile pass 50 built: 2048 2048

the frame, then the surfaces whose requests the batch held, the surfaces
merged with their keys in the merge's order, and the surface of every
tile published in the pass. The printing stays out of the allowance it
would otherwise spend, which held one surface's merge unbuilt for a cycle
of the rotation when it did not.

### Eviction

CLOCK over the effective slots: a READY slot read since its last sweep
has its reference bit cleared and is passed over once; one unread is
retired; a slot published in this pass is never evicted in it, so a slot
changes at most once a pass, and a new slot's bit starts clear, so a tile
unread through the frame after its publication is evictable at the next
boundary. Two sweeps find a victim if one exists.

### The frozen frame

On a debug build every tag and entry write is counted (tile_wrote), the
count snapshotted in world_draw right after the boundary and checked at
every packet render's start and end, so at every flush, round, and the
last join, and in round_finish (tile_check); a change exits 15 with `fps:
tile pool changed in flight`. A boundary moved after the first bind would
pass the picture and fail here.

### What the earlier caches taught

The atlas cache's cuts, each measured on the gauge against a build with no
binds: judging every block's or every span's cells against bit maps of
built and wanted cells cost 3 to 6 ms a view, more than the lighting's
whole; a hit path whose work about equalled what the hit saves gained
nothing, walls gaining and planes losing on the tile data's cache level
(the garage 19.9 ms with every read pinned to one cache-hot tile against
20 to 21 with no binds, its remaining 7 ms the tile data); a floor's spans
at yaw 0 walk across a tile's rows and read sixteen lines a block where
four-by-four blocks or Morton order would read four. The pool's block
lookup is a directory load and a tag compare a block, and its tiles keep
their texels in rows.

## .macro tile_wrote

A debug build's count of a tag or an entry written, the frozen frame's
evidence; a release build expands it to nothing.

## .macro tile_edge

A lumel cell's edge on the row in hand, the column's two nodes weighted by
the row's fraction, packed as lumel_sample packs its sum.

## tiles_init

The tile pool's load, once, after the lumel maps are baked and the chains
built: a directory for every surface with a lumel map and a texture, a grid
for each level of its material's chain, sized from the map's extent, W << k by
H << k texels of level 0, a tile at level m covering TILE_SIDE << m of them a
side, the census's sizing at one side, so the entries equal the census
directory line's at 32. A surface whose grid passes sixteen bits a side or
whose grids would pass TILE_DIRECTORY_ENTRIES stays uncached, counted, and
the next surface is tried. Every slot starts free, slot 0 on top of the free
stack, the effective slots all of them, no tile in construction; each
context gets its admission block and its touched-slot bitmap; every
surface's merged chain is none; the configuration pending is the build's,
TILE_GUARANTEE, TILE_RING, every slot, and TILE_MERGE_US, flagged changed
so the first boundary sends its record.

TILE_MEMORY is every table of the pool and the pool itself, tile_tables_end
less tile_pool, read once here; the memory in use counts the tables with the
directory at this map's entries, and the slots in use. A debug build
prints both with the side, the slots, the directory's entries, and the maps
held and left uncached:

    fps: tile pool: side 32, slots 8192 of 4096 bytes, directory 384445 entries over 228 maps and 0 uncached, memory 5703860 of 41914816 bytes

The material's masks, row shift, and chain come through material_bind, the
producer's polygon its scratch at load as lumaps_bake's is.

## tile_context

The raster context of index 0 is hart 0's, raster_context, and index n the
worker n - 1's in worker_contexts, CTX_SHIFT apart.

## tiles_forget

The console's L, an O's cold start, or a new slot cap, at the boundary:
every READY slot's entry cleared where it names the slot, every slot's
generation advanced and its state FREE, the free stack rebuilt over the
effective slots, nothing in construction, and the resets since the load
counted. STAT_TILE_RESETS counts these alone.

## tile_boundary

The pool's one change a frame, its order fixed: the configuration, the
pass's mark, the forget, the deadlines (the allowance's, the merge's
share's, and the quota, all past reach under the lift, but a debug
build's O frame's quota in force under every mode), the batch and its
merge, the fold, construction unless frozen, a debug build's B frame's
surface built whole ahead of it, the discard, the frame's stamp, the
occupancy. A debug build's cold start discards the batch in
place of its merge and builds nothing, and under CONFIG_ONCE the first
boundary with keys merged marks tile_once_done and constructs, and every
boundary after skips construction as a frozen one does. Its whole time is STAT_TILE_TICKS,
the draw record's `tiles_us`, a part of the drawing beside the others;
the construction's within it is STAT_TILE_BUILD_TICKS, and the time past
the allowance STAT_TILE_OVERRUN. The trace prints after the time is
taken.

## tile_stall

A debug build's S frame draws nothing, so its boundary serves nothing: the
batch the frame before made is counted and discarded whole, recorded as
unprocessed, and the frame's stamp taken, so every boundary consumes the
frame before's batch, drawn or stalled.

## tile_stamp

The frame's stamp is its number plus one, CLOCK_SNAPSHOT's, 0 never; every
request of the frame is stamped with it, and the next boundary consumes the
batch under it.

## tile_configure

The console's changes within a frame coalesce into one snapshot that the
frame's boundary puts in force and records: the configuration record goes
out ahead of that frame's own records and names it, so a capture carries
the configuration each frame ran under, a debug cap's or another
TILE_SIDE's build alike. A changed limit governs the admissions after it,
while the boundary consumes the frame before's batch by that batch's own
counts. A new slot cap forgets the pool, so no slot past the cap holds a
tile; the merge's share goes in the record's CONFIG_MERGE. On a debug
build a new configuration clears tile_once_done, so its CONFIG_ONCE builds
once again, and the O frame's quota goes in force with the rest, in the
record's CONFIG_QUOTA in place of TILE_QUOTA, the flags in force gaining
CONFIG_QUOTA_KEPT when it stands under the lift.

## tile_batch

The frame before's batch: its source frame, the stamp less one, all ones
at the first boundary; its admitted requests, every listed surface's tier
and every ring, from the batch's own counts; its greatest ring; and the
union of the contexts' requesting surfaces, a bit a surface, which the
merge scans.

## tile_merge

The guaranteed tiers first: the requesting surfaces from the merge
cursor's surface on, its word's surfaces before it last, each surface's
tier in each context under the batch's stamp, key by key; then the open
rings from the context cursor's context at the ring cursor's entry, that
context's entries before it last. The merge's share is checked after each
surface and every sixteenth ring entry. A stop at the share resumes the
next boundary past the surface merged or at the next entry, a stop at the
merged list's end at the surface or the entry it could not take, and a
whole merge moves the starts on a surface and a context, so every
requesting surface and every ring entry comes first in its turn whatever
its place: a merge that restarted a word or a ring at its start would
serve the same first surfaces at every boundary its share runs out
in. What the batch admitted and the merge never took is
STAT_TILE_UNPROCESSED; the duplicates among the rest follow, the admitted
less the unprocessed less the merged.

## tile_merge_key

A key merged already this boundary is a duplicate; else it goes on the
merged list and on its surface's chain, a surface's first key putting the
surface in the merge's order. The list's end stops the merge with the key
unprocessed.

## tile_fold

Each context's touched-slot bitmap folded into the slots' reference bits
and cleared, a word at a time, skipping empty words.

## tile_construct

The tile in construction finished first, then the rotation: from the
merged surface at or after the build cursor, one key a surface a pass,
the cursor moved past each surface served, until the keys run out, the
budget is spent, or no slot can be taken.

## tile_make

A key whose entry names a READY slot of its generation is built already, a
merge's key whose tile the BUILDING tile turned out to be among them. A
slot comes from the free stack, else from CLOCK; the key gives the tile's
level by the grid that holds it, and its row and column. The slot is
BUILDING under its generation until whole, so a tile the budget cuts short
stays BUILDING with its next row and is finished first at the next
boundary.

## tile_evict

CLOCK's sweep over the effective slots from its hand, two turns at most: a
slot not READY or published this pass is passed over, a read one has its
bit cleared and is passed over, the first unread one is retired.

## tile_retire

The entry cleared only where it still names this slot under its
generation, the generation then advanced and the slot free; the pool's
slots in use and the evictions counted. Under a debug build's stale knob
the entry is left naming the slot, which the generation check alone then
keeps from reading the slot's next tile.

## tile_publish

The tag READY before the entry names it, both under the slot's generation;
the slot marked with this pass and its reference bit clear.

## tile_discard

What the boundary did not serve is forgotten: the merge bitmap cleared over
the merged keys alone, the merged chains of the surfaces in the order
reset, the union cleared, and every context's list and ring emptied. The
tiers and the filter need no clearing, their stamps a frame's.

## tile_occupancy

The pool's bytes in use, the slots in use times TILE_BYTES with a BUILDING
slot counted, and their high-water, tile_peak, the draw record's
`tile_bytes` and `tile_peak`; the memory in use, those bytes and the
tables', and its high-water.

## tile_request

Called at a missed block's end with a pixel past the depth test, the block
counted missed just before, on the block's raster context; its counts are
the context's, summed with the rest by context_counts.

## tile_check

A debug build's frozen frame: the pool's writes since the snapshot taken
in world_draw after the boundary, none allowed.

## tile_trace_note

The batch's union copied whole and the merged surfaces' keys counted along
their chains, before tile_discard clears the one and construction takes the
other.

## tile_trace_print

The pass's three lines from the notes, the built surfaces from the slots
this pass published, every slot read.

## tile_build

A tile is built a row at a time, the row's v at its texels' centre, (2Y +
1) << (m + 15) in 16.16 of level 0, giving its lumel row and its 8-bit
fraction as lumel_sample takes them. Along the row, below k each lumel cell
is a segment of 2^(k - m) texels whose light is linear between the cell's
edges (tile_edge): each lane starts at the segment's first texel's centre
and steps a texel at a time, both divided toward zero, so no lane runs past
its end into a negative value, which would borrow from the lane above; at
level k a texel is half a cell and takes its edges' mean; past k a texel's
centre lies on a node column and takes its light. A texel or row past the
last node takes the last node's column or row, the limit of lumel_sample's
clamp, within 1/256 of a node's difference of the clamped coordinate's
light. The texel is the chain's at the level, scaled as the lit loop scales
one, the same two shifts a channel, the alpha kept. The quota is charged a
row's texels and the clock read between rows; whole, the routine answers 1,
and cut short, 0 with the next row kept. Page-aligned and under a page,
since its inner loop runs a texel, which the test holds.

## alphas_measure

Level 0's share of texels at or above the pass is the target; each coarser
level's alphas are the means of the level before, as texel_shrink makes them
for the chain (mip.S), and the threshold T whose share at or above it lies nearest the target
becomes the level's scale, ceil(2^23 / T), so the scaled means pass exactly
where the raw ones reach T. The least error wins, a tie goes to the lower
share, and among equal shares to the T nearest the pass, so a texture whose
levels pass as the texture does keeps one. A texture full or empty at the
pass stays so at every level and keeps one, as does one whose chain has no
level past 0 or whose level 1 is past the scratch planes.

The coverage policy is coverage-preserving alpha scaling, the technique
of NVIDIA Texture Tools, a best effort and not a guarantee, from outside
the engine archive, where Quake 3 and Doom 3 BFG average alpha like a
colour and Doom 3 BFG blurs alpha-tested textures with a level bias
instead. Averaging alpha and testing against a fixed pass does not
preserve coverage: a checkerboard of two opaque and two transparent
texels averages to 127 and vanishes at the next level under a pass of
128, or fills under rounding up. So the texture's share at or above the
pass is the target, and each coarser level's threshold is searched for
the share nearest it. The coverage is measured with the engine's own
rule, the loops' point sample against the pass, not NVIDIA's bilinear
subsamples.

The analysis is the chain's arithmetic exactly: the means are integer
means of the level before, and the level before is the scaled plane, as
mips_build shrinks level L from its stored level L - 1, whose alphas are
already scaled; a tile copies the chain's texels at its level, so the
tiles and the lit loop meet the same alphas. The search walks T from 256, which passes
nothing, down to 1, the count at or above T accumulating from the
histogram, and compares the share against the target as cov times the
texture's texels against the target count times the level's, exact in
integers; the least error wins, an equal error at a greater share loses
to the lower one already held, the transparent side, since the walk
meets the lower share first, and an equal error at the same share, the
plateau of thresholds between two alpha values, goes to the T nearest
the pass, so a texture whose levels pass as the texture does keeps a
scale of one rather than the plateau's end, where an opaque texture
would have had its alpha scaled to 128 for nothing. A texture full or
empty at level 0 is left at one without the levels, since a mean of
values at or above the pass stays at or above it and a mean of values
under it stays under.

Measured on Render Zero: the fence's share by level 7.33, 6.06, 9.47,
and 9.22 percent, with scales 1.008, 1.455, and 1.103, where the plain
average fell to 5.7, 4.0, and 1.9; the hazard sign 44.8, 44.7, 44.7,
46.1; the other signs within a quarter of a percent of full, with
scales near one; Render One's grate 60.9 at every level but the
coarsest, which reads 50.0 at a scale of one, the step above it
further from the target. The lines equal, to the digit, a reading of
the same rule in python over the PNG files for the fence, the grate,
the hazard sign, and Render One's sign, and the test holds the engine's
lines for four textures of its own equal to a nushell reading. The share
moves in jumps where many means share one value, the 127 of a
half-covered square among them, so the nearest reachable share can sit
two points from the target, as the fence's coarser levels do. The far
fence in the yard view keeps its mesh where the seventh cut thinned it.

The two scratch planes bound a level at a quarter of a megabyte, a
1024-texel-square texture's level 1; a texture past that keeps one, as
does a chain with no level past 0. A texture under eight a side was left at
one before, which a 4 by 4 of three alphas at the pass and one a step under
in every 2 by 2 showed wrong: its level 1 means read 127 and vanish under
the pass unless the search lifts them, as it does, to 128. The analysis
runs once at load over every record, the map's materials and the engine's
images, after the images load, for the chain's levels of each
(mip_levels): the sprites' chains need the policy at their silhouettes as
the fence does, where before the images never tiled and were left out. The
line prints every level of the chain, the coverage of each and the scale
of each past 0, which the test's oracle holds to the digit; an image's line
names it by its frame.

Every scale starts at one. Level 0 counts its texels at or above the pass;
the levels' source is the texture's alphas, four bytes apart, then the plane
just made, a byte apart; each level's scale, ceil(2^23 / T), is stored with
its share, and the plane is scaled in place and capped as the next level's
source. The line carries the material's name, or the engine's image by its
frame, the shares by level, and the scales.

## lumels_bright

The console's L frame with its byte 4 set rewrites every lumel at one on
each lane, in a lumel's 256ths, which lumel_pack packs from a 16.16
brightness word by a shift of eight; a first version wrote 1 << 16 and
drew black. The test's bright capture then samples the texture as the
lit one does, tile for tile, so the lit over the bright is the light
alone; a dark copy on the unlit loop read 8 of 256 of view dependence
that was the texture's sampling. Every tile is forgotten with it, its
light the old lumels'.

## lumels_parity

The console's L frame with its byte 7 set, on a debug build alone,
rewrites every lumel by its node's parity in its map, a quarter on each
lane where the column and the row sum even and one where they sum odd.
Every cell then holds a checkerboard of light, steepest beside its
corners and flat at its centre, a gradient the test computes for itself:
a tile's texel beside a node lit at the texel's centre reads apart from
one lit at its corner by more than the build's rounding, where the
room's light changes too little across a texel to tell the two.

## lumels_gradient

The console's L frame with its byte 6 set, on a debug build alone,
rewrites every node of every map by linear functions of its column c and
row r, a lane each: red 256 c / (W - 1), green 256 r / (H - 1), and blue
256 (c + r) / (W + H - 2), each floored, so every lane spans the light's
whole range over its map, red changing along u alone, green along v
alone, and blue along both. W and H are two at least (lumap_frame), so
no divisor is zero. The builder's assertion holds every tile's texels
against the host's light of their centres under it, u and v apart.

## tile_build_all

A debug build's B frame, at the boundary before construction: every tile
of the asked surface at every level of its chain made (tile_make), the
asking taken once. A tile in construction is finished first by
tile_construct, so the build waits a boundary while one is; a budget
spent or no slot to take stops it, the rest unbuilt. Under the L's lift
the whole surface is built in the one boundary, so the D frame after it
reads every key of its grids.

## tile_dump

A debug build's D frame, from console_frame, the pool standing still
between boundaries: every READY slot of the asked surface, or of every
surface for all ones, and the BUILDING one beside them while
tile_dump_building is set, written to the API as one write a tile, a dump
record (REPORT_TILE_DUMP: the slot, the key, the surface, the level, the
column and row, the map's k, W, and H, the frame, the generation, the
slot's state, and its next row to build, TILE_SIDE once whole) and
DUMP_RECORDS texel records (REPORT_TILE_TEXELS: the slot, the first
texel's index, DUMP_TEXELS texels as the tile holds them, the last
record's past the tile zero), the schema in each. A BUILDING slot's
texels are whatever it holds: its built rows, and below them the rows as
the slot held them before, its last tile's or zero. The test's tiles.nu
reads them back (`dumps`), the builder's assertion holding them to the
host's oracle.

## msg_alpha

`12 u8`.

## word_frame_name

`7 u8`.

## word_coverage

`12 u8`.

## word_of_share

`18 u8`.

## word_of_scale

`10 u8`.

## msg_tile_pool

`22 u8`.

## word_tile_slots

`9 u8`.

## word_tile_of

`5 u8`.

## word_tile_directory

`19 u8`.

## word_tile_entries_over

`15 u8`.

## word_tile_maps_and

`11 u8`.

## word_tile_uncached

`19 u8`.

## word_tile_bytes

`7 u8`.

## msg_tile_flight

`34 u8`.

## msg_tile_trace

`16 u8`.

## word_trace_requesting

`13 u8`.

## word_trace_merged

`9 u8`.

## word_trace_built

`8 u8`.

## tile_peak

`u64`: the pool's tile bytes' high-water since the load, the slots in use's.

## tile_frame

`u64`: the frame's stamp, its number plus one, 0 before the first boundary.

## tile_pass

`u64`: the boundaries since the load, the mark a slot published in one keeps.

## tile_hand

`u64`: CLOCK's hand, the slot its next sweep starts at.

## tile_used

`u64`: the slots in use, a BUILDING slot counted.

## tile_deadline

`u64`: the allowance's end, in rdtime's ticks.

## tile_merge_deadline

`u64`: the merge's share's end.

## tile_quota_left

`i64`: the texels construction may still build this boundary.

## tile_merge_cursor

`u64`: the surface the next merge's tiers start at.

## tile_context_cursor

`u64`: the context whose ring the next merge's rings start in.

## tile_ring_cursor

`u64`: the entry of that ring they start at.

## tile_build_cursor

`u64`: the surface the next rotation starts at or after.

## tile_merged_count

`u64`: the merged list's entries.

## tile_order_count

`u64`: the surfaces merged.

## tile_processed

`u64`: the batch's requests the merge took, merged or a duplicate.

## tile_batch_frame

`u64`: the last batch's source frame, all ones for the first boundary's none.

## tile_batch_admitted

`u64`: its admitted requests, by its own counts.

## tile_batch_ring

`u64`: its greatest open ring.

## tile_batch_surfaces

`u64`: its requesting surfaces, the union's.

## tile_flags

`u64`: the configuration in force's flags, CONFIG_UNLIMITED, CONFIG_FROZEN, and a debug build's CONFIG_STALE, CONFIG_ONCE, and CONFIG_QUOTA_KEPT.

## tile_guarantee

`u64`: the guarantee in force, TILE_GUARANTEE unless a debug knob holds fewer.

## tile_ring

`u64`: the open ring in force, TILE_RING unless a debug knob holds fewer.

## tile_merge_us

`u64`: the merge's share in force in microseconds, TILE_MERGE_US unless a debug knob sets another.

## tile_pending_flags
## tile_pending_guarantee
## tile_pending_ring
## tile_pending_effective
## tile_pending_merge

`u64`: the console's values for the next boundary to put in force.

## tile_entries

`u64`: the directory's entries in use, every surface's grids.

## tile_maps

`u64`: the surfaces with a directory.

## tile_uncached

`u64`: the mapped surfaces with a texture whose grids did not fit, left to the lit loop.

## tile_free_count

`u64`: the free stack's slots.

## tile_effective

`u64`: the slots the pool may use, TILE_SLOTS unless a debug cap holds fewer.

## tile_building

`i64`: the slot whose tile is in construction, -1 for none.

## tile_memory

`u64`: TILE_MEMORY, the pool's tables and the pool, in bytes.

## tile_fixed

`u64`: the tables' bytes in use, the directory at this map's entries.

## tile_memory_peak

`u64`: the most the pool's memory has held in use since the load.

## tile_writes

`u64`: on a debug build alone, the pool's tag and entry writes since the load.

## tile_writes_frozen

`u64`: on a debug build alone, their count when the boundary ended, held until the next.

## tile_trace_kind

`u64`: on a debug build alone, the address of the trace line's list word, for a line going on.

## tile_trace_at

`u64`: where the trace line in hand goes on.

## tile_trace_items

`u64`: the items on it.

## tile_trace_merged_count

`u64`: the merged surfaces the trace noted.

## tile_trace_requesting

`LUMAP_COUNT/8 u8`: the batch's requesting surfaces as the trace noted them, a bit a surface.

## tile_trace_merged

`LUMAP_COUNT*8 u8`: each merged surface the trace noted in the merge's order, the surface in the low word and its keys in the high.

## tile_trace

`u8`: 1 while the console's O frame traces the pool.

## tile_cold

`u8`: 1 when an O frame asks a cold start at the next boundary.

## tile_once_done

`u8`: on a debug build alone, 1 once a CONFIG_ONCE configuration's one construction is done, cleared by the next configuration.

## tile_build_surface

`u64`: on a debug build alone, the surface a B frame asked built whole, plus one, 0 for none.

## tile_quota

`u64`: on a debug build alone, the quota in force in texels, the O frame's, 0 for the build's own.

## tile_pending_quota

`u64`: on a debug build alone, the O frame's quota for the next boundary to put in force.

## tile_dump_records

`(1+DUMP_RECORDS)*REPORT_SIZE u8`: on a debug build alone, a tile's dump record and its texel records, written at once.

## tile_dump_building

`u8`: on a debug build alone, the D frame's byte 8, nonzero for the dump to take the BUILDING slot beside the READY ones.

## tile_config_record

`REPORT_SIZE u8`: the configuration record, REPORT_CONFIG's, CONFIG_* fields.

## tile_forget

`u8`: 1 when the console's L, an O's cold start, or a new slot cap asks every tile forgotten at the next boundary.

## tile_config_changed

`u8`: 1 when the console changed the configuration since the last boundary.

## material_alpha

`MAX_MATERIALS*MIP_LEVELS u32`: each material's alpha scale a level, 16.16.

## alpha_hist

`256 u64`: the search's counts of each alpha value.

## alpha_cover

`MIP_LEVELS u64`: the shares by level, for the line.

## alpha_chain_levels

`u64`: the chain's levels of the material in hand, the scales to find.

## alpha_plane_a

`ALPHA_PLANE_BYTES u8`: one of the two planes a level's alphas alternate between.

## alpha_plane_b

`ALPHA_PLANE_BYTES u8`: the other plane.

## tile_pool

`TILE_POOL_BYTES u8`: the slots' tiles, TILE_BYTES each, page-aligned, a tile four pages at 64.

## tile_tags

`TILE_SLOTS u32`: each slot's tag, its generation in the high sixteen bits and its state, SLOT_*, in the low.

## tile_slots

`TILE_SLOTS*SLOT_SIZE u8`: each slot's record, SLOT_* fields.

## tile_free

`TILE_SLOTS u32`: the free stack, its count tile_free_count.

## tile_surfaces

`LUMAP_COUNT*TS_SIZE u8`: each surface's record at the lumel maps' index, TS_* fields.

## tile_directory

`TILE_DIRECTORY_ENTRIES u32`: the entries, 0 for no tile, else the slot plus one in bits 0 to 15 and the slot's generation at publication in bits 16 to 31.

## tile_merge_bits

`TILE_DIRECTORY_ENTRIES/8 u8`: the boundary's merge bitmap, a bit an entry.

## tile_merged

`TILE_MERGE u64`: the boundary's merged keys, each the key in the low word and the next entry on its surface's chain in the high, all ones for none.

## tile_merge_heads

`LUMAP_COUNT u64`: each surface's merged chain, its next entry in the low word and its last in the high, all ones for none.

## tile_merge_order

`LUMAP_COUNT u32`: the surfaces merged, in the merge's order.

## tile_requesting

`LUMAP_COUNT/8 u8`: the boundary's union of the contexts' requesting surfaces, a bit a surface.

## tile_admission

`TILE_CONTEXTS*TA_SIZE u8`: each raster context's admission block, TA_* fields.

## tile_tables_end

The end of the pool's tables from `tile_pool`, TILE_MEMORY's bound.
