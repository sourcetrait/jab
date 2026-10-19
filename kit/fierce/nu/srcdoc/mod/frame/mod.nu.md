# frame

## CRACKS

The pixels a frame may leave unreached where two surfaces meet, the
float steps of their edges disagreeing by a rounding

## RECORD

The API's record, 64 bytes: the kind at 0, the camera's sector at 4,
the eye at 8, the yaw, pitch, and roll in degrees at 20, the drawing's
and the game's microseconds at 32 and 36, an event's own fields from
40: kind 2 a round (what it met: 0 nothing, 1 geometry, 2 an android;
the actor; its health after), 3 an android's event (1 roused, 2
fired, 3 struck, 4 destroyed, 5 fallen, 6 a waypoint reached; the
actor; its row), 4 the frame struck (the damage; the health), 5 a
pickup (the rounds), 6 a trace's answer (0 nothing, 1 a plane, 2 a
piece, 3 an android, 4 the player; the distance and the point in
millimetres); kinds 7, 8, 10, and 12 the frame before's clock, its
drawing, its presentation, and its packets, 13 and 15 its tile pool's
activity and storage, and 18 its harts' masks, sent at each frame's
start, 14 the pool's configuration ahead of the frame it governs, and 9
the end of a measurement, which the gauge reads (`gauge measure`) and
`records` leaves out

## CONSOLE_KIND

render.inc's REPORT_CONSOLE: a console answer's kind

## WORKERS_STARTED

The raster's workers through the console's W frame: the default, every
worker started, two on the specification's three harts, in bands of
GRAIN_DEFAULT rows (render.inc's); the spawn view of the still copy drawn
again by the serial backend, by one worker, by two a band a worker, and
by two in bands of WORKER_GRAIN rows, each the default's capture over
the whole screen and its frame line's counts the default's

## GFX_SLOTS

The workers on each machine, the program's reservation of two taking
every online secondary as its grant and a raster worker started on each
hart of it, its slot the hart's: three harts, four, eight, and four
with hart 2 failed by the kernel's jab.late knob, the sparse grant 1 3;
each machine's reserved and workers lines, and a W asking GFX_SLOTS held
to those started, a band a worker and at the default grain. Two harts
and one hold fewer secondaries than the reservation: the kernel refuses
the image, its base demand of three harts unmet, so each is reached past
that by the debug kernel's knob, SHORT_KNOB, and refused at the program's
start with its line and exit 17; and two harts without the knob refused
by the kernel before the program starts, KERNEL_SHORT, with status 1

## FRAMES_LINE

The engine's own images and sounds, every one in a tree of ours

## band-sum

The bands a frame line counts over every slot's hart, 1 to GFX_SLOTS.

## mips-built

The chains' line among a run's: the materials with a level past 0, the
levels built, the texels, and the time; a tree with textures builds
chains, at least a level a chain.

## answered

The frames that read a console command, each the count of state records
before its answer, so the frame's own state is the next one.
