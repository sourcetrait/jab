# tree

## STRADDLE_MATERIAL

The straddling sprite: a quad of the uniform alpha case over the pass,
its colour as the unlit copy draws it, fixed and two-sided, along y
through the door sector (x 3 to 5, y 8 to 9) with its feet in it and
its ends past both of its portal walls; the pose in the hall's
north-east sees it obliquely, so the quad's near end lies over the
hall's solid north wall beside the doorway, outside the door's
rectangle, where a clip to that rectangle would cut it; a point on
that near end

## ALPHA_CASES

The alpha cases, textures of the test's own laid in the sprite tree,
every one a material of its map: the sprite's halves; a uniform alpha
over the pass, which the engine leaves at one and names no line for;
a uniform alpha under it; a checkerboard of opaque and transparent
texels, whose coarser levels go uniform; an 8 by 8 texture with one
opaque 2 by 2 block, whose coarsest level is one texel; and a 4 by 4
whose every 2 by 2 holds three alphas at the pass and one a step
under it, three quarters passing, whose means of 127 vanish at level
1 unless the search lifts them back over the pass. The engine's line
for a material under full coverage, its share of texels at or above
the pass at every level of its chain in 10000ths and every coarser
level's scale in 65536ths; the slack each of the first three coarser
levels of the fence and the grate as authored may sit from level 0,
stated from the measured lines: the fence's levels read 606, 947, and
922 against 733, and the grate's 6093, 6093, and 5000 against 6093,
its third a step the search cannot reach nearer; the deeper levels of
a texture a few texels a side move in steps too coarse to hold, and
the oracle holds them exactly instead

## MIP_LEVELS

The chain's levels at most and the scratch a level's alphas take at
the search, past which a texture keeps a scale of one (render.inc's
MIP_LEVELS and ALPHA_PLANE_BYTES)

## FIXTURE_MAP

The alpha policy rendered: Render One's grate wall given a texture
of the test's own, 256 square at two repeats a metre so a lumel cell
is one repeat, in patches of 64 texels of one kind each, a kind a 2
by 2 of alphas and colours indexed by a texel's parity on each axis:
opaque red; green at the pass less one; blue at the pass; yellow
under alpha 255 and black under 0, whose weighted mean is yellow
where a plain mean is not; transparent black; cyan at 255 and 145
over black, whose mean of 100 stays under the pass; and red at 255
with blue at 128 twice over black, whose weighted mean the shrink's
rule gives as (127, 0, 128) where a plain mean gives (63, 0, 127) and
an equal weighting of the opaque texels (85, 0, 170); the grid of
kinds over the 4 by 4 patches counted so the search moves the
threshold to 127 at level 1, where the means of 127 against level 0's
halves and three quarters leave 128 short, and keeps 128 after; the
alcove behind the wall a solid backdrop of one colour on every
surface, so an absent patch reads it exactly; the samples the centre
texel of every patch in two repeats over the wall, none under the
crosshair; the poses head-on at distances where the wall's blocks
read level 0, 1, and 2 by the block's rule over 512 texels a metre,
each run again with the tiles held off for the lit loop's picture,
identical at every level; the opening compared inset from its edges

## CENTRE_FIXTURE

The texel-centre rule rendered: the fixture's wall given a white
texture of the test's own, 16 square at two repeats a metre, so a
lumel cell is 16 texels, one repeat, its nodes on the repeats' edges;
the console's L frame byte 7 setting every lumel by its node's parity,
a quarter where its column and row sum even and one where odd, so a
cell's bilinear light runs steeply from each corner; head-on at 2 m,
level 0, a texel some 15 pixels across; the four texels touching each
node in the opening read at their centres against the bilinear light
there times 255, within the slack of the build's two truncations,
where a texel lit at its corner reads 63 or 85 beside a dark node and
255 or 232 beside a bright one; a tile's texel one colour over the
pixels about its centre, where the lit loop lights each pixel at its
own coordinate and the same pixels vary

## BUILDER_FIXTURE

The builder's assertion (suite tiles builder-holds): the fixture's wall given an
opaque texture of the test's own, 64 square at a quarter repeat a
metre, 16 texels a metre, so a lumel cell is 8 texels, k 3, and its
chain of 7 levels holds levels 0 to 2 below k, 3 at it, and 4 to 6
above, every channel varied over both axes; every tile of the wall at
every level built by the console's B frame and read back by its D
frame under the bright, the gradient, and the parity lumels in turn,
each step BUILDER_STEP after the one before, from BUILDER_AT. A
texel's channel c, lit by the light L of its centre, reads c L / 256
within one for the multiply's floor and c over 256 times one lane and
the build's truncations, a centre's rounding and a step a texel along a
cell's segment, under BUILDER_TRUNCATIONS of a lane's 256ths at this k.
The oracle runs in a nu of its own over tiles.nu, which loads nothing
else, its per-texel loop slowed some fifteenfold inside this module

## HANDOFF_FIXTURE

