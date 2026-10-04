# main.S

techno: technojab.mid, the piece shipped on the program's romfs,
played through the kernel's synthesizer on its own, with TECHNOJAB in
the middle of the screen while it plays; when the piece ends, so does
the program, its last release played out by the exit.

## .set DISK

`u8`: the romfs disk's id.

## .set PIECE_BYTES

`u64`: the most of the piece read, 96 KiB.

## .set TITLE_CELLS

`u64`: the title's characters.

## .set TITLE_SCALE

`u64`: four times the console's cell, in 256ths.

## .set TITLE_WIDTH

`u64`: the title's width in pixels, bold adding one.

## .set TITLE_HEIGHT

`u64`: the title's height in pixels.

## .set TITLE_X

`i64`: the title's left, centred on the screen.

## .set TITLE_Y

`i64`: the title's top, centred on the screen.

## .set TITLE_COLOR

`u32`: the title's off-white.

## read_piece

The file is read from its romfs record's offset, each read going on from
the offset the one before returned, until a read brings nothing or the file
ends.

## piece_length

`u64`: the piece's bytes in memory.

## rec

`144 u8`: the piece's romfs record.

## piece

`98304 u8`: the piece, a Standard MIDI File.

## piece_path

`15 u8`: the piece's path on the romfs.

## title

`10 u8`: the title shown while the piece plays.

## msg_no_display

`20 u8`: the line for a machine with no display.

## msg_no_sound

`18 u8`: the line for a machine with no sound.

## msg_no_piece

`38 u8`: the line for a romfs without the piece.

## msg_refused

`31 u8`: the line for a piece jab.sys.midi.play refused.
