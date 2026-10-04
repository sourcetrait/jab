ecall sys_png_size source addr,length u64 > width a0 u64,height a1 u64,status a2 u64 [26:49] :a PNG's width and height from its header
 source :ends the run unless the whole of it lies inside the program's window
 width :0 unless the status is JAB_PNG_OK, as is the height
 status :JAB_PNG_OK, NOT_PNG, TRUNCATED, CRC, or UNSUPPORTED
ecall sys_sprite_png sprite addr,source addr,length u64,capacity u64,frames u64 > status a0 u64,record 0(sprite) [50:101] :decodes the PNG into the sprite record as a sheet of that many frames stacked top to bottom, with the span table
 sprite :ends the run unless the capacity lies inside the program's window, as must the source
 capacity :the bytes the record's buffer holds
 status :JAB_PNG_OK, FRAMES when the height does not divide, SIZE when the buffer is short, else what is wrong with the file
ecall sys_sprite_load sprite addr,id u64,path addr,capacity u64 > status a0 u64,record 0(sprite) [102:196] :fills the sprite record from the files 0.png, 1.png, and on in a directory on the disk, in order until one is missing, each decoded off the disk into its own frame
 id :ends the run when the machine has no such disk or it carries no romfs
 path :ends the run unless it starts inside the program's window
 status :JAB_PNG_OK, NOT_FOUND when the directory or its 0.png is not there, FRAMES when a frame's size differs from the first's, SIZE when the buffer is short, else a frame's own code
call local png_frame_source number u64 > status a0 u64,length png_len u64,data png_data u64,disk png_disk u64,kind png_kind u64,clobber a1-a6 [198:260] :makes <number>.png in the directory the source when it is a regular file
 number :the frame's; the disk's index in s0 and the directory's header in s3, as sys_sprite_load holds them
 status :JAB_PNG_OK or JAB_PNG_NOT_FOUND
call local png_from_memory bytes addr,length u64 > source png_src addr,length png_len u64,kind png_kind u64 [262:269] :makes the bytes the program holds the source
call local png_fetch offset u64,length u64,destination addr > clobber a0-a6 [271:322] :copies that range of the source's file, which the caller has kept inside it
call local png_be32 at addr > word a0 u32 [324:335] :the big-endian longword at a kernel buffer, how PNG writes every number
call local png_le32_store value u32,at addr > field 0(at) u32 [337:345] :stores the low 32 bits little-endian a byte at a time
call local png_room width u64,height u64,capacity u64 > status a0 u64 [347:360]
 height :the whole sheet's
 status :JAB_PNG_OK when the buffer reaches the rule, else JAB_PNG_SIZE
call local png_header > status a0 u64,width png_width u64,height png_height u64,depth png_depth u64,type png_type u64,channels png_channels u64,bpp png_bpp u64,rowbytes png_rowbytes u64,filtered png_filtered u64,cursor png_pos u64,clobber a1-a6 [362:505] :reads the source's signature and IHDR and stands the chunk cursor after them
 status :JAB_PNG_OK, NOT_PNG, TRUNCATED, CRC, or UNSUPPORTED
call local png_decode pixels addr > status a0 u64,image 0(pixels),clobber a1-a7 [507:644] :the chunk walk, the stream, the filters, the conversion, after png_header has read the source
 pixels :where the pixels go, the decode in place there
 status :JAB_PNG_OK or the code
call local png_chunk_ok offset u64,length u64 > valid a0 bool,clobber a1-a6 [646:709]
 valid :1 when the CRC-32 run over the chunk's type and data agrees with the one after the data
call local png_stream offset u64,length u64 > status a0 u64,cursor png_pos u64,chunk png_chunk_len u64,clobber a1-a6 [711:796] :inflates the zlib stream through every IDAT from the first into the pixel area and checks its Adler-32
 offset :the first IDAT's, as length is its length
 cursor :on the IDAT the stream ended in
 status :JAB_PNG_OK or the code
call local png_chunk_begin > state png_crc_state u64,clobber a0-a6 [798:819] :starts the running CRC of the chunk the cursor stands on, over its type
call local png_more > more a0 bool,cursor png_pos u64,chunk png_chunk_len u64,done png_chunk_done u64,code png_hook_code u64,clobber a1-a6 [821:925] :the decoder's hook, the next piece of the stream's IDATs made its segment
 more :1 with a segment in place, else 0 with the cursor where it was
 code :why, when a chunk was there but could not be taken
call local png_adler buffer addr,length u64 > adler a0 u32,clobber a1 [927:956]
call local png_unfilter > status a0 u64,clobber a1-a7 [958:1093] :undoes each row's filter against the row above, in place
 status :JAB_PNG_OK, or JAB_PNG_FILTER on a filter type that does not exist
call local png_convert > status a0 u64,clobber a1-a7 [1095:1323] :turns the unfiltered rows into native pixels in place, four bytes each
 status :JAB_PNG_OK, or JAB_PNG_PALETTE for an indexed image with no palette or an index past it
