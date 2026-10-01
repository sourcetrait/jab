# The type libraries under test: every macro over fixed inputs, each result
# to the UART as its bit pattern, decoded and checked on the host.
.include "jab.inc"
.include "jab_f32.inc"
.include "jab_f64.inc"
.include "jab_rng.inc"

# sin and cos over SWEEP_POINTS angles from k_start, k_step apart
.set SWEEP_POINTS, 1601
.set ATAN_PAIRS, 24
.set ANGLE_COUNT, 11
.set VEC3_PAIRS, 4
.set VEC2_COUNT, 4
.set F32_PAIRS, 3
.set RNG_BYTES, 16
.set LINE_BYTES, 256

.section .text
.global _start
_start:
    call sweep
    call atan_cases
    call angle_cases
    call const_cases
    call vec3_cases
    call vec2_cases
    call f32_vec_cases
    call rng_cases
    call expand_all
    call trapped
    jab.sys.exit 0

# `sin <x> <y>` and `cos <x> <y>` lines for every angle of the sweep.
sweep:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    fsd fs0, 8(sp)
    fsd fs1, 0(sp)
    li s2, 0
1:
    fcvt.s.w ft0, s2
    la t0, k_step
    flw ft1, 0(t0)
    fmul.s ft0, ft0, ft1
    la t0, k_start
    flw ft1, 0(t0)
    fadd.s fs0, ft0, ft1
    jab.f32.sin fs1, fs0
    la a0, word_sin
    call pair_line
    jab.f32.cos fs1, fs0
    la a0, word_cos
    call pair_line
    addi s2, s2, 1
    li t0, SWEEP_POINTS
    bltu s2, t0, 1b
    ld ra, 24(sp)
    ld s2, 16(sp)
    fld fs0, 8(sp)
    fld fs1, 0(sp)
    addi sp, sp, 32
    ret

# `atan2 <y> <x> <r>` lines, one a pair of atan_pairs.
atan_cases:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    fsd fs0, 16(sp)
    fsd fs1, 8(sp)
    fsd fs2, 0(sp)
    la s3, atan_pairs
    li s2, ATAN_PAIRS
1:
    flw fs0, 0(s3)
    flw fs1, 4(s3)
    jab.f32.atan2 fs2, fs0, fs1
    call line_reset
    la a0, word_atan2
    call line_str
    fmv.x.w a0, fs0
    call line_hex32
    li a0, ' '
    call line_char
    fmv.x.w a0, fs1
    call line_hex32
    li a0, ' '
    call line_char
    fmv.x.w a0, fs2
    call line_hex32
    call line_nl
    jab.sys.uart.print line
    addi s3, s3, 8
    addi s2, s2, -1
    bnez s2, 1b
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    fld fs0, 16(sp)
    fld fs1, 8(sp)
    fld fs2, 0(sp)
    addi sp, sp, 48
    ret

# `rad <x> <r>`, `deg <x> <r>`, and `roundtrip <x> <r>` lines, one each an angle.
angle_cases:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    fsd fs0, 16(sp)
    fsd fs1, 8(sp)
    fsd fs2, 0(sp)
    la s3, angles
    li s2, ANGLE_COUNT
1:
    flw fs0, 0(s3)
    jab.f32.rad fs1, fs0
    la a0, word_rad
    call pair_line
    jab.f32.deg fs1, fs0
    la a0, word_deg
    call pair_line
    jab.f32.rad fs2, fs0
    jab.f32.deg fs1, fs2
    la a0, word_roundtrip
    call pair_line
    addi s3, s3, 4
    addi s2, s2, -1
    bnez s2, 1b
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    fld fs0, 16(sp)
    fld fs1, 8(sp)
    fld fs2, 0(sp)
    addi sp, sp, 48
    ret

