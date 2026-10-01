# jab_f32.inc: single-precision mathematics as macros the program
# expands in place. Nothing here is a call and nothing traps: a macro's
# code lands where it is written, at the cost of its size per use, so
# a hot loop pays no call pair and no trap. The library carries no
# data: a constant is written as its bit pattern, loaded as an integer
# immediate and moved into the register. `.include "jab_f32.inc"` after
# jab.inc, which includes none of these: a program pays for what it
# names.
#
# Operands are registers, the destination first, and a macro is named
# for what its destination becomes: `jab.f32.sin fa0, fa1` makes fa0
# the sine of fa1, `jab.f32.rad fa0, fa1` the radians of the degrees in
# fa1, `jab.f32.PI ft8` makes ft8 pi. A scalar is a float register; a
# vector of N values is N consecutive singles in memory, 12 bytes for a
# vec3, named by the integer register holding its address. The scratch
# set, which any macro here may use and no operand or live value sits
# in, is ft0 to ft7 and t0 to t2. A macro carries no clobber list
# beyond that and no page guard: a caller aligning a hot function to a
# page sizes it to the expanded code. Each macro states its operands,
# what it computes, its precision as test/math measures it, and its
# size in instructions.

# jab.f32.PI dst: dst becomes pi, 0x40490fdb, 3.14159274. 3
# instructions.
.macro jab.f32.PI dst
    li t0, 0x40490fdb
    fmv.w.x \dst, t0
.endm

# jab.f32.TAU dst: dst becomes two pi, 0x40c90fdb, 6.28318548. 3
# instructions.
.macro jab.f32.TAU dst
    li t0, 0x40c90fdb
    fmv.w.x \dst, t0
.endm

# jab.f32.FRAC_PI_2 dst: dst becomes pi over two, 0x3fc90fdb,
# 1.57079637. 3 instructions.
.macro jab.f32.FRAC_PI_2 dst
    li t0, 0x3fc90fdb
    fmv.w.x \dst, t0
.endm

# jab.f32.rad dst, src: dst becomes the radians of src, degrees: src
# times pi over 180, 0x3c8efa35, 0.0174532924. One rounding; measured
# (test/math) 3e-8 relative, held under 1e-7. 4 instructions.
.macro jab.f32.rad dst, src
    li t0, 0x3c8efa35
    fmv.w.x ft0, t0
    fmul.s \dst, \src, ft0
.endm

# jab.f32.deg dst, src: dst becomes the degrees of src, radians: src
# times 180 over pi, 0x42652ee1, 57.2957802. One rounding; measured
# (test/math) 3e-8 relative, held under 1e-7. 4 instructions.
.macro jab.f32.deg dst, src
    li t0, 0x42652ee1
    fmv.w.x ft0, t0
    fmul.s \dst, \src, ft0
.endm

# jab.f32.sin dst, src: dst becomes the sine of src, radians of any
# size: src brought into a turn by subtracting the nearest whole number
# of turns, reflected into a quarter, and a ninth-order odd polynomial
# fitted on Chebyshev nodes over the quarter. Measured (test/math):
# 1.3e-7 within a half turn either way, the single's own rounding, held
# under 2e-7; 5.3e-7 over six turns either way, the fold losing bits as
# the angle grows, held under 1e-6, so a program keeps its angles within
# a turn where it can. 45 instructions.
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

# jab.f32.cos dst, src: dst becomes the cosine of src, radians of any
# size: src brought into a turn, folded into a quarter so the even
# series is taken near zero where it is exact, and a tenth-order even
# polynomial fitted on Chebyshev nodes over the quarter. Measured
# (test/math): 1.4e-7 within a half turn either way, held under 2e-7;
# 5.4e-7 over six turns either way, held under 1e-6. 46 instructions.
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

# jab.f32.atan2 dst, y, x: dst becomes the angle of the point x, y
# from the x axis counter-clockwise, radians within a half turn either
# way, Rust's `y.atan2(x)`: the ratio of the lesser magnitude to the
# greater through an eleventh-order odd polynomial for the arctangent
# on 0 to 1, unfolded by the octant; both zero gives zero, and a zero y
# of either sign reads as zero, so x under zero with it gives pi.
# Measured (test/math): 1.9e-6 radians over every octant, held under
# 3e-6. 57 instructions.
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

# jab.f32.vec3.dot dst, a, b: dst becomes the dot product of the vec3
# at a with the vec3 at b, a multiply and two fused multiply-adds, so
# three roundings. Measured (test/math): 1.8e-8 relative, held under
# 1e-7. 9 instructions.
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
