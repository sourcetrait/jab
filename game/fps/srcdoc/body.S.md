# body.S

The body under the camera and under every android: a capsule walked along the
level forward and right, held off the walls and the other bodies, on the floor
plane of its sector.

The capsule is BODY_RADIUS 0.35 wide and BODY_HEIGHT 1.8 tall with the eye
EYE_HEIGHT 1.6 above its feet, the same for the player and every android.
Walls being vertical, the body against a wall is a circle against the wall's
segment in the plan. A wall blocks when its surface is solid, when it has no
portal, or when no sector across its portals admits the body; a sector across
admits it when its floor at the nearest point lies no more than a step above
the feet and its ceiling there leaves the body's height over that floor. The
step is 0.501, a thousandth over, since a floor set exactly a step up read as
a hair higher under the eye's single rounding. The walls are tested twice
over so a corner holds; only the sector's own walls are tested, so a corner
where two sectors meet can be entered by a frame before the new sector's
walls push out.

A floor within a step above or anywhere below within a step is stood on, the
fall speed zeroed, so a ramp walks itself and a step down lands at once; a
floor further below is fallen to under GRAVITY. A ceiling is not yet met.

The lengths are the vec2 register forms, the vectors being register-resident:
body_push takes the square of the offset through `reg.sqrlen`, compares it,
and roots it only when the bodies overlap; wall_push takes the push vector's
length in place. The register forms touch only their destination, so the
vectors survive them and nothing is stored or reloaded.

## k_body_radius_d

`f64`: the capsule's radius.

## k_body_radius_sq_d

`f64`: the radius squared.

## k_body_height_d

`f64`: the capsule's height.

## k_body_eye_d

`f64`: the eye over the feet.

## k_body_step_d

`f64`: the highest floor stepped onto, over the feet.

## k_body_gravity_d

`f64`: the fall's acceleration, metres a second squared.

## k_thousandth_d

`f64`.

## k_walk_speed

`f32`: the walk at full throw, metres a second.

## body_move

The level forward and right come from the yaw.

## feet_move

The sector is followed from the moved feet at the eye's height; then the
floor is met, and where it lies further below the feet fall.

## wall_push

The wall blocks by its surface, then by any sector across it; a sector across
admits the body when its floor at the point is at most a step above the feet
and its ceiling leaves the body's height over that floor. The feet are pushed
out along the nearest point's normal, or the wall's when the feet sit on the
wall.

## body_fall

`f64`: the player's fall speed.