# `const <name> <macro> <assembled>` lines for the six constants.
const_cases:
    addi sp, sp, -32
    sd ra, 24(sp)
    fsd fs0, 16(sp)
    fsd fs1, 8(sp)
    jab.f32.PI fs0
    la t0, k_pi_f
    flw fs1, 0(t0)
    la a0, word_f32_pi
    call pair_line
    jab.f32.TAU fs0
    la t0, k_tau_f
    flw fs1, 0(t0)
    la a0, word_f32_tau
    call pair_line
    jab.f32.FRAC_PI_2 fs0
    la t0, k_half_pi_f
    flw fs1, 0(t0)
    la a0, word_f32_half_pi
    call pair_line
    jab.f64.PI fs0
    la t0, k_pi_d
    fld fs1, 0(t0)
    la a0, word_f64_pi
    call pair_line64
    jab.f64.TAU fs0
    la t0, k_tau_d
    fld fs1, 0(t0)
    la a0, word_f64_tau
    call pair_line64
    jab.f64.FRAC_PI_2 fs0
    la t0, k_half_pi_d
    fld fs1, 0(t0)
    la a0, word_f64_half_pi
    call pair_line64
    ld ra, 24(sp)
    fld fs0, 16(sp)
    fld fs1, 8(sp)
    addi sp, sp, 32
    ret

# `f64.vec3.dot`, `len`, `sqrlen`, `norm`, and `norm.aliased` lines, one a pair.
vec3_cases:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    fsd fs0, 0(sp)
    la s3, vec3_pairs
    li s2, VEC3_PAIRS
1:
    addi t3, s3, 24
    jab.f64.vec3.dot fs0, s3, t3
    call line_reset
    la a0, word_vec3_dot
    call line_str
    mv a0, s3
    li a1, 6
    call line_doubles
    fmv.x.d a0, fs0
    call line_hex64
    call line_nl
    jab.sys.uart.print line
    jab.f64.vec3.len fs0, s3
    la a0, word_vec3_len
    call vec3_result_line
    jab.f64.vec3.sqrlen fs0, s3
    la a0, word_vec3_sqrlen
    call vec3_result_line
    la t3, norm_out
    jab.f64.vec3.norm t3, s3
    la a0, word_vec3_norm
    call vec3_norm_line
    la t3, norm_out
    ld t4, 0(s3)
    sd t4, 0(t3)
    ld t4, 8(s3)
    sd t4, 8(t3)
    ld t4, 16(s3)
    sd t4, 16(t3)
    jab.f64.vec3.norm t3, t3
    la a0, word_vec3_norm_aliased
    call vec3_norm_line
    addi s3, s3, 48
    addi s2, s2, -1
    bnez s2, 1b
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    fld fs0, 0(sp)
    addi sp, sp, 32
    ret

# The line `<word> <the vec3 at s3> <fs0>`.
# a0 address The word, NUL-terminated.
# s3 address The vec3.
# fs0 f64 The result.
vec3_result_line:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s2, 0(sp)
    mv s2, a0
    call line_reset
    mv a0, s2
    call line_str
    mv a0, s3
    li a1, 3
    call line_doubles
    fmv.x.d a0, fs0
    call line_hex64
    call line_nl
    jab.sys.uart.print line
    ld ra, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 16
    ret

# The line `<word> <the vec3 at s3> <the vec3 at norm_out>`.
# a0 address The word, NUL-terminated.
# s3 address The vec3.
vec3_norm_line:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s2, 0(sp)
    mv s2, a0
    call line_reset
    mv a0, s2
    call line_str
    mv a0, s3
    li a1, 3
    call line_doubles
    la a0, norm_out
    li a1, 3
    call line_doubles
    call line_nl
    jab.sys.uart.print line
    ld ra, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 16
    ret

# `f64.vec2.len <a> <r>` and `f64.vec2.sqrlen <a> <r>` lines, one a vec2.
vec2_cases:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    fsd fs0, 0(sp)
    la s3, vec2s
    li s2, VEC2_COUNT
1:
    jab.f64.vec2.len fs0, s3
    la a0, word_vec2_len
    call vec2_result_line
    jab.f64.vec2.sqrlen fs0, s3
    la a0, word_vec2_sqrlen
    call vec2_result_line
    addi s3, s3, 16
    addi s2, s2, -1
    bnez s2, 1b
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    fld fs0, 0(sp)
    addi sp, sp, 32
    ret

