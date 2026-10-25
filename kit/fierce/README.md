# Jab FPS, 1K

A first-person shooter in RISC-V assembly on the Jab kernel, drawn on
the hart at 1080p: sloped floors and ceilings, sector over sector, a
free camera, light in colour, and its own binary map format,
`<name>.jabfps.map`, compiled from a map source. The first program
built against the Jab SDK from outside its workspace, for the 1K tier
(`doc/SPEC.md`); this directory is the game and everything it needs.

- `src/` the game: the loader of a map, which reads it off the
  program's disk, holds it to the format's rules, decodes its textures,
  reads its ambient pieces, and reports every count on the UART; the
  renderer, a portal walk over a depth buffer with an integer span, the
  sprites, and the light; and the body walked by the pad over the
  floors and against the walls. `srcdoc/` holds every symbol and its
  prose.
- `test/` the game's test, whose suite lives in `nu/mod/suite/`, on our
  own content alone: the load screen's title, a sprite and the alpha
  policy on copies of Render One, Render One from its spawn and six poses
  with a stair walked to its upper storey, Render Zero from its spawn and
  four poses, its three walks, and the fight, the frame's cadence, the
  light and the alpha policy rendered, and two broken maps; and two
  programs of their own, `fillrate`, the probe of what the hart draws a
  second, and `footprint`, the footprint arithmetic's fixtures.
- `content/` our content by kind: `map/` the map sources, Render Zero
  (`render_0`), the game's map, FPS Tech's three-storey works with its
  garage, mezzanine offices, yard, and driveway, and Render One
  (`render_1`), the map the format and the engine are proven on;
  `texture/` and `sprite/` the images, each authored as an SVG beside
  the PNG the engine reads; `ambient/` the note lists beside the MIDI
  pieces; `sound/` the recipes beside the samples.
- `nu/` our scripting: under `mod/` the map format's reader, writer, and
  compiler, a PNG writer, the review captures, the gauge, which measures
  every frame of play against the frame's ceiling, and the suite; under
  `bin/` the commands, `do.nu` and `nuance.nu`.
- `bench/` the benches: `cadence.nuon`, the frame's cadence in your
  window, and `qual_1ka1.nuon` and `qual_1kb1.nuon`, the qualification's.
- `rust/` a cargo workspace for the host tools: `svg2png`, which
  renders the SVGs, and `footprint`, the exact block footprint a
  capture's levels are held to.

The game and its two test programs build, test, and run through the jab
root's `do` in the jab workspace around them, each manifest's
`workspace` key naming it for a copy outside the tree: the kernel is
built there with the same symbols, the generic disk rides along, and the
output lands in the jab target at the program's path. Building the game compiles our maps first
(`nu/bin/nuance/prepare.nu`); the game's commands for development are
`nu/bin/nuance.nu`'s. From the jab root:

    ./do build kit/fierce                    # the game
    ./do test kit/fierce                     # the game's test and its programs'
    ./do run fierce                          # the game in a window
    kit/fierce/nu/bin/nuance.nu render       # every asset under content/ rendered
    kit/fierce/nu/bin/nuance.nu compile      # every map source into the asset shard
    kit/fierce/nu/bin/nuance.nu gauge run    # every frame of the gauge's route, three runs
    kit/fierce/nu/bin/nuance.nu              # every command for development

The bench `bench/cadence.nuon` measures the frame's cadence in your
window with live audio, your own play and then the gauge's route: run
`nu/bin/nuance.nu watch bench kit/fierce/cadence` in one terminal and
`./do bench kit/fierce/cadence` in another, and the watch reports the
whole bench when it ends.

`kit/fierce/nu/bin/nuance.nu shot` turns a run's capture into a PNG to
look at.
