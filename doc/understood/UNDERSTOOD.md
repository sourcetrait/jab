# UNDERSTOOD.md
>REIN AI

An assembly ecosystem on QEMU: an assembly kernel that is itself the API,
running RISC-V programs a hobbyist drops in. Everything is virtio, and it
runs only under QEMU's `virt` machine.

- `workspace.jab.toml` the workspace: the kernel and the programs.
- `justfile` the repository's one justfile, every recipe handing off to
  `sdk/nu/jab.nu`.
- `kernel/` the kernel: `kernel.jab.toml`, sources under `src/`, and
  each source's `.eye` and `.md` under `srcdoc/`.
- `sdk/` what a program uses, its sources under `src/` and their `.eye`
  and `.md` under `srcdoc/`: `jab.inc`, whose `jab.sys.*` macros are
  the kernel's calls, each a trap into it; `jab_f32.inc`,
  `jab_f64.inc`, and `jab_rng.inc`, mathematics and chance as macros
  the program carries and expands in place, never a call and never a
  trap; `jab_jobs.inc`, jobs for workers as macros over mailboxes the
  program owns, whose waits are the kernel's; the program link script;
  and `nu/jab.nu` for its test.
- `doc/syscalls.nuon` the system call table of record; `doc/lists.md`
  how every call that fills a buffer with records works.
- `example/<name>/`, `test/<name>/` programs by category, each with
  `program.jab.toml`, `src/main.S` and its `srcdoc/`, and its
  integration test at `test/test.nu`.
- `shim/` the preload shims, a cargo workspace, a crate each under
  `crates/`: `sdl` for the probe and `evdev` for the pad tests.
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

Build and run with `just` and nushell, from anywhere in the repository,
a program named by its path from the root or by a shortcut
`workspace.jab.toml` names, `fps` for `game/fps/1k`: `just build` (or
`just build example`, `just build game/fps/1k`), `just test` (or `just
test example/pad`), `just run example/helloworld` or `just run fps`, and
`just watch`; `just adv` lists the commands for development. `just run`
opens QEMU's own window when a display server is present, SDL with
OpenGL on Linux and Windows and Cocoa on macOS, and otherwise serves the
console over VNC on 127.0.0.1:5930, to tunnel and view; `JAB_DISPLAY`
overrides with any `-display` value. Nothing the tools clear away is
deleted, robojab included: a build's, a test's, or a bench's is moved
whole into the retire home, `tmp/retired/<stamp>/` at its place there.
`just clean` retires the whole target, so the next build starts from
nothing, and `just adv clean <path>` retires only the outputs of the
programs under a path, or the kernel's, in one tree with `--tree`.
`just retire` is the one command that deletes: it removes the retire
home's `tmp` and everything in it. Neither `just clean` nor
`just retire` takes an argument.
The toolchain is found by its install directory, the one holding
`bin/`: `RISCV_TOOLCHAIN`, else an `extern/riscv` link beside the kernel
or program, else the workspace's `extern/riscv`, else the tools on
`PATH`. QEMU is found the same way, by its install directory: an
`extern/qemu` link beside the program, else the workspace's
`extern/qemu`, its `qemu-system-riscv64` under `bin/` or at its top,
`.exe` on Windows, else `qemu-system-riscv64` on `PATH`, for a run and
a test alike; an `extern/qemu` with no binary in it is an error, never a
fall to `PATH`. A program the workspace does not list, `game/fps/1k`
the first, builds against it: its kernel is built here with the same
symbols, and the generic disk, the toolchain link, the shims, and
discovery are this workspace's, and its output lands in the one target
at its path from here; `just build` and `just test` find it under the
root and take it with the members; one outside the tree names the
workspace in its manifest, `workspace = '../../../..'` relative to the
manifest. A manifest may also name `target_assets`, a tree its content
compiles to in its asset shard of the target, which becomes its disk;
`prepare`, a nushell script the tool runs before building, testing, or
running it; and `adv`, a nushell script whose `main <command>`
definitions are its commands for development.

A build is described by its symbols: `just build --set debug,stats`
names them, in any case, and each reaches the assembler as a defined
symbol, `DEBUG` and `STATS`, for `.ifdef` to read in the kernel and in
your program alike. A build with `DEBUG` lands in the target's `debug/`
and any other in its `release/`, so the two coexist. `just test` always
sets `DEBUG`, so a program's own debug reporting is there for its test;
`just build` and `just run` are release unless asked otherwise, and a
release kernel carries no debug code and no debug text, which
`test/purity` checks.

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
answering 2 from then on rather than a wait that never ends. A run plays through the output the host's own sound
system calls its default, which `lowkickdisco` finds (below): on Linux
the sound server's default sink, reached through ALSA's `default`
device and the server's ALSA plugin, on macOS the system's output
through coreaudio, on Windows through dsound; a host with no output
gets the `none` backend, which discards, so a program's sound calls
still answer. `JAB_AUDIO` names a backend and its options outright,
skipping discovery, and `--no-sound` leaves the device off. `jab
launch --sound` records the guest's output to a wav, which `jab wave`
reads back, so the sound tests measure a tone rather than listening
for it. A list of rectangles
flipped at once crosses to the host rectangle by rectangle and is
painted once, as the rectangle holding them all: a paint costs the
host's window a fixed price and a wait however small it is, and a
window drawn on a timer draws late by as long as the paints take, so
one a tick is what keeps a busy screen smooth under SDL and Cocoa
alike.