# The line `<word> <the vec2 at s3> <fs0>`.
# a0 address The word, NUL-terminated.
# s3 address The vec2.
# fs0 f64 The result.
vec2_result_line:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s2, 0(sp)
    mv s2, a0
    call line_reset
    mv a0, s2
    call line_str
    mv a0, s3
    li a1, 2
    call line_doubles
    fmv.x.d a0, fs0
    call line_hex64
    call line_nl
    jab.sys.uart.print line
    ld ra, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 16
    ret

# `f32.vec3.dot <a> <b> <r>` lines, one a pair of f32_pairs.
f32_vec_cases:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    fsd fs0, 0(sp)
    la s3, f32_pairs
    li s2, F32_PAIRS
1:
    addi t3, s3, 12
    jab.f32.vec3.dot fs0, s3, t3
    call line_reset
    la a0, word_f32_vec3_dot
    call line_str
    mv a0, s3
    li a1, 6
    call line_floats
    fmv.x.w a0, fs0
    call line_hex32
    call line_nl
    jab.sys.uart.print line
    addi s3, s3, 24
    addi s2, s2, -1
    bnez s2, 1b
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    fld fs0, 0(sp)
    addi sp, sp, 32
    ret

# `rng` lines for a fixed seed and a zero seed, then `rngsys` from jab.sys.random.
rng_cases:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s3, 0(sp)
    la s3, rng_state
    li t3, 0x0123456789abcdef
    jab.rng.seed s3, t3
    li a0, 0x0123456789abcdef
    la a1, word_rng
    call rng_report
    li t3, 0
    jab.rng.seed s3, t3
    li a0, 0
    la a1, word_rng
    call rng_report
    li t3, 8
    jab.sys.random s3, t3
    bnez a0, 1f
    ld t3, 0(s3)
    jab.rng.seed s3, t3
    mv a0, t3
    la a1, word_rngsys
    call rng_report
    j 2f
1:
    jab.sys.uart.print msg_rngsys_none
2:
    ld ra, 8(sp)
    ld s3, 0(sp)
    addi sp, sp, 16
    ret

# The line `<word> <seed> <state> <RNG_BYTES bytes>`, the bytes drawn from s3.
# a0 u64 The seed as given.
# a1 address The word, NUL-terminated.
# s3 address The state word.
rng_report:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s4, 8(sp)
    mv s4, a0
    mv s2, a1
    call line_reset
    mv a0, s2
    call line_str
    mv a0, s4
    call line_hex64
    li a0, ' '
    call line_char
    ld a0, 0(s3)
    call line_hex64
    li s2, RNG_BYTES
1:
    li a0, ' '
    call line_char
    jab.rng.byte a0, s3
    call line_hex
    addi s2, s2, -1
    bnez s2, 1b
    call line_nl
    jab.sys.uart.print line
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s4, 8(sp)
    addi sp, sp, 32
    ret

# Every macro expanded once on a page of its own, with no kernel call.
.balign 4096
expand_all:
    la t3, angles
    flw fa0, 0(t3)
    jab.f32.sin fa1, fa0
    jab.f32.cos fa1, fa0
    jab.f32.atan2 fa1, fa0, fa0
    jab.f32.rad fa1, fa0
    jab.f32.deg fa1, fa0
    jab.f32.PI fa1
    jab.f32.TAU fa1
    jab.f32.FRAC_PI_2 fa1
    la t3, f32_pairs
    addi t4, t3, 12
    jab.f32.vec3.dot fa1, t3, t4
    jab.f64.PI fa1
    jab.f64.TAU fa1
    jab.f64.FRAC_PI_2 fa1
    la t3, vec3_pairs
    addi t4, t3, 24
    jab.f64.vec3.dot fa1, t3, t4
    jab.f64.vec3.len fa1, t3
    jab.f64.vec3.sqrlen fa1, t3
    la t4, norm_out
    jab.f64.vec3.norm t4, t3
    la t3, vec2s
    jab.f64.vec2.len fa1, t3
    jab.f64.vec2.sqrlen fa1, t3
    la t3, rng_state
    li t4, 1
    jab.rng.seed t3, t4
    jab.rng.byte t4, t3
    ret

