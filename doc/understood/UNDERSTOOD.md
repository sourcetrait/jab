# UNDERSTOOD.md
>REIN AI

An assembly ecosystem on QEMU: an assembly kernel that is itself the API,
running RISC-V programs a hobbyist drops in. Everything is virtio, and it
runs only under QEMU's `virt` machine.

- `workspace.jab.toml` the workspace: the kernel and the programs.
- `do` the driver, a link to `nu/bin/do.nu`: `build`, `test`, `run`,
  `bench`, and `watch`.
- `kernel/` the kernel: `kernel.jab.toml`, sources under `src/`, and
  each source's `.eye` and `.md` under `srcdoc/`.
- `sdk/` what a program uses, its sources under `src/` and their `.eye`
  and `.md` under `srcdoc/`: `jab.inc`, whose `jab.sys.*` macros are
  the kernel's calls, each a trap into it; `jab_f32.inc`,
  `jab_f64.inc`, and `jab_rng.inc`, mathematics and chance as macros
  the program carries and expands in place, never a call and never a
  trap; `jab_jobs.inc`, jobs for workers as macros over mailboxes the
  program owns, whose waits are the kernel's; and the program link
  script. The SDK's nushell is the root's `nu/`.
- `doc/syscalls.nuon` the system call table of record; `doc/lists.md`
  how every call that fills a buffer with records works.
- `doc/SPEC.md` the system specifications, TheUser's and the authority;
  `asset/spec.nuon` their definitions for the tools, one row a spec,
  following every edit to SPEC.md, and `asset/spec.nutype` the type they
  are read as.
- `example/<name>/`, `test/<name>/` programs by category, each with
  `program.jab.toml`, `src/main.S` and its `srcdoc/`, and its
  integration test at `test/test.nu`.
- `shim/` the preload shims, a cargo workspace, a crate each under
  `crates/`: `sdl` for the probe, `sdl_harness`, a small binary that
  tests the probe's capture, `evdev` for the pad tests, `pipe`,
  `jabpipe`, the launch's supervisor, which owns every QEMU a launch or
  a run starts and on Windows holds each of QEMU's pipes, and `pad`, the
  bridge that carries a gamepad to QEMU on macOS and Windows.
- `tool/` the host tools, a cargo workspace, a crate each under
  `crates/`: `disco`, the library `jabdisco` and its binary
  `jabdisco`, which find the gamepad a run attaches and the audio
  output it plays through; `robojab`, the harness that runs a prepared
  machine and lets an agent play it a move at a time; and the eye tools,
  the library `eye_asm` with `eye-asm`, which prints the `.eye` of every
  source under a `src/` or of one file or directory in it, its routines,
  jump targets, and macros, the flow a reader looks through before reading
  the source, a source's constants and data being its `.md`'s; and
  `eye-gen-asm`, which writes a `.eye.stub` beside each `.eye` from the
  code, carrying what the `.eye` says, and with `--done` puts each stub in
  its `.eye`'s place, refusing unless every source has one.
- `.target/` the one target, ignored, unless `XDG_CACHE_HOME` is set,
  when it is `$XDG_CACHE_HOME/jab/target/<checkout>` instead, the
  checkout its directory's name and the first eight hex digits of its
  path's SHA-256: every build and every tool's output, sharded within
  it, the builds under `release/` and `debug/` at each program's path
  from here, a program's compiled assets, benches, and kept
  measurements under `asset/`, `bench/`, and `gauge/` the same way, the
  generic disk, the shims, and `watch`'s record. What the tools clear
  away waits in `tmp/retired/`: under the XDG cache in
  `$XDG_CACHE_HOME/jab/target/tmp`, beside every checkout's target and
  shared by them, and otherwise in `.target/tmp`. `extern/` local
  links, ignored.

Every nushell tree takes one layout: the repository's own `nu/` for the
SDK and the workspace, a prog's or a kit's `nu/` beside its `src/` at
`<prog|kit>/<name>/nu/`, and the kernel's at `kernel/nu/`, which holds
`nuance.nu` alone, the kernel's casual verbs being the root's (`./do build
--kernel`). In a tree,
`bin/` holds `do.nu`, the casual driver (`build`, `run`, `test`, and
`bench`, and at the root `watch`), `nuance.nu`, the nuanced commands
grouped by concept, and `nuance/`, a nuanced script that fits no group;
`mod/<concept>/mod.nu` holds the code, one concept a directory module, a
concept past about 500 lines split into child modules under it, and code
that only a nuanced command uses under `mod/nuance/`; `nuon/<concept>/` a
module's data and `type/<concept>/<Model>.nutype` its shape; and
`srcdoc/` mirrors `bin/`, `mod/`, `type/`, and `nuon/`, a file's prose in
`<file>.md` beside its path. A bin is executable, so any tool runs it by
its path, `use`s the modules it fronts, and holds no logic, each `def
"main <verb>"` one call of one module function, its result returned as the
module returns it. A module imports another by
its path relative to the importing file, named through `path self`, `use
(path self ../target)`, so nushell, which keeps one module per path as
written, parses each module file once however many modules import it. A
bin binds each import's path first, `const MAP = path self ../../mod/map`
then `use $MAP`, since its top level runs after its parse, where `path
self` as a command refuses, and a bare relative path beside a module's
`path self` of the same module is a second parse, which slowed fierce's
map compiler 15 percent; an older script keeps the plain relative path.
A module exports its API
typed in and out, keeps its helpers unexported, and names no definition
after a builtin. A definition carries one summary line of 80 characters at most
in the source, its usage and reasoning in the mirror. The root's `do`
links to `nu/bin/do.nu` (`nu nu/bin/do.nu` on Windows, where a symlink
checks out as a text file). nushell's `path self` names the link it was
run through, not the file, so the linked bin resolves itself first,
`const HERE = (path self | path expand | path dirname)`, and binds each
import from there, `const BUILD = ($HERE | path join ../mod/build | path
expand)`. Examples and test programs keep their `test/test.nu` and carry
no tree. The SDK's nushell is the root's `nu/`, the kernel's
`kernel/nu/`, and fierce's `kit/fierce/nu/`.

