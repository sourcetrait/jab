# virtio.inc

virtio over mmio, version 2, and the virtio-gpu, virtio-input, virtio-blk,
virtio-console, and virtio-sound pieces the kernel drives its devices with,
as the virtio 1.3 specification lays them out. Offsets are bytes; the
transport's registers are 32 bits wide.

## .set VIRTIO_MMIO_MAGIC_VALUE

`u32`: the transport's registers, each 32 bits.

## .set VIRTIO_MMIO_VERSION

`u32`.

## .set VIRTIO_MMIO_DEVICE_ID

`u32`.

## .set VIRTIO_MMIO_DEVICE_FEATURES

`u32`.

## .set VIRTIO_MMIO_DEVICE_FEATURES_SEL

`u32`.

## .set VIRTIO_MMIO_DRIVER_FEATURES

`u32`.

## .set VIRTIO_MMIO_DRIVER_FEATURES_SEL

`u32`.

## .set VIRTIO_MMIO_QUEUE_SEL

`u32`.

## .set VIRTIO_MMIO_QUEUE_NUM_MAX

`u32`.

## .set VIRTIO_MMIO_QUEUE_NUM

`u32`.

## .set VIRTIO_MMIO_QUEUE_READY

`u32`.

## .set VIRTIO_MMIO_QUEUE_NOTIFY

`u32`.

## .set VIRTIO_MMIO_INTERRUPT_STATUS

`u32`.

## .set VIRTIO_MMIO_INTERRUPT_ACK

`u32`.

## .set VIRTIO_MMIO_STATUS

`u32`.

## .set VIRTIO_MMIO_QUEUE_DESC_LOW

`u32`.

## .set VIRTIO_MMIO_QUEUE_DESC_HIGH

`u32`.

## .set VIRTIO_MMIO_QUEUE_DRIVER_LOW

`u32`.

## .set VIRTIO_MMIO_QUEUE_DRIVER_HIGH

`u32`.

## .set VIRTIO_MMIO_QUEUE_DEVICE_LOW

`u32`.

## .set VIRTIO_MMIO_QUEUE_DEVICE_HIGH

`u32`.

## .set VIRTIO_MMIO_CONFIG

`u32`: the device's configuration space, read a word at a time.

## .set VIRTIO_MAGIC

`u32`: "virt" as a little-endian word.

## .set VIRTIO_VERSION_MODERN

`u32`: a modern transport's version.

## .set VIRTIO_ID_BLOCK

`u32`: the device ids a transport carries.

## .set VIRTIO_ID_CONSOLE

`u32`.

## .set VIRTIO_ID_RNG

`u32`.

## .set VIRTIO_ID_GPU

`u32`.

## .set VIRTIO_ID_INPUT

`u32`.

## .set VIRTIO_ID_SOUND

`u32`.

## .set VIRTIO_STATUS_ACKNOWLEDGE

`u32`: status bits, set in order as the driver comes up.

## .set VIRTIO_STATUS_DRIVER

`u32`.

## .set VIRTIO_STATUS_DRIVER_OK

`u32`.

## .set VIRTIO_STATUS_FEATURES_OK

`u32`.

## .set VIRTIO_RESET_TICKS

