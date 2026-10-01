# The polygon rasteriser: world points into the camera's basis, clipped and
# projected into edges, the even-odd fill, the integer span, the portal test.

.section .rodata
.balign 8
k_half_d:
    .double 0.5
k_one_d:
    .double 1.0
k_depth_scale_d:
    .double 67108864.0
k_uv_scale_d:
    .double 65536.0
k_hx_d:
    .double 960.0
k_hy_d:
    .double 540.0
k_hz_d:
    .double 960.0
.balign 4
k_near:
    .float 0.0625
k_hx:
    .float 960.0
k_hy:
    .float 540.0
k_hz:
    .float 960.0
k_half:
    .float 0.5
k_big:
    .float 1000000.0

.section .text

# Empties the polygon in hand.
# returns Clobbers t0.
poly_reset:
    la t0, vert_count
    sd zero, 0(t0)
    ret

# Appends a world point to the polygon in hand; one past MAX_VERTS is dropped.
# fa0 f32 x.
# fa1 f32 y.
# fa2 f32 z.
# returns Clobbers t0 to t3.
poly_point:
    la t0, vert_count
    ld t1, 0(t0)
    li t2, MAX_VERTS
    bgeu t1, t2, 1f
    la t2, verts
    li t3, VERT_SIZE
    mul t3, t1, t3
    add t2, t2, t3
    fsw fa0, 0(t2)
    fsw fa1, 4(t2)
    fsw fa2, 8(t2)
    addi t1, t1, 1
    sd t1, 0(t0)
1:
    ret

# Empties the edge list, its rows unbounded.
# returns Clobbers t0, t1, ft0.
edges_reset:
    la t0, edge_count
    sd zero, 0(t0)
    la t0, k_big
    flw ft0, 0(t0)
    la t1, edge_ymin
    fsw ft0, 0(t1)
    fneg.s ft0, ft0
    la t1, edge_ymax
    fsw ft0, 0(t1)
    ret

# The polygon in hand into the camera's basis, clipped to the near plane,
# projected, its edges appended to the list.
# returns
#   a0 The clipped point count, 0 when nothing is left.
poly_project:
    addi sp, sp, -80
    sd ra, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    sd s7, 24(sp)
    # into the camera's basis, down being the negative of up
    la t0, vert_count
    ld s3, 0(t0)
    la s2, verts
    la s4, vview
    la t0, camera
    flw ft0, CAM_X(t0)
    flw ft1, CAM_Y(t0)
    flw ft2, CAM_Z(t0)
    mv t1, s3
1:
    beqz t1, 2f
    flw ft3, 0(s2)
    fsub.s ft3, ft3, ft0            # dx
    flw ft4, 4(s2)
    fsub.s ft4, ft4, ft1            # dy
    flw ft5, 8(s2)
    fsub.s ft5, ft5, ft2            # dz
    flw ft6, (CAM_RIGHT + 0)(t0)
    fmul.s ft6, ft6, ft3
    flw ft7, (CAM_RIGHT + 4)(t0)
    fmadd.s ft6, ft7, ft4, ft6
    flw ft7, (CAM_RIGHT + 8)(t0)
    fmadd.s ft6, ft7, ft5, ft6
    fsw ft6, 0(s4)                  # right
    flw ft6, (CAM_UP + 0)(t0)
    fmul.s ft6, ft6, ft3
    flw ft7, (CAM_UP + 4)(t0)
    fmadd.s ft6, ft7, ft4, ft6
    flw ft7, (CAM_UP + 8)(t0)
    fmadd.s ft6, ft7, ft5, ft6
    fneg.s ft6, ft6
    fsw ft6, 4(s4)                  # down
    flw ft6, (CAM_FORWARD + 0)(t0)
    fmul.s ft6, ft6, ft3
    flw ft7, (CAM_FORWARD + 4)(t0)
    fmadd.s ft6, ft7, ft4, ft6
    flw ft7, (CAM_FORWARD + 8)(t0)
    fmadd.s ft6, ft7, ft5, ft6
    fsw ft6, 8(s4)                  # forward, the depth
    addi s2, s2, VERT_SIZE
    addi s4, s4, VERT_SIZE
    addi t1, t1, -1
    j 1b
2:
    # clipped to the near plane: a point in front kept, an edge that
    # crosses adding its crossing
    la t0, k_near
    flw ft0, 0(t0)
    la s4, vview
    la s5, cverts
    li s6, 0                        # the clipped count
    li s7, 0                        # the point
3:
    bgeu s7, s3, 6f
    li t1, VERT_SIZE
    mul t2, s7, t1
    add t2, t2, s4                  # a
    addi t3, s7, 1
    bltu t3, s3, 4f
    li t3, 0
