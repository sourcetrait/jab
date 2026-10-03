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
