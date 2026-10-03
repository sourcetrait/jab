set SHA3_LANES u64 [4] :the state's 64-bit lanes
set SHA3_RATE u64 [5] :bytes in a block
set SHA3_ROUNDS u64 [6] :the permutation's rounds
set SHA3_PAD u8 [7] :the padding byte where the message ends
set SHA3_LAST u8 [8] :the padding bit in a block's last byte
ecall sys_checksum bytes addr,size u64 > lane0 a0 u64,lane1 a1 u64,lane2 a2 u64,lane3 a3 u64 [13:31] :the SHA3-256 of the bytes, its four lanes in the order a program writes them out
 bytes :ends the run unless the whole range lies inside the program's window
call sha3_256 bytes addr,length u64 > digest sha3_a u64,clobber a0-a3 [32:95]
 digest :the first four lanes of the state
call local sha3_absorb block addr > state sha3_a u64 [97:128] :exclusive-ors SHA3_RATE bytes into the state's first lanes
call keccak_f > state sha3_a u64,clobber a0-a3 [129:268] :runs the permutation over the state
rodata local sha3_pi 25 u8 [272:274] :where each lane goes in rho and pi
rodata local sha3_rho 25 u8 [275:277] :how far each lane turns on its way there
rodata local sha3_next 5 u8 [278:279] :the column after each
rodata local sha3_next2 5 u8 [280:281] :the column two after each
rodata local sha3_prev 5 u8 [282:284] :the column before each
rodata local sha3_rc 24 u64 [285:297] :each round's iota constant
bss sha3_a 25 u64 [302:303] :the state
bss local sha3_b 25 u64 [304:305] :the lanes after rho and pi
bss local sha3_c 5 u64 [306:307] :theta's column folds
bss local sha3_block 136 u8 [308:309] :the last block, padded
