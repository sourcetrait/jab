# gauge/play

## WORKSPACE

The workspace's root, the checkout this module lies in, from the module's own
file at parse time.

## DRAIN

after the E the final records and the end marker land within this,
then the stop's quit ends the run (launch `--stop`), no screen taken;
the run's bound, BOUND_PAST later, is past both, so the run's end is the
stop's and never the bound's

## SERVICE_STOP_BEFORE

How far before the E a run's service stops: the stop and the E reach the
program in that order, so the window's END and EVIDENCE records land before
the end marker, inside the measurement the stream reads.

## nuon-list

A script flag's NUON list, as a command line carries one, every item of
the kind named: a flag typed as a list cannot be reached from a command
line, since nu passes each word of a script's command line as a string.

## route

Play the route on the build `runs` times and read every frame: the
route's placements, its legs' `sends` (console command frames by their
one-letter kind, each at its `at`), and its pad rows, an R with the
run's seed and a C with the cadence before the first frame, with
`--workers` a W with the workers and the grain beside them, the E at
the route's end, and the stop once the final records have landed. Headless with the sound
recorded, or with `--host` in the window and the audio a run of the
program has. `--qemu` words go on each launch's line after its own, and
each run's identity then takes the machine and the words the launch
returns, a diagnostic run. An image whose build flags contradict the
tree asked is refused before any launch (gauge identity contradiction). With
`--cpu`, every QEMU thread's CPU is read at the times cpu-requests
names, the readings kept whole in run.nuon and each run's windows
(gauge cpu windows) in the report. Each run mints its capture nonce before its
sends and its identity, sends it in an I beside the R and the C, and
launches paired with it (CaptureBundle); with `--sdl-probe` the sdl shim
logs each run to its sdl.log under sdl,gl=on and the run is bundled as
its last step (jab sdl-bundle) into its bundle/, and with `--trace`
QEMU's flush and set_scanout trace goes to its trace.log through the
launch's own words, which makes the run diagnostic, the oracle set.
With `--service`, a SERVICE build's synthetic service runs through the
route (service-sends), its quota of messages every frame, SceneOwnership's
steady load at 2; an image whose flags define no SERVICE is refused before
any launch, the quota is the identity's mode's `service`, and each run's
service line follows its outcome (gauge report service-line). Each run is
measured with the contract read at `--eps` and its contract line printed
after its outcome (gauge report contract-line).

- `--tree`: the build tree the kernel and the image come from, release or debug
- `--kernel`: the kernel's ELF, the tree's own unless given
- `--image`: the program's image, the tree's own unless given
- `--route`: the route, route_render_0.nuon unless given
- `--map`: the map tree the route plays on, the route's unless given
- `--assets`: the compiled map tree the disk is made from, the checkout's
  asset shard's unless given, a package's on a host
- `--runs`: the route's runs
- `--seeds`: each run's seed, a NUON list such as "[3 2 1]", run n's n unless
  given
- `--cadence`: the cadence each run asks for, the program's own 1 unless given
- `--workers`: the raster's workers each run asks for, 0 the serial backend;
  none asked, no W, unless given
- `--grain`: the rows a band asked with the workers, the program's own 32 unless
  given, 0 for a band a worker
- `--host`: the host's window and audio in place of none and the recording
- `--out`: where the runs land, a stamped directory under the tree's unless
  given
- `--label`: a name for the build in the summary
- `--spec (-s)`: the named spec the machine is, the configured default unless
  given
- `--harts`: a custom machine of 1 to 8 harts in place of a named spec, the runs
  then diagnostic
- `--qemu`: words on each launch's line after its own, a NUON list, the runs
  then diagnostic
- `--cpu`: every QEMU thread's CPU read at 5 s, each placement, and the route's
  end, as host-time windows
- `--sdl-probe`: the sdl shim on each run under sdl,gl=on, each run bundled last
- `--trace`: QEMU's flush and set_scanout trace to each run's trace.log, the
  runs then diagnostic
- `--service`: the synthetic service's messages every frame on a SERVICE
  build, -1 for none
