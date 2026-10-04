j _start [42:76] :opens the display, places the spheres, and runs until the window closes
j local frame [77:90] :takes the keys and the API's commands as they come, and on each tick moves, reports, and draws
j local no_display [92:94] :says so on the UART and exits with 1
call local elapsed > dt dt u64,last last_time u64 [96:108]
 dt :the ticks since the frame before, at most DT_MAX
 last :the clock now, for the next frame
call local advance value i64,rate i64 > value a0 i64 [110:117]
 rate :a speed a second
 value :moved on by rate times dt over JAB_TIME_HZ
call local read_keys > clobber a0-a1,a7 [119:130] :takes every key event waiting from the keyboard and applies it with apply_key
call local read_api > clobber a0-a1,a7 [132:169] :takes every key event the host has sent over the API and applies it with apply_key, a record split across reads waiting in cmd_partial, its bytes counted in cmd_pending
call local apply_key code u16,value i32 > w held_w bool,a held_a bool,s held_s bool,d held_d bool,vx player_vx i64,vy player_vy i64 [171:206] :the held flags of W, A, S, and D set and cleared, the space bar pressed stopping your sphere
 w :1 unless W was released, and a, s, and d likewise for their keys
 vx :0 on a space bar press, and vy with it
call local drive speed i64,more bool,less bool > speed a0 i64,clobber a1 [208:248] :the speed after the frame's time, held under TOP_SPEED either way
 more :the key that adds to the speed is held
 less :the key that takes from it is held
 speed :pushed at ACCEL a second, both keys held pushing nothing, no key slowing it toward 0 at DECEL and not past
call local wall position i64,speed i64,least i64,greatest i64 > position a0 i64,speed a1 i64,hit a2 bool [250:277]
 least :the least centre in pixels
 greatest :the greatest centre in pixels
 position :moved on by speed over the frame's time, put back on a wall it passed
 speed :reversed when a wall was hit
call local clamp position i64,least i64,greatest i64 > position a0 i64 [279:288]
 least :the least centre in pixels
 greatest :the greatest centre in pixels
 position :kept between least and greatest
call local isqrt value u64 > root a0 u64 [290:303]
 root :the whole square root, rounded down
call local move_player > x player_x i64,y player_y i64,vx player_vx i64,vy player_vy i64,hit_x player_hit_x bool,hit_y player_hit_y bool,clobber a0-a3 [305:348] :your sphere's speed from the held keys, then its position, a wall hit noted on either axis
call local move_ball > x ball_x i64,y ball_y i64,vx ball_vx i64,vy ball_vy i64,hit_x ball_hit_x bool,hit_y ball_hit_y bool,clobber a0-a3 [350:381] :the other sphere on and off the walls, a wall hit noted on either axis
call local collide > met met bool,point_x meet_x i64,point_y meet_y i64,player_x player_x i64,player_y player_y i64,player_vx player_vx i64,player_vy player_vy i64,ball_x ball_x i64,ball_y ball_y i64,ball_vx ball_vx i64,ball_vy ball_vy i64,clobber a0-a2,a4-a5 [383:514] :when the spheres have met, each closing one bounces off the other, and the two are set apart on the screen
 met :1 when they met, its point midway between the centres
call local report > clobber a0-a4,a7 [516:688] :sends the host what changed this frame in one write, then clears the hit and meeting notes
call local toward_side x i64 > contact a3 i64 [690:698]
 x :arrives in a3, a centre against the left or right wall
 contact :the contact point's x, a radius toward that wall
call local toward_edge y i64 > contact a4 i64 [700:708]
 y :arrives in a4, a centre against the top or bottom wall
 contact :the contact point's y, a radius toward that wall
call local append_report kind u8,sphere u8,against u8,x i32,y i32 > report report_buffer u8,count report_count u64 [710:728]
 report :the next REPORT_SIZE bytes of report_buffer, dropped past REPORT_MAX
call local render > screen JAB_DISPLAY_BASE u32,clobber a0-a4,a7,s2-s3 [730:799] :both spheres erased where they were and drawn where they are, the rectangle holding all four squares flipped
call local least_greatest least i64,greatest i64,p i64,q i64,r i64 > least a0 i64,greatest a2 i64 [801:820]
 greatest :arrives in a2
 p :arrives in t1, q in t2, r in t3
 least :the least of least, p, q, and r
 greatest :the greatest of greatest, p, q, and r
call local remember > player_x old_player_x i64,player_y old_player_y i64,ball_x old_ball_x i64,ball_y old_ball_y i64 [822:843] :where the spheres are now, in pixels, to erase next frame
call local fill_square x i64,y i64,colour u32 > square JAB_DISPLAY_BASE u32 [845:865]
 square :the pixels within RADIUS of x, y across and down, set to colour
call local draw_disc x i64,y i64,colour u32 > disc JAB_DISPLAY_BASE u32,clobber a3-a4 [867:893]
 disc :the pixels within RADIUS of x, y, set to colour
