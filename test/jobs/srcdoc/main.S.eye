j _start [31:54] :waits SELECT_WAIT for the scenario's letter over the API, finds the workers, and runs the scenario; with none, `jobs: no scenario` and exit 2
j local no_workers [56:59] :no online secondary: `jobs: no worker hart online` and exit 2
j local fixture [61:79] :`jobs: scenario fixture, workers <W>`, every worker started on a fresh mailbox
j local idle_hold [81:93] :HOLD_TICKS display ticks with every worker asleep in its await: `idle <W> workers held`
j local race_rounds [95:172] :the four races of ROUNDS rounds, `<race> <rounds> rounds, <wrong> wrong, <completions> completions` each, then every worker stopped
j local empty_full [174:213] :a mailbox free, a job in flight, free again after its join: `free <free> then <free> then <free>, out <output>`
j local wrap [215:278] :WRAP_JOBS jobs of WRAP_BANDS bands from WRAP_START through the wrap, each one's status and bands kept: `wrap <jobs> jobs, generation <done>, <wrong> wrong, statuses <statuses>, bands <bands>`
j local cancel [280:326] :a job cancelled mid-way and one cancelled before its publish: `cancel during <status> under <short>, cancel before <status> bands <bands>`, then `jobs: done` and exit 0
j local costs [328:417] :the costs' rounds for one worker and then every worker, the samples sent over the API: `jobs: costs, workers <W>, <bytes> bytes` and exit 0
j local job_worker mailbox addr,hart u64 [419:468] :a worker: each job awaited, its bands run with a cancel check between, its output, its completion and a wake of hart 0, then its lingering; a stop ends it
call local find_workers > workers a0 u64,harts worker_hart u64,count workers_n u64,clobber a1-a2,a7 [470:498] :the online secondaries, MAX_WORKERS at most
call local mailbox_of worker u64 > mailbox a0 addr [500:504]
call local output_of worker u64 > output a0 addr [506:510]
call local reset_mailbox worker u64 > clobber a0 [512:524] :the worker's mailbox zeroed
call local set_args workers u64,ticks u64,bands u64,delay u64 > clobber a0 [526:553] :each of the first workers' job arguments
call local start_worker worker u64 > clobber a0-a4,a7 [555:582] :the worker started on its hart, mailbox, and stack; a refusal ends the run
j local refused [584:587] :`jobs: a start refused` and exit 3
call local start_n workers u64 > clobber a0-a4,a7 [589:607]
call local mask_n workers u64 > mask a0 u64 [609:623] :the first workers' harts as a mask
call local stop_n workers u64 > clobber a0-a1,a7 [625:632]
call local publish_n workers u64,size u64 > clobber a0 [634:662] :a job a worker, the given size, the worker's output its payload
call local join_n workers u64 > clobber a0-a1,a7 [664:686]
call local check_n workers u64,size u64 > wrong a0 u64 [688:708] :the outputs other than the size times OUT_FACTOR plus the worker's hart
call local count_n workers u64 > completions a0 u64 [710:722]
call local spin ticks u64 [724:730]
call local field value u64,label addr > clobber a0-a1,s11 [732:741] :the label, then the value in decimal, put at the cursor
call local put_dec_then value u64,word addr > clobber a0-a1,s11 [743:752] :the value in decimal, then the word, put at the cursor
call local put_dec_then_rev value u64,word addr > clobber a0-a1,s11 [754:763] :the word, then the value in decimal, put at the cursor
call local put_kept offset u64 > clobber a0,s11 [765:788] :each wrap job's field at that offset in wrap_kept's records, in decimal and spaced, put at the cursor
call local say_str > clobber a0-a1,a7,s11 [790:798] :a whole line printed on the UART
 line :in a1, NUL-terminated
call local say > clobber a0,a7 [800:805] :the line, from its start to the cursor in s11, ended and printed on the UART
call local put_str string addr > clobber a1,s11 [807:815]
 string :in a1, NUL-terminated, put at the cursor without its terminator
call local put_dec value u64 > clobber a0,s11 [817:837] :the value in decimal at the cursor, built backward in digits first