4:
    mul t3, t3, t1
    add t3, t3, s4                  # b
    flw ft1, 8(t2)
    flw ft2, 8(t3)
    fle.s t4, ft0, ft1              # a in front
    fle.s t5, ft0, ft2              # b in front
    beqz t4, 5f
    flw ft3, 0(t2)
    fsw ft3, 0(s5)
    flw ft3, 4(t2)
    fsw ft3, 4(s5)
    fsw ft1, 8(s5)
    addi s5, s5, VERT_SIZE
    addi s6, s6, 1
5:
    beq t4, t5, 55f
    fsub.s ft3, ft0, ft1
    fsub.s ft4, ft2, ft1
    fdiv.s ft3, ft3, ft4            # how far along a to b the near plane lies
    flw ft4, 0(t2)
    flw ft5, 0(t3)
    fsub.s ft5, ft5, ft4
    fmadd.s ft4, ft3, ft5, ft4
    fsw ft4, 0(s5)
    flw ft4, 4(t2)
    flw ft5, 4(t3)
    fsub.s ft5, ft5, ft4
    fmadd.s ft4, ft3, ft5, ft4
    fsw ft4, 4(s5)
    fsw ft0, 8(s5)
    addi s5, s5, VERT_SIZE
    addi s6, s6, 1
55:
    addi s7, s7, 1
    j 3b
6:
    li t0, 3
    bltu s6, t0, 90f                # nothing left
    # projected: x = hx + right * hz / depth, y = hy + down * hz / depth
    la t0, k_hz
    flw ft0, 0(t0)
    la t0, k_hx
    flw ft1, 0(t0)
    la t0, k_hy
    flw ft2, 0(t0)
    la s5, cverts
    la s4, pverts
    mv t1, s6
7:
    beqz t1, 8f
    flw ft3, 8(s5)
    fdiv.s ft3, ft0, ft3            # hz over the depth
    flw ft4, 0(s5)
    fmadd.s ft4, ft4, ft3, ft1
    fsw ft4, 0(s4)
    flw ft4, 4(s5)
    fmadd.s ft4, ft4, ft3, ft2
    fsw ft4, 4(s4)
    addi s5, s5, VERT_SIZE
    addi s4, s4, PVERT_SIZE
    addi t1, t1, -1
    j 7b
8:
    # the edges, each from its higher end, a level one dropped
    la s4, pverts
    la t0, edge_count
    ld s7, 0(t0)
    la t0, edge_ymin
    flw ft5, 0(t0)
    la t0, edge_ymax
    flw ft6, 0(t0)
    li t1, 0
9:
    bgeu t1, s6, 12f
    li t2, PVERT_SIZE
    mul t3, t1, t2
    add t3, t3, s4                  # a
    addi t4, t1, 1
    bltu t4, s6, 10f
    li t4, 0
10:
    mul t4, t4, t2
    add t4, t4, s4                  # b
    flw ft0, 0(t3)
    flw ft1, 4(t3)
    flw ft2, 0(t4)
    flw ft3, 4(t4)
    feq.s t5, ft1, ft3
    bnez t5, 11f
    flt.s t5, ft3, ft1
    beqz t5, 101f
    fmv.s ft4, ft0
    fmv.s ft0, ft2
    fmv.s ft2, ft4
    fmv.s ft4, ft1
    fmv.s ft1, ft3
    fmv.s ft3, ft4
101:
    li t5, MAX_EDGES
    bgeu s7, t5, 11f
    la t5, edges
    li t6, EDGE_SIZE
    mul t6, s7, t6
    add t5, t5, t6
    fsw ft1, EDGE_Y0(t5)
    fsw ft3, EDGE_Y1(t5)
    fsw ft0, EDGE_X0(t5)
    fsub.s ft4, ft2, ft0
    fsub.s ft7, ft3, ft1
    fdiv.s ft4, ft4, ft7
    fsw ft4, EDGE_DXDY(t5)
    addi s7, s7, 1
    fmin.s ft5, ft5, ft1
    fmax.s ft6, ft6, ft3
11:
    addi t1, t1, 1
    j 9b
12:
    la t0, edge_count
    sd s7, 0(t0)
    la t0, edge_ymin
    fsw ft5, 0(t0)
    la t0, edge_ymax
    fsw ft6, 0(t0)
    mv a0, s6
    j 91f
90:
    li a0, 0
91:
    ld ra, 72(sp)
    ld s2, 64(sp)
    ld s3, 56(sp)
    ld s4, 48(sp)
    ld s5, 40(sp)
    ld s6, 32(sp)
    ld s7, 24(sp)
    addi sp, sp, 80
    ret

