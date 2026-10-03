# virtio.S

virtio over mmio, the transport of every Jab device: finding a device by id
among QEMU virt's transports, bringing it up, giving it a split virtqueue,
letting its interrupt line through the PLIC, running one request through a
queue at a time, and waiting for the device with the hart halted rather
than spinning. Every routine takes the transport's base in a0 and clobbers
t registers, plus a0 for what it returns, unless it says otherwise.

## plic_enable

The line is enabled in the context's word holding it, 32 lines to a word.

## plic_service

The line drops once what raised it is acknowledged: an mmio transport's
interrupt status acknowledged, or every PCI device on a PCI line asked for
its ISR (pci.S). Only virtio lines are ever enabled. On the sound device's
line its stream is refilled on its clock (sound_service).

## virtio_wait_used

The wait wakes on the transport's line. External interrupts are enabled for
the wait and disabled after it unless the sound stream is live, whose line
must keep reaching the vector while the program runs (sound.S).

## virtio_request

Descriptors 0 and 1 carry every request, descriptor 0 offered in the next
slot of the available ring.
