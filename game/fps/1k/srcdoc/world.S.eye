rodata local k_near_sq_d f64 [3:4] :the near distance squared, within which a masked wall's opening goes unfilled
rodata local k_zero_d f64 [5:6]
rodata local k_flow_near_sq_d f64 [7:9] :the flow's near case squared, 1.522 times the near distance
rodata local k_facing_slack_sq f32 [10:11] :the flow's facing slack, a millimetre squared, the eye on a wall's line within it still flowing the wall
call local world_draw > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,stats stats 22 u64,clobber a0-a7,fa0-fa7 [15:114] :the frame drawn, the depth buffer cleared, the view flowed from the camera's sector or from every sector, the sectors reached drawn in that order, then the sprites and the actors
call local world_flow > rects sector_rect MAX_SECTORS*4 i32,order walk_fifo MAX_SECTORS u32,count walk_tail u64,seen walk_seen MAX_SECTORS u8,clobber a0-a4,fa0-fa3 [116:206] :the view flowed through the portals before any drawing, every sector's rectangle emptied, the camera's sector given the screen or every sector when the camera is in none, then each queued sector flowed, its portals' openings growing the rectangles across, a sector grown queued again
 order :the sectors in the order first reached
call local flow_screen sector u32 > rect sector_rect 4 i32,queue flow_ring FLOW_RING u32,tail flow_tail u64,pending flow_pending MAX_SECTORS u8 [208:217] :a sector's rectangle set to the whole screen and the sector queued, falling into flow_queue
 rect :the sector's entry
call local flow_queue sector u32 > queue flow_ring FLOW_RING u32,tail flow_tail u64,pending flow_pending MAX_SECTORS u8 [219:236] :a sector queued for the flow, unless it waits already
call local rect_grow x0 i32,x1 i32,y0 i32,y1 i32,sector u32 > rect sector_rect 4 i32,queue flow_ring FLOW_RING u32,tail flow_tail u64,pending flow_pending MAX_SECTORS u8,clobber a0 [238:269] :a sector's rectangle grown by one, and the sector queued when it grew; a rectangle inside it already changes nothing
 x1 :the column past the last, with y1 the row past the last
 rect :the sector's entry
call local sector_flow sector u32 > rects sector_rect MAX_SECTORS*4 i32,queue flow_ring FLOW_RING u32,openings STAT_OPENINGS(stats) u64,clobber a0-a4,fa0-fa3 [271:463] :a sector's portals flowed, for each wall facing the camera each portal's opening cut and projected, its rectangle intersected with the sector's, and the neighbour's rectangle grown by it; the eye within the flow's near distance of the wall hands the neighbour the sector's own rectangle
call local opening_cut neighbour u32,ax fs0 f64,ay fs1 f64,bx fs2 f64,by fs3 f64,top_a fs4 f64,top_b fs5 f64,bottom_a fs6 f64,bottom_b fs7 f64 > points a0 u64,projected pverts MAX_CLIPPED*2 f32,edges edges MAX_EDGES*4 f32,clobber a1,fa0-fa3 [465:524] :the opening into a neighbour across the wall in hand cut as a polygon through piece_polygon, the neighbour's ceiling at both ends, clamped to the sector's where it passes it at both, over the neighbour's floor, clamped to the sector's floor the same way
 ax :the wall's start x, with ay its y and bx, by its end
 top_a :the sector's ceiling at the start, top_b at the end
 bottom_a :the sector's floor at the start, bottom_b at the end
 points :the clipped point count, 0 for nothing
call local sector_draw sector u32 > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clip clip_rect 4 i32,clobber a0-a7,fa0-fa3 [526:694] :a sector's planes facing the camera, then its walls facing the camera nearest first, within its rectangle
call local material_bind material i32 > bound a0 bool,surface poly POLY_SIZE u8,clobber a1 [696:757] :a material's texture into the surface in hand, its pixels, size, wraps, and chain, and the material's index for the tile builder
 bound :1, or 0 with the sizes 1 when the material is none or has no texture
