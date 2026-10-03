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

## .set PAD_PORT_MAGIC

The port's header, as doc/padport.md lays it out: the magic `JPAD`, a
version, the name, the buttons, the axes, and every axis's absinfo; then
eight-byte events. The stream buffer holds a header and a port buffer
besides, and the tail of a split event between reads.

## sys_pad_read

The keys are written a byte at a time, since the record sits where the
program put it.

## pad_open

Every descriptor of a device's queue is an event buffer the device may
write, all offered at once. With no device the port stands in, when it came
up with the serial device.

## pad_port_open

The name is ended at its last byte whatever the header holds, and its
length measured; each raw value is set to rest as a device's are.

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
