# Jab FPS's nushell

Our own scripting for the game.

`map.nu` is the map format's reader, writer, and compiler: `map read`
gives a Jab FPS map, `<name>.jabfps.map`, as a record of its sections
with its names resolved, held to the format's rules; `map write`
encodes one; `map build` turns a map source into one; run as a
script, `nu map.nu compile <source> <out>` writes the tree the engine
reads, and `nu map.nu show <map>` prints a compiled map's counts.
`ambient.nu` renders a note list to a Standard MIDI File and
`sound.nu` a synthesis recipe to 48 kHz PCM, both behind `just adv
render` with the SVGs. `png.nu` writes a PNG without a compressor, RGB
or RGBA. `shot.nu` turns a run's screen capture into a PNG to look at,
behind `just adv shot`. `prepare.nu` compiles the maps before the game
is built, tested, or run, and `adv.nu` holds the game's commands for
development, which `just adv` lists.

The sample content's trees in the game's asset shard of the jab target,
`asset/game/fps/1k/<map>`, are laid out by conversion tooling kept
outside this repository (`../README.md`).
