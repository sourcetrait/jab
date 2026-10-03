set RADIUS i64 [3] :the ball's radius in pixels
set BACKGROUND u32 [4] :the screen's colour, black
set BALL u32 [5] :the ball's colour, the logo's, LowKick's own
set LEFT i64 [6] :the least the centre may be across, keeping the whole ball on the screen
set RIGHT i64 [7] :the most the centre may be across
set TOP i64 [8] :the least the centre may be down
set BOTTOM i64 [9] :the most the centre may be down
set FIX u8 [10] :the fraction bits of a position or a speed
set ONE i64 [11] :one pixel in 256ths
set SPEED_X i64 [12] :210 pixels a second across, in 256ths
set SPEED_Y i64 [13] :150 pixels a second down, in 256ths
set DT_MAX u64 [14] :the most time one frame moves the ball, a tenth of a second in ticks
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
bss local last_time u64 [177:178] :the clock at the frame before, in ticks
bss local dt u64 [179:180] :the frame's time in ticks, at most DT_MAX
rodata local msg_no_display 20 u8 [183:184] :the line for a machine with no display
