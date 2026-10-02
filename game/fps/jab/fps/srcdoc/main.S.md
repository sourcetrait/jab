# main.S

The load order is the dependency order: the map's records are checked before
anything indexes them, the materials load before the engine's images, whose
records follow the map's, the lights before the lumel maps, which bake over
the sector lists, the maps before the actors, whose placement reads the
sector floors, and the camera last, since its basis writes camera_d for the
surface mathematics. The frame loop runs the game's phases before the
drawing's and times each: the game's microseconds cover the pad, the console,
the camera, the actors, and the ambient; the drawing's cover world_draw alone.

The reports are the program's own debug lines, there for its test and
nowhere else: under DEBUG the first frame is reported on the UART, and one
after each console placement, so a test reads the frame it posed, with the
walk's order after it; a release build carries neither the report routines
nor their text and says nothing but an exit, jab's rule for a program, which
the test holds by scanning a release image it builds for every `fps: `
string. The load line, the bake's, the frames', the sounds', the soundfont's,
and the ambient's lines are under the same conditional at their sites, with
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

The three type libraries are included after jab.inc: their macros expand in
place at every site, so the engine carries no sine, cosine, arctangent, dot,
length, or generator of its own. A vector that lives in a record goes through
the memory forms; one computed in registers goes through the `reg` forms,
which touch only their destination, so no site stores a vector to be read
back.

A step the load cannot take exits with its own code and a line naming it, the
codes and lines being the loader's contract with the test.