With `DEBUG` the kernel's own lines leave the console: they go to a
debug channel, a virtio-serial port, which `just run ... --set debug`
writes to `debug.log` beside the program's build output and a test reads
back as `debug` from `jab launch`. The console UART carries only what
the program sends it, and the fault lines, in every build.

The API is a second port, bytes both ways between a program and the
host through `jab.sys.api.write`, `jab.sys.api.read`, and `jab.sys.api.await`.
Every kernel carries it and any build runs with or without it: `just
run example wasd --api` puts the port on the machine, and without the
flag the calls report that there is none. The host's end sits beside
the build output: `api.in`, a named pipe the host writes into, and
`api.out`, a file the program's bytes land in, which a test drives
through `jab launch --api --send`. `example/wasd` speaks a small binary
API over it, its records at the top of its `main.S`.

A run prints nothing of its own; what the kernel says in a debug build
is in `debug.log` beside the program's build output, and what a program
sends over the API is in `api.out` there. `just watch`, from any shell
while a program runs, records the QEMU process per thread once a
second to `watch.nuonl` in the target until the run ends, printing each
second's rates as it goes: on Linux the harts as `CPU 0/TCG` and on
and the main loop under the process name, which is where the host's
copy and paint of each flip lands; on macOS, whose threads carry no
names, the first row is the thread that draws the window and the rest
are numbered. When the run ends it prints one NUON record on the
recording, the run as it was (host, QEMU, the harts, `-machine`, the
CPU, and the accelerator off QEMU's command line, window, the symbols
the kernel was built with), the translator's mode as `tcg`,
single-threaded when one `ALL CPUs/TCG` thread runs every hart, which
is never evidence of multicore performance, and multi-threaded with a
`CPU N/TCG` thread a hart, and per thread the steady CPU seconds a
second after the first five, which `--skip` changes, a run too short for
them reported over all it has, ready to paste. On
macOS a thread is its row, and QEMU's worker threads come and go, so
a row that changed identity during the recording is reported with
`stable: false` and no peak.

