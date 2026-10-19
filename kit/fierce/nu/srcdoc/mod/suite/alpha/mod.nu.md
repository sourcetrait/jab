# suite/alpha

## FIXTURE_DEEP

The alpha fixture past the old four levels the atlases held: the same
texture on the grate wall of a second tree at 16 times its scale, 8,192
texels a metre, posed head-on where the wall's blocks read levels 3 to
6, each distance the middle of its level's octave

## alpha-held

A material's alpha line among a run's, its first three coarser levels'
shares of texels at or above the pass each within the material's slack
of level 0's.

## alpha-line

An alpha line read: its material, its share of texels at or above the
pass at every level of the chain in 10000ths, and every coarser
level's scale in 65536ths.

## levels

The alpha policy as the engine applies it at load, over a texture's
alphas in row order: the share of texels at or above the pass at level
0 in 10000ths, the target; then each coarser level of the chain, its
alphas as the integer means of the two by two under them in the level
before, the threshold whose share at or above it lies nearest the
target (the least error, a tie to the lower share, equal shares to the
threshold nearest the pass), the level's scale ceil(2^23 / T), and the
level scaled by it and capped at 255 for the level after; whether the
engine names a line for the texture, which it does under full coverage
at level 0 for a chain with a level past 0 whose level 1 fits the
search's scratch; and the planes by level, level 0 the alphas given and
each coarser level's scaled alphas in row order at half the width,
which the tiles and the chain hold.

## shrink-colour

The colour the tile shrink gives a coarser texel from the four under
it, as the engine computes it: alike alphas take the plain mean of
each channel; otherwise each channel's sum weighted by the alphas,
times the truncated reciprocal of their sum in 8.24, a half added and
the product shifted down, so a transparent texel's colour counts for
nothing and an exact mean survives.

## fixture-samples

The fixture's samples: the centre texel of every patch in each repeat
of the texture over the wall, the world point it maps to along the
wall from its first vertex and down from its anchor by the surface's
scales and offsets, its colour by level, the texel's own at level 0
and the shrink's at every coarser one, which the alike path then
carries unchanged, and whether its patch passes at each level by the
oracle's plane for the level; a kind is uniform when its 2 by 2 holds
one alpha and one colour, so its level 0 reading does not hang on
which texel a pixel lands on.

## fixture-read

The fixture's samples read from a capture: each one's pixel from the
eye at yaw 0, clear of the crosshair, its colour at the level, and
whether its patch shows there.

- a loop, so a failing assertion is the error raised, not the each's

## centre-samples

The texel-centre fixture's samples: the four texels touching each node
of the wall's lumel map whose centres, with the pixels about them,
project inside the opening and clear of the crosshair, the map laid as
lumap_frame lays it, its origin a whole repeat at least a texel before
the wall's least u and its sector's top's v, a node a cell apart; each
texel with the node's parity, its light the cell's four nodes bilinear
at the texel's centre by the console's parity rule times 255, the
colour a white texel lit there takes, and the same at its corner, the
reading of the rule the centre replaced.

## centre-read

The texel-centre samples read from a capture: each one's pixel at its
centre, the most any of its channels lies from the colour expected, and
whether the pixels CENTRE_FOOTPRINT about its centre each way are all
that one colour.

## at-load

the alpha policy at load over the test's own textures, against the
same rule on the host: each level's share of texels at or above
the pass and the scale that holds it, a line a material under full
coverage and none for one at it

## grate

the grate as authored: its coarser levels' share within the slack

## fence

the fence as authored: each coarser level's share at or above the
pass within the slack of the texture's

## fixture

the alpha policy rendered: a copy of Render One with its grate
wall given the fixture texture and its alcove the solid backdrop,
every lumel full bright and the tiles forgotten by the console's L
frame, each pose read settled, so a pixel reads a tile's texel, the
chain's at the tile's level; each patch's centre projected
onto a pixel and read: its exact colour where the oracle's plane
for the pose's level passes, the backdrop exactly where it does
not, so at level 0 the 128 patches show and the 127 ones do not,
and at the coarser levels the scale the search chose lifts the 127
patches and the varied ones over the pass, the yellow surviving
the weighted mean over black and the red and blue mixing as the
shrink's rule says; each pose run again with the tiles held off
draws the lit loop's picture from the texture's chain at the same
level, read the same way and identical over the opening

## deep

past the old four: the texture at FIXTURE_DEEP's scale on a second
tree, levels 3 to 6 by the block's rule, a level-6 tile holding its
4 by 4 texels sixteen times over as the chain's masks wrap them; tiled
and held off under the bright frame, identical over the opening

## centre

the texel-centre rule (CENTRE_FIXTURE): the fixture's wall white
under lumels set by their nodes' parity, posed head-on at level 0
settled on its tiles and again with them held off; every sampled texel
beside a node read on the tiled run at its centre against the
light of its centre, the four nodes of its cell bilinear there, and
one colour over the pixels about its centre, which a tile holds and
the lit loop, lighting each pixel at its own coordinate, does not:
the held-off run's same pixels vary, proving the tiled reading came
from the tiles; the samples' own arithmetic putting a texel lit at
its corner past the slack beside dark and bright nodes alike; and
the held-off run continuous along its rows, each lit interval
starting from the exact end sample of the one before
