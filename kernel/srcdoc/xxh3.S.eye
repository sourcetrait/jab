set XX_STRIPE u64 [4] :bytes in a stripe
set XX_ACCS u64 [5] :the accumulators
set XX_SECRET u64 [6] :bytes in the secret
set XX_CONSUME u64 [7] :bytes the secret moves on by each stripe
set XX_STRIPES_PER_BLOCK u64 [8] :the stripes between scrambles
set XX_BLOCK u64 [9] :bytes in a block of stripes
set XX_MERGE_START u64 [10] :the secret's offset where the fold starts
set XX_LASTACC_START u64 [11] :how far before the secret's last stripe the input's last stripe is read against
set XX_SECRET_SIZE_MIN u64 [12] :the reference's smallest secret
set XX_MIDSIZE_START u64 [13] :the secret's offset for the rounds past the eighth from 129 to 240 bytes
set XX_MIDSIZE_LAST u64 [14] :how far before the smallest secret's end the last sixteen bytes are read against
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
rodata local xx_prime64_1 u64 [685:686]
rodata local xx_prime64_2 u64 [687:688]
rodata local xx_prime64_3 u64 [689:690]
rodata local xx_prime64_4 u64 [691:692]
rodata local xx_prime64_5 u64 [693:694]
rodata local xx_prime32_1 u64 [695:696]
rodata local xx_prime_mx1 u64 [697:698]
rodata local xx_prime_mx2 u64 [699:700]
rodata local xx_init 8 u64 [701:710] :what the eight accumulators start at
rodata local xx_secret 192 u8 [711:735] :the default secret
bss local xx_acc 8 u64 [739:740] :the accumulators
bss local xx_lo u64 [741:742] :a mix's low input, or the fold's
bss local xx_hi u64 [743:744] :a mix's high input
bss local xx_data u64 [745:746] :a stripe lane's input
bss local xx_stripe_n u64 [747:748] :the stripe xx_accumulate is at
