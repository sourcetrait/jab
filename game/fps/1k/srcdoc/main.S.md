# main.S

The game's program: the map loaded off its disk and held to its format, the
title drawn, then the frame loop: the pad, the camera and the body, the
console, the actors, the ambient, the world drawn, the HUD, the flip, the
state over the API, and the display's tick or the pad awaited.

The load order is the dependency order: the map's records are checked before
anything indexes them, the materials load before the engine's images, whose
records follow the map's, the alpha coverage and the mip chains after both,
since the images' chains want the policy as the map's do, the lights before
the lumel maps, which bake over
the sector lists, the maps before the actors, whose placement reads the
sector floors, and the camera last, since its basis writes camera_d for the
surface mathematics. The frame loop runs the game's phases before the
drawing's and times each: the game's microseconds cover the pad, the console,
the camera, the actors, and the ambient; the drawing's cover world_draw alone.
The frame's whole time is measured too, its critical path from its start to
the end of its reporting, with the crosshair, the mix, the flip, and the
reporting timed apart and the await after the path alone; the frame before's
two records go over the API at a frame's start, once its await has ended, so
a record carries the await that followed its frame and the path whole
(render.inc's REPORT_FRAME and REPORT_DRAW, read by test/gauge.nu).

The crosshair is left off under OWNER, the build whose pixel loops store
the surface index in place of the colour (raster.S), so a capture of it is
the ownership alone; the build is debug with owner beside it, `just pose
<map> <poses> <out> debug,owner`.

The three type libraries are included after jab.inc: their macros expand in
place at every site, so the engine carries no sine, cosine, arctangent, dot,
length, or generator of its own. A vector that lives in a record goes through
the memory forms; one computed in registers goes through the `reg` forms,
which touch only their destination, so no site stores a vector to be read
back.

A step the load cannot take exits with its own code and a line naming it, the
codes and lines being the loader's contract with the test.

## .set MAP_BYTES

The map buffer's bytes.

## .set FILE_BYTES

The file buffer's bytes, a texture file at most.

## .set PIXEL_BYTES

The pixel arena's bytes, the textures' records.

## .set AMBIENT_BYTES

The ambient arena's bytes.

## .set FONT_BYTES

The soundfont buffer's bytes.

## .set PAGE_BYTES

The most read_file reads a call.

## .set NAME_BYTES

The map name's buffer.

## .set PATH_BYTES

A path's buffer.

## .set LINE_BYTES

A UART line's buffer.

## .set DIGITS_BYTES

append_dec's scratch.

## .set TITLE_SCALE

The title's scale, four times the console's cell.

The title: bold at four times the console's cell, centred; bold adds a pixel
to the width.

## .set TITLE_CELL

A title cell's width in pixels.

## .set TITLE_HEIGHT

The title's height in pixels.

## .set TITLE_Y

The title's top row, centred.

## .set TITLE_COLOR

`u32`: the title's colour.

## .set MS_TICKS

The time ticks a millisecond.

## .set US_TICKS

The time ticks a microsecond.

## .set LOAD_TOO_BIG

`u64`: a texture's file larger than its buffer, beyond the kernel's PNG codes.

## .set LOAD_ARENA_FULL

`u64`: a texture's record not fitting the pixel arena.

## .set CLOCK_ORIGIN

`u64`: frame_clock's tick of the program's start.

## .set CLOCK_START

`u64`: the frame's start, the tick its await ended.

## .set CLOCK_REPORT

`u64`: the frame's reporting in ticks, the frame before's records and its own state's.

## .set CLOCK_HUD

`u64`: the crosshair's ticks.

## .set CLOCK_MIX

`u64`: mixer_update's ticks.

## .set CLOCK_FLIP

`u64`: the flip call's ticks.

## .set CLOCK_FLIP_DONE

`u64`: the tick the flip returned.

## .set CLOCK_AWAIT

`u64`: the tick the reporting ended and the await began.

## .set CLOCK_FLIP_STATUS

`u64`: the flip's status, jab.sys.display.flip's code.

## .set CLOCK_SIZE

frame_clock's bytes.

## _start

The map's name is read with its trailing whitespace dropped and the map's
path built from it, /map/<name>.jabfps.map; the title is drawn centred on the
black screen; the map is read whole, then held to its format; loaded, the
screen is cleared and a debug build reports the load.

## frame

Under DEBUG the first frame's report goes out, and the first after a console
placement.

The marks, into frame_clock: the start, which is the await's end; the
reporting so far, the frame before's records; the game and the drawing as
before; the crosshair, the mix, and the flip with its status and its end;
the state report and a debug build's lines added to the reporting; and the
await's start, which ends the critical path. One register, s9, carries the
last mark, so each phase starts where the one before ended but for the few
instructions storing it, which no phase holds: the record's unattributed
time, a few microseconds a frame (`just test` prints the walk's greatest).

## frame_records

Built from frame_clock and the stats, which world_draw zeroes only when the
next frame draws, so at a frame's start they still hold the frame before's;
the loop stores s11, the program's start, as the clock's origin before its
first frame. Ticks become microseconds by a division a field. The start and
the flip's end are 64 bits, counted from the program's start, since 32 bits
of microseconds wrap at 71 minutes, inside a played session. The pair goes
in one write, the API's write being the one call besides the await that can
wait, and its cost is the reporting's. An E the console read in the frame
just recorded set measure_end, and the end marker goes out right after that
frame's pair, so every record of the measurement precedes it and the frames
past it are outside.

## load_report

The reports are the program's own debug lines, for its test: a release build
carries neither them nor their text, and says nothing but an exit.

The reports are there for the test and nowhere else: under DEBUG the first
frame is reported on the UART, and one after each console placement, so a
test reads the frame it posed, with the walk's order after it; a release
build carries neither the report routines nor their text and says nothing
but an exit, jab's rule for a program, which the test holds by scanning a
release image it builds for every `fps: ` string. The load line, the bake's,
the chains', the frames', the sounds', the soundfont's, and the ambient's
lines are under the same conditional at their sites, with
their text beside it, while a load that fails keeps its exit line in every
build, as a fault line stays on the UART. The line's tail, the spans and the
pixels they entered, the lit ones among them,
the light's microseconds, the pixels rejected, and the lumel samples, is the
light's instrument: pixels entered over the screen's 2,073,600 is the
overdraw, the light's microseconds, the sprites' evaluations now that the
surfaces read baked maps, say what the frame still evaluates, and the
samples against the pixels' blocks of sixteen say how often the lit spans
read their maps. The load line carries the maps baked, and the bake's own
line their lumels and time. The tiles built that frame and the pixels read
from tiles close the line: the first is the build's share of the frame,
zero once the view has settled, and the second against the lit pixels is
the near blocks' share, the far and edge ones staying on the lit loop
(tile.S). The tile arena is reset after the bake, since a map's maps are
the tiles' frame.

## count_report

A COUNT build's line after each reported frame's: `fps: count {divides}
divides, {avoided} avoided; blocks {shifted} shifted, {short} short;
negative steps off sixteen {u} in u, {v} in v; flat spans {flat};
mismatches {mismatches}`, from count_stats (raster.S). The divides
span_fill made before a change are the made plus the avoided; every
avoided one was recomputed from its original operands and compared, a
difference counted a mismatch.

## clear_screen

Falls into fill_screen with the colour 0.

## rec

`JAB_ROMFS_ENTRY u8`: the romfs record read_file finds the file into.

## digits

`DIGITS_BYTES u8`: append_dec's scratch, the digits built backwards from its end.

## line

`LINE_BYTES u8`: the UART line in hand.

## name

`NAME_BYTES u8`: the map's name, NUL-terminated.

## map_path

`PATH_BYTES u8`: the map's path, /map/<name>.jabfps.map.

## tile_path

`PATH_BYTES u8`: the path of the file the loaders read.

## map_bytes

`u64`: the map's bytes read.

## pixel_cursor

`addr`: the pixel arena's next free byte.

## ambient_cursor

`addr`: the ambient arena's next free byte.

## sections

`KIND_COUNT*2 u64`: the sections as the loader placed them, an entry a kind.

## spawn_index

`i32`: the map's first spawn, -1 for none.

## sprite_count

`u32`: the map's sprite entities.

## texture_count

`u32`: the materials whose texture loaded.

## missing_count

`u32`: the materials whose texture is not on the disk.

## frame_us

`u32`: the last frame's drawing in microseconds.

## game_us

`u32`: the last frame's game in microseconds.

## frame_seconds

`f32`: the seconds since the frame before, clamped.

## frame_clock

`9 u64`: the frame's marks and phases in ticks, CLOCK_* fields.

## record_pair

`128 u8`: the frame and draw records, written as one.

## end_record

`REPORT_SIZE u8`: the end marker, REPORT_END.

## material_record

`MAX_MATERIALS addr`: each material's texture record in the pixel arena, 0 for none.

## ambient_at

`MAX_AMBIENTS addr`: each ambient piece's bytes in its arena, 0 for none.

## ambient_bytes

`MAX_AMBIENTS u64`: each ambient piece's byte count.

## map

`MAP_BYTES u8`: the map file.

## file

`FILE_BYTES u8`: a texture's file.

## pixels

`PIXEL_BYTES u8`: the pixel arena, the textures' records.

## ambient_arena

`AMBIENT_BYTES u8`: the ambient arena.

## font

`FONT_BYTES u8`: the soundfont.

## serial_fps

`4 u8`: the program disk's serial.

## path_name

`10 u8`: the file naming the map.

## word_map_dir

`6 u8`.

## word_map_ext

`12 u8`.

## word_png_ext

`5 u8`.

## word_mid_ext

`5 u8`.

## word_slash

`2 u8`.

## msg_prefix

`6 u8`.

## msg_material

`15 u8`.

## word_colon

`3 u8`.

## word_not_on_disk

`20 u8`.

## word_not_map

`22 u8`.

## word_ends_at

`10 u8`.

## word_before_structures

`32 u8`.

## word_not_fit

`18 u8`.

## word_bytes

`7 u8`.

## word_holds_more

`13 u8`.

## word_than_build

`23 u8`.

## word_name_too_long

`31 u8`.

## msg_load_failed

`32 u8`.

## word_code

`7 u8`.

## word_directory

`22 u8`.

## msg_no_display

`17 u8`.

## msg_no_sound

`15 u8`.

## msg_no_disk

`28 u8`.

## msg_no_name

`32 u8`.

## msg_ambient

`14 u8`.

The debug lines' text, from here to word_resets, is in a debug build alone,
and the count line's after it, msg_count to word_count_mismatches, in a
COUNT build alone.

## word_space

`2 u8`.

## word_loaded

`12 u8`.

## word_ms

`6 u8`.

## word_sectors

`11 u8`.

## word_walls

`9 u8`.

## word_vertices

`12 u8`.

## word_portals

`11 u8`.

## word_entities

`12 u8`.

## word_lights

`10 u8`.

## word_lumel_maps

`14 u8`.

## word_sprites

`11 u8`.

## word_materials

`13 u8`.

## word_textures

`12 u8`.

## word_missing

`9 u8`.

## word_missing_file

`9 u8`.

## word_not_fit_arena

`24 u8`.

## msg_frame

`15 u8`.

## msg_sectors

`14 u8`.

## word_us

`6 u8`.

## word_pieces

`10 u8`.

## word_planes

`10 u8`.

## word_openings

`12 u8`.

## word_uncovered

`55 u8`.

## word_comma

`3 u8`.

## word_spans

`9 u8`.

## word_pixels

`10 u8`.

## word_lit_spans

`13 u8`.

## word_lit_pixels

`14 u8`.

## word_light_us

`12 u8`.

## word_rejected

`12 u8`.

## word_lumel_samples

`11 u8`.

## word_tiles_built

`15 u8`.

## word_tiled

`9 u8`.

## word_resets

`10 u8`.

## msg_count

`12 u8`.

## word_count_avoided

`11 u8`.

## word_count_shifted

`18 u8`.

## word_count_short

`11 u8`.

## word_count_negative_u

`36 u8`.

## word_count_negative_v

`8 u8`.

## word_count_flat

`19 u8`.

## word_count_mismatches

`14 u8`.

## k_seconds_a_tick

`f32`: a time tick in seconds.

## k_dt_max

`f32`: the frame's seconds at most.