# The surface's affine coefficients over the screen from the plane in hand
# and the camera, in double, into the polygon in hand, with the unit normal
# facing the camera; a plane through the eye zeroes them all.
surface_setup:
    addi sp, sp, -144
    sd ra, 136(sp)
    fsd fs0, 128(sp)
    fsd fs1, 120(sp)
    fsd fs2, 112(sp)
    fsd fs3, 104(sp)
    fsd fs4, 96(sp)
    fsd fs5, 88(sp)
    fsd fs6, 80(sp)
    fsd fs7, 72(sp)
    fsd fs8, 64(sp)
    fsd fs9, 56(sp)
    fsd fs10, 48(sp)
    fsd fs11, 40(sp)
    # the plane as doubles, a float at a time
    la t3, plane
    la t4, plane_d
    li t5, (PLANED_SIZE / 8)
1:
    flw ft0, 0(t3)
    fcvt.d.s ft0, ft0
    fsd ft0, 0(t4)
    addi t3, t3, 4
    addi t4, t4, 8
    addi t5, t5, -1
    bnez t5, 1b
    # n.right, n.down, n.forward, and n.(q - p)
    la t3, plane_d
    la t4, camera_d
    addi t5, t4, CAMD_RIGHT
    jab.f64.vec3.dot fs0, t3, t5    # n.r
    addi t5, t4, CAMD_UP
    jab.f64.vec3.dot fs1, t3, t5
    fneg.d fs1, fs1                 # n.d
    addi t5, t4, CAMD_FORWARD
    jab.f64.vec3.dot fs2, t3, t5    # n.f
    addi t5, t3, PLANED_Q
    jab.f64.vec3.dot fs3, t3, t5    # n.q
    jab.f64.vec3.dot ft8, t3, t4
    fsub.d fs3, fs3, ft8            # n.(q - p)
    la t0, k_hz_d
    fld fs4, 0(t0)                  # hz
    la t0, k_hx_d
    fld fs5, 0(t0)
    la t0, k_hy_d
    fld fs6, 0(t0)
    fcvt.d.w ft0, zero
    feq.d t0, fs3, ft0
    bnez t0, 80f
    # the unit normal facing the camera, for the light
    la t1, poly
    li t0, -1
    sw t0, POLY_LIT_ROW(t1)         # no brightness taken yet
    sd zero, POLY_FLAT_LIT(t1)      # lit at its angle unless the caller says
    fld ft8, 0(t3)
    fld ft9, 8(t3)
    fld ft10, 16(t3)
    jab.f64.vec3.reg.norm ft8, ft9, ft10
    la t0, k_one_d
    fld ft11, 0(t0)
    fcvt.d.w ft0, zero
    flt.d t0, ft0, fs3
    beqz t0, 81f
    fneg.d ft11, ft11               # the plane's point lies ahead along n: n points away
81:
    la t1, poly
    fmul.d ft2, ft8, ft11
    fcvt.s.d ft2, ft2
    fsw ft2, POLY_LNX(t1)
    fmul.d ft2, ft9, ft11
    fcvt.s.d ft2, ft2
    fsw ft2, POLY_LNY(t1)
    fmul.d ft2, ft10, ft11
    fcvt.s.d ft2, ft2
    fsw ft2, POLY_LNZ(t1)
    fmul.d ft1, fs4, fs3
    la t0, k_one_d
    fld ft2, 0(t0)
    fdiv.d fs7, ft2, ft1            # 1 / (hz * n.(q - p))
    fmul.d fs8, fs0, fs7            # A
    fmul.d fs9, fs1, fs7            # B
    fmul.d ft3, fs2, fs4
    fnmsub.d ft3, fs0, fs5, ft3     # n.f hz - n.r hx
    fnmsub.d ft3, fs1, fs6, ft3     # - n.d hy
    fmul.d fs10, ft3, fs7           # C
    # 1/z into the polygon, 6.26, the half pixel in C
    la t0, k_depth_scale_d
    fld ft4, 0(t0)
    la t1, poly
    fmul.d ft5, fs8, ft4
    fcvt.l.d t2, ft5, rne
    sd t2, POLY_IZA(t1)
    fmul.d ft5, fs9, ft4
    fcvt.l.d t2, ft5, rne
    sd t2, POLY_IZB(t1)
    fadd.d ft5, fs8, fs9
    la t0, k_half_d
    fld ft6, 0(t0)
    fmadd.d ft5, ft5, ft6, fs10     # C + (A + B) / 2
    fmul.d ft5, ft5, ft4
    fcvt.l.d t2, ft5, rne
    sd t2, POLY_IZC(t1)
    # u/z: K = (a.p + u0) * w; the coefficients K A + a.r / hz and on
    la a0, plane_d
    addi a0, a0, PLANED_AU
    li a1, PLANED_U0
    flw fa1, POLY_TEXW(t1)
    li a2, POLY_UZA
    call surface_axis
    la a0, plane_d
    addi a0, a0, PLANED_AV
    li a1, PLANED_V0
    la t1, poly
    flw fa1, POLY_TEXH(t1)
    li a2, POLY_VZA
    call surface_axis
    j 90f
