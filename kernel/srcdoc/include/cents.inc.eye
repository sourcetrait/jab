rodata local soundfont_semitones 12 u32 [5:7] :2^(n/12) times 65536 for n of 0 to 11
rodata local soundfont_cents 100 u32 [8:18] :2^(c/1200) times 65536 for c of 0 to 99
