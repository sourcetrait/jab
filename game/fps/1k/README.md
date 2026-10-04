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
- `test/` the game's test, which runs the sample maps, a sprite, a
  walk, the proof map of our own content with a stair walked to its
  upper storey, the factory from its spawn, three poses, three walks,
  and the fight, and two broken maps; the gauge, which measures every
  frame of play against the frame's ceiling; and `fillrate`, the probe
  of what the hart draws a second, a program of its own.
- `content/` our content by kind: `map/` the map sources, the proof
  map and the factory, FPS Tech's three-storey works with its garage,
  mezzanine offices, yard, and driveway; `texture/` and `sprite/` the
  images, each authored as an SVG beside the PNG the engine reads;
  `ambient/` the note lists beside the MIDI pieces; `sound/` the
  recipes beside the samples.
- `nu/` our scripting: the map format's reader, writer, and compiler,
  a PNG writer, and a capture viewer.
- `rust/` a cargo workspace for the host tools: `svg2png`, which
  renders the SVGs.

Both programs build, test, and run through the jab root's justfile
against the jab workspace three directories up, named by the
`workspace` key of each manifest: the kernel is built there with the
same symbols, the generic disk rides along, and the output lands in the
jab target at the program's path. Building the game compiles our maps
first (`nu/prepare.nu`); the game's commands for development are
`nu/adv.nu`'s. From the jab root:

    just build game/fps/1k       # the game and the probe
    just test game/fps/1k        # the game's test and the probe's
    just run game/fps/1k         # the game in a window
    just adv render              # every asset under content/ rendered
    just adv compile             # every map source into the asset shard
    just adv gauge               # every frame of the gauge's route, three runs
    just adv                     # every command for development

The bench `bench/cadence.nuon` measures the frame's three cadences in
your window with live audio, your own play at each and then the gauge's
route at each: run `just watch bench game/fps/1k/cadence` in one
terminal and `just bench game/fps/1k/cadence` in another, and the watch
reports the whole bench when it ends.

The sample trees in the game's asset shard of the jab target,
`asset/game/fps/1k/<map>`, are laid out by conversion tooling kept
outside this repository over third-party sample content, never shipped,
until the game runs on its own content alone; the test stops with a
message when one is missing. `just adv shot` turns a run's capture into
a PNG to look at.
