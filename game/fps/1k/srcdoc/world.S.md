# world.S

The world drawn from the camera: the view flowed through the compiler's
portals to a screen rectangle a sector, then each reached sector's planes and
wall pieces drawn within its rectangle over the depth buffer.

The view is flowed through the compiler's portals before any drawing, and
every sector reached is drawn within a screen rectangle. The flow's queue
starts with the camera's sector at the whole screen, or every sector at
the whole screen when the camera is in none; each sector popped projects
the opening of every portal on its walls facing the camera, intersects
the opening's rectangle with the sector's own, and grows the neighbour's
rectangle by it, queueing the neighbour when it grew. A sector's
rectangle is the union of the rectangles of every path that reaches it;
a sector is flowed again when its union grows, with the union, so the
rectangles only grow and the flow ends, and a rectangle inside the
neighbour's already changes nothing, which is the termination and the
only cycle guard. Doom 3 walks a stack of paths with a rectangle each and
the frustum planes of the clipped portal, and guards cycles by the
portals on the stack; ours keeps one rectangle a sector and intersects
rectangles rather than clipping by planes, which is coarser where an
opening lies diagonal in its parent's rectangle and costs four compares
in place of a polygon clip. The rectangle is a bound on where the sector
can appear, never the visibility: the depth buffer stays and decides
every pixel, so an opening is never tested against what is drawn, and
the sampled test that could miss an opening narrower than its stride is
gone with the allowance that hid such a miss.

Every plane and wall piece, and a masked opening's fill, binds its tiles
right before its fill (tiles_bind, tile.S): after the mode and the map's
bind, since the tiled flag rides the lit one, and after the loops'
projection, which is why the plane's bind sits at the end of its loop
rather than beside the map's. The frame's tile budget is set beside the
stats' zeroing, so the first polygons prepared build first; a COUNT build
zeroes its count_stats there too (raster.S).

The frame is prepared, then rendered: the flow, the sectors, the sprites,
and the actors fill their polygons into the frame's packet, and the
packet is rendered after the actors (raster.S), the depth buffer and on a
debug build the magenta prepaint laid before preparation as before, since
preparation reads neither. The phases are preparation's: the planes', the
walls', and the sprites' ticks are marked by phase_mark, the clock less
the raster's ticks, so a full packet rendered inside a phase is the
raster's and no phase's; the raster's ticks are the frame line's last
phase.

## k_near_sq_d

`f64`: the near distance squared, within which a masked wall's opening goes unfilled.

## k_zero_d

`f64`.

## k_flow_near_sq_d

`f64`: the flow's near case squared, 1.522 times the near distance.

