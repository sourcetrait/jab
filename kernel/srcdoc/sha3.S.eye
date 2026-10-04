ecall sys_checksum bytes addr,size u64 > lane0 a0 u64,lane1 a1 u64,lane2 a2 u64,lane3 a3 u64 [13:31] :the SHA3-256 of the bytes, its four lanes in the order a program writes them out
 bytes :ends the run unless the whole range lies inside the program's window
call sha3_256 bytes addr,length u64 > digest sha3_a u64,clobber a0-a3 [32:95]
 digest :the first four lanes of the state
call local sha3_absorb block addr > state sha3_a u64 [97:128] :exclusive-ors SHA3_RATE bytes into the state's first lanes
call keccak_f > state sha3_a u64,clobber a0-a3 [129:268] :runs the permutation over the state
