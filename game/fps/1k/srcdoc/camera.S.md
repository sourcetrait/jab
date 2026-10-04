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

## k_turn_speed

`f32`: the yaw's turn at full throw, radians a second.

## k_look_speed

`f32`: the pitch's turn at full throw, radians a second.

## k_pitch_limit

`f32`: the pitch at most either way, 89 degrees.

## k_pad_full

`f32`: a pad axis's full scale.

## k_dead_zone

`f32`: a stick's dead zone.

## k_one

`f32`.

## k_zero

`f32`.

## k_eye_height

`f32`: the eye over the spawn's feet.

## k_sixty_four_k

`f32`: one in 16.16.

## k_sky_turns

`f32`: the sky's repeats a radian, four a turn.

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

## camera

`15 f32`: the camera, CAM_* fields.

## camera_d

`15 f64`: the camera as doubles at twice its offsets.

## cam_sector

`i32`: the camera's sector, -1 for none.

## right_x

`u32`: the right stick's x axis code.

## right_y

`u32`: the right stick's y axis code.

## report_record

`REPORT_SIZE u8`: the record going over the API.

## pad_state

`JAB_PAD_ENTRY u8`: the pad's state this frame.

## axis_record

`5 i32`: the pad's own range for an axis.
