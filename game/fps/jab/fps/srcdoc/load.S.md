# load.S

The map held to its format: the header and the sections parsed, the records
checked, the materials, the engine's images, the ambients, and the soundfont
loaded; a fault says so on the UART and exits with its code.

The loader computes nothing the compiler wrote; it checks it and reads it in
place. Every record is read with word loads, which is why the writer pads
each section to a word boundary and the loader refuses an offset off one.

## map_parse

The table and the kinds seen are cleared first; after the entries, every kind
must be present.

## map_check

map_check's order: the names of the materials and the ambients within the
table; every sector's loops, lights, ambient, and materials in range, every
loop three walls or more within the walls, each wall the sector's own and its
b the next's a around the loop; every wall's vertices in range and
different, its sector, portals, and material in range, and every portal
exact, its wall in its sector, another sector than the wall's, running the
same two vertices back; every entity's class, material, target, and sector
in range, inside its sector in the plan by the even-odd rule, the spawn
between its planes with a thousandth's slack; at least one spawn, the first
taken; every sector light an entity that is a light. A light may sit in a
ceiling and a sprite sunk in a floor: only the spawn is held to the planes.

## material_read

A missing file is named on the UART of a debug build. The record's capacity
is the header, then a row's pixels and its span for every row.

A material's record capacity is the SDK's rule, 16 plus rows times columns
times 4 plus 4; the arena is 64 MiB. The 512 by 512 textures are 1 MiB
records; the factory's 23 textures and 69 frames load in about 800 ms, most
of it the decodes.

## frames_load

A rotating set's path is android/<set>_<r>.

## ambients_load

A piece kept moves the cursor on to a word boundary. One missing, too long a
name, or not fitting is named on the UART as `fps: ambient N <path> missing`,
or with no path when the name is too long.

## soundfont_load

The soundfont is read in pages into a 160 MiB arena off the generic disk,
serial mix, which every launch inside the jab workspace carries.

## ambient_follow

The engine sees a piece's end through jab.sys.midi.playing once a frame and a
new piece's first period is the eighth in flight, so a restart lands about
200 ms after the end.

## msg_soundfont

The debug lines' text, from here to word_loaded_comma, is in a debug build
alone.
