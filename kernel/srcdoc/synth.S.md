# synth.S

The synthesizer: chip-tune voices behind a MIDI-shaped surface, TheUser's
ruling that the synth lives in the kernel and chip-tune is the default.
Sixteen channels each hold a program, a bank, a volume, a pan, an
expression, a pedal, and a bend, MIDI's own numbers; a note on takes one of
JAB_MIDI_VOICES voices and gives it the channel's instrument: a wave (a
square with a duty, a triangle, a sawtooth, a sine, or noise), an envelope
in milliseconds (attack to the top, decay to the sustain, release from
wherever it was), and a vibrato. The percussion channel's notes are drums
from a table of their own. The instruments come from a table of General
MIDI defaults, each replaceable by jab.sys.midi.instrument. With a
SoundFont loaded (soundfont.S) a note on goes to its sampled voices
instead, through the same channels; the calls reach both kinds. The voices
are rendered a period at a time into the mixer's accumulator (sound.S) on
the device's clock, so an event takes effect within a period. A pitch is a
phase step, 2^32 a cycle, per frame at JAB_SOUND_RATE, from a table of the
top octave shifted down; a bend and a vibrato move the step in proportion,
a straight line through two semitones, near enough. A voice remembers whose
note it plays, the calls' or the file's (smf.S), so a note off, a channel's
notes off, and the piece's stop each reach their own notes and no other's;
the channel's program and controllers stay shared between the two, by
MIDI's own rule.

Every MIDI call brings the sound device up first and answers with its code
when it cannot; the arguments are read from the frame after that, masked to
their ranges rather than checked; and the notes a call touches are the
calls' own (synth_live).

## .set TOP

The level in 16.16 lets a step a frame be a fraction of an amplitude unit,
so a duration of many seconds still counts out.

## .set BEND_SCALE

A bend of the full 8192 moves the step by 2^(2/12) - 1 of itself:
step * bend * BEND_SCALE >> 29.

## .set DRUM_NOTE

A drum is an instrument spec with its own note in the spare byte; the map
covers General MIDI's kit and the rest fall to one drum.

## synth_init

The channel loop keeps its place in t4 and t5 across synth_reset_channel,
which touches t0 only.

## synth_control

The bank select, the volume, pan, expression, and pedal are kept; the pedal
lifting releases what it held; 120 frees the channel's voices of the
current source at once, 121 releases what the pedal held and resets the
controllers, 123 releases the channel's notes of the current source; any
other controller is taken and ignored. On 121 what the pedal holds goes
first, as a lift would release it, since the reset takes the pedal away.

## synth_note_on

The instrument is the channel's program's, or the note's drum on the
percussion channel, which then also sets the pitch, the voice keeping the
MIDI note as its identity; a voice is taken and filled from it, tagged with
the current source. The sustain is its byte scaled to the top; the decay
runs from the top to the sustain over its time, at least a step a frame;
the attack from silence to the top over its time, or the top at once and
decaying; then the vibrato's LFO from its rate, the age, and the noise's
seed.

## synth_pitch

The top octave's table entry shifted down by the octaves below it.

## synth_all_off

Its loop keeps t4 and t5 across synth_release, which touches t0 to t2 only;
synth_note_off, synth_pedal_up, and synth_channel_off do the same.

## synth_render

Per voice and period: the step bent by its channel and then by its vibrato,
whose LFO moves a period at a time; the gains from its velocity and the
channel's volume and expression to 0..127, then the pan's share for each
side. Per frame: the wave's sample at the phase, noise being the shift
register's low bit clocked as the phase crosses each thirty-second of a
cycle; the sample at the envelope's level, the amplitude in the level's high
half, into both sides; the phase on by the step, and the envelope on by its
delta, the stage turning where it reaches the top, the sustain, or silence.

## synth_octave

A lower octave is one shift down each. The sine table after it is
sine.inc's, 256 signed 16-bit samples.

## synth_defaults

A chip-tune reading of each family: 0-7 piano, a narrow square that dies
away; 8-15 chromatic percussion, a sine that dies away; 16-23 organ, a
square held; 24-27 guitar, plucked, a triangle, and 28-31 driven, a
sawtooth; 32-37 bass, a triangle, and 38-39 synth bass, a square; 40-47
strings, a sawtooth swelling in, with vibrato; 48-55 ensemble, slower still;
56-63 brass, a third-duty square; 64-71 reed, a square; 72-79 pipe, a sine;
80-87 synth lead: square, sawtooth, calliope, chiff, charang, voice,
fifths, bass and lead; 88-95 synth pad, a slow sawtooth; 96-103 synth
effects, a slow, wide triangle; 104-111 ethnic, a plucked triangle; 112-118
percussive, a short triangle, and 119 reverse cymbal, noise swelling in;
120-127 sound effects, noise.

## synth_drums

The kit: kick, snare, closed hat, open hat, low, mid, and high toms, crash,
ride, clap, click.
