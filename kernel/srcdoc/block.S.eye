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
call block_probe > count block_count u64,records block_records,clobber a0-a6 [188:314] :scans the PCI bus and brings every virtio-blk disk up, once, in slot order, filling its record
rodata local msg_disk_pci 23 u8 [238:239] :the debug line naming a disk's PCI slot, under DEBUG only
call block_request record addr,virtqueue addr,type u32,sector u64,buffer addr,length u32,flags u16 > status a0 u8,last VQ_LAST_USED(virtqueue) u64,clobber a1 [315:370] :runs one request on the disk, the hart halted until the device answers
 flags :VIRTQ_DESC_F_WRITE when the device writes the buffer, 0 when it reads it
 status :the device's status byte, VIRTIO_BLK_S_OK for success
bss local block_queues [374:376] :the disks' virtqueue records, VQ_STRIDE apart
bss local block_records [377:378] :the disks' JAB_BLOCK_* records, the program-facing list
bss local block_bases 8 addr [379:380] :each disk's PCI device record
bss local block_count u64 [381:382] :the disks found
bss local block_probed u64 [383:384] :1 once the probe has run
bss local block_header [385:386] :the request header the device reads
bss local block_status u8 [387:390] :the status byte the device writes
bss block_bounce 512 u8 [391:392] :a sector the kernel reads through
