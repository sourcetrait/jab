# virtio.S

virtio over mmio, the transport of every Jab device: finding a device by id
among QEMU virt's transports, bringing it up, giving it a split virtqueue,
running one request through a queue at a time, and waiting for the device
with the hart halted rather than spinning. A transport's interrupt source
and its enabling are aia.S's. Every routine takes the transport's base in
a0 and clobbers t registers, plus a0 for what it returns, unless it says
otherwise.

The ordering every driver keeps with its device: a doorbell is a store to
a device register, device output, and `fence rw, rw` orders memory alone,
so the ring's stores could pass it under RVWMO. Every doorbell, and every
write that enables a queue or a device, QUEUE_READY and DRIVER_OK here,
follows `fence ow, o`, which puts the earlier memory writes and the earlier
MMIO configuration writes before it (`fence w, o` would leave the MMIO
unordered), with nothing between but value and address computation, so
the fence lies on every path to the store. On the receive side, a driver
that sees a used index move reads the entry and its buffer after `fence
r, r`: the drains outside a wait carry it themselves (keyboard.S's
keyboard_drain, pad.S's pad_input_drain, sound.S's sound_drain, and
serial.S's serial_control_drain, api_drain, api_waiting, and
serial_pad_read), and the synchronous waits have it from irq_drain
(virtio_wait_used, display.S's gpu_wait_batch). QEMU's TCG runs every
fence as one full barrier, so no run shows a fence missing; test/purity's
OrderCheck reads the sources for the doorbells and enabling writes.

## virtio_queue_setup

QUEUE_READY after `fence ow, o`: the queue's addresses, MMIO writes, and
the rings they name, memory, before the device may use the queue.

## virtio_driver_ok

DRIVER_OK after `fence ow, o`, so whatever the driver prepared reaches the
device before it is told it may drive.

## virtio_reset

Every mmio driver's fault routine ends here, so a device whose source
failed stops using the program's buffers before the failure shows: a
request abandoned with the device still running could have it write the
program's buffer later, or read a buffer the program has reused. It keeps
the fault-routine contract, the source in a0 and t registers alone. The
source gives the transport, the inverse of irq_mmio_source. The bound
counts from the write's end, since QEMU resets the device inside the write
(VIRTIO_RESET_TICKS); a device still nonzero past it ends the run rather
than leave a device running that the kernel has given up on.

## device_reset_refused

Its line, naming the source, is the hart's fault (trap.S's fatal_dec): the
shutdown runs, every other hart stops, and the run ends with status 1.
Shared by vpci_reset, which passes its PCI line as the source.

## virtio_wait_used

The wait wakes on the device's interrupt, and each wake drains the
interrupts (aia.S's irq_drain) and reports a source masked since, a safe
point for its line. A source masked as stuck sends nothing more, so the wait
ends then with the completion missing, and the caller abandons the request.
The failed bit is read before the used index on every pass, and again after
the final drain on the completion path: a fault routine's reset can drain a
request to completion, writing its used entry and its status, and a
completion read after the failure must not count, or a caller would take
the drained answer as the device's. External interrupts are enabled for
the wait and disabled after it unless the sound stream is live, whose
interrupts must keep reaching the vector while the program runs (sound.S).
Its callers read the used entry and the response after it with no fence of
their own: the irq_drain it calls once the index has moved runs `fence
iorw, rw` unconditionally (aia.S), which orders the index's read before
every later read, the acquire the receive side needs. A change to that
fence changes what every synchronous request relies on.

## virtio_request

Descriptors 0 and 1 carry every request, descriptor 0 offered in the next
slot of the available ring, and the doorbell follows `fence ow, o`. A
request whose source stuck leaves the used index where it was.

## msg_reset_refused

`u8` string: device_reset_refused's line before the source's number, a
fault line every build carries.
