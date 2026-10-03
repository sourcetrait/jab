rodata local frame_sets 8 address [3:5] :the rotating sets' stems
rodata local frame_singles 5 address [6:8] :the singles' stems, the fallen frame, the three sparks, and the magazine
rodata local android_rows 15*4 u32 [9:25] :an android's rows, the set, the milliseconds, the action, and the next, ROW_* fields
rodata local action_table 10 address [26:30] :each ACT_*'s action
rodata local k_octant f32 [31:32] :the tangent of an eighth of a half turn, the octants' edge
rodata local k_thousandth_f f32 [33:34]
rodata local k_two f32 [35:36]
rodata local k_spark_seconds f32 [37:38] :a spark frame's seconds
rodata local word_set_stand 6 u8 [39:40]
rodata local word_set_walk1 6 u8 [41:42]
rodata local word_set_walk2 6 u8 [43:44]
rodata local word_set_walk3 6 u8 [45:46]
rodata local word_set_walk4 6 u8 [47:48]
rodata local word_set_aim 4 u8 [49:50]
rodata local word_set_fire 5 u8 [51:52]
rodata local word_set_struck 7 u8 [53:54]
rodata local word_single_fallen 15 u8 [55:56]
rodata local word_single_spark1 15 u8 [57:58]
rodata local word_single_spark2 15 u8 [59:60]
rodata local word_single_spark3 15 u8 [61:62]
rodata local word_single_magazine 13 u8 [63:1220]
call local actors_place > actors actors MAX_ACTORS*ACTOR_SIZE u8,clobber a0-a5,a7,fa0-fa6 [68:151] :every actor gone, then one placed for each android and magazine entity, facing its yaw, its target the entity's, its feet on its sector's floor
call local actor_row actor address,row u32 > row ACTOR_ROW(actor) u32,timer ACTOR_TIMER(actor) f32,clobber a0-a5,a7,fa0-fa6 [153:178] :an actor put in a row, its timer the row's milliseconds, the action taken
call local actor_ms actor address > ms t0 i32 [180:186] :the milliseconds of an actor's row, negative for a held row
call local actors_tick > actors actors MAX_ACTORS*ACTOR_SIZE u8,clobber a0-a5,a7,fa0-fa6,fs7 [188:288] :one frame of every actor, an android's walk and its row's timer, a row ended entering the next with the leftover carried; a spark's frames
call local actors_draw > surface sprite_surface u64,screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clobber a0-a7,fa0-fa7 [290:324] :every actor whose sector the walk reached drawn
call local actor_draw actor address,surface sprite_surface u64 > entity actor_entity ENTITY_SIZE u8,screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clobber a0-a7,fa0-fa7 [326:423] :an actor drawn through sprite_draw from the scratch entity, by its class and row the frame's material, the quad's size, and the facing
 surface :the surface index the caller names
call local actor_rotation actor address > frame a0 u64,clobber fa0 [425:487] :the rotation frame of an actor as the eye sees it, the eighth of a turn nearest the angle from the direction toward the eye to the facing
 frame :0 facing the eye, 2 showing its right side
call local actor_alloc > actor a0 address [489:510] :a free actor, cleared
 actor :0 when the table is full
call local actor_index actor address > index a0 u64 [512:517] :an actor's index in the table
call local actor_event actor address,event u32 > record report_record REPORT_SIZE u8,clobber a0-a5,a7 [519:531] :an actor's event reported over the API with its index and its row
 event :an EVENT_*
call local actor_chest actor address > x fa0 f64,y fa1 f64,z fa2 f64 [533:540] :the point at an actor's chest
call local actor_rouse actor address > flags ACTOR_FLAGS(actor) u32,clobber a0-a5,a7,fa0-fa6 [542:563] :an actor roused into ALERT, unless it is already or is no longer shootable
call local actor_hurt actor address,damage i32 > health ACTOR_HEALTH(actor) i32,flags ACTOR_FLAGS(actor) u32,clobber a0-a5,a7,fa0-fa6 [565:599] :an actor hurt, its health less the damage; destroyed at none, else struck, either reported and its row entered
call local spark_spawn sector i32,x f64,y f64,z f64 > actors actors MAX_ACTORS*ACTOR_SIZE u8,clobber a0-a1,a4-a5,fa3-fa4 [601:636] :a spark at a point, a free actor on its first frame, its feet a quarter metre under the point so the quad centres on it; the spark's sound there
call local actor_walk actor address,x f64,y f64 > status a0 u64,feet ACTOR_X(actor) 3 f64,yaw ACTOR_YAW(actor) f32,sector ACTOR_SECTOR(actor) i32,fall ACTOR_FALL(actor) f64,blocked ACTOR_BLOCKED(actor) f32,clobber a1-a5,fa0-fa2,fs7 [638:731] :an actor walked toward a point for the frame, at its speed, no further than the point, facing its heading, the feet through feet_move
 status :1 arrived, 2 blocked past the blocked seconds, else 0