80:
    la t1, poly
    sd zero, POLY_IZA(t1)
    sd zero, POLY_IZB(t1)
    sd zero, POLY_IZC(t1)
    sd zero, POLY_UZA(t1)
    sd zero, POLY_UZB(t1)
    sd zero, POLY_UZC(t1)
    sd zero, POLY_VZA(t1)
    sd zero, POLY_VZB(t1)
    sd zero, POLY_VZC(t1)
90:
    ld ra, 136(sp)
    fld fs0, 128(sp)
    fld fs1, 120(sp)
    fld fs2, 112(sp)
    fld fs3, 104(sp)
    fld fs4, 96(sp)
    fld fs5, 88(sp)
    fld fs6, 80(sp)
    fld fs7, 72(sp)
    fld fs8, 64(sp)
    fld fs9, 56(sp)
    fld fs10, 48(sp)
    fld fs11, 40(sp)
    addi sp, sp, 144
    ret

# One texture coordinate's affine coefficients into the polygon in hand.
# a0 address The gradient, three doubles in plane_d.
# a1 int The offset's field in plane_d.
# a2 int The first of the three polygon fields written.
# fa1 f32 The texture's size.
# fs4 f64 hz; fs5 hx; fs6 hy; fs8, fs9, fs10 A, B, C, from surface_setup.
# returns Clobbers t0 to t4, ft0 to ft11, fs11.
surface_axis:
    la t3, camera_d
    jab.f64.vec3.dot fs11, a0, t3   # a.p
    la t4, plane_d
    add t4, t4, a1
    fld ft8, 0(t4)
    fadd.d fs11, fs11, ft8          # a.p + u0
    fcvt.d.s ft8, fa1               # the size
    fmul.d fs11, fs11, ft8          # K, in texels
    addi t4, t3, CAMD_RIGHT
    jab.f64.vec3.dot ft9, a0, t4
    fmul.d ft9, ft9, ft8            # a.r, in texels
    addi t4, t3, CAMD_UP
    jab.f64.vec3.dot ft10, a0, t4
    fmul.d ft10, ft10, ft8
    fneg.d ft10, ft10               # a.d
    addi t4, t3, CAMD_FORWARD
    jab.f64.vec3.dot ft11, a0, t4
    fmul.d ft11, ft11, ft8          # a.f
    # UA = K A + a.r / hz; UB = K B + a.d / hz; UC = K C + a.f - (a.r hx + a.d hy) / hz
    fdiv.d ft4, ft9, fs4
    fmadd.d ft4, fs11, fs8, ft4     # UA
    fdiv.d ft5, ft10, fs4
    fmadd.d ft5, fs11, fs9, ft5     # UB
    fmul.d ft6, ft9, fs5
    fmadd.d ft6, ft10, fs6, ft6     # a.r hx + a.d hy
    fdiv.d ft6, ft6, fs4
    fsub.d ft6, ft11, ft6
    fmadd.d ft6, fs11, fs10, ft6    # UC
    fadd.d ft7, ft4, ft5
    la t0, k_half_d
    fld ft0, 0(t0)
    fmadd.d ft6, ft7, ft0, ft6      # the half pixel
    la t0, k_uv_scale_d
    fld ft0, 0(t0)
    la t2, poly
    add t2, t2, a2
    fmul.d ft4, ft4, ft0
    fcvt.l.d t3, ft4, rne
    sd t3, 0(t2)
    fmul.d ft5, ft5, ft0
    fcvt.l.d t3, ft5, rne
    sd t3, 8(t2)
    fmul.d ft6, ft6, ft0
    fcvt.l.d t3, ft6, rne
    sd t3, 16(t2)
    ret

# The edges the row centre crosses, their x in crossings sorted ascending.
# fa0 f32 The row's centre.
# returns Clobbers t0 to t5, ft0 to ft6.
#   a0 The count.
row_crossings:
    li a0, 0
    la t0, edges
    la t1, edge_count
    ld t1, 0(t1)
1:
    beqz t1, 9f
    flw ft2, EDGE_Y0(t0)
    flw ft3, EDGE_Y1(t0)
    flt.s t2, fa0, ft2
    bnez t2, 8f
    fle.s t2, ft3, fa0
    bnez t2, 8f
    flw ft4, EDGE_X0(t0)
    flw ft5, EDGE_DXDY(t0)
    fsub.s ft6, fa0, ft2
    fmadd.s ft4, ft6, ft5, ft4      # the crossing's x
    la t2, crossings
    slli t3, a0, 2
    add t3, t2, t3                  # past the last
2:
    beq t3, t2, 3f
    flw ft6, -4(t3)
    fle.s t4, ft6, ft4
    bnez t4, 3f
    fsw ft6, 0(t3)
    addi t3, t3, -4
    j 2b
