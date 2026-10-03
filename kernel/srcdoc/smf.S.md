# smf.S

The Standard MIDI File player: a sequencer over the synthesizer (synth.S)
stepped by the sound clock, one step a period as the stream refills
(sound.S), so a file's events land on the same calls a program makes live
and within a period of their time. The file stays in the program's memory
where jab.sys.midi.play found it, read in place: the header's format, track
count, and division, then every MTrk chunk as a track with a cursor, its
running status, and the absolute tick of its next event. A step moves the
position by the period's ticks, 20000 times the division over the tempo in
microseconds a quarter note, kept in 32.32 fixed point, and fires every
track's events up to it: notes on and off, controllers, program changes,
and bends to the synthesizer, the tempo meta event to the clock, the
end-of-track meta event ending the track; every other event is skipped by
its length. The piece ends when every track has. Every read is bounded by
its track's chunk, so a malformed file ends its track rather than reading
past it.

## sys_midi_play

A file the player refuses: no MThd header, a format past 1, a SMPTE
division, no track or more than JAB_MIDI_TRACKS, or a chunk past the end.

## smf_load

The header is "MThd", a length of 6, a format of 0 or 1, 1 to TRACKS
tracks, and a division in ticks a quarter note. The tracks are each MTrk
chunk in turn, a chunk of any other kind skipped by its length, the file's
end ending the count early; each track gets its record and its first
delta.

## smf_step

Called as the stream refills, so it keeps every register but the t
registers and a0. The events it fires are the file's own notes
(synth_from_file); a note the file left held, ending without its off, goes
to its release with the piece; and the notes are the calls' again after,
the file having taken its turn inside a call or the vector.

## smf_event

A channel message of two data bytes goes to synth_note_off, synth_note_on
(velocity 0 an off), synth_control, or synth_bend, aftertouch doing
nothing; one data byte is a program change, or channel pressure, nothing. A
meta event is its kind, its length, and its bytes; a system exclusive event
is skipped by its length.