call local actor_patrol_step actor address > target ACTOR_TARGET(actor) i32,clobber a0-a5,a7,fa0-fa6,fs7 [733:773] :an actor's frame of its patrol, walked toward its target waypoint; arrived or blocked, the next waypoint, or standing when there is none
call local actor_seek_step actor address > clobber a0-a5,a7,fa0-fa6,fs7 [775:796] :an actor's frame of its search, walked toward where it last saw the player; arrived or blocked, its patrol resumes, or it stands
call local actor_to_eye actor address > facing fa0 f64,line aim 7 f64,clobber fa1 [798:835] :the line from an actor's eye to the player's into aim, the eye, the unit direction, and the distance
 facing :the facing's share of the level direction, the cosine off it
call local actor_sight actor address > sighted a0 bool,flags ACTOR_FLAGS(actor) u32,seen ACTOR_SEEN_X(actor) 3 f64,lost ACTOR_LOST(actor) f32,clobber a1-a2,fa0-fa6 [837:898] :whether an actor sees the player, within range and the front half turn, or near all round, and the trace from eye to eye reaching its capsule
 seen :the player's feet, when sighted
call local actor_face actor address > yaw ACTOR_YAW(actor) f32,clobber fa0-fa1 [900:912] :an actor turned to the player
call local actor_footstep actor address > clobber a0-a1,a4-a5,fa0-fa4 [914:941] :an actor's footstep for its row, the first on the first walking frame and the second on the third, at its feet
call local action_none actor address [943:944] :an action on entering a row, this one nothing
call local action_look actor address > clobber a0-a5,a7,fa0-fa6 [946:959] :the player seen rouses it
call local action_walk actor address > clobber a0-a5,a7,fa0-fa6 [961:972] :a patrol row, its footstep, then the look
call local action_alert actor address > yaw ACTOR_YAW(actor) f32,clobber a0-a1,a4-a5,fa0-fa4 [974:988] :faced to the player, the alert at its chest
call local action_aim actor address > lost ACTOR_LOST(actor) f32,clobber a0-a5,a7,fa0-fa6 [990:1016] :faced to the player and the sight taken; the sight lost for the lost seconds, a cycle at a time, sends it searching
call local action_fire actor address > state rng u64,clobber a0-a5,a7,fa0-fa6 [1018:1104] :with the player sighted, a round, the first after rousing certain and the rest by FIRE_CHANCE in 256, the line to the player's eye strayed, traced
call local action_seek actor address > clobber a0-a5,a7,fa0-fa6 [1106:1122] :a search row, its footstep, then the look, the player seen rousing it afresh
call local action_struck actor address > flags ACTOR_FLAGS(actor) u32,clobber a0-a1,a4-a5,fa0-fa4 [1124:1136] :the struck sound at its chest; roused
call local action_destroy actor address > state rng u64,clobber a0-a1,a4-a5,fa0-fa4 [1138:1177] :the destruction's sound at its chest and three sparks about it by chance
call local action_fall actor address > actors actors MAX_ACTORS*ACTOR_SIZE u8,clobber a0-a5,a7,fa0-fa1 [1179:1217] :the magazine dropped half a metre to the android's right, on its floor; the fall reported
rodata local k_chest_d f64 [1221:1222] :the chest over the feet
rodata local k_spark_drop_d f64 [1223:1224] :a spark's drop under its point
rodata local k_spark_spread_d f64 [1225:1226] :how far the destruction's sparks spread a unit of chance
rodata local k_android_speed_d f64 [1227:1228] :the android's walk a second
rodata local k_arrive_d f64 [1229:1230] :the arrival radius
rodata local k_quarter_d f64 [1231:1232]
rodata local k_sight_range_d f64 [1233:1234] :the android's sight's range
rodata local k_near_sight_d f64 [1235:1236] :the range it sees all round
rodata local k_stray_d f64 [1237:1239] :the G-1's stray a unit of chance, the tangent of twelve degrees over 128
rodata local k_blocked_seconds f32 [1240:1241] :the seconds blocked before a waypoint is given up
rodata local k_cycle_seconds f32 [1242:1243] :a cycle of aim and fire
rodata local k_lost_seconds f32 [1244:1245] :the seconds without sight before the search
bss local actors MAX_ACTORS*ACTOR_SIZE u8 [1249:1250] :the actor table, ACTOR_* records
bss local actor_entity ENTITY_SIZE u8 [1251:1252] :the scratch entity an actor draws through
bss local aim 7 f64 [1253:1254] :the line from an actor's eye to the player's, the eye, the unit direction, the distance, AIM_* fields
