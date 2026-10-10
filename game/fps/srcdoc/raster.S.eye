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
call local lumap_bind > coefficients POLY_UZA(poly) 6 i64,read POLY_LUMEL(poly) u64 [464:537] :the lit, mapped polygon in hand bound to its lumel map, the map's texel origin folded into the u/z and v/z coefficients and the read's one word set; a polygon unlit or without a map is left alone
macro span_cap dst reg,scratch reg > cap dst u64,scratch scratch [525:535] :the spans a packet holds, SPAN_RECORDS, or on a debug build the console's cap where it is smaller
call local row_crossings row f32 > count a0 u64,crossings crossings MAX_EDGES f32 [538:574] :the edges the row's centre crosses, their x in crossings sorted ascending
 row :the row's centre
call local span_bound x f32 > pixel a0 i32 [576:588] :the first pixel whose centre is at or past x, within the screen's columns
call local row_range > first a0 i32,last a1 i32 [590:608] :the rows the edges cover, within the screen
 last :the row past the last
call local poly_fill > records span_records SPAN_RECORDS*SPAN_RECORD_SIZE u8,count span_count u64,commands commands MAX_COMMANDS*POLY_SIZE u8,held command_count u64,runs command_runs MAX_COMMANDS u32,screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,stats stats 34 u64,clobber a0-a7,fa0 [610:700] :the polygon in hand's spans by scanlines into the packet, its rows and each span held within the rectangle in hand, the polygon copied into the packet as a command at its first span; a full packet rendered whole first
 screen :only through a full packet's render, as is depth
call local span_record first i32,end i32,row i32,command u32 > record span_records 16 u8,count span_count u64 [702:719] :the span recorded into the packet, its row, its pixels, the polygon's mode and surface, and its command's index, the caller holding room for it
 end :the pixel past the last
 command :its index in the packet
 record :the entry at the count before
call local packet_room held a3 i64 > command a0 u64,clobber a1-a7 [721:739] :room in the packet for the polygon in hand's next span: the packet rendered whole first when its spans are full, and the polygon's command emitted when it has none there
 held :the polygon's command in the packet, -1 when it has none there
 command :its index in the packet
call local command_emit > command a0 u64,commands commands MAX_COMMANDS*POLY_SIZE u8,held command_count u64,run command_runs 1 u32,emitted STAT_COMMANDS(stats) u64,clobber a1-a7 [741:788] :the polygon in hand copied whole into the packet as its next command, its run starting at the packet's next span, the packet rendered whole first when its commands are full
 run :the command's entry, the packet's span count
 command :its index in the packet
call local packet_flush > flushes STAT_FLUSHES(stats) u64,screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clobber a0-a7 [790:795] :a full packet rendered whole before preparation goes on, counted; packet_render's tail
call local context_counts context tp addr > stats stats 44 u64,counters CTX_SPANS(tp) 13 u64 [797:881] :the raster context's counters added into the frame's stats and zeroed, and on a COUNT build its counts into count_stats
call local scratch_poison > poisoned poly u64 [882:891] :on a debug build, the producer's scratch overwritten with SCRATCH_POISON once the frame's packet is published, so a read of it from the raster draws wrong or faults
 poisoned :every word from poly to scratch_end
call local poly_rect count u64 > x0 a0 i32,x1 a1 i32,y0 a2 i32,y1 a3 i32 [893:1101] :the screen rectangle of the projected polygon in hand, a pixel of slack each side, held within the screen
 count :the projected point count
 x1 :the column past the last, with y1 the row past the last
macro lumel_sample u a5 i64,v a6 i64 > bright a5 u64,scratch a0,a6-a7,t3-t4 [942:1005] :the brightness at a texel coordinate of the context's command from its lumel map, the coordinate held within the map, the four lumels about it summed under weights adding to 256
 u :16.16 texels from the map's origin
 v :16.16 texels from the map's origin
 bright :the three channels in 16.16 packed CHANNEL_BITS apart
macro mip_bind level 192(sp) u64 > texels a1 addr,vmask a2 u64,umask a3 u64,wshift a4 u64,shift s5 u64,spill 40(sp) u64,scratch a5-a7 [1007:1022] :the context's command's texture level for the block in hand bound for the loops, its texels, masks, and row shift into the texture's registers and the shift from a 16.16 coordinate to its texel at the level, u, v, and their steps left at level 0 as the tiles read them
 level :the block's level in span_fill's frame, the chain's last at most
 shift :the level plus 16
 spill :s5 as it was, v/z, which the block's end takes back
macro count_add field imm,scratch reg,base reg,n=1 imm > counter field(CTX_COUNT(tp)) u64,base base addr,scratch scratch [1025:1030] :on a COUNT build alone, the raster context's counter at field raised by n, the two registers named changed
macro census_start > scratch a0,a5 [1034:1043] :on a CENSUS build, at a block's start, its first pixel's u and v and their steps into the context's next census slot, nothing when the slots are full
macro census_end > scratch t3,t5,a0,a5 [1045:1071] :on a CENSUS build, at a block's end, a lit mapped block's surface, level, pixels, passes, and masked flag into its slot, kept, or counted dropped when the slots are full
macro interval_pixels > pixels t2 u64,scratch a0,a5-a7 [1074:1099] :an interval's pixels from the block's steps against the lumel's 2^k texels, four blocks, two, or one, cut short by the span's pixels left
 pixels :from t5's and t6's steps, the command's k, and s10, the span's pixels left
call local packet_render > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,stats stats 44 u64,context tp addr,clobber a0-a7 [1102:1160] :the packet rendered: on a debug build the tile pool checked frozen at its start and after its joins, and under the serial backend every span in order through span_fill on hart 0's context, its counters into the frame's stats, or with the frame's workers their round (workers.S's round_run); the packet emptied, and the render's ticks added to the raster's
 context :raster_context, or a worker's under the round
call local band_render first u32,end u32,clear bool,context tp addr > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,counters CTX_SPANS(tp) 13 u64,clobber a0-a7 [1162:1274] :a band's rows rendered on the caller's context: on a clearing round its depth rows zeroed and on a debug build its pixels painted magenta, then each command's spans in the band in the commands' order, the first found in the command's run by a binary search on the row
 end :the row past the band's last
 clear :the round's ROUND_CLEAR, the frame's first round
call local span_fill first i32,end i32,row i32,context tp addr > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,counters CTX_SPANS(tp) 13 u64,clobber a0-a7 [1276:2253] :the pixels of a row filled with the context's command, textured, masked, sky, or lit from its lumel map or flat by one brightness, each block at one level from its footprint, on a debug build raised by the M frame's level_raise, held under the chain's last, read from its READY tile in the tile pool where one tile holds it, else from the chain, a missed block with a pixel past the depth test asking for its tile; a lit span's intervals decided at the same blocks whatever its tiles, a tile block counting its pixels off one and a lit block after it re-entering it from its knot, so every lit pixel is the all-lit span's; no float in the loop
 end :the pixel past the last
 context :the raster context, its command the polygon as preparation published it
