# jab_f64.inc

The double twin of jab_f32.inc, whose mirror carries what the two share:
macros over calls, bit-pattern constants, the `\@` labels, the scratch set,
and how test/math measures. A 64-bit pattern costs `li` more, eight
instructions for the immediate and one `fmv.d.x`, so a constant is 9 where a
single's is 3. Every vector macro is exact against the host's doubles on the
suite's vectors, held under 1e-15 relative: the fused multiply-adds and the
square root each round once.

## .macro jab.f64.PI
## .macro jab.f64.TAU
## .macro jab.f64.FRAC_PI_2

9 instructions each.

## .macro jab.f64.vec3.dot

9 instructions.

## .macro jab.f64.vec3.sqrlen

The dot product of the vector with itself, for a comparison that needs no
root. 6 instructions.

## .macro jab.f64.vec3.len

7 instructions.

## .macro jab.f64.vec3.norm

The length goes to ft2 and each component is divided by it, so the result is
as exact as the division. A zero vector has no direction: its length is
replaced by 1.0 (`li t0, 0x3ff0000000000000`) so the three divisions write
the vector unchanged at dst, and no branch skips the writes, which is what
lets dst be a. 22 instructions.

## .macro jab.f64.vec2.sqrlen

4 instructions.

## .macro jab.f64.vec2.len

5 instructions.

## The register forms

The twins of jab_f32.inc's `reg` forms, whose mirror carries the reason: a
vector computed in registers pays stores and reloads to go through the
memory form. The fps engine's cold sites, the body's and the walls'
distances, a sound's distance, an actor's walk, the normal of the plane and
of a strayed round, all hold their vectors in registers and take these.
Exact against the host's doubles, 0 relative, as the memory forms.
