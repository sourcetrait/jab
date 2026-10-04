# actor.S

The actors: the androids the map places, the magazines they drop, the sparks
where a round lands; an android runs rows of a frame set, a time, and an
action.

The numbers: the walk 1.5 m/s, arrival 0.3 m, blocked 1 s; sight 40 m within
the front half turn and 3 m all round; a cycle of aim and fire 0.75 s and the
sight lost for 2 s; the first round after rousing certain and the rest by
FIRE_CHANCE 128 in 256; the stray tan 12 degrees over 128 a unit of chance,
so at 12 m a round lands within about 2.5 m of the eye either way. With them
one android in sight strikes the frame about every ten seconds at that range.

The generator is the SDK's xorshift over the state word rng in player.S,
seeded at player_reset; every draw names its address. The lengths and the
normalisation go through the vec3 macros: actor_to_eye writes the raw line
into aim, takes its length into AIM_DIST, and norms it in place through the
memory forms, so a zero line stays zero where the former eps clamp made it
huge; action_fire strays the direction in registers and norms it there
through `reg.norm`; actor_walk's distance is the vec2 register length.

## frame_sets

`8 addr`: the rotating sets' stems.

## frame_singles

`5 addr`: the singles' stems, the fallen frame, the three sparks, and the magazine.

## android_rows

`15*4 u32`: an android's rows, the set, the milliseconds, the action, and the next, ROW_* fields.

An android's rows: STAND holds 400 ms looking; PATROL1 to 4 cycle 200 ms
frames walking; ALERT 300 ms then AIM; AIM 600 ms then FIRE; FIRE 150 ms then
AIM; SEARCH1 to 4 cycle walking to the last sight; STRUCK 300 ms then AIM;
DESTROYED 200 ms then FALLEN, which holds. A row ended enters the next with
the leftover carried, up to eight rows a frame, so a long frame never stalls
the table.

## action_table

`10 addr`: each ACT_*'s action.

## k_octant

`f32`: the tangent of an eighth of a half turn, the octants' edge.

## k_thousandth_f

`f32`.

## k_two

`f32`.

## k_spark_seconds

`f32`: a spark frame's seconds.

## word_set_stand

`6 u8`.

## word_set_walk1

`6 u8`.

## word_set_walk2

`6 u8`.

## word_set_walk3

`6 u8`.

## word_set_walk4

`6 u8`.

## word_set_aim

`4 u8`.

## word_set_fire

`5 u8`.

## word_set_struck

`7 u8`.

## word_single_fallen

`15 u8`.

## word_single_spark1

`15 u8`.

## word_single_spark2

`15 u8`.

## word_single_spark3

`15 u8`.

## word_single_magazine

`13 u8`.

## actors_place

The feet go on the sector's floor; an android patrols from the start when it
has a waypoint, else it stands.

## actors_tick

A walking row steps toward its target before its timer runs.

## actors_draw

An actor's surface index is after the map sprites, by index.

## actor_draw

The fallen frame faces the camera, the android on its back seen from its
side, two metres by a half, so it reads from any side; drawn flat along the
yaw it read as garbage from most. An android draws its row's set.

## actor_rotation

The rotation frame is the eighth of a turn nearest the angle from the
direction toward the eye to the facing, by the octant of its cosine and sine:
c = f.d and s = fy dx - fx dy; |s| within k|c| gives 0 ahead or 4 behind,
|c| within k|s| gives 2 or 6, else the quadrant, k the tangent of 22.5
degrees. The frames are drawn so the front shows facing the eye and the right
side two eighths on.

## actor_walk

The actor faces its heading; the move made is measured against the step for
the blocked seconds.

## actor_sight

Seen, the player's feet are remembered.

## action_fire

The stray: the direction moved along the level right and up by two shares of
chance, then made unit again.

## k_chest_d

`f64`: the chest over the feet.

## k_spark_drop_d

`f64`: a spark's drop under its point.

## k_spark_spread_d

`f64`: how far the destruction's sparks spread a unit of chance.

## k_android_speed_d

`f64`: the android's walk a second.

## k_arrive_d

`f64`: the arrival radius.

## k_quarter_d

`f64`.

## k_sight_range_d

`f64`: the android's sight's range.

## k_near_sight_d

`f64`: the range it sees all round.

## k_stray_d

`f64`: the G-1's stray a unit of chance, the tangent of twelve degrees over 128.

## k_blocked_seconds

`f32`: the seconds blocked before a waypoint is given up.

## k_cycle_seconds

`f32`: a cycle of aim and fire.

## k_lost_seconds

`f32`: the seconds without sight before the search.

## actors

`MAX_ACTORS*ACTOR_SIZE u8`: the actor table, ACTOR_* records.

## actor_entity

`ENTITY_SIZE u8`: the scratch entity an actor draws through.

## aim

`7 f64`: the line from an actor's eye to the player's, the eye, the unit direction, the distance, AIM_* fields.