`u64`: how long a device's status may read back nonzero after the write of
0 that resets it, 100 ms of the time counter, counted from the write's end.
QEMU resets a device inside that write (virtio-mmio.c, virtio-pci.c), and a
virtio-blk reset there drains every disk's requests on the machine before
the write returns, so the write itself is unbounded and the readback is
the part a bound can hold (virtio 1.2, 2.4's reset handshake). A device
still nonzero past it refuses the reset: device_reset_refused ends the run.

## .set VIRTIO_F_VERSION_1_WORD

`u32`: the feature word holding VIRTIO_F_VERSION_1, offered to every device.

The feature the kernel offers every device is VIRTIO_F_VERSION_1, feature
bit 32, which is bit 0 of feature word 1. A device's own features sit in
word 0 and are offered beside it.

## .set VIRTIO_F_VERSION_1_BIT

`u32`: the bit of VIRTIO_F_VERSION_1 within its word.

## .set VIRTIO_CONSOLE_F_MULTIPORT_BIT

`u32`: virtio-console's multiport feature in word 0.

virtio-console, which QEMU calls virtio-serial: with its multiport feature
the device carries a port per channel, queues 2 and 3 carry control
messages (the device's to the kernel, the kernel's to the device), and port
n receives on queue 2n+2 and transmits on 2n+3. A control message is a port
id, an event, and a value; the device names each port it carries once told
the kernel is ready, and a port carries bytes once the kernel has answered
for it and opened it.

## .set VIRTIO_CONSOLE_CONTROL_RX_QUEUE

`u32`: the queue the device's control messages come on.

## .set VIRTIO_CONSOLE_CONTROL_TX_QUEUE

`u32`: the queue the kernel's control messages go on.

## .set VIRTIO_CONSOLE_CONTROL_ID

`u32`: a control message's port id.

## .set VIRTIO_CONSOLE_CONTROL_EVENT

`u16`.

## .set VIRTIO_CONSOLE_CONTROL_VALUE

`u16`.

## .set VIRTIO_CONSOLE_CONTROL_SIZE

`u64`: bytes in a control message.

## .set VIRTIO_CONSOLE_DEVICE_READY

`u16`: the control events.

## .set VIRTIO_CONSOLE_PORT_ADD

`u16`.

## .set VIRTIO_CONSOLE_PORT_REMOVE

`u16`.

## .set VIRTIO_CONSOLE_PORT_READY

`u16`.

## .set VIRTIO_CONSOLE_CONSOLE_PORT

`u16`.

## .set VIRTIO_CONSOLE_RESIZE

`u16`.

## .set VIRTIO_CONSOLE_PORT_OPEN

`u16`.

## .set VIRTIO_CONSOLE_PORT_NAME

`u16`.

## .set VIRTQ_SIZE

`u64`: the entries of a split virtqueue.

## .set VIRTQ_DESC_ADDR

`addr`: a descriptor's buffer.

## .set VIRTQ_DESC_LEN

`u32`.

## .set VIRTQ_DESC_FLAGS

`u16`.

## .set VIRTQ_DESC_NEXT

`u16`.

## .set VIRTQ_DESC_SIZE

`u64`: bytes in a descriptor.

## .set VIRTQ_DESC_F_NEXT

`u16`: the chain goes on at the next field.

## .set VIRTQ_DESC_F_WRITE

`u16`: the device writes the buffer.

## .set VIRTQ_AVAIL_FLAGS

`u16`: the driver's (available) ring.

## .set VIRTQ_AVAIL_IDX

`u16`.

## .set VIRTQ_AVAIL_RING

`u16`: the chain heads offered.

## .set VIRTQ_USED_FLAGS

`u16`: the device's (used) ring.

## .set VIRTQ_USED_IDX

`u16`.

## .set VIRTQ_USED_RING

`u64`: the used elements, VIRTQ_USED_ELEM_SIZE bytes each.

## .set VIRTQ_USED_ELEM_ID

`u32`: the head of the chain the device finished.

## .set VIRTQ_USED_ELEM_LEN

`u32`: the bytes the device wrote.

## .set VIRTQ_USED_ELEM_SIZE

`u64`: bytes in a used element.

## .set VQ_DESC

`u64`: the kernel's virtqueue record, its descriptor table.

The kernel's virtqueue record holds the three rings, each at its alignment
(16, 2, 4), then the last used index the kernel saw.

## .set VQ_AVAIL

`u64`: its available ring.

## .set VQ_USED

`u64`: its used ring.

## .set VQ_LAST_USED

`u64`: the last used index the kernel saw.

## .set VQ_BYTES

`u64`: bytes in the record.

## .set VQ_STRIDE

`u64`: bytes between records of an array of them, VQ_BYTES rounded up to 16.

An array of these needs every record at the descriptor table's own
alignment, so its stride is the record rounded up to 16.

## .set GPUQ_SIZE

`u64`: the entries of the GPU's control queue.

The GPU's control queue is the one queue with many commands in flight at
once, a rectangle list's transfers and flushes, so it has a record of its
own: the rings at the same alignments, the last used index, and how many
chains are pending in a batch.

## .set GPUQ_DESC

`u64`: the GPU's queue record, its descriptor table.

## .set GPUQ_AVAIL

`u64`: its available ring.

## .set GPUQ_USED

`u64`: its used ring.

## .set GPUQ_LAST_USED

`u64`: the last used index the kernel saw.

## .set GPUQ_PENDING

`u64`: how many chains are pending in a batch.

## .set GPUQ_BYTES

`u64`: bytes in the record.

## .set GPUQ_CHAINS

`u64`: the most chains a batch holds, two descriptors a chain.

A batch is at most half the queue, two descriptors a chain.

## .set VIRTIO_GPU_HDR_TYPE

`u32`: the control header every command and response starts with.

## .set VIRTIO_GPU_HDR_FLAGS

`u32`.

## .set VIRTIO_GPU_HDR_FENCE_ID

`u64`.

## .set VIRTIO_GPU_HDR_CTX_ID

`u32`.

## .set VIRTIO_GPU_HDR_SIZE

`u64`: bytes in the header.

## .set VIRTIO_GPU_CMD_GET_DISPLAY_INFO

`u32`.

## .set VIRTIO_GPU_CMD_RESOURCE_CREATE_2D

`u32`.

## .set VIRTIO_GPU_CMD_SET_SCANOUT

`u32`.

## .set VIRTIO_GPU_CMD_RESOURCE_FLUSH

`u32`.

## .set VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D

`u32`.

## .set VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING

`u32`.

## .set VIRTIO_GPU_RESP_OK_NODATA

`u32`: a command without data went through.

## .set VIRTIO_GPU_RESP_OK_DISPLAY_INFO

`u32`: the display info came back.

## .set VIRTIO_GPU_RECT_X

`u32`: a rectangle's fields.

## .set VIRTIO_GPU_RECT_Y

`u32`.

## .set VIRTIO_GPU_RECT_WIDTH

`u32`.

## .set VIRTIO_GPU_RECT_HEIGHT

`u32`.

## .set VIRTIO_GPU_CREATE_2D_RESOURCE_ID

`u32`.

## .set VIRTIO_GPU_CREATE_2D_FORMAT

`u32`.

## .set VIRTIO_GPU_CREATE_2D_WIDTH

`u32`.

## .set VIRTIO_GPU_CREATE_2D_HEIGHT

`u32`.

## .set VIRTIO_GPU_CREATE_2D_SIZE

`u64`: bytes in the command.

## .set VIRTIO_GPU_ATTACH_RESOURCE_ID

`u32`.

## .set VIRTIO_GPU_ATTACH_NR_ENTRIES

`u32`.

## .set VIRTIO_GPU_ATTACH_ENTRY_ADDR

`addr`: the one backing entry's memory.

## .set VIRTIO_GPU_ATTACH_ENTRY_LENGTH

`u32`.

## .set VIRTIO_GPU_ATTACH_SIZE

`u64`: bytes in the command with one entry.

## .set VIRTIO_GPU_SCANOUT_RECT

`u64`: the rectangle record.

## .set VIRTIO_GPU_SCANOUT_ID

`u32`.

## .set VIRTIO_GPU_SCANOUT_RESOURCE_ID

`u32`.

## .set VIRTIO_GPU_SCANOUT_SIZE

`u64`: bytes in the command.

## .set VIRTIO_GPU_TRANSFER_RECT

`u64`: the rectangle record.

## .set VIRTIO_GPU_TRANSFER_OFFSET

`u64`: the rectangle's offset in the backing.

## .set VIRTIO_GPU_TRANSFER_RESOURCE_ID

`u32`.

## .set VIRTIO_GPU_TRANSFER_SIZE

`u64`: bytes in the command.

## .set VIRTIO_GPU_FLUSH_RECT

`u64`: the rectangle record.

## .set VIRTIO_GPU_FLUSH_RESOURCE_ID

`u32`.

## .set VIRTIO_GPU_FLUSH_SIZE

`u64`: bytes in the command.

## .set VIRTIO_GPU_DISPLAY_INFO_MODES

`u64`: the display info's sixteen modes after the header.

## .set VIRTIO_GPU_DISPLAY_ONE_ENABLED

`u32`: a mode's enabled word after its rectangle.

## .set VIRTIO_GPU_DISPLAY_ONE_SIZE

`u64`: bytes in a mode, the flags word last.

## .set VIRTIO_GPU_DISPLAY_INFO_SIZE

`u64`: bytes in the response.

## .set VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM

`u32`: the framebuffer's format, bytes blue, green, red, unused.

## .set VIRTIO_INPUT_CFG_SELECT

`u8`: virtio-input's config, what the payload describes.

A select and a subselect byte pick what the payload at VIRTIO_INPUT_CFG_DATA
describes, and size says how long it is. The absinfo is five little-endian
32-bit fields: min, max, fuzz, flat, resolution.

## .set VIRTIO_INPUT_CFG_SUBSEL

`u8`.

## .set VIRTIO_INPUT_CFG_SIZE

`u8`: the payload's length.

## .set VIRTIO_INPUT_CFG_DATA

`u8`: the payload.

## .set VIRTIO_INPUT_CFG_ID_NAME

`u8`: a select for the device's name.

## .set VIRTIO_INPUT_CFG_EV_BITS

`u8`: a select, with an event type, for the bitmap of codes it sends.

## .set VIRTIO_INPUT_CFG_ABS_INFO

`u8`: a select, with an axis code, for its absinfo.

## .set VIRTIO_INPUT_ABS_MIN

`i32`: the absinfo's fields.

## .set VIRTIO_INPUT_ABS_MAX

`i32`.

## .set VIRTIO_INPUT_ABS_FUZZ

`i32`.

## .set VIRTIO_INPUT_ABS_FLAT

`i32`.

## .set VIRTIO_INPUT_ABS_RES

`i32`.

## .set VIRTIO_INPUT_ABS_SIZE

`u64`: bytes in an absinfo.

## .set PADQ_SIZE

`u64`: the buffers the pad's event queue keeps offered.

The pad's event queue is the other wide one: the device fills a buffer per
event, a pad sends several a report at over a hundred reports a second, and
the kernel drains only when the program calls or waits, so PADQ_SIZE
buffers stand offered. The record is the GPU's shape without a pending
count.

## .set PADQ_DESC

`u64`: the pad's queue record, its descriptor table.

## .set PADQ_AVAIL

`u64`: its available ring.

## .set PADQ_USED

`u64`: its used ring.

## .set PADQ_LAST_USED

`u64`: the last used index the kernel saw.

## .set PADQ_BYTES

`u64`: bytes in the record.

## .set VIRTIO_BLK_CFG_CAPACITY_LOW

`u32`: the capacity in 512-byte sectors, its low word.

The capacity opens the config space as a little-endian 64-bit value, read as
two words since the transport takes config accesses of four bytes. A
request is a header the device reads, the data, and a status byte the
device writes, three descriptors chained; the type and the sector go in the
header, and GET_ID answers with the device ID string QEMU takes from
`serial=`.

## .set VIRTIO_BLK_CFG_CAPACITY_HIGH

`u32`: its high word.

## .set VIRTIO_BLK_ID_BYTES

`u64`: the most bytes of the device ID string.

## .set VIRTIO_BLK_T_IN

`u32`: a read.

## .set VIRTIO_BLK_T_OUT

`u32`: a write.

## .set VIRTIO_BLK_T_GET_ID

`u32`: a request for the device ID string.

## .set VIRTIO_BLK_S_OK

`u8`: the status byte of a request that went through.

## .set VIRTIO_BLK_REQ_TYPE

`u32`: a request's header.

## .set VIRTIO_BLK_REQ_IOPRIO

`u32`.

## .set VIRTIO_BLK_REQ_SECTOR

`u64`.

## .set VIRTIO_BLK_REQ_SIZE

`u64`: bytes in the header.

## .set VIRTIO_INPUT_EVENT_TYPE

`u16`: a virtio-input event, as Linux's.

## .set VIRTIO_INPUT_EVENT_CODE

`u16`.

## .set VIRTIO_INPUT_EVENT_VALUE

`i32`.

## .set VIRTIO_INPUT_EVENT_SIZE

`u64`: bytes in an event.

## .set EV_SYN

`u16`: the event types.

## .set EV_KEY

`u16`.

## .set EV_ABS

`u16`.

## .set EV_MSC

`u16`.

## .set VIRTIO_SND_VQ_CONTROL

`u32`: virtio-sound's queues.

virtio-sound (virtio 1.3, section 5.14) has four queues, control, event,
tx, and rx; a control request is a code and its fields, answered with a
status; a PCM stream is set up with SET_PARAMS, PREPARE, and START; a tx
transfer is the stream id and the samples the device reads, then a status
and latency it writes. Formats and rates are enumerations, S16 and 48000
the ones Jab uses.

## .set VIRTIO_SND_VQ_EVENT

`u32`.

## .set VIRTIO_SND_VQ_TX

`u32`.

## .set VIRTIO_SND_VQ_RX

`u32`.

## .set VIRTIO_SND_R_PCM_INFO

`u32`: the control request codes.

## .set VIRTIO_SND_R_PCM_SET_PARAMS

`u32`.

## .set VIRTIO_SND_R_PCM_PREPARE

`u32`.

## .set VIRTIO_SND_R_PCM_RELEASE

`u32`.

## .set VIRTIO_SND_R_PCM_START

`u32`.

## .set VIRTIO_SND_R_PCM_STOP

`u32`.

## .set VIRTIO_SND_S_OK

`u32`: the status of a request or transfer that went through.

## .set VIRTIO_SND_D_OUTPUT

`u8`: a stream's direction as output.

## .set VIRTIO_SND_PCM_FMT_S16

`u8`: signed 16-bit samples.

## .set VIRTIO_SND_PCM_RATE_48000

`u8`: 48 kHz.

## .set VIRTIO_SND_HDR_CODE

`u32`: a control request's code.

## .set VIRTIO_SND_PCM_HDR_STREAM

`u32`: the stream id after the code.

## .set VIRTIO_SND_PCM_HDR_SIZE

`u64`: bytes in a stream request's header.

## .set VIRTIO_SND_SET_PARAMS_BUFFER_BYTES

`u32`.

## .set VIRTIO_SND_SET_PARAMS_PERIOD_BYTES

`u32`.

## .set VIRTIO_SND_SET_PARAMS_FEATURES

`u32`.

## .set VIRTIO_SND_SET_PARAMS_CHANNELS

`u8`.

## .set VIRTIO_SND_SET_PARAMS_FORMAT

`u8`.

## .set VIRTIO_SND_SET_PARAMS_RATE

`u8`.

## .set VIRTIO_SND_SET_PARAMS_SIZE

`u64`: bytes in a SET_PARAMS request.

## .set VIRTIO_SND_PCM_XFER_SIZE

`u64`: bytes in a tx transfer's header, the stream id.

## .set VIRTIO_SND_PCM_STATUS_STATUS

`u32`: a transfer's status, after the samples.

## .set VIRTIO_SND_PCM_STATUS_LATENCY

`u32`.

## .set VIRTIO_SND_PCM_STATUS_SIZE

`u64`: bytes in a transfer's status.

## .set SNDQ_SIZE

`u64`: the entries of the sound's tx queue, two descriptors a period.

The sound's tx queue record is the pad's shape.

## .set SNDQ_DESC

`u64`: the sound's queue record, its descriptor table.

## .set SNDQ_AVAIL

`u64`: its available ring.

## .set SNDQ_USED

`u64`: its used ring.

## .set SNDQ_LAST_USED

`u64`: the last used index the kernel saw.

## .set SNDQ_BYTES

`u64`: bytes in the record.
