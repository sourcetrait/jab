call local camera_spawn > camera camera 15 f32,doubles camera_d 15 f64,sector cam_sector i32,clobber a0,fa0 [26:55] :the camera at the map's first spawn, facing its yaw and pitch, roll 0, its basis derived
call local camera_basis > basis CAM_RIGHT(camera) 9 f32,doubles camera_d 15 f64,clobber fa0 [57:122] :the basis from the angles, forward (cos p cos y, cos p sin y, sin p), right (sin y, -cos y, 0) and up = right x forward, both turned by the roll; the camera as doubles for the surface mathematics
 basis :right, up, and forward
call local camera_axes > x right_x u32,y right_y u32,clobber a0-a1,a7 [124:139] :the right stick's axis codes, Z and RZ when the pad has a Z, else RX and RY
call local axis code u32 > throw fa0 f32 [141:165] :a pad axis of pad_state as -1 to 1, 0 within the dead zone, the rest rescaled to reach 1
call local camera_look seconds f32 > angles CAM_YAW(camera) 2 f32,eye camera 3 f32,sector cam_sector i32,keys pad_prev u32,state pad_state JAB_PAD_ENTRY u8,latched pad_latched u32,clobber a0-a5,a7,fa0-fa6 [167:276] :one frame of the pad, the trigger firing on a press since the frame before, among the events, or latched in the wait before, the right stick turning the yaw and the pitch, the left stick walking the body; no pad, the body meets the floor
 seconds :the seconds since the frame before
 angles :the yaw and the pitch
call local camera_locate > sector cam_sector i32,clobber a0-a5,fa0-fa2 [278:295] :cam_sector followed to the sector holding the eye, from the one it was in; none stays none until one holds it
call local sky_setup > u sky_uoff i64,v sky_voff i64 [297:316] :the sky's offsets for the frame from the yaw and pitch, repeats in 16.16
call local state_report > record report_record REPORT_SIZE u8,clobber a0-a1,a7 [318:334] :the state record over the API
call local event_report kind u32,field0 i32,field1 i32,field2 i32,field3 i32,field4 i32 > record report_record REPORT_SIZE u8,clobber a0-a1,a7 [336:351] :an event record over the API, its fields over the state's
 kind :a REPORT_*
call local report_fill > record report_record REPORT_SIZE u8 [353:380] :the state's fields into report_record, the sector, the eye, the angles in degrees, the last frame's drawing and game microseconds
