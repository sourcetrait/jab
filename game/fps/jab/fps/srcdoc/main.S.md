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

## .set TITLE_SCALE

The title: bold at four times the console's cell, centred; bold adds a pixel
to the width.

## _start

The map's name is read with its trailing whitespace dropped and the map's
path built from it, /map/<name>.jabfps.map; the title is drawn centred on the
black screen; the map is read whole, then held to its format; loaded, the
screen is cleared and a debug build reports the load.

## frame

Under DEBUG the first frame's report goes out, and the first after a console
placement.

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

## clear_screen

Falls into fill_screen with the colour 0.

## msg_ambient

The debug lines' text, from here to word_resets, is in a debug build alone.
