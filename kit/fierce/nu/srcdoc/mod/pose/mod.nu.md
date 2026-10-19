# pose

Captures of a map from placed camera poses, through the console's P frame.
`capture <map> <poses.nuon> <out> --kernel <jab.elf> --image <fierce.jab>` takes
each pose a record {name, x, y, z, yaw, pitch}, the eye in metres with z up,
degrees, yaw 0 along +x and 90 along +y, pitch up positive; a launch a pose on a
romfs of the map's tree with the frame sent at 2 s and the screen taken at 3 s,
the capture written as a PNG of every third pixel at <out>/<map>_<name>.png
through shot; the frame's line for the pose printed, with the sectors drawn on a
debug build, and the sector the camera landed in.

A pose with `trace: true` sends the console's T frame half a second after the
pose and prints what the eye's ray met, the distance, and the point; `sends`, a
list of {at, kind} in milliseconds, sends further console frames of a bare kind,
F for a round or N for a noise; `pad` names a pad table for the launch;
`capture` and `seconds` in milliseconds and seconds move the capture and the
run's end; `report` in milliseconds places the same pose again then, so the
frame line printed is the frame after that placement, for a cost read once the
frame has settled. Every event the run reports over the API, a round, an
android's, the frame struck, a pickup, or a trace, is printed with its fields.
nuance.nu's `pose` builds and runs it (game's `pose`).

`pose-frame` and `command-frame` are the console's frames, for every caller
placing a pose or sending a command.

## pose-frame

The console's P frame for a pose, CONSOLE_FRAME bytes: the kind,
three of padding, the eye's x, y, and z, then the yaw, pitch, and
roll in degrees as singles, zero to the end.

## command-frame

A console frame of a command with no fields: the kind byte and zero
to the frame's end.
