# connect.rs

QEMU 11.1.2 on Windows makes each pipe chardev one duplex named pipe,
`\\.\pipe\` followed by the chardev's `path` option as given, of one
instance, and waits inside the chardev's creation for its client
(`chardev/char-pipe.c`, the `_WIN32` branch: `CreateNamedPipe`, then
`ConnectNamedPipe` and `GetOverlappedResult` waiting, within
`pipe_chr_open`). It connects once, so the client that connects first holds
the only connection the run has, and its close ends that connection for
good.

## const CONNECT_RETRY

## const CONNECT_BOUND

## const ERROR_PIPE_BUSY

The pipe is there and its one instance held by another client. QEMU never
connects a second time, so a client finding a pipe busy waits out the bound
and fails.

## fn pipe_path

## fn waiting

NotFound is a pipe QEMU has not made yet, ERROR_PIPE_BUSY one held. Any
other failure, a refusal of access among them, ends the tries at once.

## fn connect

The relay opens with tokio's `ClientOptions`, for overlapped I/O, and the
pad bridge, which only writes, with std's synchronous open; both connect
with the same tries and bound.

## fn connect_within