# One kernel call on a page of its own.
.balign 4096
trapped:
    jab.sys.kernel.flags
    ret

# The line `<word> <fs0> <fs1>`, singles.
# a0 address The word, NUL-terminated.
pair_line:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s2, 0(sp)
    mv s2, a0
    call line_reset
    mv a0, s2
    call line_str
    fmv.x.w a0, fs0
    call line_hex32
    li a0, ' '
    call line_char
    fmv.x.w a0, fs1
    call line_hex32
    call line_nl
    jab.sys.uart.print line
    ld ra, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 16
    ret

# The line `<word> <fs0> <fs1>`, doubles.
# a0 address The word, NUL-terminated.
pair_line64:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s2, 0(sp)
    mv s2, a0
    call line_reset
    mv a0, s2
    call line_str
    fmv.x.d a0, fs0
    call line_hex64
    li a0, ' '
    call line_char
    fmv.x.d a0, fs1
    call line_hex64
    call line_nl
    jab.sys.uart.print line
    ld ra, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 16
    ret

# Empties the line.
line_reset:
    la t0, line
    la t1, lineptr
    sd t0, 0(t1)
    ret

# Appends a byte.
# a0 u8
line_char:
    la t1, lineptr
    ld t0, 0(t1)
    sb a0, 0(t0)
    addi t0, t0, 1
    sd t0, 0(t1)
    ret

# Ends the line: a newline, then NUL.
line_nl:
    la t1, lineptr
    ld t0, 0(t1)
    li t2, '\n'
    sb t2, 0(t0)
    addi t0, t0, 1
    sb zero, 0(t0)
    sd t0, 0(t1)
    ret

# Appends a string.
# a0 address NUL-terminated.
line_str:
    mv t2, a0
    la t1, lineptr
    ld t0, 0(t1)
1:
    lbu t3, 0(t2)
    beqz t3, 2f
    sb t3, 0(t0)
    addi t0, t0, 1
    addi t2, t2, 1
    j 1b
2:
    sd t0, 0(t1)
    ret

# Appends a byte as two hex digits.
# a0 u8
line_hex:
    mv t2, a0
    la t1, lineptr
    ld t0, 0(t1)
    li t5, 10
    srli t3, t2, 4
    andi t3, t3, 15
    blt t3, t5, 1f
    addi t3, t3, 'a' - 10
    j 2f
1:
    addi t3, t3, '0'
2:
    sb t3, 0(t0)
    addi t0, t0, 1
    andi t3, t2, 15
    blt t3, t5, 3f
    addi t3, t3, 'a' - 10
    j 4f
3:
    addi t3, t3, '0'
4:
    sb t3, 0(t0)
    addi t0, t0, 1
    sd t0, 0(t1)
    ret

# Appends the low 32 bits as eight hex digits, highest first.
# a0 u32
line_hex32:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s2, a0
    li s3, 24
1:
    srl a0, s2, s3
    andi a0, a0, 0xff
    call line_hex
    addi s3, s3, -8
    bgez s3, 1b
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

# Appends sixteen hex digits, highest first.
# a0 u64
line_hex64:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s2, a0
    li s3, 56
1:
    srl a0, s2, s3
    andi a0, a0, 0xff
    call line_hex
    addi s3, s3, -8
    bgez s3, 1b
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

# Appends doubles, each sixteen hex digits and a space.
# a0 address The doubles.
# a1 count How many.
line_doubles:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s2, a0
    mv s3, a1
1:
    beqz s3, 2f
    ld a0, 0(s2)
    call line_hex64
    li a0, ' '
    call line_char
    addi s2, s2, 8
    addi s3, s3, -1
    j 1b
2:
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

# Appends singles, each eight hex digits and a space.
# a0 address The singles.
# a1 count How many.
line_floats:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s2, a0
    mv s3, a1
1:
    beqz s3, 2f
    lwu a0, 0(s2)
    call line_hex32
    li a0, ' '
    call line_char
    addi s2, s2, 4
    addi s3, s3, -1
    j 1b
