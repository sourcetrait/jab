# nuance/tiles.nu

The tile pool's readers and oracles' command line, a standalone bin so they
run in a nu that loads only the tile modules: their closure commands,
invoked a row and a tile, each copy the whole engine state, and beside the
gauge nuance.nu loads, `builder-chain` took 0.64 s against 0.20 s alone.
Its verbs take the arguments and write the files tiles.nu's script did; the
suite's tiles and light parts, the handoff recipes, and the eviction probe
and stress run them a capture a nu.

## main dumps

tiles' `dumps`: a capture's whole tiles a dump and every problem, saved to
`out` as NUON.

## main keys

tiles' `keys`: a capture's dumps keyed by tile header and texels' SHA-256,
the texels never decoded, saved to `out` as NUON.

## main builder

tiles/builder's `main`: the builder's oracle over a capture, each
lighting's whole tiles held texel by texel, saved to `out` as NUON.

## main handoff

tiles/handoff's `main`: the handoff pair at `index` of the spec compared,
its statistics saved to `out` as NUON.

## main lit-steps

tiles/steps' `main`: the most the lit loop's picture steps between two
pixels side by side along a rectangle's rows, saved to `out` as NUON.
