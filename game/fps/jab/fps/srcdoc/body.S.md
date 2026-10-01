# body.S

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

The lengths ride the vec2 macros through vec3_scratch, the vectors being
register-resident: body_push stores the offset once and takes the square and
the length from it; wall_push stores the push vector and reloads it after the
macro, whose scratch set covers the registers it sat in. bodies_push holds
its loop in t4 and t5 because body_push's macros clobber t0 to t2.