2:
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

.section .rodata
.balign 8
k_step:
    .float 0.025
k_start:
    .float -20.0
# the constants the macros must match, as the assembler rounds them
k_pi_f:
    .float 3.14159265358979323846
k_tau_f:
    .float 6.28318530717958647692
k_half_pi_f:
    .float 1.57079632679489661923
.balign 8
k_pi_d:
    .double 3.14159265358979323846
k_tau_d:
    .double 6.28318530717958647692
k_half_pi_d:
    .double 1.57079632679489661923
# y, x: both zero, the axes, the diagonals, every octant, a point far
# along each axis
atan_pairs:
    .float 0.0, 0.0
    .float 1.0, 0.0
    .float 0.0, 1.0
    .float -1.0, 0.0
    .float 0.0, -1.0
    .float 1.0, 1.0
    .float -1.0, 1.0
    .float 1.0, -1.0
    .float -1.0, -1.0
    .float 0.5, 2.0
    .float 2.0, 0.5
    .float -0.5, 2.0
    .float -2.0, 0.5
    .float 0.5, -2.0
    .float 2.0, -0.5
    .float -0.5, -2.0
    .float -2.0, -0.5
    .float 3.0, 4.0
    .float -4.0, 3.0
    .float 0.001, 1.0
    .float 1.0, 0.001
    .float 100.0, 1.0
    .float 1.0, -100.0
    .float 0.25, 0.75
angles:
    .float 0.0, 1.0, 30.0, 45.0, 90.0, 180.0, 360.0, -90.0, 720.0, 0.5, 10000.0
.balign 8
# a and b, three doubles each
vec3_pairs:
    .double 1.0, 2.0, 3.0, 4.0, -5.0, 6.0
    .double 0.5, -0.25, 8.0, -1.5, 2.0, 0.125
    .double 0.0, 0.0, 0.0, 1.0, 1.0, 1.0
    .double 300000.0, -400000.0, 0.001, 0.5, 0.5, 0.5
vec2s:
    .double 3.0, 4.0
    .double -5.0, 12.0
    .double 0.0, 0.0
    .double 0.001, 0.001
.balign 4
# a and b, three singles each
f32_pairs:
    .float 1.0, 2.0, 3.0, 4.0, -5.0, 6.0
    .float 0.5, -0.25, 8.0, -1.5, 2.0, 0.125
    .float 0.1, 0.2, 0.3, 0.4, 0.5, 0.6
word_sin:
    .asciz "sin "
word_cos:
    .asciz "cos "
word_atan2:
    .asciz "atan2 "
word_rad:
    .asciz "rad "
word_deg:
    .asciz "deg "
word_roundtrip:
    .asciz "roundtrip "
word_f32_pi:
    .asciz "const f32.PI "
word_f32_tau:
    .asciz "const f32.TAU "
word_f32_half_pi:
    .asciz "const f32.FRAC_PI_2 "
word_f64_pi:
    .asciz "const f64.PI "
word_f64_tau:
    .asciz "const f64.TAU "
word_f64_half_pi:
    .asciz "const f64.FRAC_PI_2 "
word_vec3_dot:
    .asciz "f64.vec3.dot "
word_vec3_len:
    .asciz "f64.vec3.len "
word_vec3_sqrlen:
    .asciz "f64.vec3.sqrlen "
word_vec3_norm:
    .asciz "f64.vec3.norm "
word_vec3_norm_aliased:
    .asciz "f64.vec3.norm.aliased "
word_vec2_len:
    .asciz "f64.vec2.len "
word_vec2_sqrlen:
    .asciz "f64.vec2.sqrlen "
word_f32_vec3_dot:
    .asciz "f32.vec3.dot "
word_rng:
    .asciz "rng "
word_rngsys:
    .asciz "rngsys "
msg_rngsys_none:
    .asciz "rngsys none\n"

.section .bss
.balign 8
line:
    .skip LINE_BYTES
lineptr:
    .skip 8
norm_out:
    .skip 24
rng_state:
    .skip 8
