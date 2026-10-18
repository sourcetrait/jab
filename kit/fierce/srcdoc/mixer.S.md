# mixer.S

The game's sounds into the kernel's stream: MIX_CHANNELS channels mixed into
stereo frames kept MIX_AHEAD ahead of what plays, a sound at the player or
from a world point by distance and pan.

Gains are in 256ths a side; the full gain is 96, three eighths, so three
sounds together stay under full scale: at 256 a round at the player peaked
over 22,000 and two overlapping clipped, and at 128 a round with a spark and
a second round still met it. From a point the volume is 1 within MIX_NEAR 2 m
of the eye, falling straight over MIX_RANGE 38 m to nothing at 40; the pan is
the point's share along the camera's level right over the level distance
times 0.6, the left gain scaled by 1 - pan and the right by 1 + pan, each
capped at 1; a point under the eye is centred.

The ring is kept MIX_AHEAD three periods, 60 ms, ahead so a 50 ms frame does
not run it dry; with the kernel's eight periods in flight a sound lands about
200 ms after its start. The kernel adds the synthesizer's voices at full
scale over the game's frames.

## .set MIX_CHANNELS

The channels mixed.

## .set MIX_AHEAD

The frames the stream is kept ahead of what plays, three periods.

## .set MIX_MAX

The most frames mixed a frame.

## .set CHANNEL_DATA

`addr`: a channel's samples.

## .set CHANNEL_FRAMES

`u64`: the sound's frames.

## .set CHANNEL_POSITION

`u64`: the next frame to play.

## .set CHANNEL_LEFT

`i32`: the left gain in 256ths.

## .set CHANNEL_RIGHT

`i32`: the right gain in 256ths.

## .set CHANNEL_SIZE

A channel's bytes.

## .set SOUND_BYTES

The sound arena's bytes.

## sound_stems

`SOUND_COUNT addr`: the engine's stems by SOUND_*.

## k_mix_near_d

`f64`: the distance from the eye within which a sound is full.

## k_mix_range_d

`f64`: the distance past that over which it falls to nothing.

## k_mix_pan_d

`f64`: the pan at most either way.

## k_gain_full_d

`f64`: a sound's full gain, three eighths in 256ths, so three sounds together stay under full scale.

## k_mix_level_eps_d

`f64`: a level distance under which a sound is centred.

## word_sound_g1_shot

`8 u8`.

## word_sound_g1_reload

`10 u8`.

## word_sound_g1_empty

`9 u8`.

## word_sound_g1_bolt

`8 u8`.

## word_sound_footstep1

`10 u8`.

## word_sound_footstep2

`10 u8`.

## word_sound_servo

`6 u8`.

## word_sound_alert

`6 u8`.

## word_sound_spark

`6 u8`.

## word_sound_struck

`7 u8`.

## word_sound_destroy

`8 u8`.

## word_sound_pickup

`7 u8`.

## word_sound_door_open

`10 u8`.

## word_sound_door_close

`11 u8`.

## word_sound_gate

`5 u8`.

## word_sound_respawn

`8 u8`.

## word_sound_dir

`8 u8`.

## word_pcm_ext

`5 u8`.

## msg_sound

`12 u8`.

## msg_sounds

`13 u8`.

## sounds_load

A sound kept moves the cursor on to a word boundary.

## sound_start

The distance and the level distance are the vec3 and vec2 register lengths
of the eye-to-point vector; its x and y are copied to ft10 and ft11 first
because the yaw's sine and cosine, taken after, clobber the scratch set the
vector was computed in.

From the world, the volume goes by the distance to the eye; the pan is the
point's share to the right, along the level right (sin yaw, -cos yaw), over
the level distance.

## mixer_update

mixer_update is page-aligned for its per-sample loops; its two traps a frame,
the stream's room and the write, are the calls the hot check allows it.

The buffer is cleared, then each channel added; the mix is clipped into
16-bit pairs, in place from the front.

## sound_cursor

`addr`: the sound arena's next free byte.

## sound_at

`SOUND_COUNT addr`: each sound's samples in the arena, 0 for none.

## sound_frames

`SOUND_COUNT u64`: each sound's frames.

## channels

`MIX_CHANNELS*CHANNEL_SIZE u8`: the channels, CHANNEL_* fields.

## mixbuf

`MIX_MAX*2 i32`: the mix, a pair a frame, clipped in place to 16-bit pairs.

## sound_arena

`SOUND_BYTES u8`: the sounds' samples.
