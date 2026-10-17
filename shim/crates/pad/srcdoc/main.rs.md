# main.rs

The bridge for a host where QEMU cannot pass a gamepad through, macOS and
Windows: run beside QEMU by the SDK's tool as `jabshim_pad <pipe> <name>
[vendor] [product]`, the identity as jabdisco printed it, it opens the
gamepad discovery named, through gilrs, and writes the jab.pad port's header
and then every event into the port's pipe, in evdev's shapes as
doc/padport.md lays them out. It ends when the pipe has no reader left,
QEMU gone, or the pad disconnects.

gilrs's standard gamepad maps onto Linux's layout: the sticks as ABS_X,
ABS_Y, ABS_RX, ABS_RY at full scale, the triggers as the one-sided ABS_BRAKE
and ABS_GAS, the dpad as the hat, and the buttons as BTN_SOUTH on. gilrs
reports a stick's Y up-positive on every host, so it is turned to evdev's
down-positive here. gilrs's default filters are off, so the pad's own values
reach the kernel and its dead zone rides the wire as each stick's flat band.

## const MAGIC

## const VERSION

## const NAME_BYTES

## const AXES

## const FULL

## const EV_KEY

## const EV_ABS

## const BTN_GAMEPAD

## const ABS_X

## const ABS_Y

## const ABS_RX

## const ABS_RY

## const ABS_GAS

## const ABS_BRAKE

## const ABS_HAT0X

## const ABS_HAT0Y

## const BUTTONS

## const STICKS

## const WAITS_FOR_CLIENT

On Windows the port's pipe is a named pipe QEMU makes and waits in for its
one client before it starts, so the bridge is that client and connects
first, `<pipe>` the chardev's bare name, through jabpipe's `connect` with
the relay's tries and bound, before it looks for the pad: a pad it then
cannot find ends the bridge with the connection closed, and QEMU goes on
with no pad rather than waiting for a client that never comes. Elsewhere
the pipe is a fifo QEMU holds open itself, and the bridge opens it once it
has the pad.

## fn main

## const QUIET

## const LONGEST

## fn settle

On macOS gilrs lists pads from a thread of its own after it has started, so
a lookup made at once finds nothing. What is pumped here is the pad's state
before the run, which the kernel starts at rest anyway.

## fn find

## fn header

The name, each button gilrs maps, and each axis it maps with its range on
the wire: a stick at full scale with gilrs's dead zone as its flat band, the
triggers one-sided from 0, and the hat -1 to 1.

## fn translate

A button as its key, pressed or released, the dpad's buttons as the hat, a
stick's axis at full scale with Y turned down-positive, and the triggers as
the one-sided BRAKE and GAS.

## fn pressed

Up and left are -1, down and right 1, and 0 released.

## fn scale

## fn hat

## fn frame

## fn open_pipe
