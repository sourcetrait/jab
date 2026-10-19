# lib.rs

Preloaded into QEMU with LD_PRELOAD for `nu/bin/nuance/probe.nu sdl` and a probing
launch, it logs to the file `SDL_SHIM_LOG` names. The log opens with an
object table, then the run's lines, and then carries one line an event; the
SDK's `sdl resolve` and `sdl report` read it. Every line starts with
the time since the epoch in seconds and microseconds.

The real SDL functions are found in libSDL2 itself, opened by name: QEMU's
SDL front end can be a module loaded into a scope of its own, where
`RTLD_NEXT` from a preload finds nothing.

The four hooks are unsafe because they hand their callers' raw pointers
to libSDL2's own functions, so their contract is SDL's, stated by SDL; the
crate allows clippy's `missing_safety_doc` rather than restate it on each.

## struct LinkMap

Only the leading fields, `l_addr` to `l_prev`, are part of glibc's public
`<link.h>` layout; the loader's private fields follow them and are never
read.

## const FRAMES

Ten frames from the caller of `backtrace` up. The shim's own frames come
first, one or more as the compiler inlined this file's helpers, so up to
eight remain for QEMU's callers after the report drops them by object.

## fn object_line

A missing file's fields are each `-`, as for the vDSO, which has no file.
The modification time is whole nanoseconds, so the report's identity check
can hold a file to its line exactly with nushell's `ls -l`.

## fn object_of

`l_name` is the path the loader opened, which may run through a symlink;
the canonical path names the file itself. A name with no file behind it
keeps the name as written.

## fn map_of

`dladdr1` with `RTLD_DL_LINKMAP` hands back the object's link map, whose
`l_addr` is the load bias: the runtime address less the bias is the
link-time address that the object's symbol tables hold. `dli_fbase`, the
lowest mapped address, equals the bias only when an object's first segment
sits at 0, which is every PIE here and never a non-PIE executable.

## fn table

Index 0 is the executable as `/proc/self/exe` names it, the file the kernel
ran, never a name looked up again on PATH; a replaced or deleted binary
reads `(deleted)` there. Index 1 is this library, found by its own code,
which is how the report knows which leading frames are the shim's. The rest
are the loader's chain from the main program on, as loaded when the log
opens: QEMU creates its devices before its displays, so a modular build's
virtio-gpu module is already in the table.

## fn run

The log's first two events bind it to the run that made it. `process` is
the pid of the process the library lives in, QEMU's, the one the launch
reads from QEMU's pid file while QEMU lives, since QEMU unlinks that file
as it exits and a bundle is made after. `nonce` is `SDL_SHIM_NONCE` as
given, the launch's sixteen lowercase hex digits, and it is written only
where that is set. The value is not checked here: the SDK's reader holds
it to its form, so a malformed one reaches the log and is refused by name
there rather than dropped.

## fn frames

An address in no object is written whole, `?+<runtime>`, since no bias
applies. An object first met in a frame gets its table line before the
event that names it.

## fn record

The lock serialises QEMU's threads and keeps an event's object lines and
the event itself together in the log.
