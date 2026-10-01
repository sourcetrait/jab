# Double-precision mathematics as macros expanded in place: no call, no trap.
# Operands are registers, the destination first; a vecN is N consecutive
# doubles at the address in an integer register. Scratch: ft0-ft7, t0-t2.

# Pi.
# returns
#   dst f64 0x400921fb54442d18.
.macro jab.f64.PI dst
    li t0, 0x400921fb54442d18
    fmv.d.x \dst, t0
.endm

# Two pi.
# returns
#   dst f64 0x401921fb54442d18.
.macro jab.f64.TAU dst
    li t0, 0x401921fb54442d18
    fmv.d.x \dst, t0
.endm

# Pi over two.
# returns
#   dst f64 0x3ff921fb54442d18.
.macro jab.f64.FRAC_PI_2 dst
    li t0, 0x3ff921fb54442d18
    fmv.d.x \dst, t0
.endm

# Dot product of two vec3.
# a address Three doubles.
# b address Three doubles.
# returns
#   dst f64 The dot product.
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

# Squared length of a vec3.
# a address Three doubles.
# returns
#   dst f64 The squared length.
.macro jab.f64.vec3.sqrlen dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fld ft0, 16(\a)
    fmadd.d \dst, ft0, ft0, \dst
.endm

# Length of a vec3.
# a address Three doubles.
# returns
#   dst f64 The length.
.macro jab.f64.vec3.len dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fld ft0, 16(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fsqrt.d \dst, \dst
.endm

# A vec3 scaled to unit length, written at dst.
# dst address Three doubles written; may be a.
# a address Three doubles.
# returns A zero vector is written unchanged.
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

# Squared length of a vec2.
# a address Two doubles.
# returns
#   dst f64 The squared length.
.macro jab.f64.vec2.sqrlen dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
.endm

# Length of a vec2.
# a address Two doubles.
# returns
#   dst f64 The length.
.macro jab.f64.vec2.len dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fsqrt.d \dst, \dst
.endm
