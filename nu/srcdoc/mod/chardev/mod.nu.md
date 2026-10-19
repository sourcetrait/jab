# chardev

## ports

The ports, each of one virtio-serial-device: DEBUG in the build puts
the kernel's debug channel on port 1 with the host's end a file,
debug.log in `out`; `api` puts the API on port 2 with the host's end
QEMU's pipe chardev over the pipe pair api.in and api.out (pipe-pair),
api.in what the host writes into and api.out a plain file the
program's bytes land in as they are sent, both made here. A file
rather than a second pipe, so nothing has to hold a pipe open for the
run and a program is never held by a host that stopped reading.
`pad_port` puts the pad's port on port 3 the same way, over padport.in,
which the host writes the pad's header and events into
(doc/padport.md). Nothing at all with none, so the machine carries no
serial device. The console keeps the UART in every build, since a fault
line has to reach the host when a port has not come up. A previous
run's debug.log is retired into `root`'s retire home (retire). `nonce`
names a Windows run's pipes (pipe-path). Each port's pipe comes back as
pipe-pair made it, null for a port the machine lacks.

## pipe-path

The path QEMU's pipe chardev takes for a pipe of `endpoint` beside a
run's other files in `out`, on the host `os` names as $nu.os-info.name
does (PipeShape): on every host but Windows `<out>/<endpoint>`, whose
`<endpoint>.in` and `<endpoint>.out` QEMU opens itself; on Windows a
bare name, `jab-<nonce>-<endpoint>`, the run's nonce in sixteen hex
digits (nonce-hex), since QEMU makes one duplex named pipe of the option
there, `\\.\pipe\` and the option as given, a filesystem path being no
pipe's name, and the nonce keeps one run's pipes apart from another's. A
Windows pipe with no nonce, under 1, is refused.

## pipe-pair

A pipe of `endpoint` for QEMU's pipe chardev, made in `out` as the host
`os` names takes it (pipe-path): `name`, the chardev's path, with
`inward`, `<endpoint>.in`, what the host writes into, and `outward`,
`<endpoint>.out`, a plain file made empty, where the guest's bytes land.
On every host but Windows QEMU opens the two itself, inward a named pipe
(fifo-at); on Windows, where the pipe is one named pipe and a relay or
the pad bridge its client (relays-start), inward is a plain file made
empty too, which a writer appends to (pipe-write) and the relay forwards
into the pipe, as outward takes what the relay reads from it. A previous
run's files are retired first into `root`'s retire home (retire).

## relays-of

The relays a Windows machine's pipes take (PipeShape), one for each of
`pipes`, its endpoint with its pipe as pipe-pair made it, null for a
port the machine lacks, which takes none: the pipe's name, its in-file
and its out-file, and `done`, `<endpoint>.relay.nuon` in `out`, where
the relay's job saves how it ended (relays-start).

## relay-build

The relay's binary for a machine with relays (relays-of), built from
the workspace's shim/crates/pipe (shim-build), "" for one with none; a
machine with relays and no workspace to build it in is refused.

## bridge-pipe

The pipe the pad bridge writes, from the pad port's pipe as pipe-pair
made it, "" for none: its in-file, a fifo QEMU holds open, on every host
but Windows, where the bridge is the pipe's client and takes its name.

## relays-start

A Windows machine's relays started beside its QEMU, one job each
(PipeShape): `jabpipe <name> <inward> <outward>`, each connecting to its
pipe as soon as QEMU makes it and holding the run's one connection,
then forwarding what is appended to the in-file into the pipe and
writing what the pipe gives into the out-file, until QEMU closes it.
Each saves its exit and what it said to its `done` file as it ends,
through a file beside it moved over it, so a read never takes half of
one; a `done` file already there, an earlier start's, is retired first
into `root`'s retire home (retire), so the record read back is this
start's own. Each relay started with its job's id; none for a machine
with none.

## relays-stop

A machine's relays once its QEMU has ended (relays-start): each given a
second to end on its own, its pipe closed with QEMU, then any still
running stopped (job kill). How each ended: its endpoint, its pipe's
name, its exit, null for one stopped, and what it said.

## relays-held

A launch's relays held to how they ended (relays-stop): one that ended
on its own in failure, a pipe it never connected to or a pipe or a file
that failed it, fails the launch once QEMU has ended, naming its pipe
and what it said, beside QEMU's exit and its stderr; one stopped after
QEMU ended, its pipe never made, leaves QEMU's own record to say why.
Untyped because it ends in an error.

## fifo-at

A named pipe at `path`: one already there is kept, since a pipe holds
nothing once every end has closed, and anything else there is retired
into `root`'s retire home (retire) before a fresh pipe is made.

## monitor-send

Give the QEMU monitor a command through its pipe (pipe-write) under
`bound`, the run's timeout (timeout-binary); true when it went in.

## pipe-write

Bytes into one of QEMU's pipes as this host's pipes take them, `inward`
the pipe's in-file (pipe-pair): on Windows appended to the file, which
never waits and which the pipe's relay forwards (relays-start); on every
other host into the named pipe itself under `bound` (fifo-write). True
when they went in.

## fifo-write

Bytes into one of QEMU's named pipes without waiting on a reader that is
gone: opening a pipe to write waits until some process reads it, and
QEMU can end between any check that it runs and the open, so `tee`
appends the bytes under a one-second bound, `bound` the run's timeout
(timeout-binary). True when they went in; false when no reader came
within the second.

## hmp-quoted

A word for the QEMU monitor's command line, which splits on spaces: in
double quotes, a backslash and a double quote inside escaped, so a
path with spaces in it stays one argument.

## screen-whole

Whether a screen QEMU writes comes whole: its file the PPM header
naming the display's size (display_size) and every pixel's three bytes
after it, looked at every 50 ms for at most five seconds.
