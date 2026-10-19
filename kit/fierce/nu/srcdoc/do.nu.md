# do.nu

The justfile's `just do <command>` for fierce's commands, keeping their
old arguments for the runners that call them until those call the bins
themselves; it goes with the justfile. Each verb runs a bin's. `render`, `compile`, `shot`,
`pose`, `smoke`, and `play` are nuance.nu's of the same names. `gauge` and
`gauge-play` build first through fierce's `bin/do.nu build`, debug's
symbols for a debug tree, then run nuance.nu's `gauge run` and `gauge
play`; `gauge-read` and `gauge-compare` are nuance.nu's `gauge read` and
`gauge compare`.

## here

This file's directory, fierce's nu tree, from which each verb finds the
bins.
