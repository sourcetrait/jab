# Single-precision mathematics as macros expanded in place: no call, no trap.
# Operands are registers, the destination first; a vecN is N consecutive
# singles at the address in an integer register, and a `reg` form takes its
# values as float registers instead, touching only its destination.
# Scratch: ft0-ft7, t0-t2, which a `reg` form leaves alone but `reg.norm`.

# Pi.
# returns
#   dst f32 0x40490fdb.
.macro jab.f32.PI dst
    li t0, 0x40490fdb
    fmv.w.x \dst, t0
.endm

# Two pi.
# returns
#   dst f32 0x40c90fdb.
.macro jab.f32.TAU dst
    li t0, 0x40c90fdb
    fmv.w.x \dst, t0
.endm

# Pi over two.
# returns
#   dst f32 0x3fc90fdb.
.macro jab.f32.FRAC_PI_2 dst
    li t0, 0x3fc90fdb
    fmv.w.x \dst, t0
.endm

# Degrees to radians.
# src f32 Degrees.
# returns
#   dst f32 Radians.
.macro jab.f32.rad dst, src
    li t0, 0x3c8efa35               # pi/180, 0.0174532924
    fmv.w.x ft0, t0
    fmul.s \dst, \src, ft0
.endm

# Radians to degrees.
# src f32 Radians.
# returns
#   dst f32 Degrees.
.macro jab.f32.deg dst, src
    li t0, 0x42652ee1               # 180/pi, 57.2957802
    fmv.w.x ft0, t0
    fmul.s \dst, \src, ft0
.endm

# Sine.
# src f32 Radians, any size.
# returns
#   dst f32 The sine of src.
.macro jab.f32.sin dst, src
    li t0, 0x3e22f983               # 1/tau, 0.159154937
    fmv.w.x ft0, t0
    fmul.s ft1, \src, ft0
    fcvt.w.s t0, ft1, rne           # the nearest whole turn
    fcvt.s.w ft1, t0
    li t0, 0x40c90fdb               # tau
    fmv.w.x ft0, t0
    fnmsub.s ft1, ft1, ft0, \src    # src less the turns, within a half turn either way
    li t0, 0x3fc90fdb               # pi/2
    fmv.w.x ft0, t0
    li t0, 0x40490fdb               # pi
    fmv.w.x ft2, t0
    flt.s t0, ft0, ft1              # past a quarter: pi - x
    beqz t0, .Ljab_f32_sin_low\@
    fsub.s ft1, ft2, ft1
    j .Ljab_f32_sin_poly\@
.Ljab_f32_sin_low\@:
    fneg.s ft0, ft0
    flt.s t0, ft1, ft0              # before minus a quarter: -pi - x
    beqz t0, .Ljab_f32_sin_poly\@
    fneg.s ft2, ft2
    fsub.s ft1, ft2, ft1
.Ljab_f32_sin_poly\@:
    fmul.s ft2, ft1, ft1            # x squared
    li t0, 0x3630d0c5               # 2.63475636e-6
    fmv.w.x ft3, t0
    li t0, -0x46b024bd              # 0xb94fdb43, -1.98227397e-4
    fmv.w.x ft4, t0
    fmadd.s ft3, ft3, ft2, ft4
    li t0, 0x3c088827               # 8.33324250e-3
    fmv.w.x ft4, t0
    fmadd.s ft3, ft3, ft2, ft4
    li t0, -0x41d55556              # 0xbe2aaaaa, -0.166666657
    fmv.w.x ft4, t0
    fmadd.s ft3, ft3, ft2, ft4
    li t0, 0x3f800000               # 1.0
    fmv.w.x ft4, t0
    fmadd.s ft3, ft3, ft2, ft4
    fmul.s \dst, ft1, ft3
.endm

