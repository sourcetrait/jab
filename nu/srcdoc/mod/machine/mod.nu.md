# machine

## custom_ram_gib

A custom machine's RAM, the 4 GiB every machine had before named specs;
a named spec's is its own.

## cpu_profile

RVA23 is the profile Jab pins, so everything it mandates is on whether
or not Jab itself uses it; the supervisor profile is the one carrying
an MMU mode and the supervisor timer the frame clock needs. RVA23 says
nothing about machine mode, so QEMU's model of it has no physical
memory protection at all, and the kernel enters in machine mode and
opens PMP before it has a trap vector: without `pmp=true` that write
is an illegal instruction which traps to address zero and spins there
forever. It is the one CPU a machine runs: QEMU carries it from 9.2,
and a QEMU without it is refused rather than run on another model.

## accel

Multithreaded TCG, a host thread a hart, stated on every line: QEMU
11.1.2 already takes it for riscv64 when no instruction counting is
asked, and the line says so whatever the host's QEMU would choose.

## machine_name

The interrupt platform: the APLIC in MSI mode feeding each hart's IMSIC
interrupt files, with the ACLINT's timer, which only TCG offers.

## machine_rest

No parallel port: QEMU's default is a text console of its own, which
under SDL is a second, hidden window with its own GL context, drawn
on every refresh its cursor blinks.

## rng_device

The entropy device, on a run and on a launch alike, since the
kernel's jab.sys.random draws from it

## qemu-binary

The QEMU a machine runs on: an extern when there is one, else PATH.
`extern/qemu` is a QEMU install, the binary under its `bin/` or at its
top, where the Windows installer puts it, looked for as the
toolchain's `extern/riscv` is, beside `here` (the program) and then in
the workspace; one that holds no binary is an error rather than a
quiet fall to PATH, since a run on another QEMU is what the link is
there to prevent. With no extern, the name, for PATH.

## cpu-model

The CPU every machine runs, the RVA23 profile, once the QEMU it runs on
lists the model; a QEMU that does not is refused with its version.

## of

What a launch's machine is, the record a run keeps of it. A named
spec's, given its row (spec-row): its cores the harts and its RAM, with
`spec` its name in lowercase, its cores, its RAM in GiB, and its
display, `diagnostic` null. A custom machine of `harts` harts, 1 to 8
(harts_allowed), and custom_ram_gib: `diagnostic` its harts and RAM and
`spec` null, whatever its count. Never both, and one of them always.
Beside either the harts and the RAM it has, the -machine options, the
CPU model, the accelerator with its thread mode, and `overrides`, QEMU
words of a launch's own on its line.

## resolve

The machine a launch asks for (machine-of): `--harts`, given past 0, a
custom machine; else the spec `--spec` names, or the configured default
(spec-default), its row from `ws`'s spec data (spec-row). Both given are
refused, naming both, before QEMU starts.

## spec-bootargs

A launch's command line for the kernel: `bootargs`, then a named spec's
`jab.spec=<name>`; a custom machine's `bootargs` alone.

## knob-of

A debug kernel's knob as it reads one from its command line
(knob_value): the first word of `line` that starts `<name>=`, its value
when the rest is digits alone; null with no such word, or with anything
else after its `=`.

## machine-args

The machine on `qemu` as `m` (machine-of) provisions it: virt with
`options` after it when given, the RVA23 CPU, multithreaded TCG, its
harts, every transport modern.

## memory-args

The RAM `m` has (machine-of), in GiB.

## name-args

The guest is named for the program, `jab <program>`, which is what
QEMU's window shows inside its own prefix, hardcoded in every front
end (SDL adds the console's index too: `QEMU (jab pad-0)`), and the
threads are named (CPU 0/TCG and the rest), so a per-thread listing
reads; on Linux the process is named jab, so `pgrep -x jab` finds it.
`-name` alone names only the guest, and `process=` is a Linux prctl
that QEMU refuses to start without elsewhere ("Change of process name
not supported by your OS"), so the process name is Linux's alone.

## dump-tree

The device tree QEMU builds for a launch's machine, the one `--spec`
names, a custom one of `--harts` harts, or the configured default
(machine-for), written to the file `out` through -machine dumpdtb, QEMU
exiting once it is written and before any hart runs, `bootargs` in
/chosen as a launch's -append puts it, a named spec's
`jab.spec=<name>` after it; the kernel and the image place the line as plan
places it, and a previous file there is retired. The file's path.

## display

The window for a run: JAB_DISPLAY, else the manifest's display, else
the best QEMU window the host has: SDL with OpenGL on Linux and
Windows, cocoa on macOS (its only window, and it has no OpenGL). A
Linux machine with no display server is nobody's console; there the
display goes out over VNC for development.

## extra-args

Whatever JAB_QEMU_ARGS holds, split into words as a shell would read
them and nothing more, appended to a run's QEMU line after everything
else: for looking at a run with QEMU's own instruments, `-trace
alsa_* -trace virtio_snd_* -D trace.log` on a host where a stream
misbehaves. No shell reads the value, so a quote is removed here and
a `*` is passed as it is; quotes keep a word with spaces together, as
`-D "my trace.log"`. Nothing without it.

## shell-words

The words of a line as a POSIX shell splits them, nothing expanded
and nothing run: spaces separate words; a run inside single or double
quotes is part of one word with the quotes removed; a backslash keeps
the character after it, outside single quotes. An unclosed quote is
an error.

## transports

The virtio transports a QEMU line uses: every `-device` of a
virtio-*-device, which is how a device rides virt's mmio transports;
a port on the serial device's own bus, and the loader, ride none.
