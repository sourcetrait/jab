# pad.S

The pad: a gamepad the host passed through as QEMU's
virtio-input-host-device, a virtio-input device told from the keyboard and
the tablet by carrying BTN_SOUTH in its EV_KEY bits and ABS_X in its EV_ABS
bits; or, when the machine carries no such device, the pad's port on the
virtio-serial device (serial.S, doc/padport.md), where a host process writes
a header naming the pad and its axes' ranges and then the events, the same
eight-byte shape, as a byte stream the kernel reassembles. A device's event
queue is the wide one, PADQ_SIZE eight-byte events the device fills, since a
pad sends several events a report at over a hundred reports a second and
the kernel drains only when the program asks or waits. A drain keeps EV_KEY
events, setting or clearing the key's bit in the mask, and EV_ABS events,
storing the axis's raw value, and pushes both into a ring of PAD_RING events
for jab.sys.pad.input; EV_SYN and EV_MSC are dropped. Each axis's range
comes from the device's config space, or the port's header, when the pad
comes up, and its raw value starts at rest, the middle of its range or its
minimum for the one-sided ABS_GAS and ABS_BRAKE, so an axis that has not
moved reads 0 once normalised. jab.sys.pad.read normalises every axis into
the program's record at the call. A program never learns which way its pad
came.

## .set PAD_RING

`u64`: the events the pad's ring holds.

## .set PAD_ENTRY_SIZE

`u64`: bytes in a ring entry, the type at 0, the code at 2, the value at 4.

## .set PAD_KEYS_BITS

`u64`: the gamepad keys the mask holds from JAB_BTN_GAMEPAD.

## .set BTN_SOUTH_BYTE

`u64`: the byte of the EV_KEY bitmap holding BTN_SOUTH.

## .set BTN_SOUTH_BIT

`u64`: its bit there.

## .set ABS_BITMAP_BYTES

`u64`: bytes of the EV_ABS bitmap kept.

## .set PAD_PORT_MAGIC

`u32`: `JPAD` as the little-endian word a load sees.

The port's header, as doc/padport.md lays it out: the magic `JPAD`, a
version, the name, the buttons, the axes, and every axis's absinfo; then
eight-byte events. The stream buffer holds a header and a port buffer
besides, and the tail of a split event between reads.

## .set PAD_PORT_VERSION

`u32`: the header version the kernel takes.

## .set PAD_PORT_HEADER_MAGIC

`u32`: the port header's fields.

## .set PAD_PORT_HEADER_VERSION

`u32`.

## .set PAD_PORT_HEADER_NAME

`u8`: the name, JAB_PAD_NAME_BYTES.

## .set PAD_PORT_HEADER_KEYS

`u64`: the buttons.

## .set PAD_PORT_HEADER_AXES

`u64`: the axes the pad has, a bit per code.

## .set PAD_PORT_HEADER_ABSINFO

`i32`: every axis's absinfo, JAB_PAD_AXIS_ENTRY bytes each.

## .set PAD_PORT_HEADER_BYTES

`u64`: bytes in the header.

## .set PAD_PORT_EVENT_BYTES

`u64`: bytes in a port event.

## .set PAD_STREAM_BYTES

`u64`: the stream buffer, a header and a port buffer besides.

## .set PAD_SOURCE_DEVICE

`u64`: a pad on a virtio-input device.

## .set PAD_SOURCE_PORT

`u64`: a pad on the port.

## sys_pad_read

The keys are written a byte at a time, since the record sits where the
program put it.

## pad_open

Every descriptor of a device's queue is an event buffer the device may
write, all offered at once. With no device the port stands in, when it came
up with the serial device.

## msg_pad_at

`13 u8`: the debug line naming the pad's transport, under DEBUG only.

## msg_no_pad

`13 u8`: the debug line for a machine without one, under DEBUG only.

## pad_port_open

The name is ended at its last byte whatever the header holds, and its
length measured; each raw value is set to rest as a device's are.

## msg_pad_port

`18 u8`: the debug line for a pad on the port, under DEBUG only.

## msg_pad_port_refused

`23 u8`: the debug line for a header refused, under DEBUG only.

## pad_port_drain

A split event's head stays in the stream for the next read.

## pad_ranges

An axis the config space says nothing about keeps a zero range.

## pad_name_read

The device may end the name early.

## pad_accept

A key sets or clears its bit in the mask when it is one of the gamepad's,
an axis stores its raw value when its code is one the record indexes, and
either goes into the ring unless the ring is full; any other type is
dropped.

## pad_normalise

A centred axis: the flat band about the middle of the range reads 0, and
either side of it rescales to full scale at the range's end, so leaving the
band is continuous. ABS_GAS and ABS_BRAKE are one-sided: min plus flat reads
0 and max reads full. A hat, -1 to 1 with no flat, lands on the three
values.

## pad_queue

The pad's event queue record.

## pad_events

The device's event buffers, one per descriptor.

## pad_ring

The events for sys_pad_input, PAD_RING entries.

## pad_head

`u64`: the count of events put in the ring.

## pad_tail

`u64`: the count taken from it.

## pad_base

`addr`: the pad's transport.

## pad_state

`u64`: 0 until opened, then pad_open's answer plus 1.

## pad_keys

`u32`: the keys held, a bit each from JAB_BTN_GAMEPAD.

## pad_abs_bits

`u64`: the axes the pad has, a bit per code.

## pad_name_length

`u64`: the name's length.

## pad_name

`128 u8`: the name, NUL-terminated.

## pad_source

`u64`: where the pad came from, PAD_SOURCE_DEVICE or PAD_SOURCE_PORT.

## pad_stream_length

`u64`: the bytes the stream buffer holds.

## pad_stream

`2048 u8`: the port's bytes, reassembled.

## pad_raw

`64 i32`: each axis's raw value.

## pad_absinfo

Each axis's absinfo, JAB_PAD_AXIS_ENTRY bytes apiece.