# Cosine.
# src f32 Radians, any size.
# returns
#   dst f32 The cosine of src.
.macro jab.f32.cos dst, src
    li t0, 0x3e22f983               # 1/tau
    fmv.w.x ft0, t0
    fmul.s ft1, \src, ft0
    fcvt.w.s t0, ft1, rne
    fcvt.s.w ft1, t0
    li t0, 0x40c90fdb               # tau
    fmv.w.x ft0, t0
    fnmsub.s ft1, ft1, ft0, \src    # within a half turn either way
    fabs.s ft1, ft1
    li t0, 0x3fc90fdb               # pi/2
    fmv.w.x ft0, t0
    fle.s t1, ft1, ft0
    xori t1, t1, 1                  # 1 past a quarter: the cosine is minus that of pi - x
    beqz t1, .Ljab_f32_cos_poly\@
    li t0, 0x40490fdb               # pi
    fmv.w.x ft2, t0
    fsub.s ft1, ft2, ft1
.Ljab_f32_cos_poly\@:
    fmul.s ft2, ft1, ft1            # x squared
    li t0, -0x4b72d0f8              # 0xb48d2f08, -2.62975163e-7
    fmv.w.x ft3, t0
    li t0, 0x37cfd301               # 2.47745793e-5
    fmv.w.x ft4, t0
    fmadd.s ft3, ft3, ft2, ft4
    li t0, -0x4549f56b              # 0xbab60a95, -1.38886517e-3
    fmv.w.x ft4, t0
    fmadd.s ft3, ft3, ft2, ft4
    li t0, 0x3d2aaaa9               # 4.16666605e-2
    fmv.w.x ft4, t0
    fmadd.s ft3, ft3, ft2, ft4
    li t0, -0x41000000              # 0xbf000000, -0.5
    fmv.w.x ft4, t0
    fmadd.s ft3, ft3, ft2, ft4
    li t0, 0x3f800000               # 1.0
    fmv.w.x ft4, t0
    fmadd.s ft3, ft3, ft2, ft4
    beqz t1, .Ljab_f32_cos_done\@
    fneg.s ft3, ft3
.Ljab_f32_cos_done\@:
    fmv.s \dst, ft3
.endm

# The angle of the point x, y from the x axis, counter-clockwise.
# y f32
# x f32
# returns Both zero gives zero, and a zero y of either sign reads as zero.
#   dst f32 Radians, within a half turn either way.
.macro jab.f32.atan2 dst, y, x
    fabs.s ft0, \y
    fabs.s ft1, \x
    fmv.w.x ft2, zero               # 0.0
    feq.s t1, ft0, ft2
    feq.s t2, ft1, ft2
    and t1, t1, t2
    beqz t1, .Ljab_f32_atan2_ratio\@
    fmv.s \dst, ft2
    j .Ljab_f32_atan2_done\@
.Ljab_f32_atan2_ratio\@:
    fle.s t1, ft0, ft1              # |y| <= |x|: the ratio y over x
    beqz t1, .Ljab_f32_atan2_steep\@
    fdiv.s ft2, ft0, ft1
    li t2, 0
    j .Ljab_f32_atan2_poly\@
.Ljab_f32_atan2_steep\@:
    fdiv.s ft2, ft1, ft0            # else x over y, unfolded from a quarter
    li t2, 1
.Ljab_f32_atan2_poly\@:
    fmul.s ft3, ft2, ft2
    li t0, -0x43bff5b9              # 0xbc400a47, -0.0117212003
    fmv.w.x ft4, t0
    li t0, 0x3d57ab02               # 0.0526533201
    fmv.w.x ft5, t0
    fmadd.s ft4, ft4, ft3, ft5
    li t0, -0x42118ba5              # 0xbdee745b, -0.116432868
    fmv.w.x ft5, t0
    fmadd.s ft4, ft4, ft3, ft5
    li t0, 0x3e463042               # 0.193543464
    fmv.w.x ft5, t0
    fmadd.s ft4, ft4, ft3, ft5
    li t0, -0x4155b260              # 0xbeaa4da0, -0.332623482
    fmv.w.x ft5, t0
    fmadd.s ft4, ft4, ft3, ft5
    li t0, 0x3f7ffe82               # 0.999977231
    fmv.w.x ft5, t0
    fmadd.s ft4, ft4, ft3, ft5
    fmul.s ft4, ft4, ft2
    beqz t2, .Ljab_f32_atan2_quadrant\@
    li t0, 0x3fc90fdb               # pi/2
    fmv.w.x ft5, t0
    fsub.s ft4, ft5, ft4
