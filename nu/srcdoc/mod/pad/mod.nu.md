# pad

## pad-attach

The gamepad a machine carries: nothing at all unless asked. Asked, on
Linux unless `port` says otherwise, the fifo `pad` in `out`, made fresh,
which QEMU's host-input device opens as the pad with the evdev shim
preloaded to answer its ioctls as the reference pad, the QEMU arguments
and environment for that; on every other host, and on Linux with
`port`, the pad port instead, the same reference pad described by the
header the driver writes first. The shim is one of the workspace's,
`ws`, the kernel's or the one above `out`; anything at the fifo's path
is retired into `root`'s retire home (fifo-at).

## pad-table

A launch's pad table as the groups it plays: the rows grouped by their
time, each group one report the launch loop writes at that time; none
without a table, and none for a table with no rows, which still puts
the pad on the machine with nothing played into it.

## pad-report

One report of pad events, as the device would send them: each row an
input_event, then a SYN_REPORT closing the report.

## pad-frames

The same events as the pad port takes them: eight bytes each, type,
code, value, little-endian, no SYN (doc/padport.md).

## pad-port-header

The pad port's header for the reference pad, the one the evdev shim
answers as, so a table plays the same either way (doc/padport.md):
the magic, the version, the name, the buttons BTN_GAMEPAD to
BTN_GAMEPAD plus 15, the axes X, Y, Z, RZ, GAS, BRAKE, HAT0X, HAT0Y
with the shim's absinfo, and zero for every other axis.

## input-event

One input_event as an evdev device writes it, 24 bytes: the wall
clock's seconds and microseconds as two 64-bit fields, then the type
and the code as 16 bits each and the value as 32, all little-endian.

## gamepad-plan

The gamepad on the line, when there is one, from jabdisco's record.
On Linux the pad is passed through: JAB_PAD names its evdev path
outright, else the expected pad's path from the record, and nothing
goes on the line with none. On macOS and Windows QEMU cannot pass a pad
through, so with a pad in the record the pad port goes on the line and
the bridge, jabshim_pad, is to be started beside QEMU with the pad's
identity, which is what `bridge` carries (doc/padport.md), on Windows
as the pad pipe's own client (PadWindows); Linux never takes that
route. Any other host gets no pad.

## kbm-choice

The keyboard and the tablet on the line: on unless --no-kbm, and
never both flags of the pair.

## pad-choice

The gamepad on the line: on unless --no-pad, and never both flags.
