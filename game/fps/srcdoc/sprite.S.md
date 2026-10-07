# sprite.S

The sprite entities drawn after the walk, each a flat quad facing the camera,
fixed along its yaw, or flat on the floor, masked by alpha.

## k_pull_d

`f64`: the quad's share of its distance from the eye after the pull, a hundredth toward it.

## k_tiny_d

`f64`: a level right shorter than this stands on end.

## sprites_draw

A map sprite's surface index is after every map, by entity.

## sprite_draw

A sprite's position is its feet; with w and h its width and height: facing
the camera, the centre is h/2 up, r is the camera's right kept level and
scaled to w/2, and d is (0, 0, -h/2), so it turns to the eye about the
vertical and stays upright under any roll, a right standing on end leaving it
facing its yaw; fixed, r is (-sin yaw, cos yaw, 0) w/2, so it faces its yaw
with u increasing to the right of a viewer in front; flat, the centre is the
feet, r is (cos yaw, sin yaw, 0) w/2 and d (sin yaw, -cos yaw, 0) h/2, so it
lies on the floor along its yaw with its face up. The normal is d cross r,
the side the texture faces.

The quad is pulled a hundredth of the way to the eye with its axes scaled the
same, so a sprite laid on a wall wins the depth test. The plane record is the
normal, the pulled centre, and u and v as world gradients, r over twice its
length squared and d likewise, with offsets putting a half at the centre, so
each is 0 at the near edge and 1 at the far.

A sprite is lit flat: one evaluation a frame at the quad's centre,
point_light over the polygon's culled list, written as the polygon's one
brightness word, which the fill takes over the whole quad with no sample
and no step (raster.S). A sprite moves, so no map can be baked for it, and
one brightness over a quad a metre or two across is the sprite's grain; the
polygon names no map, which is what tells the mode and the fill it is flat.
Before this the brightness went into a map of four lumels alike and the
fill read it per block through the general path, converting and weighting
a constant. A sprite facing the camera is lit at no angle: POLY_FLAT_LIT is
set after surface_setup, which clears it, and before the mode, and the
evaluation takes the cosine as one for every light within reach, since the
face is the eye's and a light behind it left the android black from one
side. The evaluation's ticks are the frame line's light microseconds, the
only per-frame evaluation left.

The level length of the camera's right is jab.f64.vec2.len over camera_d's
right, the doubles the basis already wrote.

The feet and the half extents are taken as doubles, and the yaw's sine and
cosine. The quad goes in from the corner at u 0, v 0 around.

## sprite_within

The quad is clipped to its sector's rectangle from the flow (world.S)
only when it is proven within the sector, by sprite_within: the pulled
centre inside the sector by the even-odd rule; the level segment between
the pulled half widths crossing no wall of the sector's loops, a touch or
a collinear overlap counting as a crossing, the parallel case read as the
segment's start within a millimetre of the wall's line and the rest as
the crossing's shares along the segment and the wall within the unit
range widened by a thousandth; and the quad's bottom and top a millimetre
or more inside the floor and the ceiling at both ends of the segment.
Every slack points toward unproven: the margin inside the volume is
conservative, where a band outside it accepted a sliver that can stand in
the sector above or below through a stacking gap under a millimetre, which
the compiler allows, and half a millimetre at 0.125 m depth is nearly four
pixels. A flat quad, or one unproven, draws over the whole screen,
depth-tested
as before. The rectangle bounds what is seen through the sector's
openings, so it bounds a quad only while the quad lies in the sector: a
quad straddling a doorway has visible parts on the camera's side of the
portal plane, outside the rectangle, which the first form clipped away. A
flat quad can enclose an inner loop with no edge crossing, and the pull
toward the eye moves the centre and the extents, which is why the test
runs on the pulled quad and flat quads stay unclipped. A quad that pokes
through a solid wall is unproven and draws its sliver in the sector
beyond, as before this clip; a sprite in a sector the flow did not reach
is not drawn, as before. The surface index the caller names in
sprite_surface, a map sprite's by its entity and an actor's by its index,
goes into the polygon for the span record and the owner build.

The segment's ends a and b are the centre less and plus the half width, its
run d twice the half width; parallel, a crossing when the segment's start
lies within the slack of the wall's line, the cross with the run over its
length.

## k_within_den_d

`f64`: a cross product under which a wall runs parallel to the quad's segment.

## k_within_slack_sq_d

`f64`: a millimetre squared, for a segment's start on such a wall's line.

## k_within_low_d

`f64`: the crossing's shares widened a thousandth under the unit range.

## k_within_high_d

`f64`: the crossing's shares widened a thousandth over the unit range.

## sprite_surface

`u64`: the surface index the next sprite draws as, a map sprite's by its entity or an actor's by its index, named by the caller.
