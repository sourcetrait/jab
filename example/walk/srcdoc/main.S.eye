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
