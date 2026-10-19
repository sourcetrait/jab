# program

## transport_limit

virt's map has this many virtio-mmio transports, a hard ceiling on
the devices a line can carry.

## prepared

What a program's test or run needs, after building it with `names`
set: the kernel built with the same symbols in the same tree, so a
debug program runs on a debug kernel; standalone, with no workspace,
JAB_KERNEL is taken as it is.

## test-args

The arguments that run a program's test/test.nu on the kernel: the
kernel, the image, the output directory, the assets image when the
program has one, and the symbols the build was made with.

## run-line

The QEMU line that runs a program, built first: the QEMU it runs on
(qemu-binary, beside the program and then in the workspace) and its
arguments, the full virtio device set, the program's own disk when it
has one, its serial the manifest's `serial` else the program's name,
else the blank image that has always been there, the debug
channel to a file when DEBUG is set, the API's port when `api` asks,
the window given (null for the one a run would open), the UART where
`serial` says (`stdio` or `none`), and no monitor, on the machine
`spec` names, a custom one of `harts` harts, or the configured default
(machine resolve), a named spec the program does not list refused before
QEMU starts (spec-listed). The ports' files sit beside the build
output, named in the README. With a pad on the port, `bridge` is the
pad's identity and `bridge_pipe` the pipe the bridge writes
(bridge-pipe); on Windows the API's pipe takes a relay, `relays` and
`relay_binary` as plan names them, none and "" elsewhere.

- a Windows run's pipes are named pipes, named by a nonce of its own,
  the API's taking a relay and the pad port's client the bridge

## run-program

Run a program with the console window, the UART on stdio; QEMU's exit
code is the program's exit status. A run says nothing of its own.
With a pad on the port, the bridge runs beside QEMU, started first
so it is writing the header as the kernel comes up, and ended with
it; the bridge ends itself as well once its pipe has no reader. On
Windows the relays run-line names start ahead of QEMU too, which waits
for each pipe's client as it makes the pipe, and once QEMU has ended
each is given a second to end with its pipe, any left stopped, and one
that ended in failure said on stderr, naming its pipe.

## test-under

Test the programs at or under a path in the workspace, every program
for none, each on a build with DEBUG beside `names` and prepared to
test first; prints each test's output and a summary, exits 1 if any
fails. A test that drives the API asks `launch` for the port
itself.

## plan

The headless machine for a program prepared and printed as JSON, for a
harness in another language to run and drive: `nu/bin/nuance/plan.nu <dir>
--disk <romfs> --serial fps --api --gamepad --set debug`, the kernel and
the image the program's own builds, `out` under the program's build tree
unless given, `--spec`, `--harts`, and `--bootargs` plan's.

## test

Test with DEBUG set beside whatever --set names: at a workspace's root
every program's test, or those at or under a path, with a summary,
failing if any fails; at a program's directory its test/test.nu on the
debug kernel, the directory in place of `dir` when the first word is
its absolute path (workspace subject). `--spec` names the spec every
launch of the tests runs that names none of its own, JAB_SPEC for them
(spec configured).

## boot

Build, then run one program with its window and the UART on stdio: at
a workspace's root the program at a path, never a test (run-target),
at a program's directory that program, named by its absolute path as
the first word too (workspace subject). Release unless --set says
otherwise; the API's port on the machine with --api; the keyboard and
the tablet off with --no-kbm, the gamepad the host has off with
--no-pad, the sound device off with --no-sound; the machine the spec
--spec names, its cores, RAM, and display, or the configured default,
or a custom one of one to eight harts with --harts for a diagnostic run,
the two together refused.
QEMU's exit code is the program's status.
