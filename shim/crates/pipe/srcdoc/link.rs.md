# link.rs

A supervised launch's required relays, run in-process: each the one
client of a pipe QEMU serves with no client of its own, holding its
connection for the run, draining what the pipe gives into its out-file,
forwarding what is appended to its in-file, and carrying the launch's
payloads written to that pipe. On Windows the pipe is QEMU's named pipe;
off Windows a relay's name is a Unix socket's path, the transport the
tests' stand-ins serve, the SDK's schedules carrying relays on Windows
alone. A relay's task runs on the supervisor's current-thread runtime,
driven while the supervisor's loop waits.

## enum Ending

## struct Seen

A relay's connection and its end are its receipts, each the moment its
task saw it: an exit status is no proof that a relay connected or carried
its protocol.

## type Finished

## struct Carry

A payload handed to a relay's writer, its bytes, the count its pipe
accepted after each write, and its end with the time it came.

### fn new

### fn accepted

### fn result

### fn write

An explicit loop of writes from the bytes already accepted, the count
stored after each, so the account holds however far it came.

### fn finish

The first end stands: a payload finished whole is never marked failed by
the pipe's later end.

## struct InHand

A carry in the writer's hands, finished as failed if the relay ends
before its write does, since the writer's future is dropped with the
relay.

### fn drop

## struct Link

### fn start

### fn carry

### fn seen

### fn stop

## fn serve

The connection tried until the deadline, the supervisor's startup
allowance from its start, while the pipe is not there yet or its one
instance is held (`pipe_waiting`); any other refusal fails the relay at
once. Then both directions until the pipe ends.

## fn relay_carrying

`relay`'s shape (relay.rs) with the queue beside the in-file: one task,
the drain biased, a refused write giving the drain its grace to see the
close.

## fn write_side

The in-file's appended bytes and each queued payload, one at a time and
whole, so nothing interleaves inside a payload.
