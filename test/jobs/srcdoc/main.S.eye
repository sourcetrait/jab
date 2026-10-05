j _start [30:53] :waits SELECT_WAIT for the scenario's letter over the API, finds the workers, and runs the scenario; with none, `jobs: no scenario` and exit 2
j local no_workers [55:58] :no online secondary: `jobs: no worker hart online` and exit 2
j local fixture [60:78] :`jobs: scenario fixture, workers <W>`, every worker started on a fresh mailbox
j local idle_hold [80:92] :HOLD_TICKS display ticks with every worker asleep in its await: `idle <W> workers held`
j local race_rounds [94:171] :the four races of ROUNDS rounds, `<race> <rounds> rounds, <wrong> wrong, <completions> completions` each, then every worker stopped
j local empty_full [173:212] :a mailbox free, a job in flight, free again after its join: `free <free> then <free> then <free>, out <output>`
j local wrap [214:265] :WRAP_JOBS jobs from WRAP_START through the wrap: `wrap <jobs> jobs, generation <done>, <wrong> wrong`
j local cancel [267:313] :a job cancelled mid-way and one cancelled before its publish: `cancel during <status> under <short>, cancel before <status> bands <bands>`, then `jobs: done` and exit 0
j local costs [315:404] :the costs' rounds for one worker and then every worker, the samples sent over the API: `jobs: costs, workers <W>, <bytes> bytes` and exit 0
j local job_worker mailbox addr,hart u64 [406:455] :a worker: each job awaited, its bands run with a cancel check between, its output, its completion and a wake of hart 0, then its lingering; a stop ends it
call local find_workers > workers a0 u64,harts worker_hart u64,count workers_n u64,clobber a1-a2,a7 [457:485] :the online secondaries, MAX_WORKERS at most
call local mailbox_of worker u64 > mailbox a0 addr [487:491]
call local output_of worker u64 > output a0 addr [493:497]
call local reset_mailbox worker u64 > clobber a0 [499:511] :the worker's mailbox zeroed
call local set_args workers u64,ticks u64,bands u64,delay u64 > clobber a0 [513:540] :each of the first workers' job arguments
call local start_worker worker u64 > clobber a0-a4,a7 [542:569] :the worker started on its hart, mailbox, and stack; a refusal ends the run
j local refused [571:574] :`jobs: a start refused` and exit 3
call local start_n workers u64 > clobber a0-a4,a7 [576:594]
call local mask_n workers u64 > mask a0 u64 [596:610] :the first workers' harts as a mask
call local stop_n workers u64 > clobber a0-a1,a7 [612:619]
call local publish_n workers u64,size u64 > clobber a0 [621:649] :a job a worker, the given size, the worker's output its payload
call local join_n workers u64 > clobber a0-a1,a7 [651:673]
call local check_n workers u64,size u64 > wrong a0 u64 [675:695] :the outputs other than the size times OUT_FACTOR plus the worker's hart
call local count_n workers u64 > completions a0 u64 [697:709]
call local spin ticks u64 [711:717]
call local field value u64,label addr > clobber a0-a1,s11 [719:728] :the label, then the value in decimal, put at the cursor
call local put_dec_then value u64,word addr > clobber a0-a1,s11 [730:739] :the value in decimal, then the word, put at the cursor
call local put_dec_then_rev value u64,word addr > clobber a0-a1,s11 [741:750] :the word, then the value in decimal, put at the cursor
call local say_str > clobber a0-a1,a7,s11 [752:760] :a whole line printed on the UART
 line :in a1, NUL-terminated
call local say > clobber a0,a7 [762:767] :the line, from its start to the cursor in s11, ended and printed on the UART
call local put_str string addr > clobber a1,s11 [769:777]
 string :in a1, NUL-terminated, put at the cursor without its terminator
call local put_dec value u64 > clobber a0,s11 [779:799] :the value in decimal at the cursor, built backward in digits first
