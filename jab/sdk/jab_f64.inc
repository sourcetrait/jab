# jab_f64.inc: double-precision mathematics as macros the program
# expands in place, the twin of jab_f32.inc in doubles: nothing here
# is a call, nothing traps, and the library carries no data, a
# constant being its bit pattern loaded as an immediate. `.include
# "jab_f64.inc"` after jab.inc, which includes none of these.
#
# Operands are registers, the destination first, and a macro is named
# for what its destination becomes. A scalar is a float register; a
# vector of N values is N consecutive doubles in memory, 24 bytes for a
# vec3 and 16 for a vec2, named by the integer register holding its
# address, and a vector result is written where an address names, so
# `jab.f64.vec3.norm t3, t4` writes at t3 the unit vector of the one
# at t4, and t3 may be t4. The scratch set, which any macro here may
# use and no operand or live value sits in, is ft0 to ft7 and t0 to
# t2. No clobber list beyond that and no page guard. Each macro states
# its operands, what it computes, its precision as test/math measures
# it, and its size in instructions.

# jab.f64.PI dst: dst becomes pi, 0x400921fb54442d18. 9 instructions.
.macro jab.f64.PI dst
    li t0, 0x400921fb54442d18
    fmv.d.x \dst, t0
.endm

# jab.f64.TAU dst: dst becomes two pi, 0x401921fb54442d18. 9
# instructions.
.macro jab.f64.TAU dst
    li t0, 0x401921fb54442d18
    fmv.d.x \dst, t0
.endm

# jab.f64.FRAC_PI_2 dst: dst becomes pi over two, 0x3ff921fb54442d18.
# 9 instructions.
.macro jab.f64.FRAC_PI_2 dst
    li t0, 0x3ff921fb54442d18
    fmv.d.x \dst, t0
.endm

# jab.f64.vec3.dot dst, a, b: dst becomes the dot product of the vec3
# at a with the vec3 at b, a multiply and two fused multiply-adds.
# Measured (test/math): exact against the host's doubles on the
# suite's vectors, held under 1e-15 relative. 9 instructions.
.macro jab.f64.vec3.dot dst, a, b
    fld ft0, 0(\a)
    fld ft1, 0(\b)
    fmul.d \dst, ft0, ft1
    fld ft0, 8(\a)
    fld ft1, 8(\b)
    fmadd.d \dst, ft0, ft1, \dst
    fld ft0, 16(\a)
    fld ft1, 16(\b)
    fmadd.d \dst, ft0, ft1, \dst
.endm

# jab.f64.vec3.sqrlen dst, a: dst becomes the squared length of the
# vec3 at a, its dot product with itself, for a comparison that needs
# no root. Measured (test/math): exact against the host's doubles,
# held under 1e-15 relative. 6 instructions.
.macro jab.f64.vec3.sqrlen dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fld ft0, 16(\a)
    fmadd.d \dst, ft0, ft0, \dst
.endm

# jab.f64.vec3.len dst, a: dst becomes the length of the vec3 at a, the
# square root of its squared length. Measured (test/math): exact
# against the host's doubles, held under 1e-15 relative. 7
# instructions.
.macro jab.f64.vec3.len dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fld ft0, 16(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fsqrt.d \dst, \dst
.endm

# jab.f64.vec3.norm dst, a: the vec3 at a scaled to unit length and
# written at dst, both addresses, each component divided by the length
# so the result is as exact as the division; dst may be a. A zero
# vector is left as it is, written at dst unchanged, since it has no
# direction. Measured (test/math): exact against the host's doubles,
# held under 1e-15 relative. 22 instructions.
.macro jab.f64.vec3.norm dst, a
    fld ft0, 0(\a)
    fmul.d ft2, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d ft2, ft0, ft0, ft2
    fld ft0, 16(\a)
    fmadd.d ft2, ft0, ft0, ft2
    fsqrt.d ft2, ft2                # the length
    fmv.d.x ft3, zero
    feq.d t0, ft2, ft3
    beqz t0, .Ljab_f64_vec3_norm_scale\@
    li t0, 0x3ff0000000000000       # 1.0: a zero vector divides by one
    fmv.d.x ft2, t0
.Ljab_f64_vec3_norm_scale\@:
    fld ft0, 0(\a)
    fdiv.d ft0, ft0, ft2
    fsd ft0, 0(\dst)
    fld ft0, 8(\a)
    fdiv.d ft0, ft0, ft2
    fsd ft0, 8(\dst)
    fld ft0, 16(\a)
    fdiv.d ft0, ft0, ft2
    fsd ft0, 16(\dst)
.endm

# jab.f64.vec2.sqrlen dst, a: dst becomes the squared length of the
# vec2 at a. Measured (test/math): exact against the host's doubles,
# held under 1e-15 relative. 4 instructions.
.macro jab.f64.vec2.sqrlen dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
.endm

# jab.f64.vec2.len dst, a: dst becomes the length of the vec2 at a.
# Measured (test/math): exact against the host's doubles, held under
# 1e-15 relative. 5 instructions.
.macro jab.f64.vec2.len dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fsqrt.d \dst, \dst
.endm
