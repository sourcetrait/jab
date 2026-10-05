# virtio.S

virtio over mmio, the transport of every Jab device: finding a device by id
among QEMU virt's transports, bringing it up, giving it a split virtqueue,
running one request through a queue at a time, and waiting for the device
with the hart halted rather than spinning. A transport's interrupt source
and its enabling are aia.S's. Every routine takes the transport's base in
a0 and clobbers t registers, plus a0 for what it returns, unless it says
otherwise.

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

Takes the line lock as a fault's (uart_lock_fatal), since the hart may hold
nothing it could wait on, and ends the run with status 1. Shared by
vpci_reset, which passes its PCI line as the source.

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

## virtio_request

Descriptors 0 and 1 carry every request, descriptor 0 offered in the next
slot of the available ring. A request whose source stuck leaves the used
index where it was.

## msg_reset_refused

`u8` string: device_reset_refused's line before the source's number, a
fault line every build carries.