3:
    fsw ft4, 0(t3)
    addi a0, a0, 1
8:
    addi t0, t0, EDGE_SIZE
    addi t1, t1, -1
    j 1b
9:
    ret

# The first pixel whose centre is at or past fa0, within the screen's columns.
# fa0 f32
# returns Clobbers t0, ft0.
#   a0 The pixel.
span_bound:
    la t0, k_half
    flw ft0, 0(t0)
    fsub.s ft0, fa0, ft0
    fcvt.w.s a0, ft0, rup
    bgez a0, 1f
    li a0, 0
1:
    li t0, SCREEN_W
    ble a0, t0, 2f
    mv a0, t0
2:
    ret

# The rows the edges cover, within the screen.
# returns Clobbers t0, ft0, ft1.
#   a0 The first row.
#   a1 The row past the last.
row_range:
    la t0, k_half
    flw ft0, 0(t0)
    la t0, edge_ymin
    flw ft1, 0(t0)
    fsub.s ft1, ft1, ft0
    fcvt.w.s a0, ft1, rup
    bgez a0, 1f
    li a0, 0
1:
    la t0, edge_ymax
    flw ft1, 0(t0)
    fsub.s ft1, ft1, ft0
    fcvt.w.s a1, ft1, rup
    li t0, SCREEN_H
    ble a1, t0, 2f
    mv a1, t0
2:
    ret

# The polygon in hand filled by scanlines with the surface in hand.
poly_fill:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    la t0, edge_count
    ld t0, 0(t0)
    beqz t0, 9f
    call row_range
    mv s0, a0                       # the row
    mv s1, a1                       # the row past the last
1:
    bge s0, s1, 9f
    fcvt.s.w fa0, s0
    la t0, k_half
    flw ft0, 0(t0)
    fadd.s fa0, fa0, ft0
    call row_crossings
    andi a0, a0, -2
    sd a0, 16(sp)
    sd zero, 8(sp)                  # the pair
2:
    ld t0, 8(sp)
    ld t1, 16(sp)
    bge t0, t1, 8f
    la t2, crossings
    slli t3, t0, 2
    add t2, t2, t3
    flw fa0, 0(t2)
    call span_bound
    sd a0, 0(sp)
    ld t0, 8(sp)
    la t2, crossings
    slli t3, t0, 2
    add t2, t2, t3
    flw fa0, 4(t2)
    call span_bound
    mv a1, a0
    ld a0, 0(sp)
    bge a0, a1, 3f
    mv a2, s0
    call span_fill
3:
    ld t0, 8(sp)
    addi t0, t0, 2
    sd t0, 8(sp)
    j 2b
8:
    addi s0, s0, 1
    j 1b
9:
    ld ra, 40(sp)
    ld s0, 32(sp)
    ld s1, 24(sp)
    addi sp, sp, 48
    ret

# The pixels a0 to a1 of row a2 filled with the surface in hand: textured,
# masked, sky, or lit, no float in the loop.
# a0 int The first pixel.
# a1 int The pixel past the last.
# a2 int The row.
.balign CODE_PAGE
span_fill:
    addi sp, sp, -144
    sd ra, 136(sp)
    sd s2, 128(sp)
    sd s3, 120(sp)
    sd s4, 112(sp)
    sd s5, 104(sp)
    sd s6, 96(sp)
    sd s7, 88(sp)
    sd s8, 80(sp)
    sd s9, 72(sp)
    sd s10, 64(sp)
    sd s11, 56(sp)
    sd s0, 48(sp)
    sd a2, 24(sp)                   # the row
    la t0, poly
    ld s3, POLY_IZA(t0)
    ld t1, POLY_IZB(t0)
    ld t2, POLY_IZC(t0)
    mul s2, s3, a0
    mul t1, t1, a2
    add s2, s2, t1
    add s2, s2, t2                  # 1/z at the first pixel
    ld s6, POLY_UZA(t0)
    ld t1, POLY_UZB(t0)
    ld t2, POLY_UZC(t0)
    mul s4, s6, a0
    mul t1, t1, a2
    add s4, s4, t1
    add s4, s4, t2                  # u/z
    ld s7, POLY_VZA(t0)
    ld t1, POLY_VZB(t0)
    ld t2, POLY_VZC(t0)
    mul s5, s7, a0
    mul t1, t1, a2
    add s5, s5, t1
    add s5, s5, t2                  # v/z
    sub s10, a1, a0                 # the pixels left
    # lit: the brightness at both ends, taken afresh every LIGHT_ROWS
    # rows of a polygon and held between, its step a pixel into s0
    la t3, poly
    ld t4, POLY_MODE(t3)
    andi t4, t4, POLY_LIT
    beqz t4, 5f
    sd a0, 0(sp)
    sd a1, 8(sp)
    lw t5, POLY_LIT_ROW(t3)
    bltz t5, 41f
    sub t5, a2, t5
    li t6, LIGHT_ROWS
    bltu t5, t6, 42f                # within the stride: the last taken
