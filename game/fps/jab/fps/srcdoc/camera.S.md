# camera.S

The camera: the eye and its yaw, pitch, and roll, with the basis of right,
up, and forward derived from the angles each frame; the pad's look and walk;
the camera's sector; the records over the API.

The basis is derived from the angles each frame rather than accumulated, so it
is orthonormal by construction and nothing re-squares it. The roll turns right
and up about forward; a positive roll tilts the camera's up toward its right.

camera_d is the camera as doubles, written at the end of camera_basis: the
surface mathematics in surface_setup, surface_axis, and sprite_draw dots the
plane's doubles with the camera's through jab.f64.vec3.dot, which reads
doubles from memory, and every change of the eye precedes camera_basis in a
frame, the walk first and then the console's P, which derives the basis
itself.

The yaw is kept within a turn by subtracting or adding tau once a frame; the
pitch is clamped to k_pitch_limit, 89 degrees, short of straight up and down.
A stick's throw is -1 to 1 past a dead zone of 0.15, rescaled to reach 1.

## camera_basis

The level right is (sy, -cy, 0) and the up (-cy sp, -sy sp, cp); turned by
the roll, right' = right cr - up sr and up' = up cr + right sr. The camera
goes into camera_d a float at a time.

## camera_look

The trigger's press is read two ways, the keys pressed since the frame before
and every press among the events since, so a press released within the frame
still fires.

With no pad the body stands where it is. The yaw runs counter-clockwise from
east, so a right turn takes from it; the pitch is held within its limit; the
body is moved by the left stick's throws.

## report_fill

A leaf shared by the state and event records; the event's a0 to a5 survive it,
which is why it holds its addresses in t3 to t5 and converts through ft8,
outside the type libraries' scratch set.
