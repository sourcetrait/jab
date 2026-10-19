call local actors_place > actors actors MAX_ACTORS*ACTOR_SIZE u8,clobber a0-a5,a7,fa0-fa6 [68:151] :every actor gone, then one placed for each android and magazine entity, facing its yaw, its target the entity's, its feet on its sector's floor
call local actor_row actor addr,row u32 > row ACTOR_ROW(actor) u32,timer ACTOR_TIMER(actor) f32,clobber a0-a5,a7,fa0-fa6 [153:178] :an actor put in a row, its timer the row's milliseconds, the action taken
call local actor_ms actor addr > ms t0 i32 [180:186] :the milliseconds of an actor's row, negative for a held row
call local actors_tick > actors actors MAX_ACTORS*ACTOR_SIZE u8,clobber a0-a5,a7,fa0-fa6,fs7 [188:295] :one frame of every actor, an android's walk and its row's timer, a row ended entering the next with the leftover carried; a spark's frames
call local actors_draw > surface sprite_surface u64,screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clobber a0-a7,fa0-fa7 [297:335] :every actor whose sector the walk reached drawn
call local actor_draw actor addr,surface sprite_surface u64 > entity actor_entity ENTITY_SIZE u8,screen JAB_DISPLAY_BASE u32,depth zbuf SCREEN_W*SCREEN_H u32,clobber a0-a7,fa0-fa7 [337:434] :an actor drawn through sprite_draw from the scratch entity, by its class and row the frame's material, the quad's size, and the facing
 surface :the surface index the caller names
call local actor_rotation actor addr > frame a0 u64,clobber fa0 [436:498] :the rotation frame of an actor as the eye sees it, the eighth of a turn nearest the angle from the direction toward the eye to the facing
 frame :0 facing the eye, 2 showing its right side
call local actor_alloc > actor a0 addr [500:521] :a free actor, cleared
 actor :0 when the table is full
call local actor_index actor addr > index a0 u64 [523:528] :an actor's index in the table
call local actor_event actor addr,event u32 > record report_record REPORT_SIZE u8,clobber a0-a5,a7 [530:542] :an actor's event reported over the API with its index and its row
 event :an EVENT_*
call local actor_chest actor addr > x fa0 f64,y fa1 f64,z fa2 f64 [544:551] :the point at an actor's chest
call local actor_rouse actor addr > flags ACTOR_FLAGS(actor) u32,clobber a0-a5,a7,fa0-fa6 [553:574] :an actor roused into ALERT, unless it is already or is no longer shootable
call local actor_hurt actor addr,damage i32 > health ACTOR_HEALTH(actor) i32,flags ACTOR_FLAGS(actor) u32,clobber a0-a5,a7,fa0-fa6 [576:610] :an actor hurt, its health less the damage; destroyed at none, else struck, either reported and its row entered
call local spark_spawn sector i32,x f64,y f64,z f64 > actors actors MAX_ACTORS*ACTOR_SIZE u8,clobber a0-a1,a4-a5,fa3-fa4 [612:647] :a spark at a point, a free actor on its first frame, its feet a quarter metre under the point so the quad centres on it; the spark's sound there
call local actor_walk actor addr,x f64,y f64 > status a0 u64,feet ACTOR_X(actor) 3 f64,yaw ACTOR_YAW(actor) f32,sector ACTOR_SECTOR(actor) i32,fall ACTOR_FALL(actor) f64,blocked ACTOR_BLOCKED(actor) f32,clobber a1-a5,fa0-fa2,fs7 [649:742] :an actor walked toward a point for the frame, at its speed, no further than the point, facing its heading, the feet through feet_move
 status :1 arrived, 2 blocked past the blocked seconds, else 0
call local actor_patrol_step actor addr > target ACTOR_TARGET(actor) i32,clobber a0-a5,a7,fa0-fa6,fs7 [744:784] :an actor's frame of its patrol, walked toward its target waypoint; arrived or blocked, the next waypoint, or standing when there is none
call local actor_seek_step actor addr > clobber a0-a5,a7,fa0-fa6,fs7 [786:807] :an actor's frame of its search, walked toward where it last saw the player; arrived or blocked, its patrol resumes, or it stands
call local actor_to_eye actor addr > facing fa0 f64,line aim 7 f64,clobber fa1 [809:846] :the line from an actor's eye to the player's into aim, the eye, the unit direction, and the distance
 facing :the facing's share of the level direction, the cosine off it
call local actor_sight actor addr > sighted a0 bool,flags ACTOR_FLAGS(actor) u32,seen ACTOR_SEEN_X(actor) 3 f64,lost ACTOR_LOST(actor) f32,clobber a1-a2,fa0-fa6 [848:909] :whether an actor sees the player, within range and the front half turn, or near all round, and the trace from eye to eye reaching its capsule
 seen :the player's feet, when sighted
call local actor_face actor addr > yaw ACTOR_YAW(actor) f32,clobber fa0-fa1 [911:923] :an actor turned to the player
call local actor_footstep actor addr > clobber a0-a1,a4-a5,fa0-fa4 [925:952] :an actor's footstep for its row, the first on the first walking frame and the second on the third, at its feet
call local action_none actor addr [954:955] :an action on entering a row, this one nothing
call local action_look actor addr > clobber a0-a5,a7,fa0-fa6 [957:970] :the player seen rouses it
call local action_walk actor addr > clobber a0-a5,a7,fa0-fa6 [972:983] :a patrol row, its footstep, then the look
call local action_alert actor addr > yaw ACTOR_YAW(actor) f32,clobber a0-a1,a4-a5,fa0-fa4 [985:999] :faced to the player, the alert at its chest
call local action_aim actor addr > lost ACTOR_LOST(actor) f32,clobber a0-a5,a7,fa0-fa6 [1001:1027] :faced to the player and the sight taken; the sight lost for the lost seconds, a cycle at a time, sends it searching
call local action_fire actor addr > state rng u64,clobber a0-a5,a7,fa0-fa6 [1029:1115] :with the player sighted, a round, the first after rousing certain and the rest by FIRE_CHANCE in 256, the line to the player's eye strayed, traced
call local action_seek actor addr > clobber a0-a5,a7,fa0-fa6 [1117:1133] :a search row, its footstep, then the look, the player seen rousing it afresh
call local action_struck actor addr > flags ACTOR_FLAGS(actor) u32,clobber a0-a1,a4-a5,fa0-fa4 [1135:1147] :the struck sound at its chest; roused
call local action_destroy actor addr > state rng u64,clobber a0-a1,a4-a5,fa0-fa4 [1149:1188] :the destruction's sound at its chest and three sparks about it by chance
call local action_fall actor addr > actors actors MAX_ACTORS*ACTOR_SIZE u8,clobber a0-a5,a7,fa0-fa1 [1190:1228] :the magazine dropped half a metre to the android's right, on its floor; the fall reported
