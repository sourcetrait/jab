# probe

## probe-kind

Probe a program under a window. `sdl`: run it under SDL with OpenGL
for `seconds` with shim/crates/sdl preloaded into QEMU, then report how
its flips reached the window, read through QEMU's own symbol tables;
`api`, `send`, and `trace` are probe-sdl's.

## probe-sdl

The SDL probe: the shim built with cargo into the target's shim/, the
program run under `sdl,gl=on` with the UART off for `seconds`, the
shim's log read back through binutils' nm (sdl report), and one NUON
record printed, or the refusal saying why the log cannot be read and
no record. Linux only, since it preloads a library into QEMU. With no
display server SDL runs its offscreen driver, which draws nothing but
keeps every path the same. Each run mints its capture nonce for the
shim (nonce mint), keeps QEMU's pid while it lives (probe-launch),
and writes the run's identity beside the log, `identity.nuon`: the
capture's binding and the build's fields (build-fields), the latter
taken before QEMU starts, so a REPLAY build probed without a stream is
refused before it runs. Its
profile, its port, and its sends are probe-plan's: paired where the
build sets the manifest's `paired`, the nonce's frame sent first;
`--api` puts the port on with nothing sent for it; `--send <file>`
writes the file's bytes. With the port on, the program's bytes are kept
beside the log as `api.out`.
`--trace` has QEMU trace the device's flushes and set_scanouts into
`trace.log` there, its messages stamped (probe trace-args). The run is
bundled last (sdl bundle) into `bundle` there, a previous bundle and
every file the probe writes retired first.

## plan

What a probe of a program's build puts on the machine and sends
(CaptureBundle's profiles): paired where the build sets the manifest's
`paired` (probe-paired), the port on and the nonce's frame (wnon-frame)
at 200 ms, then `send`'s bytes at 200 ms where there are any; generic
otherwise, the port on with `api` or bytes to send, and only those
bytes sent, never a frame of the probe's own.

## probe-paired

Whether a probe of a program's build is paired (CaptureBundle): the
manifest's `paired` names the build symbol under which the program
reads the capture nonce's frame from the API before it starts, and the
build sets it. Any other probe is generic.

## wnon-frame

The capture nonce's frame, what a paired program reads from the API
before it starts (CaptureBundle): `WNON` as a le32, a zero word, and
the nonce as a le64, 16 bytes; the nonce 1 to 2^63 - 1.

## cadence_symbols

walk's CADENCE build's symbols, in the order its header's flags name
them; an identity's `cadence` is the ones its build sets.

## build-fields

A run's build as its identity names it, the one producer of the
probe's identity and walk's unprobed wrapper
(`example/walk/test/cadence.nu`), so a reader holds either run's stream
to the build its identity names: `workload`, the program's path in the
workspace and
its loop order as the build declares it, `prepare` where it sets
PREPARE, `await` for a CADENCE build without it, and `undeclared` for any
other, whose flags name no loop; `image` and `kernel`, each file's path and SHA-256; `flags`,
the first line of the `flags` file the build left beside the image,
whose absence is refused; `cadence`, the CADENCE symbols among the
flags' `--defsym`s; and `replay`, a REPLAY build's stream as
replay-stream reads it less its bytes, null for any other build. A
REPLAY build given no stream, and a stream given for any other build,
are refused by name.

## file-of

A file as an identity names it, its path and its SHA-256.

## replay-stream

A replay stream as a run sends it, held to the header walk reads: at
least the 64-byte header, the magic WRPL, frames 1 to replay_frames
(8,192, walk's frame buffer), and exactly a u32 dt a frame after the
header; each fault refused by name. Its file, its SHA-256, its frames,
the window its dt values sum to in seconds, the run's bound, twice that
window plus 60 s rounded up, and the bytes the run sends.

## trace-args

The QEMU words that trace the GPU device's flushes and set_scanouts into
`log`, each message stamped with the host's wall clock (-msg
timestamp=on), which sdl-bundle-check pairs with the shim's uploads;
refused on a QEMU whose trace events do not list both.

## probe-launch

A probe's QEMU run to its exit or its bound, `seconds`, under the
launch's supervisor (supervise bounded): the schedule's command QEMU
under `timeout` with `--kill-after`, its environment the shim's, its one
pipe the API's, and each entry of `sends` an action at its time, in
order. The exit, the status or 128 and the signal; QEMU's stderr; QEMU's
pid as the supervisor read it from `pidfile` while QEMU lived, null
where it never came up; and each entry's write in seconds from the go,
null where it never went in. A run that left no receipt, a startup that
did not go, and a failure the receipt names are refused.

## main

Probe one program under a window for --seconds and print one NUON
record on how its flips reached the window, at a workspace's root the
program at a path, at a program's directory that program, named by its
absolute path as the first word too (workspace subject); release unless
--set says otherwise. `sdl` is the one probe; `--api`, `--send
<file>`, and `--trace` are probe-sdl's.