Build and run with the root's `do` and nushell, a program named by its
path from the root or by a shortcut `workspace.jab.toml` names, `fierce`
for `kit/fierce`: `./do build` (or `./do build example`, `./do build
kit/fierce`), `./do test` (or `./do test example/pad`), `./do run
example/helloworld` or `./do run fierce`, and `./do watch`. An absolute
path in place of the program's names a workspace's, the kernel's, or a
program's directory, built, tested, or run alone, a program outside the
workspace among them. The commands for development are each tree's own
`nu/bin/nuance.nu`: the root's `watch bench`, `clean`, and `retire`, the
kernel's `font`, and fierce's; the SDK's own scripts are
`nu/bin/nuance/plan.nu`, `probe.nu`, and `sdl.nu`. `./do run`
opens QEMU's own window when a display server is present, SDL with
OpenGL on Linux and Windows and Cocoa on macOS, and otherwise serves the
console over VNC on 127.0.0.1:5930, to tunnel and view; `JAB_DISPLAY`
overrides with any `-display` value. Nothing the tools clear away is
deleted, robojab included: a build's, a test's, or a bench's is moved
whole into the retire home, `tmp/retired/<stamp>/` at its place there.
`nu/bin/nuance.nu clean` retires the whole target, so the next build
starts from nothing, and `nu/bin/nuance.nu clean <path>` retires only the
outputs of the programs under a path, or the kernel's, in one tree with
`--tree`. `nu/bin/nuance.nu retire` is the one command that deletes: it
removes the retire home's `tmp` and everything in it.
The toolchain is found by its install directory, the one holding
`bin/`: `RISCV_TOOLCHAIN`, else an `extern/riscv` link beside the kernel
or program, else the workspace's `extern/riscv`, else the tools on
`PATH`. QEMU is found the same way, by its install directory: an
`extern/qemu` link beside the program, else the workspace's
`extern/qemu`, its `qemu-system-riscv64` under `bin/` or at its top,
`.exe` on Windows, else `qemu-system-riscv64` on `PATH`, for a run and
a test alike; an `extern/qemu` with no binary in it is an error, never a
fall to `PATH`. Every bound a run keeps, a launch's QEMU, a probe's, and
the one second a write into one of QEMU's fifos may take, runs the one
GNU coreutils `timeout` the run resolves: `JAB_TIMEOUT` when it is set,
refused when it is not GNU's, else on Windows MSYS2's, which Windows' own
`timeout`, a pause, comes ahead of on `PATH`, else the first GNU
`timeout` on `PATH`. A launch's record names it. The tool walks the tree
through `ls` over a glob pattern rather than nu's `glob`, which breaks on
a Windows drive letter.

Windows 11 runs Jab as the setup on TheUser's host did it: the QEMU build
the project page links for Windows; MSYS2 installed separately, with its
pacman packages for the riscv64 toolchain and genromfs; and MSYS2's
`usr/bin` and the toolchain's bin directory added to the user's `PATH`.
The tool picks the window there, `sdl,gl=on`, and the sound, `dsound`.
Each of QEMU's pipes there, the monitor's, the API's, and the pad port's,
is one named pipe that QEMU waits for a client of before it starts, so
the tool names each by the run, `jab-<nonce>-<endpoint>`, and the
launch's supervisor, `jabpipe`, built with cargo from
`shim/crates/pipe`, holds each pipe's one connection for the run,
writing the launch's inputs and whatever is appended to `<endpoint>.in`
into the pipe and what the pipe gives to `<endpoint>.out`; a pipe it
cannot connect to ends the run with the pipe named. The pad bridge is
the pad port's own client, so a gamepad takes the route it takes on
macOS. That route is built and
held by its tests here on Linux, its Windows half untried on Windows
yet. A program the workspace does not list, `kit/fierce`
the first, builds against it: its kernel is built here with the same
symbols, and the generic disk, the toolchain link, the shims, and
discovery are this workspace's, and its output lands in the one target
at its path from here; `./do build` and `./do test` find it under the
root and take it with the members; one outside the tree names the
workspace in its manifest, `workspace = '../../../..'` relative to the
manifest. A manifest may also name `target_assets`, a tree its content
compiles to in its asset shard of the target, which becomes its disk;
`serial`, the serial that disk carries on a run, the program's name
unless given; `prepare`, a nushell script the tool runs before building,
testing, or running it; and `paired`, the build symbol under which a
probe of it is paired (below). A program's commands for development are
its own nu tree's bins.

A program names the system specifications it supports with `specs`, a
list of the names `asset/spec.nuon` gives them, in any case. Beside it
the manifest says what the program needs of a machine's harts:
`[reserved]`, whose `gfx_harts` is the number of harts it keeps for
graphics, and a `[feature.<name>]` table for each optional feature,
whose `io_harts` is the number of harts that feature needs while it is
active. The build checks all of it against the spec data. It refuses a
name the data does not define, a name given twice, a section beside no
`specs`, a role a section does not take, and a count below one. It
refuses a program whose base demand, its main hart and the harts it
reserves, is more than one of its specs has. A feature's demand refuses
nothing, since a spec too small for the feature runs the program without
it. The build hands the program the numbers as constants: it writes
`jab_manifest.inc` beside the image and puts that directory on the
include path, so `.include "jab_manifest.inc"` gives `JAB_BASE_HARTS`,
`JAB_RESERVED_GFX_HARTS`, and `JAB_FEATURE_<NAME>_IO_HARTS`. The build
writes that file before it decides whether the image is current, and it
rewrites the file only when the text changes. So a newer SDK that writes
different constants builds the program again. A program without `specs`
builds as it always has, and its runs are recorded as undeclared and
diagnostic.

