ecall sys_block_list buffer addr,at u64,capacity u64 > count a0 u64,next a1 u64 [10:51] :copies a JAB_BLOCK_* record per disk into the buffer, probing the disks on the first call
 buffer :ends the run unless the records written lie inside the program's window
 at :the id of the disk to start at, 0 for the first
 capacity :the records the buffer holds
 count :the records written
 next :the id to start the next page at, 0 once the last disk is in the buffer
ecall sys_block_find serial addr > id a0 u64 [52:94]
 serial :NUL-terminated, ending the run unless it starts inside the program's window
 id :the first disk carrying it, 0 when none does
ecall sys_block_read buffer addr,id u64,sector u64,count u64 > status a0 u64 [95:100] :reads that many sectors of the disk, from that one, into the buffer
 buffer :ends the run unless the whole transfer lies inside the program's window
 status :0, 1 no disk with that id, 2 it would not come up, 3 the device reported an error, 4 those sectors are not on it
ecall sys_block_write buffer addr,id u64,sector u64,count u64 > status a0 u64 [101:104] :writes that many sectors of the buffer to the disk, from that one
 status :sys_block_read's codes
j local block_transfer kind u32,flags u16 > status a0 u64 [106:157] :the transfer both calls share, their arguments in the frame
 kind :in s0, VIRTIO_BLK_T_IN or VIRTIO_BLK_T_OUT
 flags :in s1, VIRTQ_DESC_F_WRITE when the device writes the buffer
 status :sys_block_read's codes
call block_base index u64 > record a0 addr [158:165]
 record :the disk's PCI device record, what block_request takes as the disk
call block_queue index u64 > virtqueue a0 addr [166:173]
call block_record index u64 > record a0 addr [174:181]
 record :the disk's JAB_BLOCK_* record
call block_count_of > count a0 u64 [182:187]
 count :the disks the machine carries, once probed
call block_probe > count block_count u64,records block_records,clobber a0-a6 [188:316] :scans the PCI bus and brings every virtio-blk disk up, once, in slot order, filling its record
call block_request record addr,virtqueue addr,type u32,sector u64,buffer addr,length u32,flags u16 > status a0 u8,last VQ_LAST_USED(virtqueue) u64,clobber a1 [317:376] :runs one request on the disk, the hart halted until the device answers or its line is masked, the status then 0xff
 flags :VIRTQ_DESC_F_WRITE when the device writes the buffer, 0 when it reads it
 status :the device's status byte, VIRTIO_BLK_S_OK for success
call local block_progress line u64 > progress a0 u64 [378:402] :the used indexes of every disk on the PCI line summed
call local block_fault line u64 [404:425] :every disk on the line down, its calls answering 2
