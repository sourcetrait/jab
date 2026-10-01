# The pad port

A gamepad reaches a Jab program one of two ways. On Linux QEMU passes
the host's device through as `virtio-input-host-device`, and the
kernel drives it as a virtio-input device. Everywhere else QEMU has no
way to carry a gamepad, so the pad comes in over a port on the
machine's virtio-serial device, `nr=3`, named `jab.pad`, written by a
process on the host: the SDK's `jabshim_pad`, which reads the pad
through gilrs, or `jab launch --pad <file>`, which plays a table. The
kernel takes the port as the pad when the machine carries no
virtio-input pad, and a program sees no difference: `jab.sys.pad.read`,
`jab.sys.pad.input`, `jab.sys.pad.axis`, `jab.sys.pad.name`, and the pad await
answer as they do for a device.

This is the port's contract. Everything is little-endian, and the
shapes are evdev's, which the kernel already speaks.

## The header

The first 1432 bytes written into the port, once, before any event.
The kernel waits for the whole header before it answers a program's
first pad call, so a port with nothing writing into it holds the
program at that call.

| offset | size | field |
|--------|------|-------|
| 0 | 4 | magic, the bytes `JPAD` |
| 4 | 4 | version, 1 |
| 8 | 128 | the pad's name, NUL-padded; the kernel ends it at 127 |
| 136 | 4 | the buttons the pad has: bit n set for evdev code 304 plus n |
| 140 | 4 | reserved, 0 |
| 144 | 8 | the axes the pad has: bit n set for evdev ABS code n, n below 64 |
| 152 | 1280 | 64 absinfo records of 20 bytes, one per ABS code, present or zero |

An absinfo record is five signed 32-bit fields in evdev's order: min,
max, fuzz, flat, resolution. The kernel normalises an axis from its
min, max, and flat exactly as it does for a device: a centred axis
reads 0 inside the flat band about the middle of its range and full
scale at either end; `ABS_GAS` and `ABS_BRAKE` are one-sided, min plus
flat reading 0 and max reading full; a hat runs -1 to 1. Every axis
starts at rest, the middle of its range, or its minimum for the
one-sided pair.

The button mask is for a reader on the host side and for later; the
kernel takes every key event it is sent whether or not the mask names
the button.

## The events

After the header, a stream of eight-byte events, each `type` as 16
bits, `code` as 16 bits, and `value` as 32 bits, the shape the kernel
keeps in its own ring:

- `EV_KEY` (1), a gamepad code from 304 (`BTN_SOUTH`) to 335, value 1
  pressed and 0 released. The kernel sets or clears the button's bit
  and queues the event for `jab.sys.pad.input`.
- `EV_ABS` (3), an ABS code below 64 and the raw value inside the
  axis's declared range. The kernel stores it and queues the event.
- Any other type is dropped. No `EV_SYN` is needed and none is sent by
  the SDK's writers; a report is simply its events in order.

No timestamps. The port is a byte stream chunked however the host's
pipe delivers it, so an event may arrive split across two reads; the
kernel reassembles. The device holds what the kernel has not yet read,
which holds the writer once the pipe fills, so nothing is lost.

## The layout jabshim_pad writes

The bridge maps gilrs's standard gamepad onto evdev's names, so a
program sees the same codes on every host that a passed-through pad
commonly reports on Linux:

| gilrs | evdev |
|-------|-------|
| left stick | `ABS_X`, `ABS_Y`, -32767 to 32767, down positive |
| right stick | `ABS_RX`, `ABS_RY`, the same |
| left and right triggers | `ABS_BRAKE`, `ABS_GAS`, 0 to 32767 |
| dpad | `ABS_HAT0X`, `ABS_HAT0Y`, -1 to 1, up and left negative |
| South, East, North, West | `BTN_SOUTH`, `BTN_EAST`, `BTN_NORTH`, `BTN_WEST` |
| C, Z | `BTN_C`, `BTN_Z` |
| left and right trigger buttons | `BTN_TL`, `BTN_TR` |
| the triggers pressed past their threshold | `BTN_TL2`, `BTN_TR2` |
| Select, Start, Mode | `BTN_SELECT`, `BTN_START`, `BTN_MODE` |
| the sticks pressed in | `BTN_THUMBL`, `BTN_THUMBR` |

A stick's flat band is the pad's dead zone as gilrs reports it, scaled
to the range. The triggers are `ABS_GAS` and `ABS_BRAKE` rather than
`ABS_Z` and `ABS_RZ` because those are the codes the kernel treats as
one-sided, so a released trigger reads 0 to a program.

## On the host

`jab run` on macOS runs `jabdisco`, and with a gamepad in its record
puts the port on the line, `-chardev pipe,id=jabpad,path=<out>/padport`
and `-device virtserialport,chardev=jabpad,nr=3,name=jab.pad`, and
starts `jabshim_pad <out>/padport.in <name> <vendor> <product>` beside
QEMU, ended with it. On Linux the pad is passed through and the port
is never used for a run. `jab launch --pad <file>` plays the file's
table into the port on any host but Linux, and on Linux under
`--pad-port`, with a header describing the reference pad the evdev
shim answers as, so a test reads the same lines either way.
