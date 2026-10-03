set HEALTH_START i32 [1] :the player's health at the start
set MAGAZINE_ROUNDS i32 [2] :the rounds a magazine adds
set NOISE_HOPS [3] :the sectors deep a noise floods, rousing within its range
set MET_NOTHING i32 [4] :a round met nothing, over the API
set MET_GEOMETRY i32 [5] :a round met the geometry
set MET_ANDROID i32 [6] :a round met an android
rodata local k_round_range_d f64 [10:11] :a round's range
rodata local k_pickup_sq_d f64 [12:13] :a pickup's reach in the plan, squared
rodata local k_pickup_rise_d f64 [14:15] :a pickup's reach in height
rodata local k_noise_range_sq_d f64 [16:17] :a noise's range, squared
call local player_reset > health health i32,rounds rounds i32,keys pad_prev u32,state rng u64,clobber a0-a1,a7 [21:39] :the frame's health and rounds at the start, the chance seeded from the kernel's entropy, the clock without it, the pad's last keys none
call local player_fire > hit trace_hit TRACE_SIZE u8,clobber a0-a5,a7,fa0-fa6 [41:119] :one round, the G-1's report at the player, the trace from the eye along the forward, an android met hurt, a spark where it lands, the shot heard
call local player_hurt damage i32 > health health i32,clobber a0-a5,a7 [121:140] :the frame hurt, the health less the damage, floored at 0, reported
call local player_pickups > rounds rounds i32,actors actors MAX_ACTORS*ACTOR_SIZE u8,clobber a0-a5,a7,fa3-fa4 [142:206] :every magazine within a metre of the feet in the plan and a metre in height taken, its rounds added, the pickup sound, the rounds reported
call local noise_heard > clobber a0-a5,a7,fa0-fa6 [208:351] :a noise at the player, a flood from the camera's sector through the walls' portals NOISE_HOPS deep, every unroused android in it within range roused
bss local rng u64 [355:356] :the generator's state word
bss local health i32 [357:358] :the player's health
bss local rounds i32 [359:360] :the player's rounds
bss local pad_prev u32 [361:363] :the pad's keys the frame before
bss local noise_fifo MAX_SECTORS u32 [364:365] :the flood's queue, a sector with its depth above it
bss local noise_seen MAX_SECTORS u8 [366:367] :the sectors the flood reached
