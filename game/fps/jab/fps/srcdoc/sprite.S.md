# sprite.S

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
length squared and d likewise, with offsets putting a half at the centre.

A sprite is lit by one evaluation a frame at the quad's centre, point_light
over the polygon's culled list, written as the sprite's own lumel map of four
lumels alike so the fill reads it through the same loop as a wall: a sprite
moves, so no map can be baked for it, and one brightness over a quad a metre
or two across is the sprite's grain. A sprite facing the camera is lit at no
angle: POLY_FLAT_LIT is set after surface_setup, which clears it, and the
evaluation takes the cosine as one for every light within reach, since the
face is the eye's and a light behind it left the android black from one side.
The evaluation's ticks are the frame line's light microseconds, the only
per-frame evaluation left.

The level length of the camera's right is jab.f64.vec2.len over camera_d's
right, the doubles the basis already wrote.