41:
    sw a2, POLY_LIT_ROW(t3)
    mv a1, a2
    mv a2, s2
    call span_light
    la t3, poly
    sd a0, POLY_B0(t3)              # the brightness at the start
    ld a0, 0(sp)
    ld a1, 8(sp)
    sub t0, a1, a0
    mul t0, t0, s3
    add a2, s2, t0                  # 1/z past the end
    mv a0, a1
    ld a1, 24(sp)
    call span_light
    la t3, poly
    sd a0, POLY_B1(t3)
42:
    ld t0, POLY_B0(t3)
    ld t1, POLY_B1(t3)
    sd t0, 32(sp)
    # the step a pixel, a channel at a time, packed again
    li t6, ((1 << CHANNEL_BITS) - 1)
    and t2, t1, t6
    and t4, t0, t6
    sub t2, t2, t4
    div t2, t2, s10
    srli t4, t1, CHANNEL_BITS
    and t4, t4, t6
    srli t5, t0, CHANNEL_BITS
    and t5, t5, t6
    sub t4, t4, t5
    div t4, t4, s10
    slli t4, t4, CHANNEL_BITS
    add s0, t2, t4
    srli t4, t1, (2 * CHANNEL_BITS)
    srli t5, t0, (2 * CHANNEL_BITS)
    sub t4, t4, t5
    div t4, t4, s10
    slli t4, t4, (2 * CHANNEL_BITS)
    add s0, s0, t4
    ld a0, 0(sp)
    ld a1, 8(sp)
    ld a2, 24(sp)                   # the row again
5:
    li t1, SCREEN_PITCH
    mul t1, a2, t1
    slli t2, a0, 2
    add t1, t1, t2
    la t2, zbuf
    add t2, t2, t1                  # the depth
    li t3, JAB_DISPLAY_BASE
    add t1, t1, t3                  # the pixel
    mv a2, t1
    mv t1, t2
    mv t0, a2
    la t3, poly
    ld a1, POLY_TEX(t3)
    ld a2, POLY_VMASK(t3)
    ld a3, POLY_UMASK(t3)
    ld a4, POLY_WSHIFT(t3)
    ld t4, POLY_MODE(t3)
    li t5, POLY_SKY
    beq t4, t5, 70f
    sd t4, 16(sp)                   # the mode
    # u and v at the start, 16.16
    mv t3, s2
    li t4, IZ_MIN
    bge t3, t4, 1f
    mv t3, t4
1:
    li t4, 1
    slli t4, t4, Z_SHIFT
    div t4, t4, t3                  # z, 48.16
    mul s8, s4, t4
    srai s8, s8, 16                 # u
    mul s9, s5, t4
    srai s9, s9, 16                 # v
30:
    # the block: its length, its end's u and v, the steps
    li s11, BLOCK
    ble s10, s11, 31f
    j 32f
31:
    mv s11, s10
32:
    mul t3, s11, s3
    add t3, t3, s2                  # 1/z at the end
    li t4, IZ_MIN
    bge t3, t4, 33f
    mv t3, t4
33:
    li t4, 1
    slli t4, t4, Z_SHIFT
    div t4, t4, t3                  # z at the end
    mul t3, s11, s6
    add t3, t3, s4                  # u/z at the end
    mul t3, t3, t4
    srai t3, t3, 16                 # u at the end
    mul t5, s11, s7
    add t5, t5, s5                  # v/z at the end
    mul t5, t5, t4
    srai t5, t5, 16                 # v at the end
    sub t6, t5, s9
    div t6, t6, s11                 # dv a pixel
    sub t4, t3, s8
    div t4, t4, s11                 # du a pixel
    sd t3, 0(sp)
    sd t5, 8(sp)
    mv t5, t4
    mv t2, s11
    ld t3, 16(sp)
    andi t4, t3, POLY_LIT
    bnez t4, 44f
    li t4, POLY_MASKED
    beq t3, t4, 50f
    j 40f
44:
    andi t4, t3, POLY_MASKED
    ld t3, 32(sp)                   # the brightness, packed
    bnez t4, 55f
