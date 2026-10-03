rodata local k_hold_slack_d f64 [3:4] :a point's slack about its sector's planes
call local plane_height sector u32,ceiling bool,x f64,y f64 > height fa0 f64 [8:25] :the height of the sector's floor or ceiling at a point
call local sector_holds_plan sector u32,x f64,y f64 > held a0 bool,clobber a1-a5 [27:91] :whether a sector holds a point in the plan, by the even-odd rule over the walls of its loops
call local sector_holds sector u32,x fs0 f64,y fs1 f64,z fs2 f64 > held a0 bool,clobber a1-a5,fa0-fa1 [93:130] :whether a sector holds a point, in the plan and between its planes there, a thousandth's slack either way
call local sector_find before u32,x f64,y f64,z f64 > sector a0 i32,clobber a1-a5,fa0-fa1 [132:276] :the sector holding a point, from the sector it was last in, itself, else a breadth-first walk through its portals, then every sector from the top
 before :the sector before, or past the count for a search from the top
 sector :-1 when none holds the point
bss local sector_fifo MAX_SECTORS u32 [280:281] :sector_find's walk's queue
bss local sector_seen MAX_SECTORS u8 [282:283] :sector_find's sectors reached