The build records the demand with the image. Beside each image it writes
`demand.nuon`, a record of two fields: `image`, the image's SHA-256, and
`demand`, the demand the build checked, null for a program without
`specs`. A run takes its demand from that record, not from the manifest,
so an edit to the manifest changes nothing until the program is built
again. An image with no record beside it runs undeclared and diagnostic.
A record that does not hold is refused, and the refusal names each fault:
a record that does not parse, a field missing or one it does not hold,
the hash of another image, or a demand not in the shape the build
writes. The build reuses an image only when its record holds and names
the demand the build reads; otherwise it builds the image again and
writes a new record.

Every image begins with a page the build writes ahead of the program's
code. Its first word is a jump to the code, which starts at the second
page, so a kernel that enters the image at its base still reaches the
program's first instruction, and every page-aligned function stays
page-aligned. The header follows the jump: the magic `JABD`, a version,
flags, and the offset, length, and CRC-32 of the declaration. A program
that lists `specs` has its declaration after the header: its base
demand, then an entry for each spec it lists with that spec's name,
cores, RAM, display, frame rate, and ISA, taken from `asset/spec.nuon`.
A program without `specs` gets the header with its flags and every field
after them at 0. The build generates the page as `jab_header.S` beside
the image, rewrites the file only when its text changes, and counts it
among the build's inputs, so a change to a listed spec's row builds the
program again. The build refuses a listed spec whose display is not the
ABI's 1920 by 1080 or whose profile is not RVA23. `demand check-image
<image>` reads the page back and holds it to the kernel's rules.

A build is described by its symbols: `./do build --set debug,stats`
names them, in any case, and each reaches the assembler as a defined
symbol, `DEBUG` and `STATS`, for `.ifdef` to read in the kernel and in
your program alike. A build with `DEBUG` lands in the target's `debug/`
and any other in its `release/`, so the two coexist. `./do test` always
sets `DEBUG`, so a program's own debug reporting is there for its test;
`./do build` and `./do run` are release unless asked otherwise, and a
release kernel carries no debug code and no debug text, which
`test/purity` checks. The same test reads the kernel's sources for the
ordering its devices need: every virtio doorbell, and every write that
turns a queue or a device on, comes straight after a fence that puts the
driver's earlier writes before it. QEMU runs every fence as a full
barrier, so no run could show one missing, and reading the sources is how
the rule is kept.

The kernel reports what it was built with to a program through
`jab.sys.kernel.flags`, a mask with `JAB_KERNEL_DEBUG` at bit 0, the same
fact at run time that `.ifdef DEBUG` is at build. `jab.sys.random buffer,
length` fills a buffer from the machine's entropy device, virtio-rng
on every line, which is where a program's randomness comes from;
`example/pad` seeds its colours from it. Sound is virtio-sound in one
format, 48 kHz stereo signed 16-bit interleaved, a stream the kernel
keeps running on the device's clock: `jab.sys.sound.open` starts it,
`jab.sys.sound.write buffer, frames` queues frames into a ring the stream
plays in order, `jab.sys.sound.ready` says how many fit, `jab.sys.sound.await`
waits for room, and a program's exit plays the ring out. Mixed into
the same stream is the kernel's synthesizer, chip-tune voices behind
MIDI's numbers: `jab.sys.midi.program` picks a General MIDI program on a
channel, `jab.sys.midi.note.on` and `jab.sys.midi.note.off` play it,
`jab.sys.midi.control` and `jab.sys.midi.bend` shape it, `jab.sys.midi.instrument`
puts a spec of the program's own in place of a program's default, its
wave, duty, envelope, and vibrato, and `jab.sys.midi.silence` stops
everything; channel 10 is a drum kit. A Standard MIDI File the
program holds, format 0 or 1, plays through the same voices with
`jab.sys.midi.play source, length`, its tempo changes honoured, and
`jab.sys.midi.stop` and `jab.sys.midi.playing` go with it. A SoundFont 2 file
the program holds, read off a disk into its own memory and handed to
`jab.sys.midi.soundfont buffer, length`, plays the notes after it through
sampled voices instead of the chip-tune ones, the file's presets
picked by bank and program, channel 10 by its kits; the generic disk
carries FluidR3 GM at `/mix/snd/font/FluidR3_GM.sf2`. `example/techno`
plays technojab, the piece on its romfs, on its own with its name in
the middle of the screen and ends when the piece does; `example/piano`
is an octave from middle C drawn as twelve white keys, each labelled
with the key that plays it, the home row from A to the semicolon and
then V and N; `test/midi` measures a note, `test/smf` hears a file it
wrote at its notes' times, and `test/soundfont` hears a one-sample
font it wrote and then a piano from FluidR3. A program's exit plays the stream out,
the ring, the voices, and then silence enough that the host has played
the last of it, and a device that returns nothing for three seconds is
declared dead, `jab: sound stalled` on the console, the calls
answering 2 from then on rather than a wait that never ends. A debug
kernel's exit line on the debug channel counts the periods submitted,
returned, and failed, and the services that found no period still with
the device once they had taken its returns, `exhausted`; a debug kernel
reads `jab.soundlate=<ms>` to hold one service that long, which
`test/sound` uses to see the count rise by one while the stream goes on.
A run plays through the output the host's own sound
system calls its default, which `jabdisco` finds (below): on Linux
the sound server's default sink, reached through ALSA's `default`
device and the server's ALSA plugin, on macOS the system's output
through coreaudio, on Windows through dsound; a host with no output
gets the `none` backend, which discards, so a program's sound calls
still answer. `JAB_AUDIO` names a backend and its options outright,
skipping discovery, and `--no-sound` leaves the device off. `jab
launch --sound` records the guest's output to a wav, which `capture wave`
reads back, so the sound tests measure a tone rather than listening
for it. A list of rectangles
flipped at once crosses to the host rectangle by rectangle and is
painted once, as the rectangle holding them all: a paint costs the
host's window a fixed price and a wait however small it is, and a
window drawn on a timer draws late by as long as the paints take, so
one a tick is what keeps a busy screen smooth under SDL and Cocoa
alike. Every flip answers its receipt beside its status: the time the
kernel's readiness check read, the tick it held that time against, and
the present ordinal, how many presents the device has answered OK since
boot, so a program places each of its presents in the host's sequence of
flushes. A debug kernel's `jab.badxfer`, `jab.badxferat`, and
`jab.badflush` bootargs make the device refuse a chosen present's transfer
or flush, which is how `test/framecap` holds the receipts of a failure. A
kernel built with `FLIP_BATCH`, a candidate under measurement, sends the
whole flip's transfer and flush as one batch with one wait, as a list's
are sent, so a refused transfer is followed by the flush, which shows the
frame before again and counts; `./do test test/framecap --set flip_batch`
holds it, and a kernel built without the symbol is byte for byte the one
before it. bounce, walk, wasd, and pad built with `PREPARE`, the
candidate loop beside it, draw first and wait for the tick after, then
flip what they kept; `./do test example/<name> --set prepare` holds each,
and without the symbol each image is the one before it. The game built
with `FOOTPRINT`, a candidate, takes each block's mip level from the row
derivative at the block's own start, and a debug build with `LEVELS`
stores each pixel's block level, offset, and span in place of its
colour, which the game's `rust/footprint` crate reads and holds to the
exact footprint, its `differ` boxing where two pictures part;
`kit/fierce/test/footprint` holds the candidate's arithmetic to the
crate's.

With `DEBUG` the kernel's own lines leave the console: they go to a
debug channel, a virtio-serial port, which `./do run ... --set debug`
writes to `debug.log` beside the program's build output and a test reads
back as `debug` from `launch`. The console UART carries only what
the program sends it, and the fault lines, in every build.

The API is a second port, bytes both ways between a program and the
host through `jab.sys.api.write`, `jab.sys.api.read`, and `jab.sys.api.await`.
Every kernel carries it and any build runs with or without it: `./do
run example/wasd --api` puts the port on the machine, and without the
flag the calls report that there is none. The host's end sits beside
the build output: `api.in`, a named pipe the host writes into, on
Windows a plain file whose appended bytes the launch's supervisor
forwards into the pipe, and `api.out`, a file
the program's bytes land in, which a test drives through `launch
--api --send`. `example/wasd` speaks a small binary
API over it, its records at the top of its `main.S`.

Every QEMU a launch, a probe, or a run starts runs under `jabpipe
supervise`, the launch's supervisor. It owns QEMU from its spawn to its
reap, holds it inert until the caller allows it to go, and writes every
timed input at its time, timing each on its own monotonic clock from the
run's go. A launch first takes the host's launch lock, so measured runs
never overlap: `jab/launch/` under the user's state home, outside every
checkout and target. A launch leaves `launch.nuon` in its output
directory, the run's record: every input's state and time, every thread
reading, and the run's end. The supervisor's control files there,
`launch-<token>.*.json`, are cleared away once it ends.

A test takes the screen with `launch --capture <at>`, which ends the
run once the screen is whole, or with `--screen <at>`, which takes it
while the run goes on to its bound; `--stop <at>` ends the run at its
time with no screen. The supervisor writes the timed inputs, the keys,
the API's bytes, and the pad's events, in the order of their times, each
once QEMU runs and whole before the next, and the screen after those due
before its time and ahead of those due at or after it, which wait until
its file is whole: the PPM's header and every pixel of the display.
`launch due-order` is that order as a function of the inputs and the
time, so a test can hold it without a run. A screen that fails leaves
the result no screen and every input after it unwritten. The result
carries when the screen was asked and completed, when each of the API's
writes and the run's quit went in, seconds from the run's go, and every
input left unfinished.

A run prints nothing of its own; what the kernel says in a debug build
is in `debug.log` beside the program's build output, and what a program
sends over the API is in `api.out` there. `./do watch`, from any shell
while a program runs, records the QEMU process per thread once a
second to `watch.nuonl` in the target until the run ends, with the
process's resident memory beside each second (VmRSS on Linux, `ps -o
rss=` on macOS), printing each second's rates as it goes: on Linux the
harts as `CPU 0/TCG` and on
and the main loop under the process name, which is where the host's
copy and paint of each flip lands; on macOS, whose threads carry no
names, the first row is the thread that draws the window and the rest
are numbered. When the run ends it prints one NUON record on the
recording, the run as it was (host, QEMU, the harts, `-machine`, the
CPU, and the accelerator off QEMU's command line, window, the symbols
the kernel was built with), the translator's mode as `tcg`,
single-threaded when one `ALL CPUs/TCG` thread runs every hart, which
is never evidence of multicore performance, and multi-threaded with a
`CPU N/TCG` thread a hart, per thread the steady CPU seconds a
second after the first five, which `--skip` changes, a run too short for
them reported over all it has, and the resident memory's median and
peak over the same stretch, ready to paste. On
macOS a thread is its row, and QEMU's worker threads come and go, so
a row that changed identity during the recording is reported with
`stable: false` and no peak.

A test reads the threads itself with `launch --threads <at>`: every
QEMU thread's CPU at that time and again a second on, each reading timed
by the supervisor as it is taken, the span the two readings' own
interval. Each thread comes back with the CPU seconds it used
between the readings and those over the span, its share of a core, the
span beside them. `test/harts` and `test/jobs` hold an idle hart under
0.05 of a core that way.

`./do bench <program>/<bench>` runs a program's bench, the NUON file of
that name under the program's `bench/`: `./do bench kit/fierce/cadence`
(or `fierce/cadence`) is `kit/fierce/bench/cadence.nuon`. The program is
built in the bench's tree, then each step runs in order, a script of the
program's with its arguments and its own output directory; a step a
person attends is announced and counted down first, and a step that
fails is recorded and the rest run. The bench's report then reads every
step, and a bench with a failed step or a failed report exits 1 once
all of it is recorded. The cadence bench's report, `nuance.nu gauge
bench-report`, names the machine and the QEMU each step ran on, pools
only the runs a comparison would take as valid, and lists every other
run apart, as a diagnostic with its reasons, a run on a diagnostic
machine among them. `kit/fierce/bench/qual_1ka1.nuon` and
`qual_1kb1.nuon` are the qualification's, each launching every run by
its spec's name: the factory route in two batches of three seeded runs,
the second's seeds reversed, a free play, the presentation's probed
batches beside their shim control, and the worker scaling control. The
automatic workers' batches, the route's two among them, are one build,
so they carry one name, `auto_1` to `auto_6`, since the report's
comparison takes a label less its `_<n>` as the build's one name. A
step passes a list, its seeds, as NUON in one word, `"[3 2 1]"`, since a
script's command line carries strings alone. Each
run of a bench is a stamped directory in the program's `bench/` shard
of the target, with `bench.nuon` recording each step's outcome, and a
state file beside the stamps says what runs. At its end the run is
packed into one tar beside its directory, named for the bench and the
stamp, `example_workers_scaling-<stamp>.tar` for
`example/workers/scaling`, and the bench's last line names it: the one
file to copy off the host. `nu/bin/nuance.nu watch bench
<program>/<bench>`, in a second terminal before the bench starts or while
it runs, records every QEMU of the run per thread under the step its own
command line names;
when the bench has finished it prints the bench's report and its own per
QEMU, the steady CPU and the resident memory, writes them together as
`watch.nuon` in the run, then packs the run
again with its recording into that same tar, the old one moved aside,
and names it last. `./do bench` alone lists the benches, and `--only`
runs the steps its comma-separated labels name.

`nu/bin/nuance/probe.nu sdl example/walk` looks at the window itself: it runs
the program under SDL with OpenGL for twelve seconds (`--seconds N`)
with a small library preloaded into QEMU, `shim/crates/sdl`, built with
cargo into the target's `shim/`. The library logs every SDL call the
window makes with a timestamp, and for each time the window takes its
drawing context, the calls that led there. The log opens with a list of
the files QEMU has loaded. The probe reads those calls through the
files' own symbol tables with binutils' `nm`, which must be on PATH,
and so tells four things apart: a flip's upload, which comes from the
virtio-gpu device; a switch, the window taking a new surface; the
console's own redraws, which are no flip of the program's; and a drawn
frame, named by the front-end function that draws it. A QEMU whose front
end keeps only its dynamic symbols, where that function has no name, has
its drawn frames read by the window-size call that follows within 2 ms,
weaker evidence and labelled so. Then it
prints one NUON record on how the program's flips reached the window,
ready to paste: the uploads per flip and their spacing, the flip
cadence, the drawn frames and their interval, each drawn frame's gap to
its size call with any past 2 ms named, the switches, and any
frame drawn inside a flip, which is a half-drawn tick. When it cannot
read every call, as on a QEMU stripped of its symbol table, or the log
holds a line the library never writes, or the library stopped the run
because it could not reach SDL, it prints no record and says why
instead. Linux only, since it preloads into QEMU;
with no display server SDL runs its offscreen driver, drawing nothing
along the same path.

The library's log opens with QEMU's process id and the run's capture
nonce, a number made fresh for each run, so a capture names the run that
made it. As its last step the probe bundles the run into `probe/bundle`
beside the log, so the reading can be checked on another machine: the
log as it was written, the symbol tables the reading used, the reading
itself, and a manifest of every file's SHA-256 beside the host and its
QEMU. `sdl bundle-check` holds a bundle to its manifest stage by
stage and reads the log again from the bundled tables, so a bundle made
on one host is admitted on another where the files the log names are
not there, and a bundle altered anywhere is refused at the stage that
finds it. `launch --sdl-probe <log>` puts the same library into a
test's own launch, its window SDL with OpenGL.

The probe puts the API's port on the machine with `--api`, and
`--send <file>` writes the file's bytes into it at 200 ms; the
program's own bytes are then kept beside the log as `api.out`.
`--trace` has QEMU trace the device's flushes and its scanout changes
into `trace.log` there, each line stamped by the host's clock, which
the bundle's check pairs with the uploads; a QEMU whose trace events
lack them is refused. A manifest's `paired` names a build symbol under
which the program reads the capture nonce's frame from the API before it
starts: 16 bytes, `WNON` as a little-endian word, a zero word, and the
nonce. A probe of a build that sets it is paired: the port goes on, the
frame goes in at 200 ms ahead of any `--send`, and the bundle binds the
program's own records to the run by the nonce they carry. Every other
probe is generic and sends nothing of its own.

walk has such a build, `cadence`, which records every frame of a two
minute window and sends the records over the API when the window ends.
`example/walk/test/cadence.nu` runs it once with no probe, on a named
spec's machine read from the workspace the script sits in, wherever the
image and the kernel lie, a package's among them: it mints the nonce, sends the nonce's frame, keeps
`api.out`, and writes an identity naming the nonce and the digests of
the image, the kernel, and the romfs. The workbench reads the records.

A gamepad on the host reaches a program two ways, and a program never
learns which. A run finds the pad through `jabdisco`, built with
cargo into `tool/target` on first use (it needs libudev's and
ALSA's headers on Linux), which takes any pad with two sticks, a dpad,
and eight buttons; the same record carries the audio output, and
`jabdisco --debug` prints beside it every gamepad and every audio
host and output the host shows, for a report when a run finds nothing
or the wrong thing. On Linux the run passes the pad through
as `virtio-input-host-device`, QEMU holding it for the run;
`JAB_PAD=/dev/input/eventN` names one outright. On macOS and Windows
QEMU cannot carry a gamepad by any device of its own, so the run puts a
port on the machine's serial device, `jab.pad`, and runs `jabshim_pad`
beside QEMU as the launch's helper, a bridge built with cargo from
`shim/crates/pad` that
reads the pad through gilrs and writes its name, its ranges, and every
event into the port in evdev's shapes (`doc/padport.md`); the kernel
takes the port as the pad. On Windows the bridge connects to the port's
pipe before it looks for the pad, so QEMU, which waits for that client,
goes on without a pad when none is found. `--no-pad` leaves the pad off either way.
A program reads it with `jab.sys.pad.read`, the
keys as a mask and every axis by its evdev code normalised to signed
16 bits, `jab.sys.pad.input` for the events as evdev sends them, and
`jab.sys.pad.axis` for an axis's own range and `jab.sys.pad.name` for its name;
`example/pad` is wasd on the left stick and the dpad, the sticks
pressed in (THUMBL, THUMBR) stopping the sphere, every other button
painting it a colour of its own and naming itself at the top of the
screen for three seconds after it is let go, the pad's own name there
at startup, and the right stick painting the sphere a colour made from
its exact position while driving it by thirds of its throw at a
quarter, one, and twice the usual push, through `jab.sys.display.text`,
which draws a string anywhere in the framebuffer with the console's
font at any scale. The window is titled `jab <program>` inside QEMU's
own prefix, which every front end hardcodes. The keyboard and the
tablet come off
the line with `--no-kbm`. QEMU's `virt` has eight virtio-mmio
transports, fixed in the board, so the disks ride the machine's PCI
Express root instead (`virtio-blk-pci`), where any number fit, and the
full line is six transports, seven with the serial device, eight with a
pad; the tool still refuses a ninth and says so. A test plays a gamepad with no device on
the host: `launch --pad <file>` takes a NUON table of timed
events and, on Linux, makes a fifo and preloads `shim/crates/evdev`
into QEMU to answer the device's questions as an 8BitDo pad would; on
any other host, and on Linux with `--pad-port`, it plays the table
into the pad port instead, the same pad described in the port's
header, so the pad's tests run both ways here and the port's way
there.

The CPU is RVA23, `-cpu rva23s64,pmp=true`, on every machine: a QEMU
without the model, any before 9.2, is refused with its version and a
line saying to link `extern/qemu` to a QEMU 11 install, and nothing
overrides it. The assembler takes the same profile, `-march=rva23u64`
for a program and `-march=rva23s64` for the kernel, so a source may use
anything RVA23 carries, vectors included, with no `.option`. The kernel
lets a program run the cache-block operations, `cbo.zero`, `cbo.clean`,
`cbo.flush`, and `cbo.inval`, the last as a flush, and read every counter
the hart has. `time`, at `JAB_TIME_HZ`, is the clock to measure a frame's
work by; under QEMU's TCG, `cycle` and `instret` both read the host's tick
counter and count no guest work, and `hpmcounter3` to `hpmcounter18` read
0, since no event is selected and selecting one stays machine mode's.

A machine is one of the system specifications `asset/spec.nuon`
defines: its cores are the harts, `-smp`, its RAM `-m`, and its display
the GPU's; the kernel is told its name with `jab.spec=<name>` on its
command line. The spec is the one `--spec` (or `-s`) names on `./do run`,
`nu/bin/nuance/plan.nu`, `launch`, `machine dump-tree`, or the gauge, else the
default: `JAB_SPEC` when it is set, else the `spec` in `jab/config.toml`
under the XDG config home, `$XDG_CONFIG_HOME` or `~/.config`. That file
is written from `asset/default/config.toml`, `spec = '1ka1'`, the first
time a launch needs it, and never over one that is there; the config
home itself must already exist. `./do test --spec 1kb1` runs the tests'
launches on that spec. Today the launcher provisions 1KA1, three harts
and 4 GiB, and 1KB1, seven harts and 8 GiB, both at 1920 by 1080; it
refuses a spec with more cores than the eight of `jab.inc`'s
`JAB_HARTS_MAX`, or with another display, and a spec the program does not
list, naming both. `--harts` with a count from one to eight names a
custom machine instead, 4 GiB and no `jab.spec`, diagnostic whatever its
count, which every record of the run labels so; `--spec` with `--harts`
is refused. Every machine runs multithreaded TCG, `-accel
tcg,thread=multi`, a host thread a hart, and is `-machine
virt,aia=aplic-imsic,aclint=on`. Its interrupts go through the RISC-V
Advanced Interrupt Architecture: the APLIC turns each device's interrupt
line into a message, and each hart's IMSIC receives those messages in its
interrupt files. The ACLINT keeps the timer. Every launch's record
carries its machine: a named spec's name, cores, RAM, and display, or a
custom machine's harts and RAM, with `-machine`, the CPU, and the
accelerator. QEMU hands every hart the device tree it built, and the
kernel reads it once, on hart 0 in machine mode before anything else
runs. Every cpu the tree lists is discovered. Hart 0 runs the kernel and
the program. It also releases every other hart from where it waits. Each
of those sets itself up on its own stack, checks in, and sleeps until it
is given work. `jab.sys.harts` answers the discovered, online, and failed
harts as masks, bit n for hart n. A hart that has no interrupt file, does
not check in within 100 ms, fails its own self-check, or does not take a
worker's start within 100 ms is failed, and the run goes on without it. A cpu the kernel cannot use, an id past
`JAB_HARTS_MAX` among them, keeps the kernel on hart 0 with every other
hart failed, named on the debug channel; a tree
the kernel cannot read, a timer other than QEMU's 10 MHz, or an interrupt
platform other than QEMU's ends the run before the program starts, its
line on the console and status 1. `jab
launch --dtb <file>` hands the machine a tree of its own, `--bootargs
<text>` puts QEMU's `-append` in the tree, which a debug kernel prints,
and `machine dump-tree` writes the tree QEMU builds for a machine. A debug
kernel reads two more settings there for `test/harts`: `jab.late=<hart>`
holds that hart back until it has been failed, and `jab.stray=1` makes a
kernel fault. A fault in the kernel, on any hart, prints its line on the
console, naming the hart, and ends the run with status 1.

Before the program starts, the kernel holds the machine to the image's
declaration. Every kernel reads `jab.spec` from its command line, a
release one too. When a spec is named, it must be one the image lists,
in any case, and the machine must have exactly that spec's cores, every
one online, and exactly its RAM. Otherwise the run ends with a line that
names the spec, what it wants, and what the machine has. With a spec
named or not, the harts online must reach the image's base demand, or
the run ends with `jab: harts short of the program's demand: <online>
for <base>`. A header the kernel cannot accept ends the run with `jab:
declaration refused: ` and the reason. Each of these lines goes to the
console with status 1. An image built before the header, and one that
declares nothing, run as they always have. A debug kernel skips the base
demand under `jab.nominimum=1`, so a program's own answer to a short
machine can be tested; a launch with that setting records
`below_minimum` in its machine and is diagnostic, and a release kernel
ignores the setting. So below a program's minimum nothing is measured.

A program puts work on the other harts through workers. `jab.sys.worker.start
hart, entry, argument, stack, size` starts one on an online hart, and only
hart 0 may call it. The hart enters the program at the entry with the
argument in a0, its own id in a1, and sp at the top of the stack the program
gave it. That stack must lie inside the program's window, on 16 bytes, and
clear of both the main stack's reservation, `JAB_MAIN_STACK` under the
window's top, and every running worker's stack. A start the kernel refuses
answers a code and changes nothing. A worker sleeps with
`jab.sys.worker.wait word, value` while a 32-bit word holds a value, wakes
the harts sleeping on a word it changed with `jab.sys.worker.wake mask`, and
ends with `jab.sys.worker.exit`. Hart 0 waits and wakes the same way, and its
devices keep working while it waits. `jab.sys.worker.stop mask` stops
workers: a waiting worker's wait answers 1, and one still running 50 ms
later is interrupted where it is. The stop looks at every online hart in its
mask and returns only once each one's worker is gone, so a worker that was
already on its way out is waited for too. When the stop returns, the
workers' stacks and buffers are free. A worker's exit finishes its own
bookkeeping before it marks its hart free, so a start that comes during an
exit finds the hart busy, and a start after it begins cleanly. A worker may call only `jab.sys.harts` and the worker
calls; any other call answers `JAB_DENIED`, all ones, and does nothing. A
worker's fault ends the run with a line naming its hart, `jab: worker fault:
hart=N argument=... cause=... epc=... tval=...`, once every other hart has
stopped at a safe point, and `jab.sys.exit` stops every worker before the
sound plays out. A debug kernel reads three settings for the worker tests:
`jab.noack=<hart>` keeps that hart from taking its start,
`jab.claimhold=<ms>` holds the first fault's shutdown for that long before
it stops the other harts, and `jab.leavehold=<hart>` holds that hart's first
exit halfway, for 200 ms at most, while the worker's argument names a word
of the program's in which the kernel records what the next start or stop
saw there. `test/workers` and `test/workerfault` prove each rule.

Every device belongs to hart 0. A driver's state is touched only by hart 0's
calls and by the interrupt drain on hart 0, and so is the state of the
format decoders and the sprite draw. A worker's calls never reach a driver
or a decoder, and every device interrupt goes to hart 0's interrupt file. A
secondary's file enables only the wake, so a drain there claims nothing
else. `test/owners` checks this on the built kernels. Every kernel source
file is in a class, and a new file fails the check until it is placed in
one. The check follows every path a worker can take from the trap vector,
the drain, and the calls a worker may make. It fails when a path reaches a
routine or the data of a driver, a decoder, or hart 0's own storage, or
calls through a register anywhere but the call table. It also checks the
shapes it relies on, and any other shape fails by name: the test of the
hart's id that sends a worker to its own calls, the four calls a worker may
make, the call table's jump, and the drain's mask of the wake before it
serves a device. Two reads are allowed by instruction, each under its
condition: the drain's read of the sound's base address, after its mask,
which only orders the sound first, and the worker wait's read of the
sound's live flag, on hart 0's side of its branch. The check sees the
addresses an instruction names; an address held in a register and then
used is outside it. A debug kernel also ends the run when a hart other than
0 claims a device's interrupt, `jab: hart N claimed a device identity M`,
or when a secondary's file enables one, `jab: hart N enabled a device
identity M`, or disables its wake, `jab: hart N disabled the wake identity
1`.

Two of the program's buffers belong to the kernel after their call
returns. A MIDI file is read in place while it plays, and a SoundFont while
it is loaded. No hart may write either then, a worker included. Every other
request finishes inside its call. While one of hart 0's calls runs, the
buffer it uses, the framebuffer during a flip among them, is no worker's to
write either. The kernel checks none of this; breaking it is the program's
own fault.

A program that declares its harts owns them. `jab.sys.harts.reserve count`
reserves every online hart past hart 0 for the program's graphics, once a
run. The count is the program's declared `JAB_RESERVED_GFX_HARTS`, the
floor its grant may not drop below. An optional feature takes harts from
that grant with `jab.sys.harts.claim mask`, which answers the claim's id,
and gives them back with `jab.sys.harts.release id`. A claim that would
leave the grant below its floor is refused, so the reservation's required
harts are always kept. `jab.sys.harts.owned owner` answers the harts an
owner holds as a mask. After a reservation every worker's start names its
owner as a sixth argument, and a start on a hart another owner holds is
refused. A program that never reserves starts its workers as before. Only
hart 0 makes these calls; a worker's answer `JAB_DENIED`. A claim's id is
never used twice in a run, and a debug kernel reads `jab.claimids=<n>` to
leave only n of them, so a test can reach the limit. `test/reservations`
proves each rule.

`test/feature` proves how an optional feature takes harts from graphics
and gives them back. The program reserves its graphics harts and draws
frames on them. It then asks for the hart a synthetic feature needs. It
takes the hart only if the harts left over still cover the reservation.
On three harts that check fails, so the feature is refused and graphics
keeps every hart. On four harts the feature is admitted twice. At
startup it takes its hart before graphics starts. Later, while graphics
runs on every hart, it takes the hart at a safe point. The program
finishes the frame in flight, stops the graphics worker on that hart,
and only then claims the hart. The kernel refuses the claim while any
worker still runs there. The feature's worker runs under the claim's id.
When the feature is done, the program stops that worker, releases the
hart, and starts graphics on it again. Every frame records which hart
drew each row, so the test can check that the feature's hart drew no
row while the feature held it.

`sdk/src/jab_jobs.inc` gives workers jobs. Each worker has a mailbox in the
program's memory, two cache lines: hart 0 writes a job into one, and the
worker writes its completion into the other. `jab.job.publish` writes a job
and its generation, `jab.job.await` is a worker's sleep until one comes,
`jab.job.complete` marks it done, and `jab.job.join` is hart 0's sleep until
it is. The macros carry the memory ordering the hardware needs, so a worker
never reads a job before it is whole, and hart 0 never reads a result
before it is written. A job can be cancelled between the bands of its work.
A cancel names the job in flight, or the next job once the mailbox is free,
and each publish drops any other, so a cancel left over from an older job
never ends a newer one, even when the generation count wraps.
`test/jobs` races every order a job and its wake can come in, a thousand
rounds each, and `./do bench test/jobs/costs` measures what a job costs
around its work, at four job sizes, with one worker and with two on the
specification's three harts: the dispatch to a worker, the barrier back
to hart 0, and the least a round of jobs costs beyond its work, its
slowest dispatch plus its barrier.

`example/workers` puts the jobs to work on a diagnostic machine of four
harts, its three workers needing a fourth. Hart 0 deals the rows of the
Mandelbrot set in bands of eight to one, two, then three workers, five
seconds each, while the view zooms in by the clock. A bar at the left edge
shows which hart computed each row, and the frame's time is drawn as text.
With the API the program proves itself. The letter `p` draws one fixed
frame with each count of workers and hashes each image before its bars and
text, so the three hashes agree when the work is right, and it sends three
rows for the host to compute again. A digit, `1` to `3`, draws that frame
over and over for four seconds with that many workers. `./do bench
example/workers/scaling` runs one, two, and three workers on a release
build and reports the frames, the hashes, each worker's rows, each hart's
share of a core over a timed second, and how much the bands overlapped in
time.

A device that holds its interrupt raised while it makes no progress for
three seconds is cut off. The kernel masks that interrupt and resets the
device, so it stops using any buffer of the program's that it still
holds, and only then marks it failed and prints `jab: interrupt source N
stalled` on the console. From then on the device's calls answer with its
error, and a wait on it ends with the failure, even if the reset finished
the request it was waiting for. A device that will not read back its
reset within 100 ms ends the run with `jab: device reset refused: source
N` and status 1. A disk reset in QEMU finishes every disk's requests on
the machine before it returns, so the kernel notes what each disk on a
failed line had in flight before it resets any of them. A pad on the
serial port fails with the serial device, and an API write the failure
interrupts answers 2, some of its bytes perhaps already at the host. A
debug kernel reads `jab.hold=<virtio device id>` from `--bootargs` and
holds that device's interrupt raised, `jab.hold=2` every disk's, and
`jab.unsent=3` leaves the API's writes unannounced to the device;
`test/stuck` uses them to prove each rule, one scenario a launch.

`launch --qemu <words>` appends words of its own to the machine's
QEMU line, a device or a property a test needs that no option gives; the
run is then diagnostic, the words kept in its machine record and
returned apart as `overrides`. The gauge's `run` and `play` take the same
option, and a comparison refuses such runs unless `--diagnostic` admits
them, naming the words.

`JAB_QEMU_ARGS` appends its words to a run's QEMU line after
everything else, for QEMU's own instruments on a run that misbehaves,
such as `-trace alsa_* -D trace.log`; the value is split as a shell
would split it, quotes grouping a word with spaces and then removed,
and no shell ever reads it, so a `*` needs no quoting.

The program's window is the same on every machine: the kernel keeps the
first 2 MiB of RAM and the framebuffer the 8 MiB after, and the window
from there to the end of the first 4 GiB is the program's,
`sdk/src/jab.inc` naming its base, its size, and the stack top at its
end. The kernel reads the machine's RAM from the device tree's memory
nodes before anything else runs. It refuses banks that overlap, that
start below RAM's base, that reach past 256 GiB, or that are empty, and
a machine whose banks do not hold the kernel, the framebuffer, and the
window, each refusal a line on the UART and status 1. RAM past the
window, the 4 GiB from 0x180000000 on 1KB1, is counted and listed free,
and the debug channel prints it, but no program can reach it yet. A
program's assets ship on a romfs disk the tool builds from the
directory its manifest names, a virtio-blk device on the PCI Express
root the kernel brings up itself, BARs and all, since no firmware runs
before it; read with `jab.sys.romfs.*`. A second disk, serial `mix`,
rides beside it on every run and launch: the workspace's generic
assets, `generic/` mirrored to the image's root plus what
`generic/manifest.nuon` fetches, today the FluidR3 GM and GS soundfonts
under `/mix/snd/font` with their license under
`/doc/license/fluid-soundfont`, fetched into the target's `fetch/` on
first use, verified by sha256, and never committed.
Both asset disks are attached read-only, so a program's write to one
comes back as the device's error and the image the next run reads is
the one the tool built; the blank data disk a run carries when a
program ships no assets stays writable. A PNG among a program's assets, as GIMP 3
exports one, decodes in the kernel into a sprite with `jab.sys.sprite.png`
and draws with `jab.sys.sprite.draw`, which `example/logo` shows.

