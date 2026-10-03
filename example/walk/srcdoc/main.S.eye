set DISK u8 [3] :the romfs disk's id
set FRAME_W u32 [4] :a walker frame's width in pixels
set FRAME_H u32 [5] :a walker frame's height in pixels
set FRAMES u32 [6] :the frames of the walk cycle
set SPRITE_BYTES u64 [7] :the sprite buffer jab.sys.sprite.load needs for the frames
set LANES u64 [8] :the lanes, top to bottom
set LANE_H u64 [9] :a lane's height in pixels
set PER_LANE u64 [10] :the most walkers a lane holds at once
set SCALE_MIN u64 [11] :the least a walker is drawn at, five feet, in 256ths
set SCALE_MAX u64 [12] :the most a walker is drawn at, seven feet, in 256ths
set STRIDE u64 [13] :astra's stride, pixels of travel a walk cycle at the frame's own size
set ENTRY_GAP i64 [14] :the pixels a new walker needs clear at its edge
set ENTRY_WAIT u64 [15] :the most a lane waits after an entry before another, four seconds in ticks
set ANIM_TICKS u64 [16] :the animation's step, sixteen frames a second in ticks
set DT_MAX u64 [17] :the most time one frame moves anybody, a tenth of a second in ticks
set BACKGROUND u32 [18] :the screen's colour, black
set W_X i64 [19] :the left edge, in 256ths of a pixel
set W_DIR i64 [20] :1 walking right, -1 walking left
set W_SCALE u64 [21] :the scale in 256ths
set W_TINT u64 [22] :the colour, 0x00RRGGBB
set W_FRAME u64 [23] :the animation's frame
set W_TICK u64 [24] :the animation's time since its last frame
set W_DW u64 [25] :the drawn width
set W_DH u64 [26] :the drawn height
set W_Y i64 [27] :the top, the feet on the lane's floor
set W_ACTIVE u64 [28] :1 while the place holds a walker
set W_SPEED u64 [29] :256ths of a pixel a second
set W_SIZE u64 [30] :a walker record's bytes
set LANE_WAIT i64 [31] :the ticks until the lane may take another, after its walkers
set LANE_SIZE u64 [32] :a lane's bytes
set R_KIND u8 [33] :1 a walker entered, 2 one left
set R_LANE u8 [34] :the lane
set R_SIDE u8 [35] :the side it entered from, 0 the left, 0 for a leaving
set R_SCALE u8 [36] :its scale in 256ths, 0 for a leaving
set R_TINT u32 [37] :its colour, 0 for a leaving
set R_SIZE u64 [38] :an API record's bytes
j _start [42:54] :loads the walker, opens the display, and runs the sidewalk until the window closes
j local frame [55:195] :one frame, every walker cleared, moved, and drawn, the changed areas flipped
j local bad_sprite code u64 [197:213] :says so on the UART with the code and exits with 1
 code :the JAB_PNG_* code jab.sys.sprite.load gave
j local no_display [214:216] :says so on the UART and exits with 1
call local admit lane addr,number u64 > walker 0(lane) u64,wait LANE_WAIT(lane) i64,clobber a1-a2,a7 [218:295] :lets a walker in when the lane has a free place, its wait is over, and the side chosen is clear
 number :the lane's index, 0 the top
 walker :a free place's record, filled by enter
 wait :random up to ENTRY_WAIT after an entry, less dt each frame while it runs
call local enter walker addr,lane u64,side u64 > walker 0(walker) u64,clobber a0-a1,a7 [297:382] :a walker entering the lane from the side, random in colour, size, and first frame, the host told
 side :0 the left, 1 the right
 walker :every field, W_ACTIVE 1, the speed a stride a second at the frame's own size
call local leave lane u64 > clobber a0-a1,a7 [384:399] :tells the host a walker left the lane
call local note_rect left i64,right i64,top i64,height u64 > rect rects u32,count rect_count u64,clobber a0-a2 [401:433] :adds the rectangle, clipped to the screen, to the ones to flip, nothing when none of it is on the screen
 right :the column past the last
 rect :the next JAB_RECT_SIZE bytes of rects
call local elapsed > dt dt u64,last last_time u64 [435:447]
 dt :the ticks since the frame before, at most DT_MAX
 last :the clock now, for the next frame
call local advance value i64,rate i64 > value a0 i64 [449:456]
 rate :a speed a second
 value :moved on by rate times dt over JAB_TIME_HZ
call local random > next a0 u64,seed seed u64 [458:469]
 next :the next of the xorshift sequence, also the new seed
rodata local path_walker 8 u8 [472:473] :the romfs directory holding the walker's frames
rodata local msg_no_display 18 u8 [474:475] :the line for a machine with no display
data local msg_bad_sprite 38 u8 [478:479] :the line for a walker that would not load, its code following
data local msg_bad_sprite_code 4 u8 [480:481] :the code's digits, a newline, and the terminator, written by bad_sprite
bss local seed u64 [485:486] :the random sequence's state, never zero
bss local last_time u64 [487:488] :the clock at the frame before, in ticks
bss local dt u64 [489:490] :the frame's time in ticks, at most DT_MAX
bss local record 8 u8 [491:492] :the API record being sent
bss local rect_count u64 [493:494] :the rectangles noted this frame
bss local rects 96 u32 [495:496] :the rectangles to flip, one a walker at most
bss local lanes 272 u64 [497:498] :the lanes' walker records and waits
bss local sprite 19701776 u8 [499:500] :the walker sprite
