# main.S

piano: the kernel's synthesizer on the keyboard. One octave from
middle C is drawn as twelve keys across the screen, every one white,
C4 to B4 a semitone apart, and each carries the key that plays it: A
S D F G H J K L ; V N, the home row and then V and N. A key pressed
starts its note on the piano and letting go releases it.

## draw_keys

A key's rectangle is filled a row at a time. Its label's address is
computed, so the label goes by the plain call, jab.sys.display.text's
registers loaded by hand and the ecall made directly, since the macro takes
a label.

## apply_key

The key's place in key_codes, or none, gives its note, NOTE_FIRST up.
