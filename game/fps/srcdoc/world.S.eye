call local world_draw > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,stats stats 44 u64,workers round_workers u32,grain round_grain u32,first round_first u8,clobber a0-a7,fa0-fa7 [15:175] :the frame drawn, its workers and grain taken from the console's, the depth buffer cleared under the serial backend or left to the first round's bands, the tile pool's boundary run and on a debug build its writes snapshotted, the view flowed from the camera's sector or from every sector, the sectors reached prepared into the packet in that order, then the sprites and the actors, the packet rendered last
call local world_flow > rects sector_rect MAX_SECTORS*4 i32,order walk_fifo MAX_SECTORS u32,count walk_tail u64,seen walk_seen MAX_SECTORS u8,clobber a0-a4,fa0-fa3 [177:267] :the view flowed through the portals before any drawing, every sector's rectangle emptied, the camera's sector given the screen or every sector when the camera is in none, then each queued sector flowed, its portals' openings growing the rectangles across, a sector grown queued again
 order :the sectors in the order first reached
call local flow_screen sector u32 > rect sector_rect 4 i32,queue flow_ring FLOW_RING u32,tail flow_tail u64,pending flow_pending MAX_SECTORS u8 [269:278] :a sector's rectangle set to the whole screen and the sector queued, falling into flow_queue
 rect :the sector's entry
call local flow_queue sector u32 > queue flow_ring FLOW_RING u32,tail flow_tail u64,pending flow_pending MAX_SECTORS u8 [280:297] :a sector queued for the flow, unless it waits already
call local rect_grow x0 i32,x1 i32,y0 i32,y1 i32,sector u32 > rect sector_rect 4 i32,queue flow_ring FLOW_RING u32,tail flow_tail u64,pending flow_pending MAX_SECTORS u8,clobber a0 [299:330] :a sector's rectangle grown by one, and the sector queued when it grew; a rectangle inside it already changes nothing
 x1 :the column past the last, with y1 the row past the last
 rect :the sector's entry
call local sector_flow sector u32 > rects sector_rect MAX_SECTORS*4 i32,queue flow_ring FLOW_RING u32,openings STAT_OPENINGS(stats) u64,clobber a0-a4,fa0-fa3 [332:524] :a sector's portals flowed, for each wall facing the camera each portal's opening cut and projected, its rectangle intersected with the sector's, and the neighbour's rectangle grown by it; the eye within the flow's near distance of the wall hands the neighbour the sector's own rectangle
call local opening_cut neighbour u32,ax fs0 f64,ay fs1 f64,bx fs2 f64,by fs3 f64,top_a fs4 f64,top_b fs5 f64,bottom_a fs6 f64,bottom_b fs7 f64 > points a0 u64,projected pverts MAX_CLIPPED*2 f32,edges edges MAX_EDGES*4 f32,clobber a1,fa0-fa3 [526:585] :the opening into a neighbour across the wall in hand cut as a polygon through piece_polygon, the neighbour's ceiling at both ends, clamped to the sector's where it passes it at both, over the neighbour's floor, clamped to the sector's floor the same way
 ax :the wall's start x, with ay its y and bx, by its end
 top_a :the sector's ceiling at the start, top_b at the end
 bottom_a :the sector's floor at the start, bottom_b at the end
 points :the clipped point count, 0 for nothing
call local sector_draw sector u32 > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clip clip_rect 4 i32,clobber a0-a7,fa0-fa3 [587:755] :a sector's planes facing the camera, then its walls facing the camera nearest first, prepared into the packet within its rectangle
 screen :only through a full packet's render, as is depth
call local material_bind material i32 > bound a0 bool,surface poly POLY_SIZE u8,clobber a1 [757:817] :a material's texture into the surface in hand, its pixels, size, wraps, and chain
 bound :1, or 0 with the sizes 1 when the material is none or has no texture
call local surface_mode flags u32 > mode POLY_MODE(poly) u64,clobber a0 [819:826] :the polygon's mode from a surface's flags, the sky, else textured, lit with lights
call local poly_mode mode u64 > mode POLY_MODE(poly) u64,clobber a0 [828:842] :the polygon's mode set, the lit flag added when the map has lights and the polygon has no map, a sprite lit flat, or a baked one
call local plane_draw sector u32,ceiling bool > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clobber a0-a7,fa0-fa2 [844:967] :a sector's plane when its surface has a material, every loop's points at the plane's height into one edge list and one even-odd fill into the packet
call local piece_polygon top_a f64,top_b f64,bottom_a f64,bottom_b f64,ax fs0 f64,ay fs1 f64,bx fs2 f64,by fs3 f64 > points a0 u64,projected pverts MAX_CLIPPED*2 f32,edges edges MAX_EDGES*4 f32,clobber fa0-fa2 [969:1047] :the polygon in hand set to the wall piece between two heights at each end, the quad, the triangle where the planes cross, or nothing
 top_a :the top at the start, top_b at the end
 bottom_a :the bottom at the start, bottom_b at the end
 ax :the wall's start x, with ay its y and bx, by its end
 points :the clipped point count, 0 for nothing
call local piece_cross fraction ft3 f64,ax fs0 f64,ay fs1 f64,bx fs2 f64,by fs3 f64,top_a fs4 f64,top_b fs5 f64 > x fa0 f32,y fa1 f32,z fa2 f32 [1049:1059] :the point a fraction along the wall from its start, at the top's height there
 top_a :the top at the start, top_b at the end, as piece_polygon holds them
call local wall_surface sector u32,wall u32,ax fs0 f64,ay fs1 f64,bx fs2 f64,by fs3 f64 > textured a0 bool,surface poly POLY_SIZE u8,plane plane 14 f32,clobber a1-a2,fa1 [1061:1149] :the plane and surface in hand set for a wall, the normal into the sector, u along the wall from its first vertex, v down from its anchor height
 textured :1 when the wall's material has a texture, else 0
call local wall_within distance f64,ax fs0 f64,ay fs1 f64,bx fs2 f64,by fs3 f64 > within a0 bool [1151:1177] :whether the camera is within a distance of the wall in hand, in the plan
 distance :the distance, squared
call local wall_draw sector u32,wall u32 > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clobber a0-a7,fa0-fa3 [1179:1353] :a wall of a sector facing the camera, its portals from the top down, the solid pieces between them and, on a masked wall, its surface over each opening, into the packet
call local phase_mark > mark a0 u64 [1355:1360] :the clock less the raster's ticks so far, a phase's mark, so a full packet's render inside a phase is no part of it
call local uncovered > count a0 u64 [1362:1375] :how many pixels no surface reached this frame, the depth buffer's zeros
