j _start [17:29] :runs every case, then the two hot-code functions, and exits with 0
call local sweep > clobber a0,a7 [31:60] :prints a sin and a cos line for every angle of the sweep
call local atan_cases > clobber a0,a7 [62:101] :prints an atan2 line for each pair of atan_pairs
call local angle_cases > clobber a0,a7 [103:135] :prints a rad, a deg, and a roundtrip line for each angle
call local const_cases > clobber a0,a7 [137:176] :prints a const line for each of the six constants, the macro's beside the assembler's
call local vec3_cases > clobber a0-a1,a7 [178:227] :prints the f64 vec3 dot, len, sqrlen, norm, and aliased norm lines for each pair
call local vec3_result_line word addr,vec3 addr,result f64 > clobber a0-a1,a7 [229:247] :prints the word, the vec3, and the result
 word :NUL-terminated
 vec3 :arrives in s3
 result :arrives in fs0
call local vec3_norm_line word addr,vec3 addr > clobber a0-a1,a7 [249:268] :prints the word, the vec3, and the vec3 at norm_out
 word :NUL-terminated
 vec3 :arrives in s3
call local vec2_cases > clobber a0-a1,a7 [270:293] :prints the f64 vec2 len and sqrlen lines for each vector
call local vec2_result_line word addr,vec2 addr,result f64 > clobber a0-a1,a7 [295:313] :prints the word, the vec2, and the result
 word :NUL-terminated
 vec2 :arrives in s3
 result :arrives in fs0
call local f32_vec_cases > clobber a0-a1,a7 [315:344] :prints an f32 vec3 dot line for each pair of f32_pairs
call local reg_cases > clobber a0-a1,a7,fa0-fa5 [346:486] :prints a line for every register form over f32_pairs, vec3_pairs, and vec2s
call local f32_vec_line word addr,count u64,singles addr,result f32 > clobber a0,a7 [488:509] :prints the word, the singles, and the result
 word :NUL-terminated
 singles :arrives in s3
 result :arrives in fs0
call local rng_cases > clobber a0-a1,a7 [511:541] :prints rng lines for a fixed seed and a zero seed, then rngsys from jab.sys.random, or rngsys none
call local rng_report seed u64,word addr,state addr > clobber a0,a7 [543:575] :prints the word, the seed, the state, and RNG_BYTES bytes drawn from the state
 word :NUL-terminated
 state :arrives in s3, the generator's state word
call local expand_all > clobber fa0-fa3 [576:628] :every macro expanded once, on a page of its own, with no kernel call
call local trapped > flags a0 u64,clobber a7 [629:631] :one kernel call, on a page of its own
call local pair_line word addr,x f32,y f32 > clobber a0,a7 [633:652] :prints the word and the two singles
 word :NUL-terminated
 x :arrives in fs0
 y :arrives in fs1
call local pair_line64 word addr,x f64,y f64 > clobber a0,a7 [654:673] :prints the word and the two doubles
 word :NUL-terminated
 x :arrives in fs0
 y :arrives in fs1
call local line_reset > cursor lineptr addr [675:679]
 cursor :the start of line, the line empty
call local line_char char u8 > text line u8,cursor lineptr addr [681:687]
 text :the character appended at the cursor, not terminated
call local line_nl > text line u8,cursor lineptr addr [689:697]
 text :a newline and the terminator appended, the cursor left on the terminator
call local line_str string addr > text line u8,cursor lineptr addr [699:712]
 string :NUL-terminated
 text :the string appended without its terminator
call local line_hex byte u8 > text line u8,cursor lineptr addr [714:739]
 text :the byte's two lowercase hex digits appended
call local line_hex32 value u32 > text line u8,cursor lineptr addr,clobber a0 [741:758]
 text :the low 32 bits as eight hex digits, highest first
call local line_hex64 value u64 > text line u8,cursor lineptr addr,clobber a0 [760:777]
 text :sixteen hex digits, highest first
call local line_doubles doubles addr,count u64 > text line u8,cursor lineptr addr,clobber a0 [779:800]
 text :each double's sixteen hex digits and a space
call local line_floats singles addr,count u64 > text line u8,cursor lineptr addr,clobber a0 [802:823]
 text :each single's eight hex digits and a space
