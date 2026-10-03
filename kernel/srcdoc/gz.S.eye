set GZ_MAGIC0 u8 [4] :a gzip's first byte
set GZ_MAGIC1 u8 [5] :its second
set GZ_DEFLATE u8 [6] :the compression method byte for DEFLATE
set GZ_FHCRC u8 [7] :the header's flag for a header CRC
set GZ_FEXTRA u8 [8] :the flag for an extra field
set GZ_FNAME u8 [9] :the flag for a name
set GZ_FCOMMENT u8 [10] :the flag for a comment
set GZ_HEADER u64 [11] :bytes in the fixed header
set GZ_TRAILER u64 [12] :bytes in the trailer, the CRC-32 then the length
set GZ_CRC_TICK u64 [13] :bytes the CRC takes in between looks at the sound stream
ecall sys_gz_size source addr,length u64 > size a0 u64,status a1 u64 [18:49]
 source :ends the run unless the whole of it lies inside the program's window
 size :the length the contents will be, from the trailer; 0 when not a gzip
 status :JAB_GZ_OK or JAB_GZ_NOT_GZIP
ecall sys_gz_read buffer addr,source addr,length u64,capacity u64 > written a0 u64,status a1 u64 [50:114] :inflates the gzip into the buffer in one call, its CRC-32 and length checked
 buffer :ends the run unless the whole of it lies inside the program's window, as does the source
 written :the bytes inflated, 0 when the header or the stream failed
 status :a JAB_GZ_* code
call local gz_check bytes addr,length u64 > bad a0 bool [116:132]
 bad :0 when the bytes open as a gzip of deflated data long enough to carry a trailer
call local gz_body bytes addr,length u64 > offset a0 i64 [134:175]
 offset :where the compressed bytes start, past whatever of the header is optional; -1 when the header runs off the end
call local gz_le32 at addr > word a0 u32 [177:190]
 at :in t0, not a0
call gz_crc32 buffer addr,length u64 > crc a0 u32,clobber a1-a2 [191:205] :the reflected CRC-32 of the bytes
call gz_crc_begin > state a0 u32 [206:215] :a fresh CRC-32's running state, the table built if it was not
call gz_crc_update state u32,buffer addr,length u64 > state a0 u32 [216:244] :takes the bytes into the state, looking at the sound stream every GZ_CRC_TICK of them
call gz_crc_end state u32 > crc a0 u32 [245:249]
call local gz_crc_table > table gz_crc u32,ready gz_crc_ready u64 [251:279] :builds the reflected CRC-32's 256 entries on first use
bss local gz_crc_ready u64 [283:285] :1 once the table is built
bss local gz_crc 256 u32 [286:287] :the reflected CRC-32's table
