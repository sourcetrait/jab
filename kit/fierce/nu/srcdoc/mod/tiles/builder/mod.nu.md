# tiles/builder

The builder's assertion (`nu bin/nuance/tiles.nu builder <api> <spec> <out>`):
the tile dumps a capture holds, read whole by tiles' `read`, held texel by texel
to the host's oracle, each texel the chain's at its tile's level lit by the
light of its centre, bilinear over the lighting's nodes with the coordinate
clamped to the last node, within the build's rounding.

## builder-chain

The builder fixture's chain, a level a list of rows of [red, green,
blue, alpha]: level 0 the texture's texels, each coarser level the floor
of the mean of the two by two under it a channel, the shrink's rule for
alike alphas, the texture opaque, its alpha kept at a full coverage's
scale of one; one level more for every halving while both sides are two
or more, ten at most, as the engine builds it.

## builder-nodes

A map's nodes under one of the builder's lightings, a row a list of
[red, green, blue] in a lane's 256ths, as the console sets them: bright
every lane one; the gradient red 256 c / (W - 1), green 256 r / (H -
1), and blue 256 (c + r) / (W + H - 2), each floored; the parity a
quarter where c and r sum even and one where odd.

## builder-tile

A dumped tile held to the oracle under a lighting: each texel against
the chain's texel at the tile's level, the texel's column and row masked
to the level's size, lit by the light of the texel's centre, (X + 1/2)
2^m texels of level 0 from the map's first node, bilinear over the
lighting's nodes with the coordinate clamped to the last node. A
channel c lit by L reads c L / 256 within 1 + c (256 + truncations) /
65536: one for the multiply's floor and c over 256 times one lane and
the build's truncations. Counted: the texels past that, those other than
the chain's under the bright, those whose alpha is not the chain's,
those whose centre lies past the last node, and those where the light of
the texel's corner reads past twice the rounding; with the most any
channel lies from its light. Under the bright a row is held whole to the
chain's words, the light one.

## main

The builder's oracle over a capture: the spec a NUON record of the
texture's size, the lightings in the order the dumps came, the map's k,
W, and H as the host lays them out, and the build's truncations; the
result, saved to out as NUON, the dumps' count, every problem `dumps`
found, and each lighting's whole tiles with their headers and
builder-tile's counts.