1.522 times the near distance, an on-screen point's distance being at most
that times its depth (the screen's half extents over hz are 1 and 0.5625),
so an opening whose wall lies further off loses nothing on screen to the
near plane.

## k_facing_slack_sq

`f32`: the flow's facing slack, a millimetre squared, the eye on a wall's line within it still flowing the wall.

## world_draw

The draw order is the flow's first-reach order, breadth-first from the
camera's sector, which puts the near sectors first for the depth test;
a sector reached twice is drawn once. Sprites and actors are drawn within
their sector's rectangle, which also stops a quad poking through a wall
from showing in the sector beyond.

The depth clear is 8 MB, about two milliseconds; its loop and the uncovered
count's are aligned to 32 bytes inside their functions. On a DEBUG build the
frame is painted magenta first, so a capture shows what no surface reached;
the release build leaves the frame before. The flow is timed as the portals'
phase; the sectors are prepared in the order the flow reached them, then the
sprites and the actors of the sectors reached, into a packet emptied at the
frame's start, a debug build's bind count with it; on a debug build the
producer's scratch is poisoned before the last render.

## phase_mark

A phase's ticks are one mark less another; with no flush in a phase the
raster's ticks do not move inside it and the mark is the clock's.

## world_flow

Every rectangle is emptied and no sector is seen or waiting; the camera's
sector takes the whole screen, queued, and in no sector every sector does.
The queue is drained, each sector flowed with its rectangle as it stands,
into the draw order the first time.

## sector_flow

The opening's rectangle is the projected polygon's extents under the
fill's own pixel-centre rule, a pixel of slack each side, since a span's
crossing can land an ulp past a vertex and a rectangle a pixel short
would leave that pixel uncovered. The near case: with the eye within
1.522 times the near distance of the wall's segment in the plan, the
neighbour takes the sector's own rectangle, because an on-screen point
of an opening that close can lie before the near plane and clip away;
the screen's half extents over hz are 1 and 0.5625, so an on-screen
point's distance is at most sqrt(1 + 0.5625^2 + 1) times its depth, and a
wall further off than that times the near distance has no on-screen
opening point the near plane clips. Doom 3 inherits the parent's
rectangle within one of its units for the same reason, a constant of its
scale and not ours. The flow's cost is the portals' phase on the frame
line, and the openings it flowed are the line's openings.

The flow's facing test carries a slack of a millimetre in the eye's
distance from the wall's line: the cross product it reads is the wall's
run times that signed distance, so a fixed threshold on the product would
mean a different distance for every wall length, and the test passes a
wall whose product is positive or whose product squared lies within the
slack squared times the run squared, with no square root. The eye
exactly on a portal's line, which a strict test rejected before the near
case could take the wall, and which the renderer before this one
rejected the same way, now flows the wall and the near case hands the
neighbour the sector's rectangle; Render One's line pose holds it.
The draw's own facing test stays strict, since a wall edge-on draws
nothing.

Facing: the camera on the sector's side of the wall's line, its left from a
to b; the ends kept as doubles for the cut. On the line within a millimetre,
which the near case takes: the product's square against the slack's square
times the run's square. The sector's planes are taken at both ends, for the
opening's clamp; the near case once a wall. Near, the neighbour takes the
sector's own rectangle; otherwise the opening is projected and its rectangle
held within the sector's. An opening flowed grows the neighbour, queued when
it grew.

## sector_draw

A sector's facing walls are gathered with the squared distance from the eye
to each wall's nearest point as the key, insertion-sorted into wall_order,
and drawn nearest first, after the planes. The order changes no stored pixel
(the gauge captures match byte for byte) and measured no gain: the rejected
count rose by 30k on the spawn view and not at all on the up flight. A probe
that counted, per sector, the pixels whose store replaced an earlier one
placed the overwrite between sectors, not within one: on the up flight the
hall's own walls overwrite 56k pixels while up1's side walls overwrite 375k,
half of what they enter, and on the down flight down1's walls 404k. The
camera's hall is T-shaped and drawn first and whole, so the far wall of its
stem, seven metres off, is stored where the flight's near side walls land a
sector later. The rectangles reach the pixels the depth test rejected,
which never enter a span now; the overwrite inside the camera's own
rectangle stays, SpanSort's.

The sector's rectangle clips every span of it. The planes: the floor unless
the camera is below it, the ceiling unless the camera is above it, judged at
the plane's height under the camera. The walls facing the camera: the camera
on the sector's side of the wall's line, its left from a to b; each gathered
with the squared distance to its nearest point as the key, then drawn nearest
first, so the depth test rejects more of the far ones. The key is the eye's
offset from a less its share along the run, clamped to the segment, squared;
each wall is inserted in order of the key and drawn in that order.

## material_bind

material_bind names the material's mip chain in the polygon beside its
texture, the table of levels and the levels it has (mip.S), which the
span's blocks read at their footprint's level (raster.S). The width's
power of two below it gives the mask and the row shift.

## plane_draw

A plane's and a wall's surface name their surface index and their lumel
map in the polygon, then run surface_setup, the mode, and lumap_bind in
that order: the setup clears the flat flag the mode reads, so the mode
comes after it; poly_mode adds the lit flag when the map has lights and
the polygon either has no map, a sprite lit flat, or a baked one, so a
surface the bake left unmapped draws unlit rather than reading a map of
nothing; and the bind folds the map's origin into the coefficients the
setup wrote, once a polygon, a wall's for each piece and opening since each
is its own setup. No plane or wall piece culls lights per frame any more:
the per-polygon list had no reader on the baked path, and the box and the
cull ran for nothing; a sprite still culls for its one evaluation
(sprite.S), and the bake culls once a map (light.S).

The plane is the normal (-a, -b, 1) and the point (0, 0, c), u along x and v
along y by the surface's scales and offsets. The loops' edges go into one
list, each loop a polygon of its walls' first vertices at the plane's height.

## piece_polygon

The quad; the triangle at the start, the start's top and bottom and the
crossing along the top; or the triangle at the end.

## wall_surface

A wall's u runs along it from its first vertex and its v down from the
author's anchor height, the same for every piece of the wall and over its
openings. The wall's unit direction is a vec2 norm by hand over
jab.f64.vec2.reg.len, the library carrying no vec2 norm.

The normal and a point; e, the unit direction along the wall, and the
start's distance; u, the scale along e from the start; v, the scale down
from the anchor height. The mode comes after the setup, which clears the
flat flag the mode reads, then the lumel map is bound.

## wall_draw

A wall is drawn as pieces between the sectors across it, which the file's
portals give sorted from the top down: for k over the portals plus one, the
piece's top is the sector's ceiling for k 0 and portal k-1's sector's floor
after, its bottom portal k's sector's ceiling or the sector's floor at the
end, each height taken at both ends of the wall. Above each piece but the
first lies the opening into portal k-1's sector, which only a masked wall
draws: its surface filled over the opening in masked mode, the opening
cut by opening_cut as the flow cuts it, the neighbour's ceiling and floor
clamped to the sector's where they pass it at both ends, unless the camera
is within the near distance of the wall, where the opening would clip
away. A piece is cut where its planes cross along the wall: the quad when
the top is above the bottom at both ends, the triangle at the end where it
is.

## walk_tail

`u64`: the sectors in walk_fifo.

## stats

`26 u64`: the frame's counts and its ticks by phase, STAT_* fields.

## walk_fifo

`MAX_SECTORS u32`: the sectors in the order the flow first reached them, the draw order.

## walk_seen

`MAX_SECTORS u8`: 1 for a sector the flow reached this frame.

## wall_order

`MAX_WALLS u64`: a sector's facing walls in the order they are drawn, the key, the squared distance from the eye to the wall's nearest point as a float, then the wall.

## sector_rect

`MAX_SECTORS*4 i32`: every sector's screen rectangle, the union of the openings it is seen through.

## flow_pending

`MAX_SECTORS u8`: the flow's waiting flags.

## flow_ring

`FLOW_RING u32`: the flow's ring of sectors.

## flow_head

`u64`: the ring's read.

## flow_tail

`u64`: the ring's write.

## clip_rect

`4 i32`: the rectangle the spans in hand are clipped to.
