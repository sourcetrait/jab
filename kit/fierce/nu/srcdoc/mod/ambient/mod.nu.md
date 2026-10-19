# ambient

An ambient piece from a note list. `render <list.nuon> <out.mid>` writes a
Standard MIDI File, format 0, from a NUON of tracks and notes in seconds and
General MIDI numbers, the tree's `ambient/<name>.mid` the engine plays by
sector; `to-midi` is the encoder for a caller of its own. The file's beat is a
second at `division` ticks, so a note at 1.5 seconds sits at tick 720. game's
`render` renders every note list of the content through it.

## The note list

Ambient: a piece as a note list. A track is a channel with its
General MIDI program and volume, channel 9 the drum kit; a note
starts at `at` seconds and sounds for `length` seconds at a velocity.
The piece's `gain`, 1 when absent, scales every volume and velocity
as rendered, each capped at 127, so a piece authored soft plays up.

```nu
record<
    gain: float,
    tracks: table<
        channel: int,
        program: int,
        volume: int,
        notes: table<at: float, note: int, velocity: int, length: float>,
    >,
>
```

## The note list's shape

Seconds rather than beats because the pieces are environmental noise,
not music: an author places a tick of a hat at 3.4 seconds, not on a
beat. Channel 9 is the kit, as the kernel has it, so a percussion
track names channel 9 and any program.

## render

The list rendered to the file; a line with the counts.

## length-of

The piece's length in seconds, its last note's end.

## to-midi

The piece as a Standard MIDI File, format 0: one track holding every
track's program, volume, and notes merged in time order, a note's off
before another's on at the same tick, the tempo a second a beat.

The file's beat is a second (a tempo of 1,000,000 microseconds a
quarter) at 480 ticks, so a note's seconds convert to ticks by one
multiply and a piece reads back in seconds without a tempo map; the
player takes any division in ticks a quarter, so nothing is lost. One
track holds every source track's events merged, format 0, since the
kernel plays formats 0 and 1 alike and merging keeps the writer to one
delta stream. At one tick a note off sorts before a note on, so a note
retriggered where it ends is not cut by its own off; a program change
and a volume sit at tick 0 ahead of both.

## gained

A volume or velocity scaled by the piece's gain and capped at 127.

## vlq

A MIDI variable-length quantity, seven bits a byte, high bit set on
every byte but the last.
