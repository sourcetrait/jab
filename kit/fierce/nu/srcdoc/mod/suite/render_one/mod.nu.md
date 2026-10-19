# suite/render_one

## SPRITE_MAP

The sprite launches, on copies of Render One the test compiles with
its lights and its android dropped, so every texel reads as its
texture holds it (sprite-tree): the halves sprite, the test's own
texture whose left half is transparent and right half red, facing the
camera and two-sided, its feet in the hall three metres in front of
the `sprite` pose and two metres a side, so its halves fill the middle
of the screen with the hall's west wall behind; the same copy without
it draws that wall from the same pose

## LIGHT_POSE

The light: Render One's pose under the hall's light, its eye the
spawn's, facing west 45 degrees down, the floor under the light at the
bottom of the screen and the far wall at the top, blocks of [x, y, w,
h]; the bottom block's mean brightness over the top's at least
LIT_RATIO, measured 1.79 lit and 1.12 with the lit flag never set,
the floor's texture being the brighter

## plain

a sprite: a copy of Render One with its lights and its android
dropped and the halves sprite facing the camera in the hall, seen
from in front of it: its right half the texture's red and its
transparent left half the wall behind, as the same copy without the
sprite draws it from the same pose

## straddle

the straddling sprite, seen obliquely from the hall: the door's
rectangle as the flow hands it on, the hall's portal wall into the
door sector, between its two ends' columns from the pose with the
flow's pixel of slack, and the quad's near end left of it over the
solid wall beside the doorway; there it reads the texture, the quad
drawn over the whole screen as one not proven within its sector,
where a clip to the sector's rectangle would cut it off

## poses

Render One, the map the format and the engine are proven on: loaded
and held to its counts, the camera at the spawn with its eye over the
floor there facing the spawn's way, the sign drawn from the spawn,
the stairwell seen from the upper room through its window, the
alcove through the grate, the north room through the door, the ramp
posed with no pixel uncovered, the door tagged, a plan view a storey
at the storey's bounds, and last the hall's light, the floor under
it brighter than the far wall

- the line pose stands with the eye on the line the hall and the door
  sectors share, looking into the hall, which the flow reaches only by
  its facing slack, the eye's distance from the wall's line being zero
  there; the ramp's stands at its middle, midway between its planes,
  facing up its slope 30 degrees down at it; the light's is the
  capture's, last

## spawn

the camera at the spawn: in its sector, its eye a body's radius at
most from it in the plan, the eye's height over the floor there,
facing the spawn's way

## light

the hall's light, the capture's pose: the floor under the light
brighter than the far wall by LIT_RATIO at least

## stair

the stair: from Render One's spawn the left stick held forward up
the three steps onto the landing, a quarter turn to the north, then
up the ramp into the upper hall
