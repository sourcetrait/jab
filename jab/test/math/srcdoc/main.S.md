# main.S

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