call local surface_mode flags u32 > mode POLY_MODE(poly) u64,clobber a0 [759:766] :the polygon's mode from a surface's flags, the sky, else textured, lit with lights
call local poly_mode mode u64 > mode POLY_MODE(poly) u64,clobber a0 [768:782] :the polygon's mode set, the lit flag added when the map has lights and the polygon has no map, a sprite lit flat, or a baked one
call local plane_draw sector u32,ceiling bool > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clobber a0-a7,fa0-fa2 [784:908] :a sector's plane when its surface has a material, every loop's points at the plane's height into one edge list and one even-odd fill
call local piece_polygon top_a f64,top_b f64,bottom_a f64,bottom_b f64,ax fs0 f64,ay fs1 f64,bx fs2 f64,by fs3 f64 > points a0 u64,projected pverts MAX_CLIPPED*2 f32,edges edges MAX_EDGES*4 f32,clobber fa0-fa2 [910:988] :the polygon in hand set to the wall piece between two heights at each end, the quad, the triangle where the planes cross, or nothing
 top_a :the top at the start, top_b at the end
 bottom_a :the bottom at the start, bottom_b at the end
 ax :the wall's start x, with ay its y and bx, by its end
 points :the clipped point count, 0 for nothing
call local piece_cross fraction ft3 f64,ax fs0 f64,ay fs1 f64,bx fs2 f64,by fs3 f64,top_a fs4 f64,top_b fs5 f64 > x fa0 f32,y fa1 f32,z fa2 f32 [990:1000] :the point a fraction along the wall from its start, at the top's height there
 top_a :the top at the start, top_b at the end, as piece_polygon holds them
call local wall_surface sector u32,wall u32,ax fs0 f64,ay fs1 f64,bx fs2 f64,by fs3 f64 > textured a0 bool,surface poly POLY_SIZE u8,plane plane 14 f32,clobber a1-a2,fa1 [1002:1090] :the plane and surface in hand set for a wall, the normal into the sector, u along the wall from its first vertex, v down from its anchor height
 textured :1 when the wall's material has a texture, else 0
call local wall_within distance f64,ax fs0 f64,ay fs1 f64,bx fs2 f64,by fs3 f64 > within a0 bool [1092:1118] :whether the camera is within a distance of the wall in hand, in the plan
 distance :the distance, squared
call local wall_draw sector u32,wall u32 > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clobber a0-a7,fa0-fa3 [1120:1296] :a wall of a sector facing the camera, its portals from the top down, the solid pieces between them and, on a masked wall, its surface over each opening
call local uncovered > count a0 u64 [1298:1311] :how many pixels no surface reached this frame, the depth buffer's zeros
bss local walk_tail u64 [1315:1316] :the sectors in walk_fifo
bss local stats 22 u64 [1317:1318] :the frame's counts and its ticks by phase, STAT_* fields
bss local walk_fifo MAX_SECTORS u32 [1319:1320] :the sectors in the order the flow first reached them, the draw order
bss local walk_seen MAX_SECTORS u8 [1321:1323] :1 for a sector the flow reached this frame
bss local wall_order MAX_WALLS u64 [1324:1326] :a sector's facing walls in the order they are drawn, the key, the squared distance from the eye to the wall's nearest point as a float, then the wall
bss local sector_rect MAX_SECTORS*4 i32 [1327:1328] :every sector's screen rectangle, the union of the openings it is seen through
bss local flow_pending MAX_SECTORS u8 [1329:1331] :the flow's waiting flags
bss local flow_ring FLOW_RING u32 [1332:1333] :the flow's ring of sectors
bss local flow_head u64 [1334:1335] :the ring's read
bss local flow_tail u64 [1336:1337] :the ring's write
bss local clip_rect 4 i32 [1338:1339] :the rectangle the spans in hand are clipped to
