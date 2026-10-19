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
and writes the run's identity beside the log, `identity.nuon`. Its
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

## trace-args

The QEMU words that trace the GPU device's flushes and set_scanouts into
`log`, each message stamped with the host's wall clock (-msg
timestamp=on), which sdl-bundle-check pairs with the shim's uploads;
refused on a QEMU whose trace events do not list both.

## probe-launch

A probe's QEMU run to its exit or its bound, `seconds`, polled as a
launch polls (launch): QEMU's pid kept from `pidfile` at the first poll
that finds it alive, since QEMU unlinks the file as it exits, and each
entry of `sends` written into `api_in` once its time has come, in
order, through fifo-write. The exit, QEMU's stderr, the pid, null where
QEMU never came up, and each entry's write in seconds from the start,
null where it never went in.

## main

Probe one program under a window for --seconds and print one NUON
record on how its flips reached the window, at a workspace's root the
program at a path, at a program's directory that program, named by its
absolute path as the first word too (workspace subject); release unless
--set says otherwise. `sdl` is the one probe; `--api`, `--send
<file>`, and `--trace` are probe-sdl's.
