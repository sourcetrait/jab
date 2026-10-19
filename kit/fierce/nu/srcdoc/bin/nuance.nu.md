# nuance.nu

Fierce's nuanced commands (NuLayout's bins), each verb one call of a module
function, its arguments and its output those of the command it replaces:
do.nu's development commands through game, shot, and map/trees, and
gauge.nu's verbs through gauge's aggregator. Its imports' paths are bound
at parse time, so a module game and the gauge both reach loads once.

## main render

game's `render`: every asset under content/ rendered to the file beside it,
the SVGs through svg2png, the note lists through ambient's `render`, the
recipes through sound's.

## main compile

map/trees: every map source compiled into the asset shard, a compiler's nu
a source.

## main shot

shot's `main`: a run's screen capture sampled every `--step` pixels each
way, written as an RGB PNG.

## main pose

game's `pose`: fierce built with `--set`, then pose's `capture` of the map
from the placed poses on the debug build, the PNGs under `out`.

## main smoke

game's `smoke`: a debug build played by seeded random pads, the seeds
separated by commas, each seed's run held to walk and survive.

## main play

game's `play`: a debug build's map handed to robojab, the MCP server line
and config record printed, or a socket served.

## main gauge run

`gauge play route`: the route played on a build `--runs` times, every
frame of each run read from the program's records, each run's files and
the batch's gauge.nuon kept.

## main gauge play

`gauge play host`: the build in the host's window, audio, and gamepad for
a person to play, measured for `--seconds`.

## main gauge read

`gauge read`: a capture made either way, read under the identity it
resolves.

## main gauge compare

`gauge compare report`: builds' gauge.nuon files side by side, the
comparison written to compare.nuon and printed.

## main gauge bench-report

`gauge bench report`: a bench run's steps read, each cadence's frames
pooled, report.nuon and report.txt written into the run.
