rodata local kind_sizes KIND_COUNT u32 [3:5] :a kind's record size, by kind from 1
rodata local kind_limits KIND_COUNT u32 [6:9] :the most of a kind this build holds, by kind from 1
rodata local kind_words KIND_COUNT address [10:14] :a kind's word, by kind from 1
rodata local k_slack_d f64 [15:16] :the spawn's slack about its sector's planes
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
call local materials_load disk s0 u64 > records material_record MAX_MATERIALS address,loaded texture_count u32,missing missing_count u32,cursor pixel_cursor address,clobber a0-a4,a7 [560:617] :every material's texture read off the disk at /<name>.png and decoded into the pixel arena
call local material_read index u32,message address,disk s0 u64,path tile_path u8 > record a0 address,cursor pixel_cursor address,clobber a1-a4,a7 [619:698] :the texture at a path read whole and decoded into the pixel arena; a load that fails exits
 index :the material's index, for the UART
 message :the line's start on the UART of a debug build
 record :the texture's record, 0 when the file is not there, named as missing on a debug build
call local frames_load disk s0 u64 > base frame_base u32,records material_record MAX_MATERIALS address,cursor pixel_cursor address,clobber a0-a4,a7 [700:793] :the engine's own images read off the disk at /sprite/<stem>.png into the material records after the map's
 base :the first image's material index
call local ambients_load disk s0 u64 > pieces ambient_at MAX_AMBIENTS address,bytes ambient_bytes MAX_AMBIENTS u64,playing ambient_playing i32,cursor ambient_cursor address,clobber a0-a4,a7 [795:898] :every ambient piece read off the disk at /<name>.mid into its arena; one not there, too long a name, or not fitting is named on the UART of a debug build and left as none
 playing :-1, nothing playing
call local soundfont_load > font font FONT_BYTES u8,clobber a0-a4,a7 [900:955] :the generic disk's soundfont put into the synthesizer, its counts on the UART of a debug build; without the disk or the file the chip voices play
call local ambient_follow > playing ambient_playing i32,clobber a0-a1,a7 [957:1029] :the piece of the camera's sector played, a change stopping the one playing and starting the new, said on the UART of a debug build; a piece that has ended starts again
bss local kind_seen 16 u8 [1033:1034] :the kinds the directory named, a byte a kind
bss local ambient_playing i32 [1035:1036] :the ambient playing, -1 for none
bss local frame_base u32 [1037:1038] :the material index of the engine's first image, after the map's
rodata local word_kind_names 6 u8 [1041:1042]
rodata local word_kind_materials 10 u8 [1043:1044]
rodata local word_kind_vertices 9 u8 [1045:1046]
rodata local word_kind_sectors 8 u8 [1047:1048]
rodata local word_kind_loops 6 u8 [1049:1050]
rodata local word_kind_walls 6 u8 [1051:1052]
rodata local word_kind_portals 8 u8 [1053:1054]
rodata local word_kind_entities 9 u8 [1055:1056]
rodata local word_kind_ambients 9 u8 [1057:1058]
rodata local word_kind_sector_lights 14 u8 [1059:1060]
rodata local word_directory_count 46 u8 [1061:1062]
rodata local word_directory_kind 30 u8 [1063:1064]
rodata local word_directory_twice 19 u8 [1065:1066]
rodata local word_directory_aligned 35 u8 [1067:1068]
rodata local word_directory_size 50 u8 [1069:1070]
rodata local word_directory_missing 13 u8 [1071:1072]
rodata local word_material 10 u8 [1073:1074]
rodata local word_ambient 9 u8 [1075:1076]
rodata local word_sector 8 u8 [1077:1078]
rodata local word_loop 6 u8 [1079:1080]
rodata local word_wall 6 u8 [1081:1082]
rodata local word_portal 8 u8 [1083:1084]
rodata local word_entity 8 u8 [1085:1086]
rodata local word_sector_light 14 u8 [1087:1088]
rodata local word_name_past 34 u8 [1089:1090]
rodata local word_loops_range 26 u8 [1091:1092]
rodata local word_lights_range 27 u8 [1093:1094]
rodata local word_ambient_range 27 u8 [1095:1096]
rodata local word_materials_range 30 u8 [1097:1098]
rodata local word_under_three 23 u8 [1099:1100]
rodata local word_walls_range 26 u8 [1101:1102]
rodata local word_other_sector 43 u8 [1103:1104]
rodata local word_not_next 43 u8 [1105:1106]
rodata local word_vertices_range 41 u8 [1107:1108]
rodata local word_sector_range 26 u8 [1109:1110]
rodata local word_portals_range 28 u8 [1111:1112]
rodata local word_material_range 28 u8 [1113:1114]
rodata local word_out_of_range 17 u8 [1115:1116]
rodata local word_not_exact 14 u8 [1117:1118]
rodata local word_class_unknown 35 u8 [1119:1120]
rodata local word_references_range 31 u8 [1121:1122]
rodata local word_outside_sector 22 u8 [1123:1124]
rodata local word_outside_planes 36 u8 [1125:1126]
rodata local word_not_light 16 u8 [1127:1128]
rodata local word_no_spawn 14 u8 [1129:1130]
rodata local serial_mix 4 u8 [1131:1132] :the generic disk's serial
rodata local path_font 29 u8 [1133:1134] :the soundfont's path on the generic disk
rodata local word_sprite_dir 9 u8 [1135:1136]
rodata local word_android_dir 9 u8 [1137:1139]
rodata local msg_soundfont 16 u8 [1140:1141]
rodata local word_presets 11 u8 [1142:1143]
rodata local word_instruments 15 u8 [1144:1145]
rodata local word_samples 9 u8 [1146:1147]
rodata local msg_soundfont_refused 24 u8 [1148:1149]
rodata local msg_no_soundfont 43 u8 [1150:1151]
rodata local word_playing 9 u8 [1152:1153]
rodata local word_refused 10 u8 [1154:1155]
rodata local msg_frames 13 u8 [1156:1157]
rodata local msg_frame_missing 12 u8 [1158:1159]
rodata local word_loaded_comma 10 u8 [1160:1162]
