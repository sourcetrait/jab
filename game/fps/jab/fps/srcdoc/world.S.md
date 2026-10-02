# world.S

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

The draw order is the flow's first-reach order, breadth-first from the
camera's sector, which puts the near sectors first for the depth test;
a sector reached twice is drawn once. Sprites and actors are drawn within
their sector's rectangle, which also stops a quad poking through a wall
from showing in the sector beyond.

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

A wall's u runs along it from its first vertex and its v down from the
author's anchor height, the same for every piece of the wall and over its
openings. The wall's unit direction is a vec2 norm by hand over
jab.f64.vec2.reg.len, the library carrying no vec2 norm.

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

Every plane and wall piece, and a masked opening's fill, binds its tiles
right before its fill (tiles_bind, tile.S): after the mode and the map's
bind, since the tiled flag rides the lit one, and after the loops'
projection, which is why the plane's bind sits at the end of its loop
rather than beside the map's. The frame's tile budget is set beside the
stats' zeroing, so the first polygons drawn build first.

The depth clear is 8 MB, about two milliseconds; its loop and the uncovered
count's are aligned to 32 bytes inside their functions. On a DEBUG build the
frame is painted magenta first, so a capture shows what no surface reached.
