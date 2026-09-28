# Jab FPS

A first-person shooter in RISC-V assembly on the Jab kernel, drawn on
the hart at 1080p: sloped floors and ceilings, sector over sector, a
free camera, light in colour, and its own binary map format,
`<name>.jabfps.map`, compiled from a map source. The first program
built against the Jab SDK from outside its workspace.

- `jab/` the programs: `fillrate`, the probe of what the hart draws a
  second, and `fps`, the game: the loader of a map, which reads it off
  the program's disk, holds it to the format's rules, decodes its
  textures, reads its ambient pieces, and reports every count on the
  UART; the renderer, a portal walk over a depth buffer with an integer
  span, the sprites, and the light; and the body walked by the pad over
  the floors and against the walls. Its test runs the sample maps, a
  sprite, a walk, the proof map of our own content with a stair walked
  to its upper storey, the factory from its spawn, three poses, and
  three walks, and two broken maps.
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

Each program under `jab/` builds, tests, and runs through its own
justfile against the jab workspace at `../../../jab`, named by the
`workspace` key of its manifest: the kernel is built there with the
same symbols, and the generic disk rides along.

    just render     # every SVG under content/ to its PNG
    just compile    # every map source into .target/asset/<name>

    cd jab/fillrate
    just test
    just run --no-pad --no-sound

    cd jab/fps
    just test
    just run

A program's `assets` recipe compiles our maps first. The sample trees
under `.target/asset/<map>` are laid out by conversion tooling kept
outside this repository over third-party sample content, never
shipped, until the game runs on its own content alone; the recipe stops
with a message when one is missing. `just shot` turns a run's capture
into a PNG to look at.
