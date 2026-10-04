# cents.inc

Generated once, and its text, comments included, is the generator's. The
ratios the soundfont renderer scales by (soundfont.S), each rounded; a ratio
2^(cents/1200) is the semitone's entry times the cent's entry, shifted by
the octave. Included in soundfont.S's .rodata.

## soundfont_semitones

`12 u32`: 2^(n/12) times 65536 for n of 0 to 11.

## soundfont_cents

`100 u32`: 2^(c/1200) times 65536 for c of 0 to 99.
