set RADIUS i64 [3] :a sphere's radius in pixels
set BACKGROUND u32 [4] :the screen's colour, black
set PLAYER u32 [5] :your sphere's colour at the start
set BALL u32 [6] :the bouncing sphere's colour, the logo's, LowKick's own
set LEFT i64 [7] :the least a centre may be across, keeping the whole sphere on the screen
set RIGHT i64 [8] :the most a centre may be across
set TOP i64 [9] :the least a centre may be down
set BOTTOM i64 [10] :the most a centre may be down
set FIX u8 [11] :the fraction bits of a position or a speed
set ONE i64 [12] :one pixel in fixed point
set BALL_VX i64 [13] :the bouncing sphere's speed across, bounce's 210 pixels a second
set BALL_VY i64 [14] :the bouncing sphere's speed down, bounce's 150 pixels a second
set TOP_SPEED i64 [15] :your sphere's top speed on each axis, 780 pixels a second
set ACCEL i64 [16] :what a full push adds a second, 720 pixels a second squared
set DECEL i64 [17] :what a free axis loses a second, 450 pixels a second squared
set DT_MAX u64 [18] :the most time one frame moves anything, a tenth of a second in ticks
set TOUCH_SQ i64 [19] :the spheres have met when their centres are this close in pixels, squared
set APART i64 [20] :how far apart met spheres are set, two pixels more than touching
set CMD_SIZE u64 [22] :an API command's bytes
set CMD_CODE u16 [23] :the key's code, a JAB_KEY_*
set CMD_VALUE u16 [24] :pressed or released, a JAB_KEY_* value
set CMD_READ_BYTES u64 [25] :the most one API read takes
set REPORT_SIZE u64 [26] :a report's bytes
set REPORT_KIND u8 [27] :the kind, REPORT_VELOCITY, REPORT_ACCELERATION, REPORT_HIT, or REPORT_COLOR
set REPORT_SPHERE u8 [28] :the sphere, a SPHERE_*
set REPORT_AGAINST u8 [29] :a hit's other party, AGAINST_WALL or a SPHERE_*
set REPORT_X i32 [30] :x in fixed point after a pad byte, a colour record's colour
set REPORT_Y i32 [31] :y in fixed point, a colour record's button code
set REPORT_VELOCITY u8 [32] :a sphere's velocity changed
set REPORT_ACCELERATION u8 [33] :the drive vector changed
set REPORT_HIT u8 [34] :a collision, at the contact point
set REPORT_COLOR u8 [35] :a button painted your sphere
set SPHERE_PLAYER u8 [36] :your sphere
set SPHERE_BALL u8 [37] :the bouncing sphere
set AGAINST_WALL u8 [38] :a wall
set REPORT_MAX u64 [39] :the most reports a frame
set BUTTONS u64 [40] :the pad's buttons given a colour, from JAB_BTN_GAMEPAD
set COLOR_FLOOR u8 [41] :the least a button colour's channel is, so it shows on black
set COLOR_SPAN u8 [42] :the range above COLOR_FLOOR a channel is drawn from
set LABEL_SCALE u64 [43] :one and a half times the console's font, in 256ths
set LABEL_CELL u64 [44] :a label character's width in pixels
set LABEL_HEIGHT u64 [45] :the label strip's height in pixels
set LABEL_Y i64 [46] :the label strip's top
set LABEL_COLOR u32 [47] :the label's off-white
set LABEL_TIME u64 [48] :how long a name stays after its button is released, three seconds in ticks
set NAMED_BUTTONS u64 [49] :the entries of button_names, the last for a button with no name
set NO_BUTTON i64 [50] :label_code with no button announced
set ACCEL_MAX i64 [51] :the strongest push on an axis, which nothing exceeds
set BAND i64 [52] :a third of the right stick's throw
j _start [56:141] :opens the display, gives the buttons their colours, places the spheres, and runs until the window closes
j local frame [142:160] :takes the keys, the API's commands, and the pad's events as they come, and on each tick reads the pad, moves, reports, and draws
j local no_display [162:164] :says so on the UART and exits with 1
call local read_keys > clobber a0-a1,a7 [166:177] :takes every key event waiting from the keyboard and applies it with apply_key
call local read_api > clobber a0-a1,a7 [179:216] :takes every key event the host has sent over the API and applies it with apply_key, a record split across reads waiting in cmd_partial, its bytes counted in cmd_pending
call local read_pad > code label_code i64,text label_text address,left label_left i64,label label_changed bool,vx player_vx i64,vy player_vy i64,colour player_color u32,painter color_code u64,painted color_changed bool,clobber a0-a2,a7 [218:279] :takes every pad event waiting, a button pressed announcing itself and stopping or painting your sphere
 code :the button pressed, its name in text, label set
 left :LABEL_TIME once the announced button is released, 0 when one is pressed
 vx :0 when THUMBL or THUMBR is pressed, and vy with it
 colour :the button's own when any other is pressed, painter its code, painted set
