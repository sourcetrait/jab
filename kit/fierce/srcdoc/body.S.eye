call local body_move seconds f32,strafe f32,forward f32 > eye camera 3 f32,sector cam_sector i32,fall body_fall f64,clobber a0-a5,fa0-fa2 [23:102] :the player's feet moved for the frame, then the walls, the sector, the floor, and the eye placed
 strafe :the strafe throw, -1 to 1
 forward :the forward throw, -1 to 1
call local feet_move before i32,fall addr,walker addr,seconds f32,x fs0 f64,y fs1 f64,z fs2 f64 > x fs0 f64,y fs1 f64,z fs2 f64,sector a0 i32,speed 0(fall) f64,clobber a1-a5,fa0-fa2,fs5-fs7 [104:204] :the feet placed after a step, the walls of their sector twice over, the other bodies, the sector followed, then the floor met and the fall; in no sector nothing holds the body
 before :the sector the feet were in
 fall :the fall speed, a double
 walker :the actor walking, 0 for the player
 sector :-1 when none holds them
call local bodies_push walker addr,x fs0 f64,y fs1 f64,z fs2 f64 > x fs0 f64,y fs1 f64 [206:244] :the feet pushed out of every other body in the plan, every solid android but the walker, and the player's when the walker is an android
 walker :0 for the player
call local body_push bx ft0 f64,by ft1 f64,bz ft2 f64,x fs0 f64,y fs1 f64,z fs2 f64 > x fs0 f64,y fs1 f64 [246:275] :the feet pushed out of another body to twice the radius in the plan when within it and the heights overlap; two on one spot part eastward
 bx :the other body's feet's x, with by and bz
call local wall_push wall u32,x fs0 f64,y fs1 f64,z fs2 f64 > x fs0 f64,y fs1 f64,clobber a0-a2,a5,fa0-fa1,fs5-fs7 [277:397] :the feet pushed out of a wall when it blocks the body and lies within its radius
