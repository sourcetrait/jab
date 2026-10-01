# mixer.S

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

The distance and the level distance are the vec3 and vec2 register lengths
of the eye-to-point vector; its x and y are copied to ft10 and ft11 first
because the yaw's sine and cosine, taken after, clobber the scratch set the
vector was computed in.

mixer_update is page-aligned for its per-sample loops; its two traps a frame,
the stream's room and the write, are the calls the hot check allows it.
