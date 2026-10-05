# virtio.S

virtio over mmio, the transport of every Jab device: finding a device by id
among QEMU virt's transports, bringing it up, giving it a split virtqueue,
running one request through a queue at a time, and waiting for the device
with the hart halted rather than spinning. A transport's interrupt source
and its enabling are aia.S's. Every routine takes the transport's base in
a0 and clobbers t registers, plus a0 for what it returns, unless it says
otherwise.

## virtio_wait_used

The wait wakes on the device's interrupt, and each wake drains the
interrupts (aia.S's irq_drain) and reports a source masked since, a safe
point for its line. A source masked as stuck sends nothing more, so the wait
ends then with the completion missing, and the caller abandons the request.
External interrupts are enabled for the wait and disabled after it unless
the sound stream is live, whose interrupts must keep reaching the vector
while the program runs (sound.S).

## virtio_request

Descriptors 0 and 1 carry every request, descriptor 0 offered in the next
slot of the available ring. A request whose source stuck leaves the used
index where it was.
