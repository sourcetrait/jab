ecall sys_harts_reserve count u64 > status a0 u64,grant a1 u64 [9:65] :hart 0's, once a run: every unowned online secondary to the reservation, the count its floor; under DEBUG jab.claimids=<n> leaves n claim ids
 status :JAB_RESERVE_*, decided before anything is written: ALREADY first, then SHORT, then BUSY
 grant :the reservation's harts, 0 on a refusal
ecall sys_harts_claim mask u64 > status a0 u64,owner a1 u64 [66:123] :hart 0's: the mask's harts from the reservation's grant to a new claim
 status :JAB_CLAIM_*, decided before anything is written, in code order; SPENT once owners_next reaches CLAIM_IDS, the counter and the owners as they stood
 owner :the claim's id, 2 up to 2^63 - 1 from owners_next, never reused within the run; 0 on a refusal
ecall sys_harts_release owner u64 > status a0 u64,returned a1 u64 [124:161] :hart 0's: a claim's harts back to the reservation's grant
 status :JAB_RELEASE_*: UNKNOWN for an id below OWNER_FIRST_CLAIM or one no online hart holds, BUSY with a worker on a hart of it
 returned :the harts returned, 0 on a refusal
ecall sys_harts_owned owner u64 > harts a0 u64 [162:166] :hart 0's: the online secondaries holding the owner, read at the call
call local owned_mask owner u64 > harts a0 u64,clobber a1-a2 [168:199] :the online secondaries whose HART_OWNER is the owner, from the records; hart 0 never among them
call local working harts u64 > working a0 u64 [201:226] :those of the harts whose HART_WORK is not idle, read before fence r, rw, so each one's last exit is acquired
call local set_owner harts u64,owner u64 [228:261] :every hart of the mask its HART_OWNER the owner
