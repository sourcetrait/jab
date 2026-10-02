# mip.S

The chain exists so a block reads the texture at about a texel a pixel
whatever its distance: the lit and unlit loops read level 0 at any
distance before it, a far floor sampling every fourth to sixteenth texel,
which aliases and touches a cache line a pixel, and the tile cache's
coarser levels had no cheaper source than averaging the level below. The
level is still chosen per block by its footprint (raster.S); a level per
surface at its nearest point, which an engine with faces capped at a few
hundred units can afford, would leave the far end of a twenty-metre floor
at level 0.

## texel_shrink

One macro for the tile and the chain, lifted from tile_shrink's loop
instruction for instruction, so a tile at a level and the chain's level
hold the same texel under one brightness and the two cannot drift; the
alpha fixture holds the tiled and the lit pictures identical over the
opening at levels 0, 1, and 2. The rule and its history are tile_shrink's
(tile.S.md): alike alphas the plain mean, unalike the alpha-weighted mean
by one reciprocal with each product rounded, the alpha the mean scaled by
the level's factor and capped.

## mip_levels

A level while both sides stay two texels or more, so a 256-by-1024 fence
reaches 1 by 4 at level 8 and stops; MIP_LEVELS caps a 1024-texel square
at level 9, two by two.

## mips_build

Runs after the engine's images load and after alphas_measure, so the
sprites' chains, which the android's frames need at distance as the fence
does, build under the policy's scales; the measure moved behind the
images for the same reason and runs over every record. Each level is
built from the one before, the finer row pair walked two texels at a
time, the output written straight into the arena from a bump cursor; a
chain the arena cannot finish stops at the level in hand and the
material's count says so, the span holding its level under the count.
Nothing is freed: the chain is a property of the load, as the lumel maps
are. The arena is bss, free until touched, and a chain is a third of its
texture, so the factory's chains take about six megabytes of the thirty-two.
