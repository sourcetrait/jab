# main.S

The load order is the dependency order: the map's records are checked before
anything indexes them, the materials load before the engine's images, whose
records follow the map's, the lights before the actors, whose placement reads
the sector floors, and the camera last, since its basis writes camera_d for
the surface mathematics. The frame loop runs the game's phases before the
drawing's and times each: the game's microseconds cover the pad, the console,
the camera, the actors, and the ambient; the drawing's cover world_draw alone.

The first frame is reported on the UART, and one after each console placement,
so a test reads the frame it posed; the DEBUG build adds the walk's order.

The three type libraries are included after jab.inc: their macros expand in
place at every site, so the engine carries no sine, cosine, arctangent, dot,
length, or generator of its own. A vector that lives in a record goes through
the memory forms; one computed in registers goes through the `reg` forms,
which touch only their destination, so no site stores a vector to be read
back.

A step the load cannot take exits with its own code and a line naming it, the
codes and lines being the loader's contract with the test.
