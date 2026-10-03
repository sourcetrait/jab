rodata local k_lumel_d f64 [3:4] :half a metre, a lumel's aim along u
rodata local k_sqrt2_mantissa u64 [5:7] :root two's mantissa, past which k rounds up
rodata local k_light_ambient f32 [8:9] :the ambient in each channel
rodata local k_light_none f32 [10:11] :a point light's spread cosine, under -1
rodata local k_light_minus_one f32 [12:13]
rodata local k_depth_scale f32 [14:16] :2^26, one in 6.26
rodata local msg_lumels 17 u8 [17:18]
rodata local word_baked_in 11 u8 [19:20]
rodata local word_lumels 10 u8 [21:22]
rodata local word_unmapped 10 u8 [23:25]
call local lights_gather > lights lights MAX_LIGHTS*12 f32,count light_count u32,entities entity_light MAX_ENTITIES i32,lists sector_lights MAX_SECTORS*SECTOR_LIGHTS_SIZE u8,clobber a0,fa0-fa1 [29:166] :the light entities into the light table, then each sector's list of light indices from the file's
call local verts_bounds > xmin fa0 f32,xmax fa1 f32,ymin fa2 f32,ymax fa3 f32,zmin fa4 f32,zmax fa5 f32 [168:193] :the world box of the polygon in hand's points
call local plane_box sector addr,plane addr > xmin fa0 f32,xmax fa1 f32,ymin fa2 f32,ymax fa3 f32,zmin fa4 f32,zmax fa5 f32 [195:221] :the world box of a sector's plane, its bounds in the plan and the plane's height at their corners
 plane :its a, b, c
call local lights_cull xmin f32,xmax f32,ymin f32,ymax f32,zmin f32,zmax f32 > list POLY_LIGHTS(poly) 32 u8,clobber a5 [223:292] :the surface's sector's lights culled into the polygon's own list, a light staying when its sphere meets the box and, unless the surface is lit at no angle, it lies ahead of the plane's normal facing the camera
call local span_light pixel i32,row i32,iz i64 > bright a0 u64,clobber a2,fa0-fa7 [293:352] :the brightness at a pixel of the surface in hand over the polygon's list, for a dynamic light, the world point down the pixel's ray, then point_light under the surface's normal facing the camera
 iz :1/z there, 6.26
 bright :the three channels in 16.16 packed CHANNEL_BITS apart
call local point_light x f32,y f32,z f32,nx f32,ny f32,nz f32,flat t6 bool,list t2 addr > bright a0 u64,clobber fa6-fa7 [354:440] :the brightness at a world point of a surface, the ambient plus each light of a list in reach, in single precision throughout
 nx :the unit normal's x, with ny and nz
 flat :1 lit at no angle, every light in reach by its falloff alone
 list :a count byte then that many light indices
 bright :the three channels in 16.16 packed CHANNEL_BITS apart
call local lumel_pack bright u64 > lumel a0 u64 [442:453] :a brightness word's channels as a lumel's, each lane's 16.16 to 256ths
call local lumaps_bake > maps lumaps LUMAP_COUNT*6 u64,lumels lumel_arena LUMEL_ARENA_BYTES u8,cursor lumel_cursor addr,clobber a0-a1,a5,a7,fa0-fa7 [455:881] :every textured surface's lumel map baked in the surface's own texels, the sector planes then the walls, each over the sector's lights culled to the surface; a line on the UART of a debug build; with no lights none bakes and every surface draws unlit
call local lumap_frame record addr,umin f64,umax f64,vmin f64,vmax f64,texels f64 > frame LUMAP_W(record) 5 u64 [883:929] :a map's frame from the surface's texel range, k, the lumel's texels as the power of two nearest half a metre along u; the origin, a multiple of the texture's size at or below the least texel less one on each axis; the columns and rows reaching a node past the greatest texel, two at the least
 umin :the least texel u of the surface, with umax the greatest
 vmin :the least texel v, with vmax the greatest
 texels :the texels a metre along u
 frame :LUMAP_W, LUMAP_H, LUMAP_U0, LUMAP_V0, and LUMAP_K
call local lumap_fill record addr > lumels lumel_arena LUMEL_ARENA_BYTES u8,base LUMAP_BASE(record) addr,cursor lumel_cursor addr,clobber a0,fa0-fa7 [931:1032] :a map's lumels baked over bake_grid into the arena from the cursor, each node's point under the normal over the polygon's list through point_light; the record's base, or none when the arena is full, which counts the map unmapped
 record :the record, its frame set
bss local light_count u32 [1036:1038] :the lights in the table
bss local lights MAX_LIGHTS*12 f32 [1039:1040] :the light table, LIGHT_* fields
bss local sector_lights MAX_SECTORS*SECTOR_LIGHTS_SIZE u8 [1041:1042] :each sector's list, a count byte then that many light indices
bss local entity_light MAX_ENTITIES i32 [1043:1045] :each entity's light index, -1 for an entity that is no light
bss local lumel_cursor addr [1046:1047] :the arena's next free lumel
bss local lumap_count u64 [1048:1049] :the maps baked
bss local lumel_count u64 [1050:1051] :the lumels in them
bss local lumap_missing u64 [1052:1053] :the textured surfaces left without a map
bss local bake_grid GRID_SIZE u8 [1054:1056] :the frame the map in hand is baked over, GRID_* fields
bss local lumaps LUMAP_COUNT*6 u64 [1057:1059] :every surface's map, LUMAP_* fields
bss local lumel_arena LUMEL_ARENA_BYTES u8 [1060:1061] :every map's lumels