45:
    # textured, lit: each channel of the texel scaled by its brightness,
    # the texel's bytes blue, green, red from the low end
    srli a5, s9, 16
    and a5, a5, a2
    sll a5, a5, a4
    srli a6, s8, 16
    and a6, a6, a3
    slli a6, a6, 2
    add a5, a5, a6
    add a5, a5, a1
    lw a0, 0(a5)
    lwu a7, 0(t1)
    bgeu a7, s2, 46f
    slli a5, t3, (64 - 3 * CHANNEL_BITS)
    srli a5, a5, (64 - CHANNEL_BITS + 8)    # blue's brightness, 8.8
    andi a6, a0, 0xff
    mul a6, a6, a5
    srli a6, a6, 8                  # blue
    slli a5, t3, (64 - 2 * CHANNEL_BITS)
    srli a5, a5, (64 - CHANNEL_BITS + 8)    # green's
    srli a7, a0, 8
    andi a7, a7, 0xff
    mul a7, a7, a5
    srli a7, a7, 8
    slli a7, a7, 8
    or a6, a6, a7
    slli a5, t3, (64 - CHANNEL_BITS)
    srli a5, a5, (64 - CHANNEL_BITS + 8)    # red's
    srli a7, a0, 16
    andi a7, a7, 0xff
    mul a7, a7, a5
    srli a7, a7, 8
    slli a7, a7, 16
    or a6, a6, a7
    srli a7, a0, 24
    slli a7, a7, 24
    or a6, a6, a7                   # the alpha kept
    sw a6, 0(t0)
    sw s2, 0(t1)
46:
    add s2, s2, s3
    add s8, s8, t5
    add s9, s9, t6
    add t3, t3, s0
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 45b
    sd t3, 32(sp)
    j 60f
55:
    # masked, lit
    srli a5, s9, 16
    and a5, a5, a2
    sll a5, a5, a4
    srli a6, s8, 16
    and a6, a6, a3
    slli a6, a6, 2
    add a5, a5, a6
    add a5, a5, a1
    lw a0, 0(a5)
    srli a6, a0, 24
    beqz a6, 56f
    lwu a7, 0(t1)
    bgeu a7, s2, 56f
    slli a5, t3, (64 - 3 * CHANNEL_BITS)
    srli a5, a5, (64 - CHANNEL_BITS + 8)
    andi a6, a0, 0xff
    mul a6, a6, a5
    srli a6, a6, 8
    slli a5, t3, (64 - 2 * CHANNEL_BITS)
    srli a5, a5, (64 - CHANNEL_BITS + 8)
    srli a7, a0, 8
    andi a7, a7, 0xff
    mul a7, a7, a5
    srli a7, a7, 8
    slli a7, a7, 8
    or a6, a6, a7
    slli a5, t3, (64 - CHANNEL_BITS)
    srli a5, a5, (64 - CHANNEL_BITS + 8)
    srli a7, a0, 16
    andi a7, a7, 0xff
    mul a7, a7, a5
    srli a7, a7, 8
    slli a7, a7, 16
    or a6, a6, a7
    srli a7, a0, 24
    slli a7, a7, 24
    or a6, a6, a7
    sw a6, 0(t0)
    sw s2, 0(t1)
56:
    add s2, s2, s3
    add s8, s8, t5
    add s9, s9, t6
    add t3, t3, s0
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 55b
    sd t3, 32(sp)
    j 60f
40:
    # textured: the texel, the depth test, the stores
    srli a5, s9, 16
    and a5, a5, a2
    sll a5, a5, a4
    srli a6, s8, 16
    and a6, a6, a3
    slli a6, a6, 2
    add a5, a5, a6
    add a5, a5, a1
    lw a0, 0(a5)
    lwu a7, 0(t1)
    bgeu a7, s2, 41f
    sw a0, 0(t0)
    sw s2, 0(t1)
41:
    add s2, s2, s3
    add s8, s8, t5
    add s9, s9, t6
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 40b
    j 60f
50:
    # masked: a texel with no alpha leaves the pixel
    srli a5, s9, 16
    and a5, a5, a2
    sll a5, a5, a4
    srli a6, s8, 16
    and a6, a6, a3
    slli a6, a6, 2
    add a5, a5, a6
    add a5, a5, a1
    lw a0, 0(a5)
    srli a6, a0, 24
    beqz a6, 51f
    lwu a7, 0(t1)
    bgeu a7, s2, 51f
    sw a0, 0(t0)
    sw s2, 0(t1)
51:
    add s2, s2, s3
    add s8, s8, t5
    add s9, s9, t6
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 50b
60:
    # the block's end is the next block's start
    ld s8, 0(sp)
    ld s9, 8(sp)
    mul t3, s11, s6
    add s4, s4, t3
    mul t3, s11, s7
    add s5, s5, t3
    sub s10, s10, s11
    bgtz s10, 30b
    j 90f
