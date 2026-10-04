call local sprites_draw > surface sprite_surface u64,screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clobber a0-a7,fa0-fa7 [10:46] :every sprite entity in a sector the walk reached drawn
call local sprite_draw entity addr,surface sprite_surface u64 > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clip clip_rect 4 i32,sprites STAT_SPRITES(stats) u64,clobber a0-a7,fa0-fa7 [48:372] :a sprite entity drawn when it has a texture and faces the camera or is two-sided; lit flat by one brightness at its centre
 surface :the surface index the caller names
call local sprite_within sector u32,x fs0 f64,y fs1 f64,z fs2 f64,rx fs3 f64,ry fs4 f64,dz fs8 f64 > proven a0 bool,clobber a1-a5,fa0-fa1 [374:539] :whether a standing sprite's quad is proven within a sector, its pulled centre inside the sector in the plan, its level segment crossing no wall of the sector's loops, and its bottom and top a millimetre or more inside the floor and the ceiling at both ends of the segment
 x :the pulled centre's x, with y and z
 rx :the pulled half width's x, with ry its y, level
 dz :the pulled half height's z, the quad from the centre less it to the centre plus it
