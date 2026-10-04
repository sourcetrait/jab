# main.S

piano: the kernel's synthesizer on the keyboard. One octave from
middle C is drawn as twelve keys across the screen, every one white,
C4 to B4 a semitone apart, and each carries the key that plays it: A
S D F G H J K L ; V N, the home row and then V and N. A key pressed
starts its note on the piano and letting go releases it.

## .set CHANNEL

`u8`: the MIDI channel the keys play on.

## .set PROGRAM

`u8`: the General MIDI program, the acoustic grand piano.

## .set VELOCITY

`u8`: every note's velocity.

## .set KEYS

`u64`: the keys, one octave.

## .set NOTE_FIRST

`u8`: the first key's note, middle C.

## .set KEY_WIDTH

`u64`: a key's width in pixels.

## .set KEY_HEIGHT

`u64`: a key's height in pixels.

## .set KEY_GAP

`u64`: the pixels between two keys.

## .set KEY_STRIDE

`u64`: a key and its gap.

## .set ROW_WIDTH

`u64`: the row of keys' width.

## .set ROW_X

`i64`: the row's left, centred on the screen.

## .set ROW_Y

`i64`: the row's top, centred on the screen.

## .set KEY_COLOR

`u32`: every key's colour, white.

## .set LABEL_SCALE

`u64`: three times the console's cell, in 256ths.

## .set LABEL_WIDTH

`u64`: a label's width, bold adding a pixel.

## .set LABEL_HEIGHT

`u64`: a label's height.

## .set LABEL_X

`i64`: a label's left within its key, centred.

## .set LABEL_Y

`i64`: a label's top within its key, centred.

## .set LABEL_COLOR

`u32`: a label's colour, black.

## .set LABEL_ENTRY

`u64`: a label's bytes, a character and its terminator.

## draw_keys

A key's rectangle is filled a row at a time. Its label's address is
computed, so the label goes by the plain call, jab.sys.display.text's
registers loaded by hand and the ecall made directly, since the macro takes
a label.

## apply_key

The key's place in key_codes, or none, gives its note, NOTE_FIRST up.

## key_codes

`12 u8`: the keys that play, C4 up a semitone each.

## labels

`24 u8`: each key's label, LABEL_ENTRY bytes, terminated.

## msg_no_display

`19 u8`: the line for a machine with no display.

## msg_no_sound

`17 u8`: the line for a machine with no sound.
