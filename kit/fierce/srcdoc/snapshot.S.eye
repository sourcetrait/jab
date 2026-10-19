macro snapshot_of index reg,dst reg,scratch reg > address dst addr,scratch scratch [3:8] :a snapshot buffer's address by its index
call local snapshots_init > snapshots snapshots (SNAPSHOT_RING+1)*SNAPSHOT_SIZE u8,ring snapshot_ring SNAPSHOT_RING u32,drawn snapshot_drawn u32,head snapshot_head u32,table crc_table 256 u32 [12:53] :the ring empty, slot k on buffer k and the spare buffer the frame in hand's; CRC-32's table built
call local snapshot_begin frame u32 > snapshot snapshots SNAPSHOT_SIZE u8 [55:66] :the frame in hand's snapshot opened: its number, no packet yet, no span, no actor
call local snapshot_spans > snapshot snapshots SNAPSHOT_SIZE u8 [67:94] :a LEVELS build's packet's spans, x0, x1, and row, into the frame's snapshot, its sequence the packet's in its frame
call local snapshot_actor actor addr > snapshot snapshots SNAPSHOT_SIZE u8 [96:134] :an actor as actor_draw just drew it, its index and its scratch entity's fields, into the frame's snapshot
 actor :the actor's record in actors
call local snapshot_present > ring snapshot_ring SNAPSHOT_RING u32,drawn snapshot_drawn u32,head snapshot_head u32 [136:157] :a presented frame's snapshot into the ring in the oldest's place, that slot's buffer the next frame's; a frame not presented leaves the ring
call local snapshot_export > clobber a0-a2,a7 [159:183] :every snapshot the ring holds written to the API, the oldest first
call local snapshot_write buffer u32 > records snapshot_stage SNAPSHOT_STAGE*REPORT_SIZE u8,clobber a0-a2,a7 [185:297] :one snapshot's records over the API in one write: its span records, its actor records, and its end with the table's CRC-32
 buffer :the buffer's index; an empty one writes nothing
call local record_clear record addr [299:308] :a 64-byte record zeroed
call local crc32 crc u32,bytes addr,length u64 > crc a0 u32,clobber a1-a2 [310:326] :CRC-32 continued over bytes, table-driven by the reflected 0xEDB88320
 crc :all ones before the first bytes; the caller inverts the result
