# virtio.inc

virtio over mmio, version 2, and the virtio-gpu, virtio-input, virtio-blk,
virtio-console, and virtio-sound pieces the kernel drives its devices with,
as the virtio 1.3 specification lays them out. Offsets are bytes; the
transport's registers are 32 bits wide.

## .set VIRTIO_F_VERSION_1_WORD

The feature the kernel offers every device is VIRTIO_F_VERSION_1, feature
bit 32, which is bit 0 of feature word 1. A device's own features sit in
word 0 and are offered beside it.

## .set VIRTIO_CONSOLE_F_MULTIPORT_BIT

virtio-console, which QEMU calls virtio-serial: with its multiport feature
the device carries a port per channel, queues 2 and 3 carry control
messages (the device's to the kernel, the kernel's to the device), and port
n receives on queue 2n+2 and transmits on 2n+3. A control message is a port
id, an event, and a value; the device names each port it carries once told
the kernel is ready, and a port carries bytes once the kernel has answered
for it and opened it.

## .set VQ_DESC

The kernel's virtqueue record holds the three rings, each at its alignment
(16, 2, 4), then the last used index the kernel saw.

## .set VQ_STRIDE

An array of these needs every record at the descriptor table's own
alignment, so its stride is the record rounded up to 16.

## .set GPUQ_SIZE

The GPU's control queue is the one queue with many commands in flight at
once, a rectangle list's transfers and flushes, so it has a record of its
own: the rings at the same alignments, the last used index, and how many
chains are pending in a batch.

## .set GPUQ_CHAINS

A batch is at most half the queue, two descriptors a chain.

## .set VIRTIO_INPUT_CFG_SELECT

A select and a subselect byte pick what the payload at VIRTIO_INPUT_CFG_DATA
describes, and size says how long it is. The absinfo is five little-endian
32-bit fields: min, max, fuzz, flat, resolution.

## .set PADQ_SIZE

The pad's event queue is the other wide one: the device fills a buffer per
event, a pad sends several a report at over a hundred reports a second, and
the kernel drains only when the program calls or waits, so PADQ_SIZE
buffers stand offered. The record is the GPU's shape without a pending
count.

## .set VIRTIO_BLK_CFG_CAPACITY_LOW

The capacity opens the config space as a little-endian 64-bit value, read as
two words since the transport takes config accesses of four bytes. A
request is a header the device reads, the data, and a status byte the
device writes, three descriptors chained; the type and the sector go in the
header, and GET_ID answers with the device ID string QEMU takes from
`serial=`.

## .set VIRTIO_SND_VQ_CONTROL

virtio-sound (virtio 1.3, section 5.14) has four queues, control, event,
tx, and rx; a control request is a code and its fields, answered with a
status; a PCM stream is set up with SET_PARAMS, PREPARE, and START; a tx
transfer is the stream id and the samples the device reads, then a status
and latency it writes. Formats and rates are enumerations, S16 and 48000
the ones Jab uses.

## .set SNDQ_SIZE

The sound's tx queue record is the pad's shape.
