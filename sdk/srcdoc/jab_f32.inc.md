# jab_f32.inc

Macros rather than calls because of how the machine runs the program: QEMU's
TCG ends a translation block at a 4 KiB page boundary and at every call, so a
hot loop that calls a sine pays two block exits, about 45 ns, per call.
Expanded in place the mathematics costs its size per use and nothing per
iteration. No macro carries a page guard: a caller aligning a hot function to
a page sizes it to the expanded code, and the sizes below are measured with
objdump, never derived, since a `li` whose low twelve bits are zero assembles
to one `lui` where another takes two instructions.

Constants are bit patterns loaded as integer immediates and moved across with
`fmv.w.x`, so the library carries no data and a program needs no `.rodata`
for it. A negative pattern is written in signed form (`li t0, -0x41d55556` for
0xbe2aaaaa) because `li` of the unsigned form on rv64 costs more instructions
and `fmv.w.x` reads the low 32 bits either way; the side comment carries the
unsigned pattern and the value. Macro-internal labels carry `\@` so a macro
expands more than once in a function.

The scratch set ft0-ft7, t0-t2 is the whole clobber contract: a caller keeps
nothing live there across an expansion.

Precisions are measured by test/math, which expands every macro over fixed
inputs in the guest, prints each result as its bit pattern, and holds the
decoded value against nushell's own mathematics on the host. The sweep behind
the sine and cosine figures runs from -20 to 20 radians, about three turns
either way, a fortieth of a radian apart.

## .macro jab.f32.PI
## .macro jab.f32.TAU
## .macro jab.f32.FRAC_PI_2

3 instructions each.

## .macro jab.f32.rad
## .macro jab.f32.deg

One rounding each. Measured 3e-8 relative, held under 1e-7. 4 instructions.

## .macro jab.f32.sin

The angle is folded by the nearest whole number of turns (`fcvt.w.s` with
`rne`, then `fnmsub.s`), leaving a value within a half turn either way, then
reflected into the first quarter: past pi/2 the sine of pi - x, before -pi/2
the sine of -pi - x. The quarter is covered by a ninth-order odd polynomial
fitted by interpolation on Chebyshev nodes over 0 to pi/2 and evaluated by
Horner in x squared; the coefficients s1 to s9 are 1.0, -0.166666657,
8.33324250e-3, -1.98227397e-4, 2.63475636e-6.

The Taylor series the fps game carried before this library measured 1.6e-4 at
a quarter turn, past what a single's last bits warrant, which is why the
fitted set replaced it.

Measured: 1.3e-7 within a half turn either way, the single's own rounding,
held under 2e-7; 5.3e-7 over the whole sweep, held under 1e-6. The fold loses
bits as the angle grows, since the turn count is subtracted in single
precision, so a program keeps its angles within a turn where it can. 45
instructions.

## .macro jab.f32.cos

The same fold, then `fabs.s` since the cosine is even, and past pi/2 the
cosine is minus that of pi - x, so the even series is taken near zero where
it is exact. Tenth-order even polynomial on Chebyshev nodes over 0 to pi/2;
the coefficients c0 to c10 are 1.0, -0.5, 4.16666605e-2, -1.38886517e-3,
2.47745793e-5, -2.62975163e-7. The Taylor series it replaced measured 2.5e-5
at a quarter turn.

Measured: 1.4e-7 within a half turn either way, held under 2e-7; 5.4e-7 over
the whole sweep, held under 1e-6. 46 instructions.

## .macro jab.f32.atan2

The ratio of the lesser magnitude to the greater keeps the argument within 0
to 1, where an eleventh-order odd polynomial for the arctangent holds; a steep
point, |y| above |x|, takes x over y and is unfolded from pi/2. The
coefficients are the set the fps game carried, a1 to a11: 0.999977231,
-0.332623482, 0.193543464, -0.116432868, 0.0526533201, -0.0117212003. The
octant is then unfolded by the signs: x under zero takes pi minus the angle,
y under zero negates.

ft2 holds 0.0 for the both-zero test and is then reused for the ratio, so it
is reloaded with zero before the sign tests. Without the reload the sign
tests compare against the ratio, and a point with 0 < y < ratio comes out
negated: (0.25, 0.75) read 0.6435 radians off.

A zero y of either sign reads as zero because `flt.s` on -0.0 is false, so x
under zero with it gives pi, never -pi.

Measured: 1.9e-6 radians over every octant, held under 3e-6. 57 instructions.

## .macro jab.f32.vec3.dot

A multiply and two fused multiply-adds, three roundings. Measured 1.8e-8
relative, held under 1e-7. 9 instructions.

## The register forms

`jab.f32.vec3.reg.dot`, `reg.sqrlen`, `reg.len`, `reg.norm`, and the `vec2`
pair take the vector's values as float registers, for a vector that was
computed in registers and never stored. The memory form on such a vector
costs the stores, the loads inside the macro, and the loads to recover the
registers the macro's scratch set clobbered; in the fps engine's light loop
that was twelve memory operations a light, about a millisecond a frame on
a lit view, which is what the register forms remove. The dot, the lengths,
and the squares touch only their destination, so they may be used on values
in the scratch set and cost 2 to 4 instructions; the destination must not
be one of the operands, since the first instruction writes it. `reg.norm`
scales its three registers in place by their length through ft0, ft1, and
t0, 13 instructions, a zero vector left as it is as the memory form leaves
it. Measured by test/math over the same vectors as the memory forms: 5.7e-8
relative, held under 1e-7.