call local label_tick > left label_left i64,text label_text address,code label_code i64,label label_changed bool [281:302] :the frame's time off the name's three seconds once they have started
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
bss local player_x i64 [1338:1339] :your sphere's centre across, in fixed point
bss local player_y i64 [1340:1341] :your sphere's centre down, in fixed point
bss local player_vx i64 [1342:1343] :your sphere's speed across, in fixed point a second
bss local player_vy i64 [1344:1345] :your sphere's speed down, in fixed point a second
bss local ball_x i64 [1346:1347] :the other sphere's centre across, in fixed point
bss local ball_y i64 [1348:1349] :the other sphere's centre down, in fixed point
bss local ball_vx i64 [1350:1351] :the other sphere's speed across, in fixed point a second
bss local ball_vy i64 [1352:1353] :the other sphere's speed down, in fixed point a second
bss local old_player_x i64 [1354:1355] :your sphere's centre across in pixels, as last drawn
bss local old_player_y i64 [1356:1357] :your sphere's centre down in pixels, as last drawn
bss local old_ball_x i64 [1358:1359] :the other sphere's centre across in pixels, as last drawn
bss local old_ball_y i64 [1360:1361] :the other sphere's centre down in pixels, as last drawn
bss local last_player_vx i64 [1362:1363] :your sphere's speed across as last reported
bss local last_player_vy i64 [1364:1365] :your sphere's speed down as last reported
bss local last_ball_vx i64 [1366:1367] :the other sphere's speed across as last reported
bss local last_ball_vy i64 [1368:1369] :the other sphere's speed down as last reported
bss local last_ax i64 [1370:1371] :the drive vector across as last reported
bss local last_ay i64 [1372:1373] :the drive vector down as last reported
bss local drive_x i64 [1374:1375] :this frame's drive vector across, a second
bss local drive_y i64 [1376:1377] :this frame's drive vector down, a second
bss local meet_x i64 [1378:1379] :where the spheres met across, in fixed point
bss local meet_y i64 [1380:1381] :where the spheres met down, in fixed point
bss local report_count u64 [1382:1383] :the reports in report_buffer this frame
bss local cmd_pending u64 [1384:1385] :the bytes of a command in cmd_partial
bss local rand_state u64 [1386:1387] :the colours' random sequence state, never zero
bss local color_code u64 [1388:1389] :the code of the button that last painted your sphere
bss local label_code i64 [1390:1391] :the button announced, NO_BUTTON for none
bss local label_text address [1392:1393] :the label's NUL-terminated text
bss local label_left i64 [1394:1395] :the ticks the label has left once its button is released, 0 while it stays
bss local last_time u64 [1396:1397] :the clock at the frame before, in ticks
bss local dt u64 [1398:1399] :the frame's time in ticks, at most DT_MAX
bss local report_buffer 120 u8 [1400:1401] :this frame's reports
bss local cmd_read 64 u8 [1402:1403] :one API read's bytes
bss local cmd_partial 4 u8 [1404:1405] :a command arriving in pieces
bss local right_x u64 [1406:1407] :the right stick's axis across, a byte offset into pad_state
bss local right_y u64 [1408:1410] :the right stick's axis down, a byte offset into pad_state
bss local pad_state 132 u8 [1411:1412] :the pad's state as jab.sys.pad.read last wrote it
bss local axis_record 5 i32 [1413:1414] :the range jab.sys.pad.axis wrote while the right stick was found
bss local button_colors 32 u32 [1415:1416] :every button's colour, from JAB_BTN_GAMEPAD
bss local player_color u32 [1417:1418] :your sphere's colour
bss local rects 8 u32 [1419:1420] :the spheres' rectangle and the label strip, flipped together
bss local pad_name 128 u8 [1421:1422] :the pad's name as the device reports it
bss local color_changed bool [1423:1424] :a button painted your sphere, not yet reported
bss local label_changed bool [1425:1426] :the label's text changed, not yet drawn
bss local held_w bool [1427:1428] :1 while W is held
bss local held_a bool [1429:1430] :1 while A is held
bss local held_s bool [1431:1432] :1 while S is held
bss local held_d bool [1433:1434] :1 while D is held
bss local player_hit_x bool [1435:1436] :your sphere hit a side wall this frame
bss local player_hit_y bool [1437:1438] :your sphere hit the top or the bottom this frame
bss local ball_hit_x bool [1439:1440] :the other sphere hit a side wall this frame
bss local ball_hit_y bool [1441:1442] :the other sphere hit the top or the bottom this frame
bss local met bool [1443:1444] :the spheres met this frame
rodata local msg_no_display 17 u8 [1447:1448] :the line for a machine with no display
rodata local name_south 6 u8 [1449:1450] :evdev's name for JAB_BTN_SOUTH
rodata local name_east 5 u8 [1451:1452] :evdev's name for JAB_BTN_EAST
rodata local name_c 2 u8 [1453:1454] :evdev's name for JAB_BTN_C
rodata local name_north 6 u8 [1455:1456] :evdev's name for JAB_BTN_NORTH
rodata local name_west 5 u8 [1457:1458] :evdev's name for JAB_BTN_WEST
rodata local name_z 2 u8 [1459:1460] :evdev's name for JAB_BTN_Z
rodata local name_tl 3 u8 [1461:1462] :evdev's name for JAB_BTN_TL
rodata local name_tr 3 u8 [1463:1464] :evdev's name for JAB_BTN_TR
rodata local name_tl2 4 u8 [1465:1466] :evdev's name for JAB_BTN_TL2
rodata local name_tr2 4 u8 [1467:1468] :evdev's name for JAB_BTN_TR2
rodata local name_select 7 u8 [1469:1470] :evdev's name for JAB_BTN_SELECT
rodata local name_start 6 u8 [1471:1472] :evdev's name for JAB_BTN_START
rodata local name_mode 5 u8 [1473:1474] :evdev's name for JAB_BTN_MODE
rodata local name_thumbl 7 u8 [1475:1476] :evdev's name for JAB_BTN_THUMBL
rodata local name_thumbr 7 u8 [1477:1478] :evdev's name for JAB_BTN_THUMBR
rodata local name_none 1 u8 [1479:1481] :the empty name, for a button with none and for a clear strip
rodata local button_names 16 address [1482:1485] :every button's name from JAB_BTN_GAMEPAD, the last for a button with none
