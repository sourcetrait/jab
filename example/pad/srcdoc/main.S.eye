j _start [56:141] :opens the display, gives the buttons their colours, places the spheres, and runs until the window closes
j local frame [142:160] :takes the keys, the API's commands, and the pad's events as they come, and on each tick reads the pad, moves, reports, and draws
j local no_display [162:164] :says so on the UART and exits with 1
call local read_keys > clobber a0-a1,a7 [166:177] :takes every key event waiting from the keyboard and applies it with apply_key
call local read_api > clobber a0-a1,a7 [179:216] :takes every key event the host has sent over the API and applies it with apply_key, a record split across reads waiting in cmd_partial, its bytes counted in cmd_pending
call local read_pad > code label_code i64,text label_text addr,left label_left i64,label label_changed bool,vx player_vx i64,vy player_vy i64,colour player_color u32,painter color_code u64,painted color_changed bool,clobber a0-a2,a7 [218:279] :takes every pad event waiting, a button pressed announcing itself and stopping or painting your sphere
 code :the button pressed, its name in text, label set
 left :LABEL_TIME once the announced button is released, 0 when one is pressed
 vx :0 when THUMBL or THUMBR is pressed, and vy with it
 colour :the button's own when any other is pressed, painter its code, painted set
call local label_tick > left label_left i64,text label_text addr,code label_code i64,label label_changed bool [281:302] :the frame's time off the name's three seconds once they have started
 text :name_none at their end, code NO_BUTTON, label set
call local elapsed > dt dt u64,last last_time u64 [304:316]
 dt :the ticks since the frame before, at most DT_MAX
 last :the clock now, for the next frame
call local advance value i64,rate i64 > value a0 i64 [318:325]
 rate :a speed a second
 value :moved on by rate times dt over JAB_TIME_HZ
call local right_stick > colour player_color u32,clobber a0-a3 [327:364] :with the right stick off its rest, your sphere's colour from its exact position
 colour :red from x and green from y, each across the whole travel, blue from how far it is pushed
call local right_axes > x a0 i16,y a1 i16 [366:376] :the right stick's axes from pad_state, normalised
call local assign_colors > colours button_colors u32,clobber a0,s1-s3 [378:391] :a colour for every button, at random
call local random_color > colour a0 u32,clobber s3 [393:414]
 colour :0x00RRGGBB, each channel from COLOR_FLOOR up so it shows on black
call local random > next a0 u64,state rand_state u64 [416:427]
 next :the next of the xorshift sequence, also the new state
call local apply_key code u16,value i32 > w held_w bool,a held_a bool,s held_s bool,d held_d bool,vx player_vx i64,vy player_vy i64 [429:464] :the held flags of W, A, S, and D set and cleared, the space bar pressed stopping your sphere
 w :1 unless W was released, and a, s, and d likewise for their keys
 vx :0 on a space bar press, and vy with it
call local drive_vector > ax a0 i64,ay a1 i64 [466:567] :the acceleration a second in fixed point, the keys, both sticks, and the hat summed, each axis within ACCEL_MAX
call local drive speed i64,accel i64 > speed a0 i64,clobber a1 [569:600] :the speed after the frame's time, held under TOP_SPEED either way
 accel :a second, in fixed point
 speed :pushed, or with no push slowed toward 0 at DECEL a second and not past it
call local wall position i64,speed i64,least i64,greatest i64 > position a0 i64,speed a1 i64,hit a2 bool [602:629]
 least :the least centre in pixels
 greatest :the greatest centre in pixels
 position :moved on by speed over the frame's time, put back on a wall it passed
 speed :reversed when a wall was hit
call local clamp position i64,least i64,greatest i64 > position a0 i64 [631:640]
 least :the least centre in pixels
 greatest :the greatest centre in pixels
 position :kept between least and greatest
call local isqrt value u64 > root a0 u64 [642:655]
 root :the whole square root, rounded down
call local move_player > ax drive_x i64,ay drive_y i64,x player_x i64,y player_y i64,vx player_vx i64,vy player_vy i64,hit_x player_hit_x bool,hit_y player_hit_y bool,clobber a0-a3 [657:701] :the drive vector, then your sphere's speed and position, a wall hit noted on either axis
call local move_ball > x ball_x i64,y ball_y i64,vx ball_vx i64,vy ball_vy i64,hit_x ball_hit_x bool,hit_y ball_hit_y bool,clobber a0-a3 [703:734] :the other sphere on and off the walls, a wall hit noted on either axis
call local collide > met met bool,point_x meet_x i64,point_y meet_y i64,player_x player_x i64,player_y player_y i64,player_vx player_vx i64,player_vy player_vy i64,ball_x ball_x i64,ball_y ball_y i64,ball_vx ball_vx i64,ball_vy ball_vy i64,clobber a0-a2,a4-a5 [736:867] :when the spheres have met, each closing one bounces off the other, and the two are set apart on the screen
 met :1 when they met, its point midway between the centres
call local report > clobber a0-a4,a7 [869:1045] :sends the host what changed this frame in one write, then clears the hit, colour, and meeting notes
call local toward_side x i64 > contact a3 i64 [1047:1055]
 x :arrives in a3, a centre against the left or right wall
 contact :the contact point's x, a radius toward that wall
call local toward_edge y i64 > contact a4 i64 [1057:1065]
 y :arrives in a4, a centre against the top or bottom wall
 contact :the contact point's y, a radius toward that wall
call local append_report kind u8,sphere u8,against u8,x i32,y i32 > report report_buffer u8,count report_count u64 [1067:1085]
 report :the next REPORT_SIZE bytes of report_buffer, dropped past REPORT_MAX
call local render > screen JAB_DISPLAY_BASE u32,clobber a0-a5,a7,s2-s3 [1087:1180] :both spheres erased and redrawn, the rectangle holding all four squares flipped with the label strip when it changed
call local draw_label > strip JAB_DISPLAY_BASE u32,clobber a0-a5,a7 [1182:1218]
 strip :cleared across the screen, then the label's text centred in it, bold off-white at LABEL_SCALE
call local fill_rect x i64,y i64,width u64,height u64,colour u32 > rect JAB_DISPLAY_BASE u32 [1220:1240]
 rect :the pixels from x, y on for width and height, set to colour
call local least_greatest least i64,greatest i64,p i64,q i64,r i64 > least a0 i64,greatest a2 i64 [1242:1261]
 greatest :arrives in a2
 p :arrives in t1, q in t2, r in t3
 least :the least of least, p, q, and r
 greatest :the greatest of greatest, p, q, and r
call local remember > player_x old_player_x i64,player_y old_player_y i64,ball_x old_ball_x i64,ball_y old_ball_y i64 [1263:1284] :where the spheres are now, in pixels, to erase next frame
call local fill_square x i64,y i64,colour u32 > square JAB_DISPLAY_BASE u32 [1286:1306]
 square :the pixels within RADIUS of x, y across and down, set to colour
call local draw_disc x i64,y i64,colour u32 > disc JAB_DISPLAY_BASE u32,clobber a3-a4 [1308:1334]
 disc :the pixels within RADIUS of x, y, set to colour
