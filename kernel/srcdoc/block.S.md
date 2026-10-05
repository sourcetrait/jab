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
and nothing more, a kind set only once the sector's read answered OK.

A disk goes into the tables, block_count covering it, before its first
request, so a fault on its line during the probe reaches it (block_fault
iterates the count). A disk on a line already failed is counted at kind 0
and sent nothing, never brought up: its requests would be abandoned at once
on a device no fault routine reset. A failed or abandoned request ends that
disk's probe at kind 0, with no request after it. Under DEBUG a disk's line
can be held (aia.S's irq_hold), and the probe ends with a line per disk on
the debug channel (block_report).

## msg_disk_pci

`23 u8`: the debug line naming a disk's PCI slot, under DEBUG only.

## block_request

Three descriptors are offered as one chain, the chain's head in the next
slot of the available ring; the doorbell's fence is vpci_notify's own
(virtio_pci.S). The status byte is set to 0xff first, so an
unanswered request cannot read OK. An abandoned request answers 0xff
without reading the status byte, which the reset's drain may have written
OK while the line was failing.

## block_fault

Two passes over the disks on the line. The first records, for each, whether
a request was in flight (its used index short of its available index) into
block_outstanding; then `fence r, o`; then the second resets each one
(vpci_reset) and sets its kind 0. A virtio-blk reset in QEMU drains every
disk's requests on the machine inside its status write, completing them, so
a disk reset first would complete the requests of the disks after it and
their record would read nothing in flight; every queue is read before the
first reset. The record is the fixture's per-run proof that a request was
in flight when its line failed (test/stuck).

## block_report

Under DEBUG, at the probe's end: `jab: disk <id> kind <k> status <s> offered
<n> outstanding <0|1> enabled <0|1>`, the status the device's read back from
its common configuration (0 once reset, or never brought up), the requests
its available index counts, the outstanding record, and its line's enable
read back from the APLIC's setie.

## msg_disk
## msg_disk_kind
## msg_disk_status
## msg_disk_offered
## msg_disk_outstanding
## msg_disk_enabled

`u8` strings: block_report's line, its values between them, under DEBUG
only.

## block_queues

The disks' virtqueue records, VQ_STRIDE apart.

## block_records

The disks' JAB_BLOCK_* records, the program-facing list. A disk whose
PCI line stuck (aia.S) has its kind 0, as one that never came up.

## block_bases

`8 addr`: each disk's PCI device record.

## block_outstanding

`JAB_BLOCK_MAX u8`: per disk, 1 when a request was in flight as its line
failed, recorded by block_fault and read by block_report.

## block_count

`u64`: the disks found.

## block_probed

`u64`: 1 once the probe has run.

## block_header

The request header the device reads.

## block_status

`u8`: the status byte the device writes.

## block_bounce

`512 u8`: a sector the kernel reads through.
