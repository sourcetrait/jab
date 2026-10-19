# shot

A screen capture as a PNG to look at. `shot <ppm> <png> [--step N]` takes every
Nth pixel of each Nth row of the PPM a run captured (P6, 8 bits) and writes an
RGB PNG of the sampled size through png, so no compressor is needed; the step is
4 by default, 1920 by 1080 becoming 480 by 270. nuance.nu's `shot` runs it, and
`pose capture` writes each pose's capture through it.
