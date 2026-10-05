ecall sys_block_list buffer addr,at u64,capacity u64 > count a0 u64,next a1 u64 [11:52] :copies a JAB_BLOCK_* record per disk into the buffer, probing the disks on the first call
 buffer :ends the run unless the records written lie inside the program's window
 at :the id of the disk to start at, 0 for the first
 capacity :the records the buffer holds
 count :the records written
 next :the id to start the next page at, 0 once the last disk is in the buffer
ecall sys_block_find serial addr > id a0 u64 [53:95]
 serial :NUL-terminated, ending the run unless it starts inside the program's window
 id :the first disk carrying it, 0 when none does
ecall sys_block_read buffer addr,id u64,sector u64,count u64 > status a0 u64 [96:101] :reads that many sectors of the disk, from that one, into the buffer
 buffer :ends the run unless the whole transfer lies inside the program's window
 status :0, 1 no disk with that id, 2 it would not come up, 3 the device reported an error, 4 those sectors are not on it
ecall sys_block_write buffer addr,id u64,sector u64,count u64 > status a0 u64 [102:105] :writes that many sectors of the buffer to the disk, from that one
 status :sys_block_read's codes
j local block_transfer kind u32,flags u16 > status a0 u64 [107:158] :the transfer both calls share, their arguments in the frame
 kind :in s0, VIRTIO_BLK_T_IN or VIRTIO_BLK_T_OUT
 flags :in s1, VIRTQ_DESC_F_WRITE when the device writes the buffer
 status :sys_block_read's codes
call block_base index u64 > record a0 addr [159:166]
 record :the disk's PCI device record, what block_request takes as the disk
call block_queue index u64 > virtqueue a0 addr [167:174]
call block_record index u64 > record a0 addr [175:182]
 record :the disk's JAB_BLOCK_* record
call block_count_of > count a0 u64 [183:188]
 count :the disks the machine carries, once probed
call block_probe > count block_count u64,records block_records,clobber a0-a6 [189:330] :scans the PCI bus and brings every virtio-blk disk up, once, in slot order, filling its record: each counted before its first request, one on a failed line sent none, a failed or abandoned request ending its probe at kind 0
call block_request record addr,virtqueue addr,type u32,sector u64,buffer addr,length u32,flags u16 > status a0 u8,last VQ_LAST_USED(virtqueue) u64,clobber a1 [331:393] :runs one request on the disk, the hart halted until the device answers or its line is masked, the status then 0xff
 flags :VIRTQ_DESC_F_WRITE when the device writes the buffer, 0 when it reads it
 status :the device's status byte, VIRTIO_BLK_S_OK for success
call local block_progress line u64 > progress a0 u64 [395:419] :the used indexes of every disk on the PCI line summed
call local block_fault line u64 [421:483] :every disk on the line down, its calls answering 2: whether each had a request in flight recorded first, then each reset (vpci_reset)
call local block_report > clobber a0-a3 [484:569] :under DEBUG, a line per probed disk on the debug channel: its kind, its device status read back, the requests offered, whether one was in flight when its line failed, and its source's enable read back from the APLIC