- `--eps`: the contract's on-time tolerance in ticks, the cap's 10,000 unless
  given, a calibrated eps for a comparison

- the run's capture nonce, minted here, the outermost layer, once

## host

Put the build in the host's window, with its audio and its own
gamepad, for a person to play from the spawn: an R with the seed and a
C with the cadence before the first frame, the E after `seconds`, and
the stop once the final records have landed, which closes the window.
`--qemu` as `run` takes it, and an image whose build flags contradict the
tree asked is refused as `run` refuses it. The run's contract is read at
`--eps` and its line printed as `run` prints it.

- `--tree`: the build tree, release or debug
- `--kernel`: the kernel's ELF, the tree's own unless given
- `--image`: the program's image, the tree's own unless given
- `--seconds`: the measurement's length
- `--seed`: the seed the run sends
- `--cadence`: the cadence the run asks for, the program's own 1 unless given
- `--workers`: the raster's workers the run asks for, 0 the serial backend; none
  asked, no W, unless given
- `--grain`: the rows a band asked with the workers, the program's own 32 unless
  given, 0 for a band a worker
- `--assets`: the compiled map tree the disk is made from, the checkout's
  asset shard's unless given
- `--out`: where the run lands, a stamped directory under the tree's unless
  given
- `--label`: a name for the build in the summary
- `--spec (-s)`: the named spec the machine is, the configured default unless
  given
- `--harts`: a custom machine of 1 to 8 harts in place of a named spec, the run
  then diagnostic
- `--qemu`: words on the launch's line after its own, a NUON list, the run then
  diagnostic
- `--eps`: the contract's on-time tolerance in ticks, as `run` takes it

## audio

RegressionSuite's fixture as a bench step, the qualification's audio row:
a debug build alone, the kernel's pad and sound counts being DEBUG's, an
image whose flags contradict it refused. The pad table (gauge audio
play-table) through ten seconds of play from the spawn under the default
workers, the E closing the measurement and the Z's exit writing the counts
(gauge audio sends), QEMU tracing its dropped reports into its log; with
`--host` in the host's window with live sound, else headless with the
sound recorded. The identity's mode records the pad `table`, no seed, and
no cadence; the trace's words are its QEMU words, so its standing is
diagnostic. The reading (gauge audio reading) is kept as audio.nuon beside
the run and in the report's run, its line printed after the run's.

- `--tree`: debug, the one tree it takes
- `--kernel`: the kernel's ELF, the tree's own unless given
- `--image`: the program's image, the tree's own unless given
- `--assets`: the compiled map tree the disk is made from, the checkout's
  asset shard's unless given, a package's on a host
- `--host`: the host's window and live sound in place of none and the
  recording
- `--out`: where the run lands, a stamped directory under the tree's unless
  given
- `--label`: a name for the build in the summary
- `--spec (-s)`: the named spec the machine is, the configured default unless
  given
- `--harts`: a custom machine of 1 to 8 harts in place of a named spec
- `--qemu`: words on the launch's line after its own and the trace's, a NUON
  list

## service-sends

A run's V frames asking the service: its start at SEED_AT with `quota`
messages every frame, the V's total with no quota frames, and its stop
SERVICE_STOP_BEFORE the E; none for a quota under 0.

## places

Where a run's pieces are: the game, the workspace, the tree, the
kernel and the image (the tree's own unless given), and the output
directory, a stamped one under the tree's gauge unless given, made.

## assets-of

The compiled map tree a run's disk is made from: `assets` when given, a
package's tree on a host, else the checkout's asset shard's; its
`map/name` must be the map the run plays. Every launch names the gauge's
own workspace (launch's `--workspace`), so an image with no `home`
marker, a packaged one, still finds the checkout's QEMU, shims, and
generic disk; for a tree's or an export's image it is the workspace its
home names already.

## romfs-of

A map's tree as the romfs image the program reads, built in `out`.

## workers-asked

The workers and grain a run asks for, as its identity records them:
none, both null, for workers under 0, so no W goes out and the image's
own default draws; else the workers, 0 to GFX_SLOTS, and the grain, 0
to the screen's rows.
