set VIRTIO_MMIO_MAGIC_VALUE u32 [1] :the transport's registers, each 32 bits
set VIRTIO_MMIO_VERSION u32 [2]
set VIRTIO_MMIO_DEVICE_ID u32 [3]
set VIRTIO_MMIO_DEVICE_FEATURES u32 [4]
set VIRTIO_MMIO_DEVICE_FEATURES_SEL u32 [5]
set VIRTIO_MMIO_DRIVER_FEATURES u32 [6]
set VIRTIO_MMIO_DRIVER_FEATURES_SEL u32 [7]
set VIRTIO_MMIO_QUEUE_SEL u32 [8]
set VIRTIO_MMIO_QUEUE_NUM_MAX u32 [9]
set VIRTIO_MMIO_QUEUE_NUM u32 [10]
set VIRTIO_MMIO_QUEUE_READY u32 [11]
set VIRTIO_MMIO_QUEUE_NOTIFY u32 [12]
set VIRTIO_MMIO_INTERRUPT_STATUS u32 [13]
set VIRTIO_MMIO_INTERRUPT_ACK u32 [14]
set VIRTIO_MMIO_STATUS u32 [15]
set VIRTIO_MMIO_QUEUE_DESC_LOW u32 [16]
set VIRTIO_MMIO_QUEUE_DESC_HIGH u32 [17]
set VIRTIO_MMIO_QUEUE_DRIVER_LOW u32 [18]
set VIRTIO_MMIO_QUEUE_DRIVER_HIGH u32 [19]
set VIRTIO_MMIO_QUEUE_DEVICE_LOW u32 [20]
set VIRTIO_MMIO_QUEUE_DEVICE_HIGH u32 [21]
set VIRTIO_MMIO_CONFIG u32 [22] :the device's configuration space, read a word at a time
set VIRTIO_MAGIC u32 [24] :"virt" as a little-endian word
set VIRTIO_VERSION_MODERN u32 [25] :a modern transport's version
set VIRTIO_ID_BLOCK u32 [26] :the device ids a transport carries
set VIRTIO_ID_CONSOLE u32 [27]
set VIRTIO_ID_RNG u32 [28]
set VIRTIO_ID_GPU u32 [29]
set VIRTIO_ID_INPUT u32 [30]
set VIRTIO_ID_SOUND u32 [31]
set VIRTIO_STATUS_ACKNOWLEDGE u32 [33] :status bits, set in order as the driver comes up
set VIRTIO_STATUS_DRIVER u32 [34]
set VIRTIO_STATUS_DRIVER_OK u32 [35]
set VIRTIO_STATUS_FEATURES_OK u32 [36]
set VIRTIO_F_VERSION_1_WORD u32 [38] :the feature word holding VIRTIO_F_VERSION_1, offered to every device
set VIRTIO_F_VERSION_1_BIT u32 [39] :the bit of VIRTIO_F_VERSION_1 within its word
set VIRTIO_CONSOLE_F_MULTIPORT_BIT u32 [41] :virtio-console's multiport feature in word 0
set VIRTIO_CONSOLE_CONTROL_RX_QUEUE u32 [42] :the queue the device's control messages come on
set VIRTIO_CONSOLE_CONTROL_TX_QUEUE u32 [43] :the queue the kernel's control messages go on
set VIRTIO_CONSOLE_CONTROL_ID u32 [44] :a control message's port id
set VIRTIO_CONSOLE_CONTROL_EVENT u16 [45]
set VIRTIO_CONSOLE_CONTROL_VALUE u16 [46]
set VIRTIO_CONSOLE_CONTROL_SIZE u64 [47] :bytes in a control message
set VIRTIO_CONSOLE_DEVICE_READY u16 [48] :the control events
set VIRTIO_CONSOLE_PORT_ADD u16 [49]
set VIRTIO_CONSOLE_PORT_REMOVE u16 [50]
set VIRTIO_CONSOLE_PORT_READY u16 [51]
set VIRTIO_CONSOLE_CONSOLE_PORT u16 [52]
set VIRTIO_CONSOLE_RESIZE u16 [53]
set VIRTIO_CONSOLE_PORT_OPEN u16 [54]
set VIRTIO_CONSOLE_PORT_NAME u16 [55]
set VIRTQ_SIZE u64 [57] :the entries of a split virtqueue
set VIRTQ_DESC_ADDR addr [58] :a descriptor's buffer
set VIRTQ_DESC_LEN u32 [59]
set VIRTQ_DESC_FLAGS u16 [60]
set VIRTQ_DESC_NEXT u16 [61]
set VIRTQ_DESC_SIZE u64 [62] :bytes in a descriptor
set VIRTQ_DESC_F_NEXT u16 [63] :the chain goes on at the next field
set VIRTQ_DESC_F_WRITE u16 [64] :the device writes the buffer
set VIRTQ_AVAIL_FLAGS u16 [65] :the driver's (available) ring
set VIRTQ_AVAIL_IDX u16 [66]
set VIRTQ_AVAIL_RING u16 [67] :the chain heads offered
set VIRTQ_USED_FLAGS u16 [68] :the device's (used) ring
set VIRTQ_USED_IDX u16 [69]
set VIRTQ_USED_RING u64 [70] :the used elements, VIRTQ_USED_ELEM_SIZE bytes each
set VIRTQ_USED_ELEM_ID u32 [71] :the head of the chain the device finished
set VIRTQ_USED_ELEM_LEN u32 [72] :the bytes the device wrote
set VIRTQ_USED_ELEM_SIZE u64 [73] :bytes in a used element
set VQ_DESC u64 [75] :the kernel's virtqueue record, its descriptor table
set VQ_AVAIL u64 [76] :its available ring
set VQ_USED u64 [77] :its used ring
set VQ_LAST_USED u64 [78] :the last used index the kernel saw
set VQ_BYTES u64 [79] :bytes in the record
set VQ_STRIDE u64 [80] :bytes between records of an array of them, VQ_BYTES rounded up to 16
set GPUQ_SIZE u64 [82] :the entries of the GPU's control queue
set GPUQ_DESC u64 [83] :the GPU's queue record, its descriptor table
set GPUQ_AVAIL u64 [84] :its available ring
set GPUQ_USED u64 [85] :its used ring
set GPUQ_LAST_USED u64 [86] :the last used index the kernel saw
set GPUQ_PENDING u64 [87] :how many chains are pending in a batch
set GPUQ_BYTES u64 [88] :bytes in the record
set GPUQ_CHAINS u64 [89] :the most chains a batch holds, two descriptors a chain
set VIRTIO_GPU_HDR_TYPE u32 [91] :the control header every command and response starts with
set VIRTIO_GPU_HDR_FLAGS u32 [92]
set VIRTIO_GPU_HDR_FENCE_ID u64 [93]
set VIRTIO_GPU_HDR_CTX_ID u32 [94]
set VIRTIO_GPU_HDR_SIZE u64 [95] :bytes in the header
set VIRTIO_GPU_CMD_GET_DISPLAY_INFO u32 [97]
set VIRTIO_GPU_CMD_RESOURCE_CREATE_2D u32 [98]
set VIRTIO_GPU_CMD_SET_SCANOUT u32 [99]
set VIRTIO_GPU_CMD_RESOURCE_FLUSH u32 [100]
set VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D u32 [101]
set VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING u32 [102]
set VIRTIO_GPU_RESP_OK_NODATA u32 [103] :a command without data went through
set VIRTIO_GPU_RESP_OK_DISPLAY_INFO u32 [104] :the display info came back
set VIRTIO_GPU_RECT_X u32 [106] :a rectangle's fields
set VIRTIO_GPU_RECT_Y u32 [107]
set VIRTIO_GPU_RECT_WIDTH u32 [108]
set VIRTIO_GPU_RECT_HEIGHT u32 [109]
set VIRTIO_GPU_CREATE_2D_RESOURCE_ID u32 [111]
set VIRTIO_GPU_CREATE_2D_FORMAT u32 [112]
set VIRTIO_GPU_CREATE_2D_WIDTH u32 [113]
set VIRTIO_GPU_CREATE_2D_HEIGHT u32 [114]
set VIRTIO_GPU_CREATE_2D_SIZE u64 [115] :bytes in the command
set VIRTIO_GPU_ATTACH_RESOURCE_ID u32 [116]
set VIRTIO_GPU_ATTACH_NR_ENTRIES u32 [117]
set VIRTIO_GPU_ATTACH_ENTRY_ADDR addr [118] :the one backing entry's memory
set VIRTIO_GPU_ATTACH_ENTRY_LENGTH u32 [119]
set VIRTIO_GPU_ATTACH_SIZE u64 [120] :bytes in the command with one entry
set VIRTIO_GPU_SCANOUT_RECT u64 [121] :the rectangle record
set VIRTIO_GPU_SCANOUT_ID u32 [122]
set VIRTIO_GPU_SCANOUT_RESOURCE_ID u32 [123]
set VIRTIO_GPU_SCANOUT_SIZE u64 [124] :bytes in the command
set VIRTIO_GPU_TRANSFER_RECT u64 [125] :the rectangle record
set VIRTIO_GPU_TRANSFER_OFFSET u64 [126] :the rectangle's offset in the backing
set VIRTIO_GPU_TRANSFER_RESOURCE_ID u32 [127]
set VIRTIO_GPU_TRANSFER_SIZE u64 [128] :bytes in the command
set VIRTIO_GPU_FLUSH_RECT u64 [129] :the rectangle record
set VIRTIO_GPU_FLUSH_RESOURCE_ID u32 [130]
set VIRTIO_GPU_FLUSH_SIZE u64 [131] :bytes in the command
set VIRTIO_GPU_DISPLAY_INFO_MODES u64 [133] :the display info's sixteen modes after the header
set VIRTIO_GPU_DISPLAY_ONE_ENABLED u32 [134] :a mode's enabled word after its rectangle
set VIRTIO_GPU_DISPLAY_ONE_SIZE u64 [135] :bytes in a mode, the flags word last
set VIRTIO_GPU_DISPLAY_INFO_SIZE u64 [136] :bytes in the response
set VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM u32 [138] :the framebuffer's format, bytes blue, green, red, unused
set VIRTIO_INPUT_CFG_SELECT u8 [140] :virtio-input's config, what the payload describes
set VIRTIO_INPUT_CFG_SUBSEL u8 [141]
set VIRTIO_INPUT_CFG_SIZE u8 [142] :the payload's length
set VIRTIO_INPUT_CFG_DATA u8 [143] :the payload
set VIRTIO_INPUT_CFG_ID_NAME u8 [144] :a select for the device's name
set VIRTIO_INPUT_CFG_EV_BITS u8 [145] :a select, with an event type, for the bitmap of codes it sends
set VIRTIO_INPUT_CFG_ABS_INFO u8 [146] :a select, with an axis code, for its absinfo
set VIRTIO_INPUT_ABS_MIN i32 [147] :the absinfo's fields
set VIRTIO_INPUT_ABS_MAX i32 [148]
set VIRTIO_INPUT_ABS_FUZZ i32 [149]
set VIRTIO_INPUT_ABS_FLAT i32 [150]
set VIRTIO_INPUT_ABS_RES i32 [151]
set VIRTIO_INPUT_ABS_SIZE u64 [152] :bytes in an absinfo
set PADQ_SIZE u64 [154] :the buffers the pad's event queue keeps offered
set PADQ_DESC u64 [155] :the pad's queue record, its descriptor table
set PADQ_AVAIL u64 [156] :its available ring
set PADQ_USED u64 [157] :its used ring
set PADQ_LAST_USED u64 [158] :the last used index the kernel saw
set PADQ_BYTES u64 [159] :bytes in the record
set VIRTIO_BLK_CFG_CAPACITY_LOW u32 [161] :the capacity in 512-byte sectors, its low word
set VIRTIO_BLK_CFG_CAPACITY_HIGH u32 [162] :its high word
set VIRTIO_BLK_ID_BYTES u64 [163] :the most bytes of the device ID string
set VIRTIO_BLK_T_IN u32 [164] :a read
set VIRTIO_BLK_T_OUT u32 [165] :a write
set VIRTIO_BLK_T_GET_ID u32 [166] :a request for the device ID string
set VIRTIO_BLK_S_OK u8 [167] :the status byte of a request that went through
set VIRTIO_BLK_REQ_TYPE u32 [168] :a request's header
set VIRTIO_BLK_REQ_IOPRIO u32 [169]
set VIRTIO_BLK_REQ_SECTOR u64 [170]
set VIRTIO_BLK_REQ_SIZE u64 [171] :bytes in the header
set VIRTIO_INPUT_EVENT_TYPE u16 [173] :a virtio-input event, as Linux's
set VIRTIO_INPUT_EVENT_CODE u16 [174]
set VIRTIO_INPUT_EVENT_VALUE i32 [175]
set VIRTIO_INPUT_EVENT_SIZE u64 [176] :bytes in an event
set EV_SYN u16 [177] :the event types
set EV_KEY u16 [178]
set EV_ABS u16 [179]
set EV_MSC u16 [180]
set VIRTIO_SND_VQ_CONTROL u32 [182] :virtio-sound's queues
set VIRTIO_SND_VQ_EVENT u32 [183]
set VIRTIO_SND_VQ_TX u32 [184]
set VIRTIO_SND_VQ_RX u32 [185]
set VIRTIO_SND_R_PCM_INFO u32 [186] :the control request codes
set VIRTIO_SND_R_PCM_SET_PARAMS u32 [187]
set VIRTIO_SND_R_PCM_PREPARE u32 [188]
set VIRTIO_SND_R_PCM_RELEASE u32 [189]
set VIRTIO_SND_R_PCM_START u32 [190]
set VIRTIO_SND_R_PCM_STOP u32 [191]
set VIRTIO_SND_S_OK u32 [192] :the status of a request or transfer that went through
set VIRTIO_SND_D_OUTPUT u8 [193] :a stream's direction as output
set VIRTIO_SND_PCM_FMT_S16 u8 [194] :signed 16-bit samples
set VIRTIO_SND_PCM_RATE_48000 u8 [195] :48 kHz
set VIRTIO_SND_HDR_CODE u32 [196] :a control request's code
set VIRTIO_SND_PCM_HDR_STREAM u32 [197] :the stream id after the code
set VIRTIO_SND_PCM_HDR_SIZE u64 [198] :bytes in a stream request's header
set VIRTIO_SND_SET_PARAMS_BUFFER_BYTES u32 [199]
set VIRTIO_SND_SET_PARAMS_PERIOD_BYTES u32 [200]
set VIRTIO_SND_SET_PARAMS_FEATURES u32 [201]
set VIRTIO_SND_SET_PARAMS_CHANNELS u8 [202]
set VIRTIO_SND_SET_PARAMS_FORMAT u8 [203]
set VIRTIO_SND_SET_PARAMS_RATE u8 [204]
set VIRTIO_SND_SET_PARAMS_SIZE u64 [205] :bytes in a SET_PARAMS request
set VIRTIO_SND_PCM_XFER_SIZE u64 [206] :bytes in a tx transfer's header, the stream id
set VIRTIO_SND_PCM_STATUS_STATUS u32 [207] :a transfer's status, after the samples
set VIRTIO_SND_PCM_STATUS_LATENCY u32 [208]
set VIRTIO_SND_PCM_STATUS_SIZE u64 [209] :bytes in a transfer's status
set SNDQ_SIZE u64 [211] :the entries of the sound's tx queue, two descriptors a period
set SNDQ_DESC u64 [212] :the sound's queue record, its descriptor table
set SNDQ_AVAIL u64 [213] :its available ring
set SNDQ_USED u64 [214] :its used ring
set SNDQ_LAST_USED u64 [215] :the last used index the kernel saw
set SNDQ_BYTES u64 [216] :bytes in the record
