# synth.inc

What the synthesizer's files share (synth.S, smf.S, soundfont.S): the
channel record, and whose notes a voice plays.

## .set CHANNEL_PROGRAM

`u8`: a channel's General MIDI program.

## .set CHANNEL_VOLUME

`u8`: controller 7.

## .set CHANNEL_PAN

`u8`: controller 10.

## .set CHANNEL_EXPRESSION

`u8`: controller 11.

## .set CHANNEL_PEDAL

`u8`: controller 64.

## .set CHANNEL_BANK

`u8`: the bank select, JAB_MIDI_CC_BANK.

## .set CHANNEL_BEND

`i16`: the pitch bend, -8192 to 8191.

## .set CHANNEL_SIZE

`u64`: bytes in a channel record.

## .set CHANNEL_SHIFT

`u64`: log2 of CHANNEL_SIZE.

## .set SOURCE_LIVE

`u64`: a voice playing the calls' notes.

## .set SOURCE_FILE

`u64`: a voice playing the file's notes.

## .set SOURCE_ANY

`i64`: both sources, where a routine takes one.
