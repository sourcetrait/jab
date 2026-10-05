j _start [41:80] :opens the display, finds the workers, and starts each on its mailbox and stack; then, with the API's port on the machine, waits SELECT_WAIT for a letter: p the proof, 1 to 3 the bench with that many workers, anything else or none the animation; with no port, the animation at once
j local no_display [82:85] :`workers: no display` and exit 1
j local no_workers [87:90] :no online secondary: `workers: no worker hart online` and exit 2
j local animate [92:122] :for good: the workers by the clock, one, two, then three, PHASE_TICKS each; the zoom's step by the clock; each frame rendered, its bars and caption drawn, and flipped at the display's tick
j local proof [124:210] :the fixed frame for one worker up to every worker, each hashed before its bars and text: `workers: proof <W> hash <hash> rows <rows by worker> owned <rows owned>`, then shown; the last frame's SAMPLES rows over the API, `workers: proof sent <SAMPLES> rows`, and exit 0
j local bench [212:281] :the fixed frame over and over by the letter's workers for BENCH_TICKS: `workers: bench <W> frames <frames> ms <ms> hash <hash> rows <rows by worker>`, the last frame's band intervals and rows' owners over the API, and exit 0; more workers than run, `workers: too few worker harts for the bench` and exit 2
call local render workers u64 > ticks a0 u64,clobber a1,a7 [283:326] :a frame from the parameters: each worker's index and job published, one wake for them all, every join
 ticks :from before the first publish to after the last join
call local set_view x i64,y i64,step i64 > left PARAM_LEFT(params) i64,top PARAM_TOP(params) i64,pixel PARAM_STEP(params) i64 [328:339] :the frame centred on the point, Q.28
call local make_zoom > steps zoom_steps i64 [341:353] :SLOTS steps from STEP0, each ZOOM_NUM/256 of the one before
call local clear_owners > owners owners u8 [355:364] :every row's owner 0xff, none
call local owned_rows > rows a0 u64 [366:379] :the rows with an owner
call local copy_words from addr,to addr,bytes u64 > clobber a0-a2 [381:389]
 bytes :a multiple of 8, never 0
call local draw_bars > bars JAB_DISPLAY_BASE u32 [391:414] :each row's first BAR_WIDTH pixels in its owner's colour
call local draw_caption workers u64,ticks u64 > text caption u8,box JAB_DISPLAY_BASE u32,clobber a0-a5,a7,s11 [416:461] :the caption's box black, then `<W> worker(s), <ms> ms` in it
call local find_workers > workers a0 u64,harts worker_hart u64,count workers_n u64,clobber a1-a2,a7 [463:487] :the online secondaries, MAX_WORKERS at most
call local mailbox_of worker u64 > mailbox a0 addr [489:493]
call local mask_n workers u64 > mask a0 u64 [495:509] :the first workers' harts as a mask
call local start_worker worker u64 > clobber a0-a4,a7 [511:538] :the worker started on its hart, mailbox, and stack; a refusal ends the run
j local refused [540:543] :`workers: a start refused` and exit 3
call local say_str > clobber a0-a1,a7,s11 [545:553] :a whole line printed on the UART
 line :in a1, NUL-terminated
call local say > clobber a0,a7 [555:560] :the line, from its start to the cursor in s11, ended and printed on the UART
call local put_dec_then value u64,word addr > clobber a0-a1,s11 [562:571] :the value in decimal, then the word, put at the cursor
call local put_dec_then_rev value u64,word addr > clobber a0-a1,s11 [573:582] :the word, then the value in decimal, put at the cursor
call local put_str string addr > clobber a1,s11 [584:592]
 string :in a1, NUL-terminated, put at the cursor without its terminator
call local put_hex value u64 > clobber s11 [594:610] :the value as sixteen hex digits at the cursor
call local put_dec value u64 > clobber a0,s11 [612:634] :the value in decimal at the cursor, built backward in digits first
call local mandel_row row u64 > pixels JAB_DISPLAY_BASE u32,clobber a1-a7 [635:681] :the row's pixels from the parameters: each pixel's escape count's palette colour, or black for one in the set
j local frame_worker mailbox addr,hart u64 [683:730] :a worker: each job awaited, its bands rendered with each row's owner and each band's interval kept, its rows counted, its completion and a wake of hart 0; a stop ends it
