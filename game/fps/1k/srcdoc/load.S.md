# load.S

The map held to its format: the header and the sections parsed, the records
checked, the materials, the engine's images, the ambients, and the soundfont
loaded; a fault says so on the UART and exits with its code.

The loader computes nothing the compiler wrote; it checks it and reads it in
place. Every record is read with word loads, which is why the writer pads
each section to a word boundary and the loader refuses an offset off one.

## kind_sizes

`KIND_COUNT u32`: a kind's record size, by kind from 1.

## kind_limits

`KIND_COUNT u32`: the most of a kind this build holds, by kind from 1.

## kind_words

`KIND_COUNT addr`: a kind's word, by kind from 1.

## k_slack_d

`f64`: the spawn's slack about its sector's planes.

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
records; Render Zero's 23 textures and 69 frames load in about 800 ms, most
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

## kind_seen

`16 u8`: the kinds the directory named, a byte a kind.

## ambient_playing

`i32`: the ambient playing, -1 for none.

## frame_base

`u32`: the material index of the engine's first image, after the map's.

## word_kind_names

`6 u8`.

## word_kind_materials

`10 u8`.

## word_kind_vertices

`9 u8`.

## word_kind_sectors

`8 u8`.

## word_kind_loops

`6 u8`.

## word_kind_walls

`6 u8`.

## word_kind_portals

`8 u8`.

## word_kind_entities

`9 u8`.

## word_kind_ambients

`9 u8`.

## word_kind_sector_lights

`14 u8`.

## word_directory_count

`46 u8`.

## word_directory_kind

`30 u8`.

## word_directory_twice

`19 u8`.

## word_directory_aligned

`35 u8`.

## word_directory_size

`50 u8`.

## word_directory_missing

`13 u8`.

## word_material

`10 u8`.

## word_ambient

`9 u8`.

## word_sector

`8 u8`.

## word_loop

`6 u8`.

## word_wall

`6 u8`.

## word_portal

`8 u8`.

## word_entity

`8 u8`.

## word_sector_light

`14 u8`.

## word_name_past

`34 u8`.

## word_loops_range

`26 u8`.

## word_lights_range

`27 u8`.

## word_ambient_range

`27 u8`.

## word_materials_range

`30 u8`.

## word_under_three

`23 u8`.

## word_walls_range

`26 u8`.

## word_other_sector

`43 u8`.

## word_not_next

`43 u8`.

## word_vertices_range

`41 u8`.

## word_sector_range

`26 u8`.

## word_portals_range

`28 u8`.

## word_material_range

`28 u8`.

## word_out_of_range

`17 u8`.

## word_not_exact

`14 u8`.

## word_class_unknown

`35 u8`.

## word_references_range

`31 u8`.

## word_outside_sector

`22 u8`.

## word_outside_planes

`36 u8`.

## word_not_light

`16 u8`.

## word_no_spawn

`14 u8`.

## serial_mix

`4 u8`: the generic disk's serial.

## path_font

`29 u8`: the soundfont's path on the generic disk.

## word_sprite_dir

`9 u8`.

## word_android_dir

`9 u8`.

## msg_soundfont

`16 u8`.

The debug lines' text, from here to word_loaded_comma, is in a debug build
alone.

## word_presets

`11 u8`.

## word_instruments

`15 u8`.

## word_samples

`9 u8`.

## msg_soundfont_refused

`24 u8`.

## msg_no_soundfont

`43 u8`.

## word_playing

`9 u8`.

## word_refused

`10 u8`.

## msg_frames

`13 u8`.

## msg_frame_missing

`12 u8`.

## word_loaded_comma

`10 u8`.
