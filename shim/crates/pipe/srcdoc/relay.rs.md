# relay.rs

One task, the two directions as two futures under one select. The pipe's
read stays pending while a write into it is too, which on Windows needs the
client opened for overlapped I/O, as tokio's named pipe client is: a handle
opened for synchronous I/O serializes every operation on it, so a blocked
read would hold each write behind it, and with QEMU's own writes waiting on
the relay's reads the two could wait on each other for good.

## const POLL

## const GRACE

## fn drain

A broken pipe reads as the end, as mio already reads ERROR_BROKEN_PIPE on a
named pipe's read, as zero bytes.

## fn forward

The in-file is a plain file read on from where the last read ended, so a
read at its end gives nothing until a writer appends, and every byte goes
into the pipe once, in the order appended, those already there when the
relay starts first. It returns only how it ended: the pipe refusing a
write, `Pipe`, or the in-file failing a read, `Io`.

## fn relay

The pipe's end ends the relay. The select is biased toward the drain, so a
close seen beside a refused write ends it clean. A refused write alone is
the far end going, so the drain gets `grace` to see the close and land what
came before it; a pipe still refusing writes and open past that is a
failure.

## fn relay_duplex
