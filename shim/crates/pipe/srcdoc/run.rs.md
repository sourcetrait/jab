# run.rs

The SDK's tool runs the relay as a job beside QEMU on Windows, one a pipe
chardev QEMU serves with no client of its own (`relays-start` in
`sdk/nu/jab.nu`): `<name>` is the chardev's `path` option, a bare name,
`<in-file>` the file the launch appends what it sends to, and `<out-file>`
the file the pipe's bytes land in. Exit 0 is the pipe closed by QEMU, 1 a
connection never made or a pipe or file failing, 2 an invocation or a host
the relay cannot run with.

## fn run

## fn relayed

## fn duplex

On Windows, one current-thread runtime: the client is opened inside its
context, since tokio registers a named pipe with the reactor of the runtime
current where it is opened, and connected as `connect` connects, so the
relay may start before QEMU has made the pipe, which QEMU does as it creates
the chardev, each in the order its line names them. Elsewhere the relay
refuses: QEMU's POSIX pipe chardev opens a pair of fifos itself and takes no
client.
