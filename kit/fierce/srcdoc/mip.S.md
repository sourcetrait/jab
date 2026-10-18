# mip.S

The texture's mip chain: each material's coarser levels built at load from the
level before by texel_shrink under the level's alpha scale, so a span reads
the level a block's footprint asks for, and a tile of the pool, which copies
the chain's texels at its level lit, and the lit loop at the same level draw
the same texel.

The chain exists so a block reads the texture at about a texel a pixel
whatever its distance: the lit and unlit loops read level 0 at any
distance before it, a far floor sampling every fourth to sixteenth texel,
which aliases and touches a cache line a pixel. The
level is still chosen per block by its footprint (raster.S); a level per
surface at its nearest point, which an engine with faces capped at a few
hundred units can afford, would leave the far end of a twenty-metre floor
at level 0.

## msg_mips

`11 u8`.

## word_chains

`10 u8`.

## word_levels

`10 u8`.

## word_texels_in

`12 u8`.

## word_ms_end

`4 u8`.

## .macro texel_shrink

Alike alphas take the plain mean a channel and the alpha as it is; unalike,
each channel's mean weighted by the alphas, so a transparent texel's colour
counts for nothing, by one reciprocal of their sum, each product rounded to
the nearest so an exact mean survives, the alpha their mean; the alpha then
scaled by the level's factor and capped at 255.

An earlier rule averaged the colour channels plainly and kept the
upper-left texel's alpha, so a square with one opaque texel was either an
opaque dark texel or nothing by which corner the opaque one sat in, and
the fence and the grate changed density and darkened with distance by
sampling phase, Astra's finding. Now the colour is weighted by the four
alphas, so a transparent texel's colour, black in the content's PNGs,
counts for nothing, and the alpha is the mean of the four, scaled by the
material's factor for the level (alphas_measure) and capped at 255. The
weighting divides once a texel by one reciprocal of the alpha sum in 8.24,
three multiplies in place of three divides, each product rounded to the
nearest before its shift: the reciprocal's truncation puts a product under
the true mean by at most a sixtieth of a level, so with the half added an
exact mean, a constant colour under any alphas among them, comes back
exact, where a plain shift returned 254 for one opaque white texel among
three transparent ones (Astra's review), and a half-way case may fall by
one. The four texels are loaded unsigned, since a sign-extended word's top
byte is not its alpha. The alike case, four equal alphas, which is every
texel of an opaque texture and most of a masked one, takes the plain mean
and the alpha as it is, with no divide.

The scale lands a mean at or above the chosen threshold T at or above the
pass and nothing under T there, which an 8.8 scale, ceil(32768 / T), fails
above T 194 (brute force over every T and alpha: T 195 with alpha 194
passes, and twenty more pairs up to T 254); ceil(2^23 / T) in 16.16 holds
for every T to 2896, so every T. The masked loops then test the word's top
bit, the alpha at or above 128, in place of any nonzero alpha, the same op
count. A tile copies the chain's texels at its level, so the tiled and the
lit pictures agree over the alpha fixture's opening at every level, which
the test holds.

## mip_levels

A level is added while both sides of the one before are two texels or more,
so a side can end at one texel: the 256-by-1024 fence reaches 1 by 4 at
level 8 and stops there. MIP_LEVELS is a cap of its own, a policy apart from
that limit, which holds a 1024-texel square at level 9, two by two.

## mips_build

Runs after the engine's images load and after alphas_measure, so the
sprites' chains, which the android's frames need at distance as the fence
does, build under the policy's scales; the measure moved behind the
images for the same reason and runs over every record. Each level is
built from the one before, the finer row pair walked two texels at a
time, the output written straight into the arena from a bump cursor; a
chain the arena cannot finish stops at the level in hand and the
material's count says so, span_fill holding every block's level under the
count before it chooses the tile or the chain, and the tile pool's
directory holding a grid for every level the count names.
Nothing is freed: the chain is a property of the load, as the lumel maps
are. The arena is bss, free until touched, and a chain is a third of its
texture, so Render Zero's chains take about six megabytes of the thirty-two.

Each level takes its alpha scale from material_alpha; a level built is
counted and the next builds from it; where the chain ends the count is the
level in hand.

## material_mips

`MAX_MATERIALS*MIP_LEVELS addr`: each material's chain, the texels of every level, level 0 the record's own.

## material_mip_count

`MAX_MATERIALS u64`: the levels each material has.

## mip_cursor

`addr`: the arena's next free byte.

## mip_arena

`MIP_ARENA_BYTES u8`: the chains' coarser levels.
