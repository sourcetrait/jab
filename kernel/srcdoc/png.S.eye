set PNG_SIG_LOW u32 [4] :the signature's first word, as the big-endian word a read sees
set PNG_SIG_HIGH u32 [5] :its second
set PNG_IHDR u32 [6] :the chunk types as big-endian words
set PNG_PLTE u32 [7]
set PNG_TRNS u32 [8]
set PNG_IDAT u32 [9]
set PNG_IEND u32 [10]
set PNG_HEADER_END u64 [11] :the signature and the IHDR chunk, where the chunks after it begin
set PNG_ADLER_MOD u64 [12] :the modulus of Adler-32
set PNG_ADLER_RUN u64 [13] :bytes between reductions of the Adler sums
set PNG_SIDE_LIMIT u64 [14] :past this a width or height cannot fit any buffer a program has
set PNG_DEFLATE_BASE u64 [15] :what turns a deflate code of 1 to 7 into JAB_PNG_INPUT to JAB_PNG_DISTANCE
set PNG_SEGMENT u64 [16] :a piece of a chunk, as it is read and handed to the decoder
set PNG_PLTE_MAX u64 [17] :the longest palette chunk taken
set PNG_TRNS_MAX u64 [18] :the longest transparency chunk taken
set PNG_FROM_MEMORY u64 [19] :a source the program holds
set PNG_FROM_DISK u64 [20] :a source on a romfs disk
set PNG_NAME_BYTES u64 [21] :a frame's name, digits and .png
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
bss local png_kind u64 [1327:1328] :the source's kind, PNG_FROM_MEMORY or PNG_FROM_DISK
bss local png_src addr [1329:1330] :the program's bytes
bss local png_len u64 [1331:1332] :the file's length
bss local png_disk u64 [1333:1334] :the disk's index
bss local png_data u64 [1335:1336] :where the file's bytes begin on the disk
bss local png_pos u64 [1337:1338] :the chunk cursor, an offset into the file
bss local png_chunk_len u64 [1339:1340] :the length of the IDAT the stream is in
bss local png_chunk_done u64 [1341:1342] :the bytes of it handed on
bss local png_crc_state u64 [1343:1344] :that chunk's running CRC
bss local png_crc_word u64 [1345:1346] :the IHDR's CRC as computed
bss local png_width u64 [1347:1348]
bss local png_height u64 [1349:1350]
bss local png_depth u64 [1351:1352] :the bit depth
bss local png_type u64 [1353:1354] :the colour type
bss local png_channels u64 [1355:1356] :the samples a pixel
bss local png_bpp u64 [1357:1358] :bytes a pixel for the filters, at least one
bss local png_rowbytes u64 [1359:1360] :bytes a row without its filter byte
bss local png_filtered u64 [1361:1362] :the filtered size of the whole image
bss local png_pixels addr [1363:1364] :where the pixels go
bss local png_plte addr [1365:1366] :the palette, 0 with none
bss local png_plte_count u64 [1367:1368] :its entries
bss local png_trns addr [1369:1370] :the transparency, 0 with none
bss local png_trns_len u64 [1371:1372] :its bytes
bss local png_seen_idat u64 [1373:1374] :1 once the stream has been read
bss local png_hook_code u64 [1375:1376] :why the hook stopped, 0 when the bytes simply ended
bss local png_head 40 u8 [1377:1378] :the signature and the IHDR as read
bss local png_chunkhead 8 u8 [1379:1380] :a chunk's length and type, or a CRC
bss local png_name 32 u8 [1381:1382] :a frame's name, built from the end
bss local png_plte_buf 768 u8 [1383:1384]
bss local png_trns_buf 256 u8 [1385:1386]
bss local png_seg 2048 u8 [1387:1388] :the piece of a chunk last read
