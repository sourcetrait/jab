# synth.inc: what the synthesizer's files share (synth.S, smf.S,
# soundfont.S): the channel record, and whose notes a voice plays.

# A channel: its program, its controllers, its bank, and its bend
.set CHANNEL_PROGRAM, 0
.set CHANNEL_VOLUME, 1
.set CHANNEL_PAN, 2
.set CHANNEL_EXPRESSION, 3
.set CHANNEL_PEDAL, 4
.set CHANNEL_BANK, 5            # the bank select, JAB_MIDI_CC_BANK
.set CHANNEL_BEND, 6            # i16, -8192 to 8191
.set CHANNEL_SIZE, 8
.set CHANNEL_SHIFT, 3

# Whose note a voice plays: the calls' or the file's; SOURCE_ANY names
# both where a routine takes a source
.set SOURCE_LIVE, 0
.set SOURCE_FILE, 1
.set SOURCE_ANY, -1
