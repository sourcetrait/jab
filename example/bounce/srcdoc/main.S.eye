j _start [18:27] :opens the display and bounces the ball until the window closes
j local frame x i64,y i64,speed_x i64,speed_y i64 [28:95] :one frame, the tick awaited, the ball moved by time, the rectangle it crossed flipped
 x :arrives in s0, the centre across in 256ths of a pixel
 y :arrives in s1, the centre down in 256ths of a pixel
 speed_x :arrives in s2, in 256ths of a pixel a second, turned at a side wall
 speed_y :arrives in s3, in 256ths of a pixel a second, turned at the top or bottom
j local no_display [97:99] :says so on the UART and exits with 1
call local elapsed > dt dt u64,last last_time u64 [101:113]
 dt :the ticks since the frame before, at most DT_MAX
 last :the clock now, for the next frame
call local advance value i64,rate i64 > value a0 i64 [115:122]
 rate :a speed a second
 value :moved on by rate times dt over JAB_TIME_HZ
call local fill_square x i64,y i64,colour u32 > square JAB_DISPLAY_BASE u32 [124:144]
 square :the pixels within RADIUS of x, y across and down, set to colour
call local draw_ball x i64,y i64 > disc JAB_DISPLAY_BASE u32,clobber a3-a4 [146:173]
 disc :the pixels within RADIUS of x, y, set to BALL
