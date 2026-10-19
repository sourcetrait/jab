# sdl.nu

The SDK's sdl tools for use by hand, the readers a probe's run and its
bundle go through, as a standalone script (NuLayout's `nu/bin/nuance/`),
each verb one call of the `sdl` aggregator's api. `sdl pair` has no verb
here: it takes its events and flips as lists, which a script's command
line cannot carry, and a verb that read them from files would make more
than its one call; a body that imports `nu/mod/sdl` calls it.

## main bundle

`sdl bundle`: the probe directory's run bundled into a bundle directory
not there yet, written once, the files named after it copied whole as
its extras; `--profile` the profile claimed, else the run's identity's.

## main bundle-check

`sdl bundle-check`: the bundle held to its manifest stage by stage, the
first failure raised by its stage, the reading returned. A paired bundle
needs its program's reader of the API's records, which a command line
cannot carry, so a paired bundle stops at the run's stage here; a
generic or historical one is checked whole.

## main report

`sdl report`: a shim log's report, the flips, the renders, and their
callers, as one record.
