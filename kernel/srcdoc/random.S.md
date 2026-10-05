# random.S

Random bytes: QEMU's virtio-rng device, the entropy device, over the mmio
transport, id 4, on the line since the start and drawn from here. One queue:
the driver offers a buffer the device may write and the device fills it with
random bytes from the host's own source, saying how many it wrote, which is
the whole buffer from QEMU's default backend but need not be by the
specification. The device comes up on the first call and the program's own
buffer is what the device writes, so nothing is copied.

## sys_random

One descriptor the device writes, the program's buffer, is offered in the
next slot; the used element says how many bytes the device wrote.

## msg_rng_at

`13 u8`: the debug line naming the device's transport, under DEBUG only.

## msg_no_rng

`13 u8`: the debug line for a machine without one, under DEBUG only.

## random_queue

The device's virtqueue record.

## random_base

`addr`: the device's transport.

## random_state

`u64`: 0 until opened, then random_open's answer plus 1, and 3 once its
source stuck (aia.S).
