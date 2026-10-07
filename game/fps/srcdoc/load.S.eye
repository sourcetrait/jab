call local map_parse > sections sections KIND_COUNT*2 u64 [20:117] :the header and the section directory held to the format, every section's address and count into sections; a fault exits
j local directory_count [119:121] :exits 12, the directory holding more sections than the format has kinds
j local directory_kind [123:125] :exits 12, the directory naming a kind the format lacks
j local directory_twice [127:129] :exits 12, the directory naming a kind twice
j local directory_aligned [131:133] :exits 12, the directory putting a section off a word boundary
j local directory_size [135:137] :exits 12, the directory giving a section a record size the format does not
j local directory_missing [139:141] :exits 12, the directory lacking a kind
call local name_check offset u32 > held a0 bool [143:160] :whether the names table holds a NUL-terminated name at the offset
call local map_check > spawn spawn_index i32,sprites sprite_count u32,clobber a0-a5,fa0-fa2 [162:558] :the records held to the format's rules, the first to break one named on the UART with exit 11
 spawn :the first spawn's index
 sprites :the sprite entities counted
call local materials_load disk s0 u64 > records material_record MAX_MATERIALS addr,loaded texture_count u32,missing missing_count u32,cursor pixel_cursor addr,clobber a0-a4,a7 [560:617] :every material's texture read off the disk at /<name>.png and decoded into the pixel arena
call local material_read index u32,message addr,disk s0 u64,path tile_path u8 > record a0 addr,cursor pixel_cursor addr,clobber a1-a4,a7 [619:698] :the texture at a path read whole and decoded into the pixel arena; a load that fails exits
 index :the material's index, for the UART
 message :the line's start on the UART of a debug build
 record :the texture's record, 0 when the file is not there, named as missing on a debug build
call local frames_load disk s0 u64 > base frame_base u32,records material_record MAX_MATERIALS addr,cursor pixel_cursor addr,clobber a0-a4,a7 [700:793] :the engine's own images read off the disk at /sprite/<stem>.png into the material records after the map's
 base :the first image's material index
call local ambients_load disk s0 u64 > pieces ambient_at MAX_AMBIENTS addr,bytes ambient_bytes MAX_AMBIENTS u64,playing ambient_playing i32,cursor ambient_cursor addr,clobber a0-a4,a7 [795:898] :every ambient piece read off the disk at /<name>.mid into its arena; one not there, too long a name, or not fitting is named on the UART of a debug build and left as none
 playing :-1, nothing playing
call local soundfont_load > font font FONT_BYTES u8,clobber a0-a4,a7 [900:955] :the generic disk's soundfont put into the synthesizer, its counts on the UART of a debug build; without the disk or the file the chip voices play
call local ambient_follow > playing ambient_playing i32,clobber a0-a1,a7 [957:1029] :the piece of the camera's sector played, a change stopping the one playing and starting the new, said on the UART of a debug build; a piece that has ended starts again
