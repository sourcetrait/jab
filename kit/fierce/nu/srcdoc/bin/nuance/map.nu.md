# nuance/map.nu

The map compiler's command line, a standalone bin so the compiler runs in a
nu that loads only the map modules: its closure commands, invoked a wall and
an entity, each copy the whole engine state, so the compile slows with all
the code loaded beside it. render_0's `build` took 0.42 s alone, 0.64 s
beside the SDK's build module, and 2.5 s beside the gauge nuance.nu loads.
Its verbs take the arguments and print the lines map.nu's script did; tree
and map/trees run its `compile` a source.

## main compile

map/compile's `main`: a source compiled to its tree under `out`, the
content at `--content` or the game's own.

## main show

map's `show`: a compiled map's counts and its spawn as one NUON record.
