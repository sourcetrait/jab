j _start [182:201] :loads the walker, opens the display, and runs the sidewalk until the window closes; under CADENCE the measurement's start first
j local frame [202:366] :one frame, every walker cleared, moved, and drawn, the changed areas flipped; under CADENCE each recorded
j local bad_sprite code u64 [368:384] :says so on the UART with the code and exits with 1
 code :the JAB_PNG_* code jab.sys.sprite.load gave
j local no_display [385:387] :says so on the UART and exits with 1
call local admit lane addr,number u64 > walker 0(lane) u64,wait LANE_WAIT(lane) i64,clobber a1-a2,a7 [389:466] :lets a walker in when the lane has a free place, its wait is over, and the side chosen is clear
 number :the lane's index, 0 the top
 walker :a free place's record, filled by enter
 wait :random up to ENTRY_WAIT after an entry, less dt each frame while it runs
call local enter walker addr,lane u64,side u64 > walker 0(walker) u64,clobber a0-a1,a7 [468:557] :a walker entering the lane from the side, random in colour, size, and first frame, the host told, under CADENCE through the event buffer
 side :0 the left, 1 the right
 walker :every field, W_ACTIVE 1, the speed a stride a second at the frame's own size
call local leave lane u64 > clobber a0-a1,a7 [559:578] :tells the host a walker left the lane, under CADENCE through the event buffer
call local note_rect left i64,right i64,top i64,height u64 > rect rects u32,count rect_count u64,area frame_rect_area u64,clobber a0-a2 [580:619] :adds the rectangle, clipped to the screen, to the ones to flip, nothing when none of it is on the screen
 right :the column past the last
 rect :the next JAB_RECT_SIZE bytes of rects
 area :under CADENCE, the rectangle's width by its height added
call local elapsed > dt dt u64,last last_time u64,raw raw_elapsed u64 [621:637]
 dt :the ticks since the frame before, at most DT_MAX
 last :the clock now, for the next frame
 raw :under CADENCE, those ticks before DT_MAX holds them
call local advance value i64,rate i64 > value a0 i64 [639:646]
 rate :a speed a second
 value :moved on by rate times dt over JAB_TIME_HZ
call local random > next a0 u64,seed seed u64 [648:661]
 next :the next of the xorshift sequence, also the new seed
call local cadence_setup > nonce H_NONCE(header) u64,seed seed u64,origin origin u64,last last_time u64,ordinal last_ordinal u64,frame s6 u64,clobber a0-a1,a7,s7 [662:729] :CADENCE's start: the capture nonce, under REPLAY its stream, read by one deadline; the seed, the leading anchor, and the origin
 nonce :WNON's, never 0; exit 6 past REPLAY_WAIT or on a malformed frame
 seed :CADENCE_SEED, under REPLAY the stream's; in the header besides
 origin :the clock after the anchor's last wait, the zero of every stamp; in the header besides
 last :the origin, so frame 0's elapsed runs from it
 ordinal :1, the display's open the machine's first present
 frame :0
j local no_nonce [730:732] :says so on the UART and exits with 6
j local bad_nonce [733:736] :says so on the UART and exits with 6
j local no_replay [737:739] :says so on the UART and exits with 5
j local bad_replay [740:743] :says so on the UART and exits with 5
call local api_fill bytes addr,length u64,deadline s7 u64 > short a0 bool,clobber a1,a7 [745:772] :exactly the length read from the API into the bytes, never waiting past the deadline, the display's tick waking each pass
 short :1 when the deadline passed with the bytes short, 0 when they came whole
call local frame_begin frame s6 u64 > record s5 addr,enters frame_enters u64,leaves frame_leaves u64,walkers frame_walkers u64,drawn frame_drawn u64,area frame_rect_area u64 [774:789] :the frame's record and its counters made ready
 record :frames plus the frame's number times F_SIZE
call local await_stamped record s5 addr > waited F_WAITED(record) u8,clobber a0-a1,a7 [791:809] :the frame's presentation wait, its start and its end stamped under TIMING
call local frame_started frame s6 u64,record s5 addr > start F_START(record) u32,dt dt u64,clobber a0-a1 [811:828] :the frame's start, elapsed's clock, stamped
 dt :under REPLAY the stream's value for the frame in place of the measured one
call local stamp clock u64,field u64,record s5 addr > offset field(record) u32,range range_hit u64 [830:843] :the clock's ticks from the origin stored at the field of the frame's record
 range :1 when they reach 2^32, the offset then not stored and the window ended at this frame
call local note_drawn walker s1 addr > walkers frame_walkers u64,drawn frame_drawn u64 [845:857] :a walker drawn this frame counted, its drawn area, DW by DH, added
call local event_append record record R_SIZE u8 > events events EVENTS_MAX*R_SIZE u8,count event_count u64,omitted event_omitted u64,enters frame_enters u64,leaves frame_leaves u64 [859:887] :the API record into the event buffer in place of its write, its enter or leave counted for the frame
 omitted :one more for a record past the buffer, which is not written
call local frame_present record s5 addr,frame s6 u64 > closes a0 bool,status F_STATUS(record) u8,receipt F_S(record) 2 u64,ordinal F_ORDINAL(record) u32,last last_ordinal u64,frame s6 u64,clobber a1-a3,a7,s7-s10 [889:966] :the frame's end: CADENCE_TEST's spin, the work's end, PREPARE's wait, the flip or its skip with their stamps and the receipt, the record closed by frame_end
 closes :frame_end's
 status :the final flip's, NO_STATUS with none issued; under PREPARE an early refusal is waited again and taken again
 receipt :the flip's acceptance and its tick, 0 and 0 with none issued
 ordinal :the flip's present ordinal, or with none issued the last the program knows
call local frame_end record s5 addr,frame s6 u64 > closes a0 bool,frame s6 u64,ended ended_by u64 [968:1034] :the frame's record completed and counted, then the window's ends held in order: an offset's range, REPLAY's last frame or the duration, a full frame buffer, too little event room
 closes :1 when one holds, ended_by then its ENDED_* value
 frame :the frames recorded
call local test_spin frame s6 u64 [1035:1053] :CADENCE_TEST's work: frames STALL_FIRST to STALL_LAST spin after their draw until STALL_TICKS from the frame's start, CLAMP_FRAME until CLAMP_TICKS
j local trail > clobber s7 [1055:1062] :after the window, TRAIL_PERIODS waits with no flip, the export, and the exit with 0
call local export frames s6 u64 > header header H_SIZE u8,end end_record E_SIZE u8,clobber a0-a2,a7 [1064:1145] :the record out over the API: the header and the end record completed, the CRC-32 taken over the header, the frames, and the events, then each written, the end record last
call local crc32 state u32,bytes addr,length u64 > state a0 u32,clobber a1-a2 [1147:1166] :the CRC-32, reflected 0xedb88320, carried on from the state, pre-inverted, over the bytes
call local api_out bytes addr,length u64 > clobber a0-a1,a7 [1168:1197] :the bytes to the API in writes of at most EXPORT_CHUNK; exit 3 at a status of 1, no port, and 4 at 2, an interrupted send, nothing retried
