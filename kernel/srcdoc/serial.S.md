# serial.S

The ports: QEMU's virtio-serial-device over the same mmio transport as every
other Jab device, one port per channel. Port SERIAL_API_PORT is the API,
bytes both ways between the program and the host through jab.sys.api.write,
jab.sys.api.read, and the JAB_AWAIT_API bit; it is there on a run that put
it on the machine (`--api`) and absent otherwise, which the calls report
rather than fault on, so one build runs either way. Port SERIAL_PAD_PORT is
the pad's, the host's bytes alone, which pad.S drives. Under DEBUG port
SERIAL_DEBUG_PORT is the kernel's debug channel, where its own lines go
instead of the console UART; a fault line stays on the UART in every build,
since it has to work when a port has not come up, and the debug channel's
code and text exist only in a DEBUG build.

The device is driven with its multiport feature (virtio.inc): the kernel
stocks the control receive queue, tells the device it is ready, the device
names each port it carries, the kernel notes and answers for each one it
knows, opens those, and a port then carries bytes: one descriptor per
write, the hart halted until the device has taken it, as every other
request here. A port whose host side is a file or a pipe is open from the
start.

The API: the program's bytes to the host go straight from its buffer
through the port's transmit queue; the host's bytes to the program arrive in
the offered buffers and move into a ring, which jab.sys.api.read empties
and jab.sys.await watches. With no port on the machine the calls say so.

The pad's port carries bytes from the host alone, which pad.S reads out of
the offered buffers as a stream and parses itself (doc/padport.md).

## .set SERIAL_API_PORT

`u32`: the API's port.

## .set SERIAL_API_RX_QUEUE

`u32`: its receive queue.

## .set SERIAL_API_TX_QUEUE

`u32`: its transmit queue.

## .set API_BUFFER_BYTES

`u64`: bytes in a buffer offered for the API's receive queue.

What the host sends lands in these buffers, offered to the device in
advance, and moves into a ring the program reads from; what arrives beyond
the ring waits with the device.

## .set API_RING_BYTES

`u64`: bytes the API's ring holds, as much as the buffers do.

## .set SERIAL_CONTROL_BYTES

`u64`: a control message buffer, a port's name included.

## .set SERIAL_PAD_PORT

`u32`: the pad's port, jab.pad.

A host process writes a pad's header and its events into it, and pad.S
takes it as the pad when the machine carries no virtio-input pad. Its bytes
land in buffers offered in advance, and pad.S reads them out as a stream
through serial_pad_read.

## .set SERIAL_PAD_RX_QUEUE

`u32`: its receive queue.

## .set SERIAL_PAD_TX_QUEUE

`u32`: its transmit queue.

## .set PAD_PORT_BUFFER_BYTES

`u64`: bytes in a buffer offered for the pad's receive queue.

## .set SERIAL_DEBUG_PORT

`u32`: the debug channel's port, under DEBUG only.

## .set SERIAL_DEBUG_TX_QUEUE

`u32`: its transmit queue.

## .set DEBUG_LINE_BYTES

`u64`: the longest debug line gathered before it goes out.

A debug line gathers and goes out whole at its newline, so a line lands in
the log in one piece.

## serial_open

The control queues and the ports' queues are set up and the receive queues
stocked; the device is told the kernel is ready, names its ports, and each
known one is noted and answered for as it is named; then each port that
came is opened. Which ports came is a separate question, api_up's.

## serial_stock

The caller notifies once the device is driven.

## serial_control_drain

PORT_READY makes the device say more, taken in the same pass. What else the
device says, a port's name or that its host side is open, changes nothing
here, since the ports are fixed by number; a port the kernel does not know
is left unanswered.

## serial_pad_read

A buffer that does not fit stays with the device for the next read.

## debug_putc

The debug channel's output has the shape of the UART's: a byte, a string, a
value in hex, a value in decimal. A routine that writes to it clobbers a0 to
a3 in a DEBUG build, which the clobbers of every routine logging under
DEBUG include.

## debug_flush

The UART stands in when the machine carries no virtio-serial device or the
device came without the debug port, so a debug kernel on a bare line still
reports, each line under the line lock (uart.S).

## serial_control_rx_queue

The control receive queue's record.

## serial_control_tx_queue

The control transmit queue's record.

## serial_api_rx_queue

The API's receive queue record.

## serial_api_tx_queue

The API's transmit queue record.

## serial_pad_rx_queue

The pad's receive queue record.

## serial_pad_tx_queue

The pad's transmit queue record.

## serial_debug_tx_queue

The debug channel's transmit queue record, under DEBUG only.

## debug_line

`256 u8`: the debug line gathering.

## debug_length

`u64`: its bytes so far.

## serial_api_buffers

`2048 u8`: the API's receive buffers.

## serial_pad_buffers

`2048 u8`: the pad's receive buffers.

## api_ring

`2048 u8`: the bytes from the host the program has not read.

## api_head

`u64`: the count of bytes put in the ring.

## api_tail

`u64`: the count taken from it.

## serial_control_buffers

`512 u8`: the control receive buffers.

## serial_control_message

`8 u8`: a control message the kernel sends.

## serial_base

`addr`: the device's transport.

## serial_state

`u64`: 0 until opened, then serial_open's answer plus 1, and 3 once its
source stuck (aia.S), every port then down.

## serial_ports

`u64`: a bit per port the device named and the kernel answered for.
