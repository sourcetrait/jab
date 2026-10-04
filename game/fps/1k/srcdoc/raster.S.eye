call local poly_reset > count vert_count u64 [39:42] :the polygon in hand emptied
call local poly_point x f32,y f32,z f32 > point verts 3 f32,count vert_count u64 [44:59] :a world point appended to the polygon in hand; one past MAX_VERTS is dropped
 point :the entry at the count before
call local edges_reset > count edge_count u64,top edge_ymin f32,bottom edge_ymax f32 [61:71] :the edge list emptied, its rows unbounded
call local poly_project > points a0 u64,projected pverts MAX_CLIPPED*2 f32,edges edges MAX_EDGES*4 f32,count edge_count u64,top edge_ymin f32,bottom edge_ymax f32 [73:276] :the polygon in hand into the camera's basis, clipped to the near plane, projected, its edges appended to the list
 points :the clipped point count, 0 when nothing is left
call local surface_setup > wide plane_d 14 f64,coefficients POLY_IZA(poly) 9 i64,normal POLY_LNX(poly) 3 f32,flat POLY_FLAT_LIT(poly) u64,clobber a0-a2,fa1 [278:415] :the surface's affine coefficients over the screen from the plane in hand and the camera, in double, into the polygon in hand, with the unit normal facing the camera; a plane through the eye zeroes them all
 coefficients :1/z, u/z, and v/z
 normal :for the light
 flat :0, lit at its angle until the caller says otherwise
call local surface_axis gradient addr,field u64,first u64,size fa1 f32,hz fs4 f64,hx fs5 f64,hy fs6 f64,a fs8 f64,b fs9 f64,c fs10 f64 > coefficients first(poly) 3 i64,clobber fs11 [417:462] :one texture coordinate's affine coefficients into the polygon in hand
 gradient :the coordinate's gradient, three doubles in plane_d
 field :the coordinate's offset's field in plane_d
 first :the first of the three polygon fields written
 size :the texture's size along the coordinate
 a :1/z's A from surface_setup, with b its B and c its C
call local lumap_bind > coefficients POLY_UZA(poly) 6 i64,read POLY_LUMEL(poly) u64 [464:525] :the lit, mapped polygon in hand bound to its lumel map, the map's texel origin folded into the u/z and v/z coefficients and the read's one word set; a polygon unlit or without a map is left alone
call local row_crossings row f32 > count a0 u64,crossings crossings MAX_EDGES f32 [526:562] :the edges the row's centre crosses, their x in crossings sorted ascending
 row :the row's centre
call local span_bound x f32 > pixel a0 i32 [564:576] :the first pixel whose centre is at or past x, within the screen's columns
call local row_range > first a0 i32,last a1 i32 [578:596] :the rows the edges cover, within the screen
 last :the row past the last
call local poly_fill > serial poly_serial u64,records span_records SPAN_RECORDS*SPAN_RECORD_SIZE u8,count span_count u64,screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,stats stats 22 u64,clobber a0-a7,fa0 [598:676] :the polygon in hand filled by scanlines with the surface in hand, its rows and each span held within the rectangle in hand, each span recorded before it is drawn
call local span_record first i32,end i32,row i32 > record span_records 16 u8,count span_count u64 [678:700] :the span recorded before it is drawn, its row, its pixels, the mode, the surface, and the polygon's serial, into the frame's table while it has room
 end :the pixel past the last
 record :the entry at the count before, written while the count is under SPAN_RECORDS
 count :running on past the table, which a reader takes as the frame's records being incomplete
call local poly_rect count u64 > x0 a0 i32,x1 a1 i32,y0 a2 i32,y1 a3 i32 [702:833] :the screen rectangle of the projected polygon in hand, a pixel of slack each side, held within the screen
 count :the projected point count
 x1 :the column past the last, with y1 the row past the last
macro lumel_sample u a5 i64,v a6 i64 > bright a5 u64,scratch a0,a6-a7,t3-t4 [751:814] :the brightness at a texel coordinate of the surface in hand from its lumel map, the coordinate held within the map, the four lumels about it summed under weights adding to 256
 u :16.16 texels from the map's origin
 v :16.16 texels from the map's origin
 bright :the three channels in 16.16 packed CHANNEL_BITS apart
macro mip_bind level 192(sp) u64 > texels a1 addr,vmask a2 u64,umask a3 u64,wshift a4 u64,shift s5 u64,spill 40(sp) u64,scratch a5-a7 [816:831] :the texture's level for the block in hand bound for the loops, its texels, masks, and row shift into the texture's registers and the shift from a 16.16 coordinate to its texel at the level, u, v, and their steps left at level 0 as the tiles read them
 level :the block's level in span_fill's frame, the chain's last at most
 shift :the level plus 16
 spill :s5 as it was, v/z, which the block's end takes back
call local span_fill first i32,end i32,row i32 > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,stats stats 22 u64,clobber a0-a7 [834:1606] :the pixels of a row filled with the surface in hand, textured, masked, sky, or lit from its lumel map or flat by one brightness, each block at one level from its footprint held under the chain's last, read from the tiles where that level is built whole, else from the chain; no float in the loop
 end :the pixel past the last
