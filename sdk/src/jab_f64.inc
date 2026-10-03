.macro jab.f64.PI dst
    li t0, 0x400921fb54442d18
    fmv.d.x \dst, t0
.endm

.macro jab.f64.TAU dst
    li t0, 0x401921fb54442d18
    fmv.d.x \dst, t0
.endm

.macro jab.f64.FRAC_PI_2 dst
    li t0, 0x3ff921fb54442d18
    fmv.d.x \dst, t0
.endm

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

.macro jab.f64.vec3.sqrlen dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fld ft0, 16(\a)
    fmadd.d \dst, ft0, ft0, \dst
.endm

.macro jab.f64.vec3.len dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fld ft0, 16(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fsqrt.d \dst, \dst
.endm

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

.macro jab.f64.vec2.sqrlen dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
.endm

.macro jab.f64.vec2.len dst, a
    fld ft0, 0(\a)
    fmul.d \dst, ft0, ft0
    fld ft0, 8(\a)
    fmadd.d \dst, ft0, ft0, \dst
    fsqrt.d \dst, \dst
.endm

.macro jab.f64.vec3.reg.dot dst, ax, ay, az, bx, by, bz
    fmul.d \dst, \ax, \bx
    fmadd.d \dst, \ay, \by, \dst
    fmadd.d \dst, \az, \bz, \dst
.endm

.macro jab.f64.vec3.reg.sqrlen dst, x, y, z
    fmul.d \dst, \x, \x
    fmadd.d \dst, \y, \y, \dst
    fmadd.d \dst, \z, \z, \dst
.endm

.macro jab.f64.vec3.reg.len dst, x, y, z
    fmul.d \dst, \x, \x
    fmadd.d \dst, \y, \y, \dst
    fmadd.d \dst, \z, \z, \dst
    fsqrt.d \dst, \dst
.endm

.macro jab.f64.vec3.reg.norm x, y, z
    fmul.d ft0, \x, \x
    fmadd.d ft0, \y, \y, ft0
    fmadd.d ft0, \z, \z, ft0
    fsqrt.d ft0, ft0                # the length
    fmv.d.x ft1, zero
    feq.d t0, ft0, ft1
    beqz t0, .Ljab_f64_vec3_reg_norm_scale\@
    li t0, 0x3ff0000000000000       # 1.0: a zero vector divides by one
    fmv.d.x ft0, t0
.Ljab_f64_vec3_reg_norm_scale\@:
    fdiv.d \x, \x, ft0
    fdiv.d \y, \y, ft0
    fdiv.d \z, \z, ft0
.endm

.macro jab.f64.vec2.reg.sqrlen dst, x, y
    fmul.d \dst, \x, \x
    fmadd.d \dst, \y, \y, \dst
.endm

.macro jab.f64.vec2.reg.len dst, x, y
    fmul.d \dst, \x, \x
    fmadd.d \dst, \y, \y, \dst
    fsqrt.d \dst, \dst
.endm
