# chardev

## ports

The ports, each of one virtio-serial-device: DEBUG in the build puts
the kernel's debug channel on port 1 with the host's end a file,
debug.log in `out`; `api` puts the API on port 2 with the host's end
QEMU's pipe chardev over the pipe pair api.in and api.out (chardev pipe-pair),
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
names a Windows run's pipes (chardev pipe-path). Each port's pipe comes back as
pipe-pair made it, null for a port the machine lacks.

## pipe-path

The path QEMU's pipe chardev takes for a pipe of `endpoint` beside a
run's other files in `out`, on the host `os` names as $nu.os-info.name
does (PipeShape): on every host but Windows `<out>/<endpoint>`, whose
`<endpoint>.in` and `<endpoint>.out` QEMU opens itself; on Windows a
bare name, `jab-<nonce>-<endpoint>`, the run's nonce in sixteen hex
digits (nonce hex), since QEMU makes one duplex named pipe of the option
there, `\\.\pipe\` and the option as given, a filesystem path being no
pipe's name, and the nonce keeps one run's pipes apart from another's. A
Windows pipe with no nonce, under 1, is refused.

## pipe-pair

A pipe of `endpoint` for QEMU's pipe chardev, made in `out` as the host
`os` names takes it (chardev pipe-path): `name`, the chardev's path, with
`inward`, `<endpoint>.in`, what the host writes into, and `outward`,
`<endpoint>.out`, a plain file made empty, where the guest's bytes land.
On every host but Windows QEMU opens the two itself, inward a named pipe
(fifo-at), which a launch's supervisor writes its actions into; on
Windows, where the pipe is one named pipe and its one client a relay of
the launch's supervisor or the pad bridge, inward is a plain file made
empty too, whose appended bytes the relay forwards into the pipe beside
the supervisor's own actions, as outward takes what the relay reads from
it. A previous run's files are retired first into `root`'s retire home
(retire).

## relays-of

The relays a Windows machine's pipes take (PipeShape), one for each of
`pipes`, its endpoint with its pipe as pipe-pair made it, null for a
port the machine lacks, which takes none: the pipe's name, its in-file,
and its out-file, which a launch's schedule carries to its supervisor.

## bridge-pipe

The pipe the pad bridge writes, from the pad port's pipe as pipe-pair
made it, "" for none: its in-file, a fifo QEMU holds open, on every host
but Windows, where the bridge is the pipe's client and takes its name.

## fifo-at

A named pipe at `path`: one already there is kept, since a pipe holds
nothing once every end has closed, and anything else there is retired
into `root`'s retire home (retire) before a fresh pipe is made.

## hmp-quoted

A word for the QEMU monitor's command line, which splits on spaces: in
double quotes, a backslash and a double quote inside escaped, so a
path with spaces in it stays one argument.
