# error.rs

## enum PipeError

`Pipe` is the pipe itself refusing a read or a write, which `relay` reads as
the far end going away; `Io` a file or the runtime, named; `Connect` a pipe
that never took the client, `within` the bound when it was waited for and
none when the open refused outright.

### fn io

### fn exit_code

### fn fmt

### fn source

## type PipeResult
