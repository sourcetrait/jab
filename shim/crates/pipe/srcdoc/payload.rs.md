# payload.rs

A timed action's bytes on their way into one of QEMU's pipes, their
progress kept across attempts, since a failed or interrupted write is no
proof that no byte reached QEMU. Every attempt writes only what remains,
on the one open of its pipe it began with, and never blocks: an attempt
that cannot go on now returns, and the supervisor tries again at its
retry while QEMU lives. A payload starts over only while none of it is
accepted; once some is, a pipe that breaks is never reopened and the
payload never replayed.

## enum Route

Off Windows a fifo QEMU holds open; on Windows the connection a relay
holds (link.rs), the pipe's end in the schedule its relay's endpoint.

## enum Step

## struct Payload

### fn new

### fn attempt

The first attempt's time and the completion's are sampled with the
operation, nanoseconds from the go; a relay's completion carries the time
its writer finished.

### fn account

## fn ns_since

## fn fifo_attempt

The fifo opened for writing without blocking, so an open that no reader
takes yet fails at once with nothing written (ENXIO) and waits for the
next attempt; QEMU opens its pipe chardev's fifos read and write, so it
is a reader for as long as it runs. A write the pipe cannot take now
(EAGAIN) waits; a failure with nothing accepted closes the fifo to start
over; a failure once bytes are in is the pipe broken. The fifo is closed
once the payload is whole.
