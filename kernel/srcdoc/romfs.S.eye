set ROMFS_MAGIC_LOW u32 [6] :"-rom" as the little-endian word a load sees
set ROMFS_MAGIC_HIGH u32 [7] :"1fs-" likewise
set ROMFS_HEADER u64 [8] :bytes in a header before its name
set ROMFS_BOUNCE_SECTORS u64 [9] :the sectors the bounce holds
set ROMFS_BOUNCE_BYTES u64 [10]
set ROMFS_NAME_LIMIT u64 [11] :past this a name is not long but corrupt
set ROMFS_LINK_LIMIT u64 [12] :the hard links followed before a chain is taken as endless
ecall sys_romfs_list buffer address,id u64,directory u64,offset u64,capacity u64 > count a0 u64,next a1 u64 [17:54] :writes a JAB_ROMFS_* record per entry of the directory into the buffer
 buffer :ends the run where a record would be written outside the program's window
 id :ends the run when the machine has no such disk or it carries no romfs
 directory :its header offset, JAB_ROMFS_ROOT for the root
 offset :the entry this page starts at, 0 for the directory's first
 capacity :the records the buffer holds
 count :the records written
 next :the offset to start the next page at, 0 once the chain has ended
ecall sys_romfs_find buffer address,id u64,directory u64,path address > status a0 u64,offset a1 u64 [55:82] :looks for the path from the directory and writes the entry's record into the one-record buffer, hard links followed
 path :components separated by /, a leading / starting at the root, an empty one skipped
 status :0 found, 1 nothing of that name, 2 a component along the way is not a directory
 offset :the entry's own header offset, 0 unless found
call romfs_lookup disk u64,directory u64,path address,end address > status a0 u64,offset a1 u64,record romfs_scratch,clobber a2-a6 [83:191] :the walk of sys_romfs_find
 disk :the disk's index
 end :where the path ends
 status :sys_romfs_find's
 record :the entry's JAB_ROMFS_* record when found
ecall sys_romfs_read buffer address,id u64,file u64,offset u64,length u64 > written a0 u64,next a1 u64 [192:295] :reads at most that many bytes of the file, from that byte of it, into the buffer
 buffer :ends the run unless the bytes read lie inside the program's window
 file :its header offset, a regular file or a symlink, the run ended otherwise
 next :the offset to read from next, 0 at the file's end
call romfs_magic sector address > magic a0 bool [296:308]
 magic :1 when the sector opens with the volume magic
call romfs_disk id u64 > index a0 u64 [309:334] :ends the run when the machine has no such disk or it carries no romfs
call local romfs_volume disk u64 > root a0 u64,size a1 u64,roots romfs_roots u64,sizes romfs_sizes u64,clobber a2-a6 [336:399] :the root header's offset and the accessible size, read and checked on the first call for the disk
 disk :the disk's index, the run ended when it holds no sound volume
call local romfs_chain disk u64,directory u64 > first a0 u64,record romfs_scratch,clobber a1-a6 [401:423] :the offset of the directory's first entry, a hard link followed first
 directory :its header offset, JAB_ROMFS_ROOT for the root, the run ended when it is not a directory
call local romfs_resolve disk u64,header u64 > target a0 u64,record romfs_scratch,clobber a1-a6 [425:456] :follows hard links to what they stand for, the run ended on a chain with no end
 record :the target's
call romfs_entry disk u64,header u64,record address > metadata a0 u64,entry 0(record),clobber a1-a6 [457:537] :reads the header, holds it to its checksum, and writes the record of jab.inc, the run ended on a bad header
 metadata :the length of the header and its name, how far after it a file's data begins
call romfs_window disk u64,offset u64 > at a0 address,readable a1 u64,clobber a2-a6 [538:606] :reads the sectors holding the offset into the bounce, as many as it and the disk allow, the run ended on a disk error or an offset past the disk
 at :that byte's address in the bounce
 readable :the bytes there from it
call local romfs_be32 at address > word a0 u32 [608:619]
call local romfs_checksum at address,size u64 > sum a0 u32,clobber a1 [621:642]
 size :a multiple of four
 sum :of the big-endian longwords there, zero over a sound header
call local romfs_strnlen at address,limit u64 > length a0 i64 [644:658]
 length :-1 when no terminator is within reach
call local romfs_name_equal name address,length u64 > equal a0 bool [660:681]
 equal :1 when the scratch record carries the same name
j local romfs_fault_disk_id id u64 [683:689] :ends the run with a line naming the disk id the machine lacks
j local romfs_fault_not_romfs id u64 [691:697] :ends the run with a line naming the disk that carries no romfs
j local romfs_fault_header offset u64 [699:705] :ends the run with a line naming the bad header
j local romfs_fault_kind offset u64 [707:713] :ends the run with a line naming the header of the wrong kind
j local romfs_fault_disk [715:718] :ends the run with a line for a disk error
j local romfs_fault_end [720:724] :ends a fault line and the run with 1
bss local romfs_bounce 2048 u8 [728:730] :the bounce, sectors as the disk holds them
bss romfs_scratch [731:732] :the JAB_ROMFS_* record a header is read into
bss local romfs_roots 8 u64 [733:734] :each disk's root header offset, 0 until read
bss local romfs_sizes 8 u64 [735:736] :each disk's accessible size
bss local romfs_bounce_disk u64 [737:738] :the disk the bounce holds, its index plus 1, 0 for none
bss local romfs_bounce_sector u64 [739:740] :the first sector it holds
bss local romfs_bounce_count u64 [741:742] :the sectors it holds
rodata local msg_romfs_disk_id 21 u8 [745:746]
rodata local msg_romfs_not_romfs 30 u8 [747:748]
rodata local msg_romfs_header 27 u8 [749:750]
rodata local msg_romfs_kind 27 u8 [751:752]
rodata local msg_romfs_disk_error 23 u8 [753:754]
