# actor.S

An android's rows: STAND holds 400 ms looking; PATROL1 to 4 cycle 200 ms
frames walking; ALERT 300 ms then AIM; AIM 600 ms then FIRE; FIRE 150 ms then
AIM; SEARCH1 to 4 cycle walking to the last sight; STRUCK 300 ms then AIM;
DESTROYED 200 ms then FALLEN, which holds. A row ended enters the next with
the leftover carried, up to eight rows a frame, so a long frame never stalls
the table.

The numbers: the walk 1.5 m/s, arrival 0.3 m, blocked 1 s; sight 40 m within
the front half turn and 3 m all round; a cycle of aim and fire 0.75 s and the
sight lost for 2 s; the first round after rousing certain and the rest by
FIRE_CHANCE 128 in 256; the stray tan 12 degrees over 128 a unit of chance,
so at 12 m a round lands within about 2.5 m of the eye either way. With them
one android in sight strikes the frame about every ten seconds at that range.

The rotation frame is the eighth of a turn nearest the angle from the
direction toward the eye to the facing, by the octant of its cosine and sine:
c = f.d and s = fy dx - fx dy; |s| within k|c| gives 0 ahead or 4 behind,
|c| within k|s| gives 2 or 6, else the quadrant, k the tangent of 22.5
degrees. The frames are drawn so the front shows facing the eye and the right
side two eighths on.

The fallen frame faces the camera, the android on its back seen from its
side, two metres by a half, so it reads from any side; drawn flat along the
yaw it read as garbage from most.

The generator is the SDK's xorshift over the state word rng in player.S,
seeded at player_reset; every draw names its address. The lengths and the
normalisation go through the vec3 macros: actor_to_eye writes the raw line
into aim, takes its length into AIM_DIST, and norms it in place through the
memory forms, so a zero line stays zero where the former eps clamp made it
huge; action_fire strays the direction in registers and norms it there
through `reg.norm`; actor_walk's distance is the vec2 register length.
