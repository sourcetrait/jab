# ambient.nu

## to-midi

The file's beat is a second (a tempo of 1,000,000 microseconds a
quarter) at 480 ticks, so a note's seconds convert to ticks by one
multiply and a piece reads back in seconds without a tempo map; the
player takes any division in ticks a quarter, so nothing is lost. One
track holds every source track's events merged, format 0, since the
kernel plays formats 0 and 1 alike and merging keeps the writer to one
delta stream. At one tick a note off sorts before a note on, so a note
retriggered where it ends is not cut by its own off; a program change
and a volume sit at tick 0 ahead of both.

## The note list's shape

Seconds rather than beats because the pieces are environmental noise,
not music: an author places a tick of a hat at 3.4 seconds, not on a
beat. Channel 9 is the kit, as the kernel has it, so a percussion
track names channel 9 and any program.
