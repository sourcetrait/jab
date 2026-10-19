# do.nu

Fierce's casual commands (NuLayout's bins): `build`, `run`, `test`, and
`bench` through the SDK's modules, each one call with fierce's path,
`kit/fierce`, and the workspace's root, a constant resolved from the bin's
own path. The root's `do` takes any program by its path; this one takes
fierce alone.

## main build

The SDK's `build`: the kernel and fierce with the symbols `--set` names,
fierce's maps compiled first by its manifest's prepare.

## main test

The SDK's `program test`: fierce's test with DEBUG, its suite and its
programs' fixtures, `test/fillrate` and `test/footprint`.

## main run

The SDK's `program boot`: fierce built, then run in its window with the
UART on stdio, its flags the root's `run`'s.

## main bench

The SDK's `bench`: one of fierce's benches by its name, `cadence`,
`qual_1ka1`, or `qual_1kb1`, every step in order, then its report and its
tar; with `--package` the bench of that name the package holds, run
from it, nothing built.
