# main.S

The type libraries under test: every macro over fixed inputs, each result
to the UART as its bit pattern, decoded and checked on the host.

Results leave the guest as bit patterns, one case a line, so the guest formats
no float and the host decodes exactly what the macro produced: test/test.nu
rebuilds each value from its pattern and holds it against nushell's own sine,
cosine, arctangent, and arithmetic, and each constant's expansion against the
assembler's own `.float` or `.double` of the value.

The sweep makes each angle in single precision from its index, k_start plus
the index times k_step, rather than accumulating, so the host reproduces the
exact input from the index and the sweep carries no drift. It runs from -20
to 20 radians, about three turns either way, a fortieth of a radian apart.

`roundtrip` is the degrees back from their radians, rad then deg, holding the
pair's combined rounding.

`rngsys` seeds from the 8 bytes jab.sys.random gives; on a machine with no rng
device the line is `rngsys none` and the test accepts it.

The register forms are exercised over the same tables as the memory forms,
each vector loaded into argument registers first, so a line's inputs are
still the table's and the host decodes the same values; a vector is
reloaded before every macro, since a `uart.print` between two macros could
not be trusted to leave the argument registers alone. The f32 table gained
the zero vector for the register norm's zero case.

## .set SWEEP_POINTS

`u64`: the sin and cos sweep's angles, from k_start, k_step apart.

## .set ATAN_PAIRS

`u64`: the pairs of atan_pairs.

## .set ANGLE_COUNT

`u64`: the angles of angles.

## .set VEC3_PAIRS

`u64`: the pairs of vec3_pairs.

## .set VEC2_COUNT

`u64`: the vectors of vec2s.

## .set F32_PAIRS

`u64`: the pairs of f32_pairs.

## .set RNG_BYTES

`u64`: the bytes drawn for each rng line.

## .set LINE_BYTES

`u64`: room for a line.

## sweep

Its lines are `sin <x> <y>` and `cos <x> <y>`.

## atan_cases

Its lines are `atan2 <y> <x> <r>`, one a pair.

## angle_cases

Its lines are `rad <x> <r>`, `deg <x> <r>`, and `roundtrip <x> <r>`, one
each an angle.

## const_cases

Its lines are `const <name> <macro> <assembled>`.

## vec3_cases

Its lines are `f64.vec3.dot`, `len`, `sqrlen`, `norm`, and `norm.aliased`,
one a pair. The aliased norm copies the vector to norm_out and normalises it
there in place.

## vec2_cases

Its lines are `f64.vec2.len <a> <r>` and `f64.vec2.sqrlen <a> <r>`, one a
vec2.

## f32_vec_cases

Its lines are `f32.vec3.dot <a> <b> <r>`, one a pair of f32_pairs.

## reg_cases

The register forms: `f32.vec3.reg.dot <a> <b> <r>`, `f32.vec3.reg.sqrlen
<a> <r>`, `len`, `norm <a> <n>`, and the vec2 forms over each pair's first
two singles, over f32_pairs; the f64 forms over vec3_pairs and vec2s.

## rng_report

The line is `<word> <seed> <state> <RNG_BYTES bytes>`, the bytes drawn from
the state.

## expand_all
## trapped

The two sit on pages of their own for `jab hot`, the SDK's hot-code check,
which measures a function as the span from its symbol to the next symbol in
address order: `expand_all` must hold every macro with no `ecall`, and
`trapped` one `ecall`. They are placed before the line helpers so `trapped`'s
next symbol is `line_reset` and each measured span is the function alone.

## line_reset

A line is LINE_BYTES, 256, enough for the longest case,
`f64.vec3.norm.aliased` with six doubles of seventeen characters each behind
a 22-character word.

## k_step

`f32`: the sweep's step, a fortieth of a radian.

## k_start

`f32`: the sweep's first angle, -20 radians.

## k_pi_f

`f32`: pi as the assembler rounds it, which the macro must match.

## k_tau_f

`f32`: tau as the assembler rounds it.

## k_half_pi_f

`f32`: half pi as the assembler rounds it.

## k_pi_d

`f64`: pi as the assembler rounds it.

## k_tau_d

`f64`: tau as the assembler rounds it.

## k_half_pi_d

`f64`: half pi as the assembler rounds it.

## atan_pairs

`48 f32`: y, x pairs, both zero, the axes, the diagonals, every octant, a point far along each axis.

## angles

`11 f32`: the angles each conversion takes.

## vec3_pairs

`24 f64`: a and b, three doubles each.

## vec2s

`8 f64`: the vectors, two doubles each.

## f32_pairs

`24 f32`: a and b, three singles each.

## word_sin

`5 u8`.

## word_cos

`5 u8`.

## word_atan2

`7 u8`.

## word_rad

`5 u8`.

## word_deg

`5 u8`.

## word_roundtrip

`11 u8`.

## word_f32_pi

`14 u8`.

## word_f32_tau

`15 u8`.

## word_f32_half_pi

`21 u8`.

## word_f64_pi

`14 u8`.

## word_f64_tau

`15 u8`.

## word_f64_half_pi

`21 u8`.

## word_vec3_dot

`14 u8`.

## word_vec3_len

`14 u8`.

## word_vec3_sqrlen

`17 u8`.

## word_vec3_norm

`15 u8`.

## word_vec3_norm_aliased

`23 u8`.

## word_vec2_len

`14 u8`.

## word_vec2_sqrlen

`17 u8`.

## word_f32_vec3_dot

`14 u8`.

## word_f32_reg_dot

`18 u8`.

## word_f32_reg_sqrlen

`21 u8`.

## word_f32_reg_len

`18 u8`.

## word_f32_reg_norm

`19 u8`.

## word_f32_vec2_reg_sqrlen

`21 u8`.

## word_f32_vec2_reg_len

`18 u8`.

## word_f64_reg_dot

`18 u8`.

## word_f64_reg_sqrlen

`21 u8`.

## word_f64_reg_len

`18 u8`.

## word_f64_reg_norm

`19 u8`.

## word_f64_vec2_reg_sqrlen

`21 u8`.

## word_f64_vec2_reg_len

`18 u8`.

## word_rng

`5 u8`.

## word_rngsys

`8 u8`.

## msg_rngsys_none

`13 u8`: the line for a machine with no rng device.

## line

`256 u8`: the line being built.

## lineptr

`addr`: the cursor in line.

## norm_out

`3 f64`: a vec3 norm's result.

## norm_out_f

`3 f32`: an f32 register norm's result.

## rng_state

`u64`: the generator's state word.
