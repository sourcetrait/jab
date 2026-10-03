rodata local k_trace_eps_d f64 [3:4] :a cross or a change under which the ray runs along a wall or a plane, or straight up or down
rodata local k_trace_step_d f64 [5:6] :a millionth, how far past the distance walked a crossing must lie
rodata local k_trace_neg_d f64 [7:8] :a nanometre's slack before a wall's start
rodata local k_trace_one_plus_d f64 [9:10] :a nanometre's slack past a wall's end
rodata local k_trace_range_d f64 [11:12] :the console's trace's range
call local trace_ray sector u32,skip address,flags u64,ox f64,oy f64,oz f64,dx f64,dy f64,dz f64,distance f64 > kind a0 u64,hit trace_hit TRACE_SIZE u8,clobber a1,fa0-fa2 [16:325] :the ray walked, the geometry, then the capsules; trace_hit filled
 sector :the sector the origin is in
 skip :the actor left out, 0 for none
 flags :TRACE_TO_PLAYER to test the player's capsule too
 ox :the origin's x, with oy and oz
 dx :the unit direction's x, with dy and dz
 kind :the kind met, a TRACE_*
call local trace_point distance f64,ox fs0 f64,oy fs1 f64,oz fs2 f64,dx fs3 f64,dy fs4 f64,dz fs5 f64 > point TRACE_PX(trace_hit) 3 f64 [327:335] :trace_hit's point set to the ray's at a distance, from the origin and direction trace_ray holds
 distance :kept in fa0
call local trace_capsule x f64,y f64,z f64,ox fs0 f64,oy fs1 f64,oz fs2 f64,dx fs3 f64,dy fs4 f64,dz fs5 f64 > met a0 bool,distance fa0 f64 [337:386] :whether the ray trace_ray holds meets the capsule on the feet before the distance in trace_hit
 x :the feet's x, with y and z
 distance :the distance when met
bss local trace_hit TRACE_SIZE u8 [390:391] :the trace's answer, TRACE_* fields
