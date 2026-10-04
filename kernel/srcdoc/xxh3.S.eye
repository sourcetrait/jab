ecall sys_hash bytes addr,size u64 > hash a0 u64 [19:29] :the XXH3-64 of the bytes
 bytes :ends the run unless the whole range lies inside the program's window
call xxh3_64 bytes addr,length u64 > hash a0 u64,clobber a1-a2 [30:52] :the XXH3-64 with seed zero, chosen among the four algorithms by length
call local xx_short bytes addr,length u64 > hash a0 u64,clobber a1 [54:191] :up to and including 16 bytes, in four cases of its own
call local xx_mid bytes addr,length u64 > hash a0 u64,clobber a1 [193:243] :seventeen to 128 bytes, as pairs of mixes working inward from both ends
call local xx_midlarge bytes addr,length u64 > hash a0 u64,clobber a1 [245:314] :129 to 240 bytes
call local xx_long bytes addr,length u64 > hash a0 u64,clobber a1-a2 [316:387] :past 240 bytes, over eight accumulators
call local xx_accumulate input addr,secret addr,stripes u64 > accumulators xx_acc u64,clobber a0-a1 [389:418] :each stripe against the secret moved on XX_CONSUME bytes a stripe, the sound stream looked at before each
call local xx_accumulate_512 stripe addr,secret addr > accumulators xx_acc u64,clobber a0 [420:468]
call local xx_scramble secret addr > accumulators xx_acc u64,clobber a0 [470:501]
call local xx_merge start u64 > hash a0 u64,clobber a1 [503:551] :folds the accumulators down from the start value
call local xx_mix16 input addr,secret addr > mix a0 u64,clobber a1 [553:584] :sixteen bytes against sixteen of the secret
call local xx_mul128_fold left u64,right u64 > fold a0 u64 [586:590] :the 128-bit product's two halves exclusive-ored together
call local xx_avalanche value u64 > mixed a0 u64 [592:600] :the XXH3 finisher
call local xx64_avalanche value u64 > mixed a0 u64 [602:615] :the XXH64 finisher
call local xx_rrmxmx value u64,length u64 > mixed a0 u64 [617:635] :the finisher of four to eight bytes
call local xx_bswap64 value u64 > swapped a0 u64 [637:651]
call local xx_le64 at addr > value a0 u64 [653:668]
call local xx_le32 at addr > value a0 u32 [670:681]