`just bench <program>/<bench>` runs a program's bench, the NUON file of
that name under the program's `bench/`: `just bench game/fps/1k/cadence`
(or `fps/cadence`) is `game/fps/1k/bench/cadence.nuon`. The program is
built in the bench's tree, then each step runs in order, a script of the
program's with its arguments and its own output directory; a step a
person attends is announced and counted down first, and a step that
fails is recorded and the rest run. The bench's report then reads every
step, and a bench with a failed step or a failed report exits 1 once
all of it is recorded. The cadence bench's report, `gauge.nu
bench-report`, names the machine and the QEMU each step ran on, pools
only the runs a comparison would take as valid, and lists every other
run apart, as a diagnostic with its reasons, a run on a diagnostic
machine among them. Each
run of a bench is a stamped directory in the program's `bench/` shard
of the target, with `bench.nuon` recording each step's outcome, and a
state file beside the stamps says what runs. `just watch bench
<program>/<bench>`, in a second terminal before the bench starts or
while it runs, records every QEMU of the run per thread under the step
its own command line names; when the bench has finished it prints the
bench's report and its own per QEMU, and writes them together as
`watch.nuon` in the run. `just bench` alone lists the benches, and
`--only` runs the steps its comma-separated labels name.

`just adv probe sdl example/walk` looks at the window itself: it runs
the program under SDL with OpenGL for twelve seconds (`--seconds N`)
with a small library preloaded into QEMU, `shim/crates/sdl`, built with
cargo into the target's `shim/`, which logs every SDL call the window
makes with a timestamp and its callers; then it prints one NUON record
on how the program's flips reached the window, ready to paste: the
uploads per flip and their spacing, the flip cadence, the drawn frames
and their interval, and any frame drawn inside a flip, which is a
half-drawn tick. Linux only, since it preloads into QEMU; with no
display server SDL runs its offscreen driver, drawing nothing along the
same path.

A gamepad on the host reaches a program two ways, and a program never
learns which. A run finds the pad through `jabdisco`, built with
cargo into `tool/target` on first use (it needs libudev's and
ALSA's headers on Linux), which takes any pad with two sticks, a dpad,
and eight buttons; the same record carries the audio output, and
`jabdisco --debug` prints beside it every gamepad and every audio
host and output the host shows, for a report when a run finds nothing
or the wrong thing. On Linux the run passes the pad through
as `virtio-input-host-device`, QEMU holding it for the run;
`JAB_PAD=/dev/input/eventN` names one outright. On macOS QEMU cannot
carry a gamepad by any device of its own, so the run puts a port on
the machine's serial device, `jab.pad`, and starts `jabshim_pad`
beside QEMU, a bridge built with cargo from `shim/crates/pad` that
reads the pad through gilrs and writes its name, its ranges, and every
event into the port in evdev's shapes (`doc/padport.md`); the kernel
takes the port as the pad. `--no-pad` leaves the pad off either way.
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
the host: `jab launch --pad <file>` takes a NUON table of timed
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

Every machine has four harts, `-smp 4`, on multithreaded TCG, `-accel
tcg,thread=multi`, a host thread a hart. The machine is `-machine
virt,aia=aplic-imsic,aclint=on`. Its interrupts go through the RISC-V
Advanced Interrupt Architecture: the APLIC turns each device's interrupt
line into a message, and each hart's IMSIC receives those messages in its
interrupt files. The ACLINT keeps the timer. `--harts 1` or `--harts 2` on
`just run`, `jab.nu plan`, or `jab launch` gives a diagnostic machine of
one or two harts, which every record of the run labels so, and any other
count is refused before QEMU starts; every launch's record carries its
machine, the harts asked for, diagnostic or not, `-machine`, the CPU, and
the accelerator. QEMU hands every hart the device tree it built, and the
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
and `jab dump-tree` writes the tree QEMU builds for a machine. A debug
kernel reads two more settings there for `test/harts`: `jab.late=<hart>`
holds that hart back until it has been failed, and `jab.stray=1` makes a
kernel fault. A fault in the kernel, on any hart, prints its line on the
console, naming the hart, and ends the run with status 1.

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
later is interrupted where it is. When the stop returns, the workers' stacks
and buffers are free. A worker may call only `jab.sys.harts` and the worker
calls; any other call answers `JAB_DENIED`, all ones, and does nothing. A
worker's fault ends the run with a line naming its hart, `jab: worker fault:
hart=N argument=... cause=... epc=... tval=...`, once every other hart has
stopped at a safe point, and `jab.sys.exit` stops every worker before the
sound plays out. A debug kernel reads two settings for the worker tests:
`jab.noack=<hart>` keeps that hart from taking its start, and
`jab.claimhold=<ms>` holds the first fault's shutdown for that long before
it stops the other harts. `test/workers` and `test/workerfault` prove each
rule.

`sdk/src/jab_jobs.inc` gives workers jobs. Each worker has a mailbox in the
program's memory, two cache lines: hart 0 writes a job into one, and the
worker writes its completion into the other. `jab.job.publish` writes a job
and its generation, `jab.job.await` is a worker's sleep until one comes,
`jab.job.complete` marks it done, and `jab.job.join` is hart 0's sleep until
it is. The macros carry the memory ordering the hardware needs, so a worker
never reads a job before it is whole, and hart 0 never reads a result
before it is written. A job can be cancelled between the bands of its work.
`test/jobs` races every order a job and its wake can come in, a thousand
rounds each, and `just bench test/jobs/costs` measures what a job costs
around its work, at four job sizes, with one worker and with three.

`example/workers` puts the jobs to work. Hart 0 deals the rows of the
Mandelbrot set in bands of eight to one, two, then three workers, five
seconds each, while the view zooms in by the clock. A bar at the left edge
shows which hart computed each row, and the frame's time is drawn as text.
With the API the program proves itself. The letter `p` draws one fixed
frame with each count of workers and hashes each image before its bars and
text, so the three hashes agree when the work is right, and it sends three
rows for the host to compute again. A digit, `1` to `3`, draws that frame
over and over for four seconds with that many workers. `just bench
example/workers/scaling` runs one, two, and three workers on a release
build and reports the frames, the hashes, each worker's rows, each hart's
CPU, and how much the bands overlapped in time.

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

`jab launch --qemu <words>` appends words of its own to the machine's
QEMU line, a device or a property a test needs that no option gives; the
run is then diagnostic, its machine record marked so and the words
returned apart as `overrides`. The gauge's `run` and `play` take the same
option, and a comparison refuses such runs unless `--diagnostic` admits
them, naming the words.

`JAB_QEMU_ARGS` appends its words to a run's QEMU line after
everything else, for QEMU's own instruments on a run that misbehaves,
such as `-trace alsa_* -D trace.log`; the value is split as a shell
would split it, quotes grouping a word with spaces and then removed,
and no shell ever reads it, so a `*` needs no quoting.

The machine has 4 GiB of RAM, and a program owns nearly all of it: the
kernel keeps the first 2 MiB and the framebuffer the 8 MiB after, and
the window from there to the end of RAM is the program's,
`sdk/src/jab.inc` naming its base, its size, and the stack top at its
end. A program's assets ship on a romfs disk the tool builds from the
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