70:
    # sky: the texel by screen position, the texture's width across the
    # screen's and its height down the same count of rows, offset by
    # the sky's yaw and pitch in repeats, 16.16; drawn where nothing has
    la t3, poly
    lwu t4, POLY_TEXWI(t3)
    slli t3, t4, 16
    li t5, SCREEN_W
    div t5, t3, t5                  # u's step a pixel, 16.16
    la t3, sky_uoff
    ld s8, 0(t3)
    mul s8, s8, t4                  # the offset in texels
    mul t3, t5, a0
    add s8, s8, t3                  # u at the first pixel
    la t3, poly
    lwu t4, POLY_TEXHI(t3)
    slli t3, t4, 16
    li t6, SCREEN_W
    div t6, t3, t6                  # v's step a row
    la t3, sky_voff
    ld s9, 0(t3)
    mul s9, s9, t4
    ld t3, 24(sp)
    mul t6, t6, t3
    add s9, s9, t6                  # v on this row
    srai s9, s9, 16
    and s9, s9, a2
    sll s9, s9, a4                  # the texel row's bytes
    li s2, SKY_DEPTH
    mv t2, s10
71:
    srai a6, s8, 16
    and a6, a6, a3
    slli a6, a6, 2
    add a5, s9, a6
    add a5, a5, a1
    lw a0, 0(a5)
    lwu a7, 0(t1)
    bgeu a7, s2, 72f
    sw a0, 0(t0)
    sw s2, 0(t1)
72:
    add s8, s8, t5
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 71b
90:
    ld ra, 136(sp)
    ld s2, 128(sp)
    ld s3, 120(sp)
    ld s4, 112(sp)
    ld s5, 104(sp)
    ld s6, 96(sp)
    ld s7, 88(sp)
    ld s8, 80(sp)
    ld s9, 72(sp)
    ld s10, 64(sp)
    ld s11, 56(sp)
    ld s0, 48(sp)
    addi sp, sp, 144
    ret

# Whether any of the polygon in hand shows against what is drawn, sampled.
# returns
#   a0 1 when a sample's buffer depth is under the surface's 1/z, else 0.
.balign CODE_PAGE
poly_shows:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    la t0, edge_count
    ld t0, 0(t0)
    beqz t0, 8f
    call row_range
    mv s0, a0
    mv s1, a1
    la t0, poly
    ld s2, POLY_IZA(t0)
    ld s3, POLY_IZB(t0)
1:
    bge s0, s1, 8f
    fcvt.s.w fa0, s0
    la t0, k_half
    flw ft0, 0(t0)
    fadd.s fa0, fa0, ft0
    call row_crossings
    andi a0, a0, -2
    sd a0, 16(sp)
    sd zero, 8(sp)
2:
    ld t0, 8(sp)
    ld t1, 16(sp)
    bge t0, t1, 7f
    la t2, crossings
    slli t3, t0, 2
    add t2, t2, t3
    flw fa0, 0(t2)
    call span_bound
    sd a0, 0(sp)
    ld t0, 8(sp)
    la t2, crossings
    slli t3, t0, 2
    add t2, t2, t3
    flw fa0, 4(t2)
    call span_bound
    mv a1, a0
    ld a0, 0(sp)
    bge a0, a1, 3f
    # the samples along the span
    la t0, poly
    ld t1, POLY_IZC(t0)
    mul t2, s2, a0
    add t1, t1, t2
    mul t2, s3, s0
    add t1, t1, t2                  # 1/z at the first pixel
    slli t2, s2, 1                  # its step over two pixels
    li t3, SCREEN_PITCH
    mul t3, s0, t3
    slli t4, a0, 2
    add t3, t3, t4
    la t4, zbuf
    add t3, t3, t4                  # the depth
    sub t4, a1, a0                  # the pixels
4:
    lwu t5, 0(t3)
    bltu t5, t1, 9f
    add t1, t1, t2
    addi t3, t3, (PORTAL_STEP_X * 4)
    addi t4, t4, -PORTAL_STEP_X
    bgtz t4, 4b
3:
    ld t0, 8(sp)
    addi t0, t0, 2
    sd t0, 8(sp)
    j 2b
7:
    addi s0, s0, PORTAL_STEP_Y
    j 1b
8:
    li a0, 0
    j 10f
9:
    li a0, 1
10:
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    addi sp, sp, 64
    ret

.section .bss
.balign 8
vert_count:
    .skip 8
edge_count:
    .skip 8
edge_ymin:
    .skip 4
edge_ymax:
    .skip 4
# The sky's offsets from the camera's yaw and pitch, in texture
# repeats, 16.16
sky_uoff:
    .skip 8
sky_voff:
    .skip 8
.balign 8
poly:
    .skip POLY_SIZE
plane:
    .skip PLANE_SIZE
.balign 8
plane_d:
    .skip PLANED_SIZE
.balign 8
verts:
    .skip (MAX_VERTS * VERT_SIZE)
vview:
    .skip (MAX_VERTS * VERT_SIZE)
cverts:
    .skip (MAX_CLIPPED * VERT_SIZE)
pverts:
    .skip (MAX_CLIPPED * PVERT_SIZE)
.balign 16
edges:
    .skip (MAX_EDGES * EDGE_SIZE)
crossings:
    .skip (MAX_EDGES * 4)
.balign 16
zbuf:
    .skip ZBUF_BYTES