The handoff's measurement (suite tiles handoff-holds), the HANDOFF set running
it alone: the north room's long wall, HANDOFF_EDGE of its loop, given an
opaque white texture of the test's own, 64 square at half a repeat a
metre, 32 texels a metre, so a lumel cell is 16 texels, k 4, its chain
of 7 levels holding levels 0 to 3 below k, 4 at it, and 5 and 6 above,
and a tile of level 0 two metres of the wall, so its spans cross tiles
at the levels whose tiles are narrower than the wall seen, where the
grate wall is one tile wide; posed head-on HANDOFF_DISTANCE from it,
where every block of the wall reads level 0, each level of the chain
drawn by the console's M frame raising every block's level; under the
gradient and the parity lumels, the wall settled on its tiles under the
lift and drawn with them held off, and at the levels whose spans cross
tiles, drawn under partial residency, construction once on
HANDOFF_PARTIAL_SLOTS slots on the serial backend, the O frame sent
HANDOFF_ONCE_AFTER the first placement, so its spans alternate hits and
misses. Each run places the view at PLACE_AT and again at SETTLE_AT,
takes its screen at HANDOFF_SCREEN_AT while it goes on, and sends the
console's E at HANDOFF_END_AT, the bound HANDOFF_SECONDS; the HUD
stamps each frame's number (raise-frame's `--stamp`, stamp-of)

## GROW_MAP

The flow's growth: a map of the test's own (grow-source) where the
hall S is reached from the camera's room C first through a narrow
high window, two hops, and again through a side room T and its wide
door, three hops, after S has been flowed once; a far room D opens
off S in the line of sight through T's doors and outside the window's
rectangle on screen, so D is reached only when S is flowed again with
its grown rectangle; D's surfaces are the backdrop, read exactly on a
point of its far wall through its doorway, the map unlit

## EYE_HEIGHT

The eye's height over the feet, and how far in the plan the spawn's
eye may stand from the spawn, a body's radius, the push off a wall
there, with a millimetre's slack

## variant

A copy of a map source with the entities of the given classes dropped,
compiled under out with the game's content; the tree's path.

## romfs

A romfs image of the tree, as the SDK builds one, with the program's
volume name; the image's path.

## sprite-tree

A copy of a map source compiled with its lights and its android
dropped, so every texel reads as its texture holds it, and an alpha
case a sprite, two-sided: the straddler, a fixed quad along y; with
--halves the halves sprite facing the camera; and every other case a
small fixed quad standing in the upper storey, out of the lower's
sight, so it is a material of the map; each case's texture written
into the tree after the compile, which names it unresolved; the
tree's path.

## case-texel

A texel of an alpha case: its four bytes as the PNG carries them, red,
green, blue, alpha, and its alpha. The halves: the left transparent, the
right opaque red. Uniform: one colour at the case's alpha. The checker:
opaque red and transparent texels alternating on both axes. The block:
transparent but for an opaque white 2 by 2 at the top left. The edge:
one colour at the case's alpha, the pass, but a step under it where
both coordinates are odd, one texel of every 2 by 2.

## chain-levels

The levels a texture's mip chain has, as the engine builds it: one,
and one more for every halving while both sides are two texels or
more, MIP_LEVELS at most, so a side can end at one texel.

## fixture-row

A row of the alpha fixture: its pixels as the PNG carries them, each
texel the colour and the alpha its patch's kind gives its parity on
each axis in the kind's 2 by 2, and the row's alphas alone.

## fixture-tree

A copy of Render One compiled with its grate wall given a material
of the test's own at a scale, the alcove's floor, ceiling, and walls
given the backdrop's, its android dropped, and the backdrop laid in the
tree after the compile, which names it unresolved; the tree's path.

## alpha-tree

The alpha fixture's tree: the grate wall given the fixture's texture
at its scale, or at `--scale`, the texture laid in; the tree's path.

## centre-tree

The texel-centre fixture's tree: the grate wall given an opaque white
texture of CENTRE_FIXTURE's size at its scale, laid in; the tree's
path.

## grow-source

The growth map's source: eight rectangular sectors, the camera's room
C with a narrow high window W into the hall S and a door E into the
side room T, T's wide door G into S, and S's door H into the far room
D, every surface the panel but D's, which are the backdrop; a spawn in
C and no lights, so every texel reads exactly.

## grow-tree

The growth map compiled under out with the game's content and the
backdrop texture laid in after the compile, which names it
unresolved; the tree's path.

## builder-tree

The builder fixture's tree: the grate wall given its texture at its
scale, laid in; the tree's path.

## handoff-tree

The handoff fixture's tree: the north room's long wall, HANDOFF_EDGE of
its loop, given an opaque white texture of HANDOFF_FIXTURE's size at its
scale, laid in, its other walls the room's own; the tree's path.

## wall-lumap

A wall's lumel map as lumap_frame lays it (light.S): k the exponent of
the power of two nearest the texels in half a metre along u, a cell 2^k
texels; U0 and V0 a texel before the least u and v, aligned down to
the texture's size; W and H the columns and rows, two past the cells
from them to the greatest u and v.

## plan-views

The plan views of a compiled tree held to the source: an SVG a
storey, each at the storey's bounds with the compiler's margin and
scale.

## broken

A tree holding a map of the given bytes under the given name; its
path.

## wall-clearance

A point's distance in the plan from the nearest wall of a sector's
loops.
