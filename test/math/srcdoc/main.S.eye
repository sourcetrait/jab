set SWEEP_POINTS u64 [6] :the sin and cos sweep's angles, from k_start, k_step apart
set ATAN_PAIRS u64 [7] :the pairs of atan_pairs
set ANGLE_COUNT u64 [8] :the angles of angles
set VEC3_PAIRS u64 [9] :the pairs of vec3_pairs
set VEC2_COUNT u64 [10] :the vectors of vec2s
set F32_PAIRS u64 [11] :the pairs of f32_pairs
set RNG_BYTES u64 [12] :the bytes drawn for each rng line
set LINE_BYTES u64 [13] :room for a line
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
rodata local k_step f32 [827:828] :the sweep's step, a fortieth of a radian
rodata local k_start f32 [829:830] :the sweep's first angle, -20 radians
rodata local k_pi_f f32 [831:832] :pi as the assembler rounds it, which the macro must match
rodata local k_tau_f f32 [833:834] :tau as the assembler rounds it
rodata local k_half_pi_f f32 [835:837] :half pi as the assembler rounds it
rodata local k_pi_d f64 [838:839] :pi as the assembler rounds it
rodata local k_tau_d f64 [840:841] :tau as the assembler rounds it
rodata local k_half_pi_d f64 [842:843] :half pi as the assembler rounds it
rodata local atan_pairs 48 f32 [844:868] :y, x pairs, both zero, the axes, the diagonals, every octant, a point far along each axis
rodata local angles 11 f32 [869:871] :the angles each conversion takes
rodata local vec3_pairs 24 f64 [872:876] :a and b, three doubles each
rodata local vec2s 8 f64 [877:882] :the vectors, two doubles each
rodata local f32_pairs 24 f32 [883:887] :a and b, three singles each
rodata local word_sin 5 u8 [888:889]
rodata local word_cos 5 u8 [890:891]
rodata local word_atan2 7 u8 [892:893]
rodata local word_rad 5 u8 [894:895]
rodata local word_deg 5 u8 [896:897]
rodata local word_roundtrip 11 u8 [898:899]
rodata local word_f32_pi 14 u8 [900:901]
rodata local word_f32_tau 15 u8 [902:903]
rodata local word_f32_half_pi 21 u8 [904:905]
rodata local word_f64_pi 14 u8 [906:907]
rodata local word_f64_tau 15 u8 [908:909]
rodata local word_f64_half_pi 21 u8 [910:911]
rodata local word_vec3_dot 14 u8 [912:913]
rodata local word_vec3_len 14 u8 [914:915]
rodata local word_vec3_sqrlen 17 u8 [916:917]
rodata local word_vec3_norm 15 u8 [918:919]
rodata local word_vec3_norm_aliased 23 u8 [920:921]
rodata local word_vec2_len 14 u8 [922:923]
rodata local word_vec2_sqrlen 17 u8 [924:925]
rodata local word_f32_vec3_dot 14 u8 [926:927]
rodata local word_f32_reg_dot 18 u8 [928:929]
rodata local word_f32_reg_sqrlen 21 u8 [930:931]
rodata local word_f32_reg_len 18 u8 [932:933]
rodata local word_f32_reg_norm 19 u8 [934:935]
rodata local word_f32_vec2_reg_sqrlen 21 u8 [936:937]
rodata local word_f32_vec2_reg_len 18 u8 [938:939]
rodata local word_f64_reg_dot 18 u8 [940:941]
rodata local word_f64_reg_sqrlen 21 u8 [942:943]
rodata local word_f64_reg_len 18 u8 [944:945]
rodata local word_f64_reg_norm 19 u8 [946:947]
rodata local word_f64_vec2_reg_sqrlen 21 u8 [948:949]
rodata local word_f64_vec2_reg_len 18 u8 [950:951]
rodata local word_rng 5 u8 [952:953]
rodata local word_rngsys 8 u8 [954:955]
rodata local msg_rngsys_none 13 u8 [956:957] :the line for a machine with no rng device
bss local line 256 u8 [961:962] :the line being built
bss local lineptr addr [963:964] :the cursor in line
bss local norm_out 3 f64 [965:966] :a vec3 norm's result
bss local norm_out_f 3 f32 [967:969] :an f32 register norm's result
bss local rng_state u64 [970:971] :the generator's state word
