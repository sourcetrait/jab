macro jab.rng.seed state address,value u64 > word 0(state) u64,scratch t0 [1:7]
 value :0 seeds 0x2545f4914f6cdd1d instead
macro jab.rng.byte dst reg,state address > byte dst u8,word 0(state) u64,scratch t0-t1 [9:20]
 byte :bits 24 to 31 of the new word
