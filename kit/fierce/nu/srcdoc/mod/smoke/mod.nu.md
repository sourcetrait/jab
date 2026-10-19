# smoke

The game played, not posed: a seeded random player on the pad for the run's
length, walking and strafing, turning and looking, firing now and then, from the
spawn, with the API's state records proving the body moved and the run survived;
a program fault ends the run with its line on the UART, which is resolved to its
routine from the ELF's symbols and printed, since a fixed pose never finds what
ten seconds of play does.

`seeds --kernel <jab.elf> --image <fierce.jab> --out <dir> --seeds "[1 2 3]"
--seconds 60`; nuance.nu's `smoke [seeds] [seconds]`, the seeds separated by
commas, builds and runs it (game's `smoke`). Every seed is one launch of a debug
build with Render Zero's tree; the table it played is kept beside the run as
pad.nuon, so a seed that faults is replayed by its number.

## TICK

A tick of play: the sticks move every so often, the trigger now and
then, from after the load until just before the capture ends the run

## LEFT_X

The sticks' values on the reference pad, 0 to 255 about 127, up being
0 on the Y axes; the left stick leans forward, the right turns freely
and looks a little

## STATES_A_SECOND

What a run must show: states a second at least, metres walked at least

## seeds

- A list from the command line arrives as its text, quoted when it
  holds a space, so the seeds are NUON read here

## play-table

A seed's play: every tick the sticks take a value from their sets, the
left stick leaning forward and the right turning, each axis sent on a
change; the trigger pressed one tick in FIRE_IN and released a tenth
later; from FIRST until a second before the run's end.

## states

The state records of an API capture: the sector and the eye.

## float-at

A single at an offset of a record, little-endian.

## resolve

The routine a fault line's epc falls in, from the ELF's symbols through
the toolchain the build's flags name.
