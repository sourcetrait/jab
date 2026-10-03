# Jab
[![License Badge]][License]

An assembly ecosystem on QEMU: an assembly kernel that is itself the API,
running RISC-V programs a hobbyist drops in. Everything is virtio, and it
runs only under QEMU's `virt` machine.

- `workspace.jab.toml` the workspace: the kernel and the programs.
- `kernel/` the kernel: `kernel.jab.toml`, a `justfile`, sources under
  `src/`, and each source's `.eye` and `.md` under `srcdoc/`.
- `sdk/` what a program uses, its sources under `src/` and their `.eye`
  and `.md` under `srcdoc/`: `jab.inc`, whose `jab.sys.*` macros are
  the kernel's calls, each a trap into it; `jab_f32.inc`,
  `jab_f64.inc`, and `jab_rng.inc`, mathematics and chance as macros
  the program carries and expands in place, never a call and never a
  trap; the program link script; and `nu/jab.nu` for its test.
- `doc/syscalls.nuon` the system call table of record; `doc/lists.md`
  how every call that fills a buffer with records works.
- `example/<name>/`, `test/<name>/` programs by category, each with
  `program.jab.toml`, a `justfile`, `src/main.S` and its `srcdoc/`, and
  its integration test at `test/test.nu`.
- `shim/` the preload shims, a cargo workspace, a crate each under
  `crates/`: `sdl` for the probe and `evdev` for the pad tests.
- `tool/` the host tools, a cargo workspace, a crate each under
  `crates/`: `disco`, the library `jabdisco` and its binary
  `jabdisco`, which find the gamepad a run attaches and the audio
  output it plays through; `robojab`, the harness that runs a prepared
  machine and lets an agent play it a move at a time.
- `.target/release/` and `.target/debug/` build output, ignored;
  `extern/` local links, ignored.

Build and run with `just` and nushell: `just build`, `just test` (or
`just test example`, `just test example helloworld`), `just run example
helloworld` from here, or `just build` and `just test` inside the kernel
or a program. `just run` opens QEMU's own window when a display server
is present, SDL with OpenGL on Linux and Windows and Cocoa on macOS,
and otherwise serves the console over VNC on 127.0.0.1:5930, to tunnel
and view; `JAB_DISPLAY` overrides with any `-display` value.
The toolchain is found by its install directory, the one holding
`bin/`: `RISCV_TOOLCHAIN`, else an `extern/riscv` link beside the kernel
or program, else `extern/riscv` beside this file, else the tools on
`PATH`. A program the workspace does not list, `game/fps` the first,
builds against it: its kernel is built here with the same symbols, and
the generic disk, the toolchain link, the shims, and discovery are this
workspace's, while its own output lands in a `.target/` beside it; one
outside the tree names the workspace in its manifest, `workspace =
'../../../..'` relative to the manifest.

A build is described by its symbols: `just build --set debug,stats`
names them, in any case, and each reaches the assembler as a defined
symbol, `DEBUG` and `STATS`, for `.ifdef` to read in the kernel and in
your program alike. A build with `DEBUG` lands in `.target/debug` and
any other in `.target/release`, so the two coexist. `just test` always
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
second to `.target/watch.nuonl` until the run ends, printing each
second's rates as it goes: on Linux the harts as `CPU 0/TCG` and on
and the main loop under the process name, which is where the host's
copy and paint of each flip lands; on macOS, whose threads carry no
names, the first row is the thread that draws the window and the rest
are numbered. `just watched` then prints one NUON record on the
recording, the run as it was (host, QEMU, window, the symbols the
kernel was built with) and per thread the steady CPU seconds a second
after the first five, which `--skip` changes, ready to paste. On
macOS a thread is its row, and QEMU's worker threads come and go, so
a row that changed identity during the recording is reported with
`stable: false` and no peak.

`just probe sdl example walk` looks at the window itself: it runs the
program under SDL with OpenGL for twelve seconds (`--seconds N`) with a
small library preloaded into QEMU, `shim/crates/sdl`, built with cargo
into `.target/shim`, which logs every SDL call the window makes with a
timestamp and its callers; then it prints one NUON record on how the
program's flips reached the window, ready to paste: the uploads per
flip and their spacing, the flip cadence, the drawn frames and their
interval, and any frame drawn inside a flip, which is a half-drawn
tick. Linux only, since it preloads into QEMU; with no display server
SDL runs its offscreen driver, drawing nothing along the same path.

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

The CPU is RVA23, `-cpu rva23s64`, which QEMU carries from 9.2; on an
older QEMU the tool runs the generic `rv64`, which has what the kernel
needs, and `JAB_CPU` overrides either with any `-cpu` value.
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
`/doc/license/fluid-soundfont`, fetched into `.target/fetch` on first
use, verified by sha256, and never committed.
Both asset disks are attached read-only, so a program's write to one
comes back as the device's error and the image the next run reads is
the one the tool built; the blank data disk a run carries when a
program ships no assets stays writable. A PNG among a program's assets, as GIMP 3
exports one, decodes in the kernel into a sprite with `jab.sys.sprite.png`
and draws with `jab.sys.sprite.draw`, which `example/logo` shows.

Repository
--------------------------------------------------------------------------------

Found a bug?  
Let us know! Upvote an existing issue or create one if not found.

Have questions, concerns, ideas, or requests?  
Upvote an existing discussion or create one if not found.

### Contributors
Contributors, please review [SOURCETRAIT.md](https://github.com/sourcetrait/sourcetrait_common/blob/dev/SOURCETRAIT.md).  

#### Copyright Assignment Agreement (CAA)
By committing to this repository you
[agree to assign](https://github.com/sourcetrait/sourcetrait_common/blob/dev/docs/legal/Copyright_Assignment_Agreement.md)
to [Asmov LLC](https://asmov.software)
all right, title, and interest worldwide in all copyright covering your
contribution.


License (AGPL3)
--------------------------------------------------------------------------------
Jab  
Developed by [SourceTrait](https://sourcetrait.com), a division of **Asmov LLC**  
Copyright (C) 2026 [Asmov LLC](https://asmov.software)  

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a [copy](./LICENSE-AGPL-3.txt) of the
GNU Affero General Public License along with this program.
If not, see https://www.gnu.org/licenses/.


[License]: #License-AGPL3
[License Badge]: https://img.shields.io/badge/license-AGPL3-blue.svg
