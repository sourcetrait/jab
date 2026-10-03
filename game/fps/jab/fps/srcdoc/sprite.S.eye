rodata local k_pull_d f64 [3:4] :the quad's share of its distance from the eye after the pull, a hundredth toward it
rodata local k_tiny_d f64 [5:542] :a level right shorter than this stands on end
call local sprites_draw > surface sprite_surface u64,screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clobber a0-a7,fa0-fa7 [10:46] :every sprite entity in a sector the walk reached drawn
call local sprite_draw entity address,surface sprite_surface u64 > screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clip clip_rect 4 i32,sprites STAT_SPRITES(stats) u64,clobber a0-a7,fa0-fa7 [48:372] :a sprite entity drawn when it has a texture and faces the camera or is two-sided; lit flat by one brightness at its centre
 surface :the surface index the caller names
call local sprite_within sector u32,x fs0 f64,y fs1 f64,z fs2 f64,rx fs3 f64,ry fs4 f64,dz fs8 f64 > proven a0 bool,clobber a1-a5,fa0-fa1 [374:539] :whether a standing sprite's quad is proven within a sector, its pulled centre inside the sector in the plan, its level segment crossing no wall of the sector's loops, and its bottom and top a millimetre or more inside the floor and the ceiling at both ends of the segment
 x :the pulled centre's x, with y and z
 rx :the pulled half width's x, with ry its y, level
 dz :the pulled half height's z, the quad from the centre less it to the centre plus it
rodata local k_within_den_d f64 [543:544] :a cross product under which a wall runs parallel to the quad's segment
rodata local k_within_slack_sq_d f64 [545:546] :a millimetre squared, for a segment's start on such a wall's line
rodata local k_within_low_d f64 [547:548] :the crossing's shares widened a thousandth under the unit range
rodata local k_within_high_d f64 [549:550] :the crossing's shares widened a thousandth over the unit range
bss local sprite_surface u64 [554:555] :the surface index the next sprite draws as, a map sprite's by its entity or an actor's by its index, named by the caller