.Ljab_f32_atan2_quadrant\@:
    fmv.w.x ft2, zero               # 0.0 again, the ratio having used it
    flt.s t1, \x, ft2               # x under 0: the angle from the other side
    beqz t1, .Ljab_f32_atan2_sign\@
    li t0, 0x40490fdb               # pi
    fmv.w.x ft5, t0
    fsub.s ft4, ft5, ft4
.Ljab_f32_atan2_sign\@:
    flt.s t1, \y, ft2               # y under 0: the angle below
    beqz t1, .Ljab_f32_atan2_write\@
    fneg.s ft4, ft4
.Ljab_f32_atan2_write\@:
    fmv.s \dst, ft4
.Ljab_f32_atan2_done\@:
.endm

# Dot product of two vec3.
# a address Three singles.
# b address Three singles.
# returns
#   dst f32 The dot product.
.macro jab.f32.vec3.dot dst, a, b
    flw ft0, 0(\a)
    flw ft1, 0(\b)
    fmul.s \dst, ft0, ft1
    flw ft0, 4(\a)
    flw ft1, 4(\b)
    fmadd.s \dst, ft0, ft1, \dst
    flw ft0, 8(\a)
    flw ft1, 8(\b)
    fmadd.s \dst, ft0, ft1, \dst
.endm

# Dot product of two vec3 in registers.
# ax f32; ay f32; az f32 The first.
# bx f32; by f32; bz f32 The second.
# returns Touches nothing else; dst is none of the operands.
#   dst f32 The dot product.
.macro jab.f32.vec3.reg.dot dst, ax, ay, az, bx, by, bz
    fmul.s \dst, \ax, \bx
    fmadd.s \dst, \ay, \by, \dst
    fmadd.s \dst, \az, \bz, \dst
.endm

# Squared length of a vec3 in registers.
# x f32; y f32; z f32
# returns Touches nothing else; dst is none of the operands.
#   dst f32 The squared length.
.macro jab.f32.vec3.reg.sqrlen dst, x, y, z
    fmul.s \dst, \x, \x
    fmadd.s \dst, \y, \y, \dst
    fmadd.s \dst, \z, \z, \dst
.endm

# Length of a vec3 in registers.
# x f32; y f32; z f32
# returns Touches nothing else; dst is none of the operands.
#   dst f32 The length.
.macro jab.f32.vec3.reg.len dst, x, y, z
    fmul.s \dst, \x, \x
    fmadd.s \dst, \y, \y, \dst
    fmadd.s \dst, \z, \z, \dst
    fsqrt.s \dst, \dst
.endm

# A vec3 in registers scaled to unit length in place.
# x f32; y f32; z f32 Outside ft0 and ft1.
# returns A zero vector is left as it is. Uses ft0, ft1, t0.
#   x, y, z The unit vector.
.macro jab.f32.vec3.reg.norm x, y, z
    fmul.s ft0, \x, \x
    fmadd.s ft0, \y, \y, ft0
    fmadd.s ft0, \z, \z, ft0
    fsqrt.s ft0, ft0                # the length
    fmv.w.x ft1, zero
    feq.s t0, ft0, ft1
    beqz t0, .Ljab_f32_vec3_reg_norm_scale\@
    li t0, 0x3f800000               # 1.0: a zero vector divides by one
    fmv.w.x ft0, t0
.Ljab_f32_vec3_reg_norm_scale\@:
    fdiv.s \x, \x, ft0
    fdiv.s \y, \y, ft0
    fdiv.s \z, \z, ft0
.endm

# Squared length of a vec2 in registers.
# x f32; y f32
# returns Touches nothing else; dst is none of the operands.
#   dst f32 The squared length.
.macro jab.f32.vec2.reg.sqrlen dst, x, y
    fmul.s \dst, \x, \x
    fmadd.s \dst, \y, \y, \dst
.endm

# Length of a vec2 in registers.
# x f32; y f32
# returns Touches nothing else; dst is none of the operands.
#   dst f32 The length.
.macro jab.f32.vec2.reg.len dst, x, y
    fmul.s \dst, \x, \x
    fmadd.s \dst, \y, \y, \dst
    fsqrt.s \dst, \dst
.endm
