# block.S

The disks: QEMU's virtio-blk devices on the PCI Express root (pci.S,
virtio_pci.S), past the eight mmio slots every other Jab device sits in,
driven as sectors and nothing more. The first block or romfs call scans the
bus, brings up every device carrying virtio id 2, and gives each an id in
slot order, learning its capacity from its device configuration, its serial
from a GET_ID request, and what is on it from its first sector. All of that
is kept in the program-facing record of jab.inc, so a listing is a copy
rather than a translation. A request is three descriptors - the header the
device reads, the data, and the status byte it writes - run one at a time
per disk with the hart halted until the device answers, as the display's
commands are. A disk that refuses the kernel is still counted, with
JAB_BLOCK_KIND_NONE and no capacity, so a program sees that the machine
carries a disk there and reads why from the code it gets back. A format
reads through this layer: romfs.S.

## sys_block_list

An id is one more than its index, so an `at` of 1 also starts at the first
disk. Never more records are written than there are disks from there on.

## sys_block_find

Twenty bytes matched is all virtio carries, so the serial matches only if
the program's string ends there too.

## sys_block_read

The device writes the program's buffer itself, so nothing is copied.

## block_transfer

The queue is found first: block_base leaves a1 alone, where block_queue
would clobber any t register holding the transport.

## block_probe

The devices come in slot order, which is the order QEMU's command line named
them. The probe runs once, whatever comes of it. A disk's record carries its
id from the start, so a device that refuses the kernel is still one a
program can see and ask about. The capacity is two words of the device
configuration, since the region answers four bytes at a time. The serial
goes straight into the record: QEMU writes the terminator only when it fits,
so the field is cleared first. What is on the disk is found by asking each
format known about the first sector; anything unrecognised is raw sectors
and nothing more.

## block_request

Three descriptors are offered as one chain, the chain's head in the next
slot of the available ring. The status byte is set to 0xff first, so an
unanswered request cannot read OK.
