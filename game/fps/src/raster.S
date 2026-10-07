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
k_lane_bias:
    .dword ((1 << 20) | (1 << 41) | (1 << 62))
k_lane_masks:
    .dword ~(0xf | (0xf << 21) | (0xf << 42))
    .dword ~(0x1f | (0x1f << 21) | (0x1f << 42))
    .dword ~(0x3f | (0x3f << 21) | (0x3f << 42))
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

poly_reset:
    la t0, vert_count
    sd zero, 0(t0)
    ret

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

poly_project:
    addi sp, sp, -80
    sd ra, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    sd s7, 24(sp)
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
    la t1, poly
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

lumap_bind:
    la t0, poly
    ld t1, POLY_MODE(t0)
    andi t1, t1, POLY_LIT
    beqz t1, 9f
    ld t2, POLY_LUMAP(t0)
    beqz t2, 9f
    ld t3, LUMAP_U0(t2)
    ld t4, POLY_IZA(t0)
    mul t4, t4, t3
    srai t4, t4, (DEPTH_BITS - 16)
    ld t5, POLY_UZA(t0)
    sub t5, t5, t4
    sd t5, POLY_UZA(t0)
    ld t4, POLY_IZB(t0)
    mul t4, t4, t3
    srai t4, t4, (DEPTH_BITS - 16)
    ld t5, POLY_UZB(t0)
    sub t5, t5, t4
    sd t5, POLY_UZB(t0)
    ld t4, POLY_IZC(t0)
    mul t4, t4, t3
    srai t4, t4, (DEPTH_BITS - 16)
    ld t5, POLY_UZC(t0)
    sub t5, t5, t4
    sd t5, POLY_UZC(t0)
    ld t3, LUMAP_V0(t2)
    ld t4, POLY_IZA(t0)
    mul t4, t4, t3
    srai t4, t4, (DEPTH_BITS - 16)
    ld t5, POLY_VZA(t0)
    sub t5, t5, t4
    sd t5, POLY_VZA(t0)
    ld t4, POLY_IZB(t0)
    mul t4, t4, t3
    srai t4, t4, (DEPTH_BITS - 16)
    ld t5, POLY_VZB(t0)
    sub t5, t5, t4
    sd t5, POLY_VZB(t0)
    ld t4, POLY_IZC(t0)
    mul t4, t4, t3
    srai t4, t4, (DEPTH_BITS - 16)
    ld t5, POLY_VZC(t0)
    sub t5, t5, t4
    sd t5, POLY_VZC(t0)
    ld t3, LUMAP_BASE(t2)
    la t4, lumel_arena
    sub t3, t3, t4
    ld t4, LUMAP_W(t2)
    slli t4, t4, (3 + LUMEL_ROWBYTES_SHIFT)
    or t3, t3, t4
    ld t4, LUMAP_H(t2)
    slli t4, t4, LUMEL_ROWS_SHIFT
    or t3, t3, t4
    ld t4, LUMAP_K(t2)
    slli t4, t4, LUMEL_K_SHIFT
    or t3, t3, t4
    sd t3, POLY_LUMEL(t0)
9:
    ret

.macro span_cap dst, scratch
    li \dst, SPAN_RECORDS
.ifdef DEBUG
    la \scratch, packet_span_cap
    lwu \scratch, 0(\scratch)
    beqz \scratch, .Lspan_cap\@
    bgeu \scratch, \dst, .Lspan_cap\@
    mv \dst, \scratch               # the console's cap on the spans a packet holds
.Lspan_cap\@:
.endif
.endm

.balign CODE_PAGE
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

poly_fill:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    la t0, edge_count
    ld t0, 0(t0)
    beqz t0, 9f
    call row_range
    la t0, clip_rect
    lw t1, RECT_Y0(t0)
    bge a0, t1, 231f
    mv a0, t1
231:
    lw t1, RECT_Y1(t0)
    ble a1, t1, 232f
    mv a1, t1
232:
    mv s0, a0                       # the row
    mv s1, a1                       # the row past the last
    li t0, -1
    sd t0, 32(sp)                   # the polygon's command in the packet, none before its first span
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
    la t2, clip_rect
    lw t3, RECT_X0(t2)
    bge a0, t3, 233f
    mv a0, t3
233:
    lw t3, RECT_X1(t2)
    ble a1, t3, 234f
    mv a1, t3
234:
    bge a0, a1, 3f
    ld a3, 32(sp)                   # the command
    la t0, span_count
    ld t1, 0(t0)
    span_cap t2, t3
    bltz a3, 235f                   # the polygon's first span: its command first
    bltu t1, t2, 236f               # room in the packet for the span
235:
    sd a0, 0(sp)
    sd a1, 24(sp)
    call packet_room
    sd a0, 32(sp)
    mv a3, a0
    ld a0, 0(sp)
    ld a1, 24(sp)
236:
    mv a2, s0
    call span_record
3:
    ld t0, 8(sp)
    addi t0, t0, 2
    sd t0, 8(sp)
    j 2b
8:
    addi s0, s0, 1
    j 1b
9:
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    addi sp, sp, 64
    ret

span_record:
    la t0, span_count
    ld t1, 0(t0)
    addi t2, t1, 1
    sd t2, 0(t0)
    la t2, span_records
    slli t1, t1, 4
    add t2, t2, t1
    sh a2, SPAN_ROW(t2)
    sh a0, SPAN_X0(t2)
    sh a1, SPAN_X1(t2)
    la t3, poly
    ld t1, POLY_MODE(t3)
    sh t1, SPAN_MODE(t2)
    ld t1, POLY_SURFACE(t3)
    sw t1, SPAN_SURFACE(t2)
    sw a3, SPAN_POLY(t2)
    ret

packet_room:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a3, 0(sp)
    la t0, span_count
    ld t1, 0(t0)
    span_cap t2, t3
    bltu t1, t2, 1f
    call packet_flush               # the packet's spans full: rendered whole, emptied
    li t0, -1
    sd t0, 0(sp)                    # the polygon's command gone with it
1:
    ld a0, 0(sp)
    bgez a0, 2f
    call command_emit
2:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

command_emit:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, command_count
    ld t1, 0(t0)
    li t2, MAX_COMMANDS
.ifdef DEBUG
    la t3, packet_command_cap
    lwu t3, 0(t3)
    beqz t3, 1f
    bgeu t3, t2, 1f
    mv t2, t3                       # the console's cap on the commands a packet holds
1:
.endif
    bltu t1, t2, 2f
    call packet_flush               # the packet's commands full: rendered whole, emptied
    la t0, command_count
    ld t1, 0(t0)
2:
    addi t2, t1, 1
    sd t2, 0(t0)
    la t3, span_count
    ld t3, 0(t3)
    la t4, command_runs
    slli t2, t1, 2
    add t4, t4, t2
    sw t3, 0(t4)                    # the command's run starts at the packet's next span
    li t2, POLY_SIZE
    mul t2, t1, t2
    la t3, commands
    add t3, t3, t2                  # the command
    la t4, poly
    li t5, (POLY_SIZE / 8)
3:
    ld t6, 0(t4)
    sd t6, 0(t3)
    addi t4, t4, 8
    addi t3, t3, 8
    addi t5, t5, -1
    bnez t5, 3b
    la t0, stats
    ld t2, STAT_COMMANDS(t0)
    addi t2, t2, 1
    sd t2, STAT_COMMANDS(t0)
    mv a0, t1
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

packet_flush:
    la t0, stats
    ld t1, STAT_FLUSHES(t0)
    addi t1, t1, 1
    sd t1, STAT_FLUSHES(t0)
    j packet_render

packet_resolve:
    la t0, commands
    la t1, command_count
    ld t1, 0(t1)
    la t2, tile_generation
    ld t2, 0(t2)
    li t5, 0                        # the bindings invalidated
1:
    beqz t1, 9f
    ld t3, POLY_MODE(t0)
    andi t4, t3, POLY_TILED
    beqz t4, 2f
    ld t4, POLY_TILE_GENERATION(t0)
    beq t4, t2, 2f
    andi t3, t3, ~POLY_TILED        # bound before a reset: the chain at each block's level
    sd t3, POLY_MODE(t0)
    addi t5, t5, 1
2:
    addi t0, t0, POLY_SIZE
    addi t1, t1, -1
    j 1b
9:
    la t0, stats
    ld t1, STAT_INVALIDATED(t0)
    add t1, t1, t5
    sd t1, STAT_INVALIDATED(t0)
    ret

context_counts:
    la t0, stats
    ld t1, CTX_SPANS(tp)
    ld t2, STAT_SPANS(t0)
    add t2, t2, t1
    sd t2, STAT_SPANS(t0)
    ld t1, CTX_PIXELS(tp)
    ld t2, STAT_PIXELS(t0)
    add t2, t2, t1
    sd t2, STAT_PIXELS(t0)
    ld t1, CTX_LIT_SPANS(tp)
    ld t2, STAT_LIT_SPANS(t0)
    add t2, t2, t1
    sd t2, STAT_LIT_SPANS(t0)
    ld t1, CTX_LIT_PIXELS(tp)
    ld t2, STAT_LIT_PIXELS(t0)
    add t2, t2, t1
    sd t2, STAT_LIT_PIXELS(t0)
    ld t1, CTX_REJECTED(tp)
    ld t2, STAT_REJECTED(t0)
    add t2, t2, t1
    sd t2, STAT_REJECTED(t0)
    ld t1, CTX_SAMPLES(tp)
    ld t2, STAT_SAMPLES(t0)
    add t2, t2, t1
    sd t2, STAT_SAMPLES(t0)
    ld t1, CTX_TILED_PIXELS(tp)
    ld t2, STAT_TILED_PIXELS(t0)
    add t2, t2, t1
    sd t2, STAT_TILED_PIXELS(t0)
.ifdef COUNT
    la t0, count_stats
    li t3, 0
1:
    add t4, tp, t3
    ld t1, CTX_COUNT(t4)
    sd zero, CTX_COUNT(t4)
    add t4, t0, t3
    ld t2, 0(t4)
    add t2, t2, t1
    sd t2, 0(t4)
    addi t3, t3, 8
    li t4, COUNT_SIZE
    bltu t3, t4, 1b
.endif
    sd zero, CTX_SPANS(tp)
    sd zero, CTX_PIXELS(tp)
    sd zero, CTX_LIT_SPANS(tp)
    sd zero, CTX_LIT_PIXELS(tp)
    sd zero, CTX_REJECTED(tp)
    sd zero, CTX_SAMPLES(tp)
    sd zero, CTX_TILED_PIXELS(tp)
    ret

.ifdef DEBUG
scratch_poison:
    la t0, poly
    la t1, scratch_end
    li t2, SCRATCH_POISON
1:
    sd t2, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 1b
    ret
.endif

poly_rect:
    la t0, pverts
    flw ft0, 0(t0)
    fmv.s ft1, ft0                  # min x, max x
    flw ft2, 4(t0)
    fmv.s ft3, ft2                  # min y, max y
    mv t1, a0
1:
    beqz t1, 2f
    flw ft4, 0(t0)
    fmin.s ft0, ft0, ft4
    fmax.s ft1, ft1, ft4
    flw ft4, 4(t0)
    fmin.s ft2, ft2, ft4
    fmax.s ft3, ft3, ft4
    addi t0, t0, PVERT_SIZE
    addi t1, t1, -1
    j 1b
2:
    la t0, k_half
    flw ft5, 0(t0)
    fsub.s ft0, ft0, ft5
    fcvt.w.s a0, ft0, rup
    addi a0, a0, -1
    fsub.s ft1, ft1, ft5
    fcvt.w.s a1, ft1, rup
    addi a1, a1, 1
    fsub.s ft2, ft2, ft5
    fcvt.w.s a2, ft2, rup
    addi a2, a2, -1
    fsub.s ft3, ft3, ft5
    fcvt.w.s a3, ft3, rup
    addi a3, a3, 1
    bgez a0, 3f
    li a0, 0
3:
    li t0, SCREEN_W
    ble a1, t0, 4f
    mv a1, t0
4:
    bgez a2, 5f
    li a2, 0
5:
    li t0, SCREEN_H
    ble a3, t0, 6f
    mv a3, t0
6:
    ret

.macro lumel_sample
    ld t3, CTX_COMMAND(tp)
    ld t3, POLY_LUMEL(t3)           # the arena offset, a row's bytes, the rows, k
    srli a7, t3, LUMEL_K_SHIFT
    addi a7, a7, 16                 # k + 16
    bgez a5, .Llumel_u0\@
    li a5, 0
.Llumel_u0\@:
    bgez a6, .Llumel_v0\@
    li a6, 0
.Llumel_v0\@:
    slli a0, t3, (64 - LUMEL_ROWBYTES_SHIFT - 16)
    srli a0, a0, 48                 # a row's bytes
    srli t4, a0, 3
    addi t4, t4, -1
    sll t4, t4, a7
    addi t4, t4, -1                 # the greatest u, under the last column
    ble a5, t4, .Llumel_u1\@
    mv a5, t4
.Llumel_u1\@:
    slli t4, t3, (64 - LUMEL_ROWS_SHIFT - 16)
    srli t4, t4, 48
    addi t4, t4, -1
    sll t4, t4, a7
    addi t4, t4, -1                 # the greatest v
    ble a6, t4, .Llumel_v1\@
    mv a6, t4
.Llumel_v1\@:
    srl t4, a6, a7                  # the row
    mul t4, t4, a0
    slli t3, t3, (64 - LUMEL_OFFSET_BITS)
    srli t3, t3, (64 - LUMEL_OFFSET_BITS)
    add t4, t4, t3                  # the row's offset into the arena
    la t3, lumel_arena
    add t4, t4, t3                  # the row's address
    srl t3, a5, a7                  # the column
    slli t3, t3, 3
    add t4, t4, t3                  # the lumel above left
    add t3, t4, a0                  # the one below it
    addi a7, a7, -8
    srl a5, a5, a7
    andi a5, a5, 0xff               # u's fraction in 256ths
    srl a6, a6, a7
    andi a6, a6, 0xff               # v's
    mul a7, a5, a6
    srli a7, a7, 8                  # the weight below right
    sub a5, a5, a7                  # above right
    sub a6, a6, a7                  # below left
    ld a0, 8(t3)
    mul a0, a0, a7
    ld t3, 0(t3)
    mul t3, t3, a6
    add a0, a0, t3
    ld t3, 8(t4)
    mul t3, t3, a5
    add a0, a0, t3
    neg a7, a7
    addi a7, a7, 256
    sub a7, a7, a5
    sub a7, a7, a6                  # above left, the four summing to 256
    ld t4, 0(t4)
    mul t4, t4, a7
    add a5, a0, t4
.endm

.macro mip_bind
    ld a5, 192(sp)                  # the block's level, the chain's last at most
    ld a6, CTX_COMMAND(tp)
    ld a1, POLY_MIPS(a6)
    slli a7, a5, 3
    add a1, a1, a7
    ld a1, 0(a1)                    # the level's texels
    ld a2, POLY_VMASK(a6)
    srl a2, a2, a5
    ld a3, POLY_UMASK(a6)
    srl a3, a3, a5
    ld a4, POLY_WSHIFT(a6)
    sub a4, a4, a5
    sd s5, 40(sp)
    addi s5, a5, 16                 # a coordinate to its texel at the level
.endm

.ifdef COUNT
.macro count_add field, scratch, base, n=1
    addi \base, tp, CTX_COUNT
    ld \scratch, \field(\base)
    addi \scratch, \scratch, \n
    sd \scratch, \field(\base)
.endm
.endif

.balign CODE_PAGE
packet_render:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    rdtime t0
    sd t0, 0(sp)                    # the render's start
    call packet_resolve
    la t0, round_workers
    lwu t0, 0(t0)
    beqz t0, 1f
    call round_run                  # the workers' round, their counts summed
    j 3f
1:
    la tp, raster_context
    la s2, span_records
    la t0, span_count
    ld s3, 0(t0)                    # the spans
    la s4, commands
    beqz s3, 2f
11:
    lwu t0, SPAN_POLY(s2)
    li t1, POLY_SIZE
    mul t0, t0, t1
    add t0, t0, s4
    sd t0, CTX_COMMAND(tp)          # the span's command, which span_fill reads through the context
    lhu a0, SPAN_X0(s2)
    lhu a1, SPAN_X1(s2)
    lhu a2, SPAN_ROW(s2)
    call span_fill
    addi s2, s2, SPAN_RECORD_SIZE
    addi s3, s3, -1
    bnez s3, 11b
2:
    call context_counts
3:
    la t0, span_count
    sd zero, 0(t0)
    la t0, command_count
    sd zero, 0(t0)                  # the packet emptied
    rdtime t0
    ld t1, 0(sp)
    sub t0, t0, t1
    la t1, stats
    ld t2, STAT_RASTER_TICKS(t1)
    add t2, t2, t0
    sd t2, STAT_RASTER_TICKS(t1)
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 48
    ret

band_render:
    addi sp, sp, -96
    sd ra, 88(sp)
    sd s0, 80(sp)
    sd s2, 72(sp)
    sd s3, 64(sp)
    sd s4, 56(sp)
    sd s5, 48(sp)
    sd s6, 40(sp)
    sd s7, 32(sp)
    sd s8, 24(sp)
    sd s9, 16(sp)
    sd s10, 8(sp)
    mv s0, a0                       # the band's first row
    mv s2, a1                       # the row past its last
    beqz a2, 3f                     # no clear this round
    li t0, SCREEN_PITCH
    mul t1, s0, t0
    mul t2, s2, t0
    la t0, zbuf
    add t1, t1, t0
    add t2, t2, t0                  # the band's depth rows
1:
    sd zero, 0(t1)
    sd zero, 8(t1)
    sd zero, 16(t1)
    sd zero, 24(t1)
    addi t1, t1, 32
    bltu t1, t2, 1b
.ifdef DEBUG
    li t0, SCREEN_PITCH
    mul t1, s0, t0
    mul t2, s2, t0
    li t0, JAB_DISPLAY_BASE
    add t1, t1, t0
    add t2, t2, t0                  # the band's pixels, magenta where nothing reaches
    li t3, 0xff00ff
    slli t4, t3, 32
    or t3, t3, t4
2:
    sd t3, 0(t1)
    sd t3, 8(t1)
    sd t3, 16(t1)
    sd t3, 24(t1)
    addi t1, t1, 32
    bltu t1, t2, 2b
.endif
3:
    la t0, round
    lwu s3, ROUND_COMMANDS(t0)
    lwu s4, ROUND_SPANS(t0)
    la s5, command_runs
    la s6, span_records
    la s7, commands
    li s8, 0                        # the command
4:
    bgeu s8, s3, 9f
    slli t0, s8, 2
    add t0, t0, s5
    lwu t4, 0(t0)                   # its run's first span
    mv s9, s4                       # its run's end, the packet's spans for the last command
    addi t1, s8, 1
    bgeu t1, s3, 5f
    lwu s9, 4(t0)                   # the next command's first span
5:
    mv t5, s9
6:
    bgeu t4, t5, 7f                 # the first span at or past the band's first row
    add t6, t4, t5
    srli t6, t6, 1
    slli t0, t6, 4
    add t0, t0, s6
    lhu t0, SPAN_ROW(t0)
    bgeu t0, s0, 61f
    addi t4, t6, 1
    j 6b
61:
    mv t5, t6
    j 6b
7:
    mv s10, t4                      # the span
    li t0, POLY_SIZE
    mul t0, s8, t0
    add t0, t0, s7
    sd t0, CTX_COMMAND(tp)          # the run's command, which span_fill reads through the context
8:
    bgeu s10, s9, 81f
    slli t0, s10, 4
    add t0, t0, s6
    lhu a2, SPAN_ROW(t0)
    bgeu a2, s2, 81f                # past the band
    lhu a0, SPAN_X0(t0)
    lhu a1, SPAN_X1(t0)
    call span_fill
    addi s10, s10, 1
    j 8b
81:
    addi s8, s8, 1
    j 4b
9:
    ld ra, 88(sp)
    ld s0, 80(sp)
    ld s2, 72(sp)
    ld s3, 64(sp)
    ld s4, 56(sp)
    ld s5, 48(sp)
    ld s6, 40(sp)
    ld s7, 32(sp)
    ld s8, 24(sp)
    ld s9, 16(sp)
    ld s10, 8(sp)
    addi sp, sp, 96
    ret

span_fill:
    addi sp, sp, -240
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
    sd zero, 144(sp)                # the pixels the depth test rejected, as entered less passed
    sd zero, 176(sp)                # the lumel samples
.ifdef OWNER
    ld t0, CTX_COMMAND(tp)
    ld t0, POLY_SURFACE(t0)
    sd t0, 32(sp)                   # the surface, stored as the pixel
.endif
    ld t0, CTX_COMMAND(tp)          # the command, the polygon as preparation published it
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
    ld t4, CTX_SPANS(tp)
    addi t4, t4, 1
    sd t4, CTX_SPANS(tp)
    ld t4, CTX_PIXELS(tp)
    add t4, t4, s10
    sd t4, CTX_PIXELS(tp)
    ld t3, CTX_COMMAND(tp)
    ld t4, POLY_MODE(t3)
    andi t4, t4, POLY_LIT
    beqz t4, 5f
    ld t5, CTX_LIT_SPANS(tp)
    addi t5, t5, 1
    sd t5, CTX_LIT_SPANS(tp)
    ld t5, CTX_LIT_PIXELS(tp)
    add t5, t5, s10
    sd t5, CTX_LIT_PIXELS(tp)
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
    ld t3, CTX_COMMAND(tp)
    ld a1, POLY_TEX(t3)
    ld a2, POLY_VMASK(t3)
    ld a3, POLY_UMASK(t3)
    ld a4, POLY_WSHIFT(t3)
    ld t4, POLY_MODE(t3)
    li t5, POLY_SKY
    beq t4, t5, 70f
    sd t4, 16(sp)                   # the mode
    mv t3, s2
    li t4, IZ_MIN
    bge t3, t4, 1f
    mv t3, t4
1:
.ifdef COUNT
    count_add COUNT_DIVIDES, a5, a6
.endif
    li t4, 1
    slli t4, t4, Z_SHIFT
    div t4, t4, t3                  # z, 48.16
    sd t4, 232(sp)                  # the span's z, a flat row's z everywhere along it
    mul s8, s4, t4
    srai s8, s8, 16                 # u
    mul s9, s5, t4
    srai s9, s9, 16                 # v
    li t3, -1
    sd t3, 200(sp)                  # no tiles for the span
    ld a0, CTX_COMMAND(tp)
    mul t3, s10, s3
    add t3, s2, t3                  # 1/z at the end, kept for the row below it
    li t4, IZ_MIN
    bge t3, t4, 21f
    mv t3, t4
21:
    beqz s3, 22f
.ifdef COUNT
    count_add COUNT_DIVIDES, a5, a6
.endif
    li t4, 1
    slli t4, t4, Z_SHIFT
    div t4, t4, t3                  # z at the end
    j 27f
22:
    ld t4, 232(sp)                  # 1/z flat along the row: z at the end the start's
.ifdef COUNT
    count_add COUNT_FLAT, a5, a6
    li a5, 1
    slli a5, a5, Z_SHIFT
    div a5, a5, t3                  # the reference, from the end's clamped 1/z
    count_add COUNT_AVOIDED, a6, a7
    beq a5, t4, 27f
    count_add COUNT_MISMATCHES, a6, a7
.endif
27:
    mul a5, s10, s6
    add a5, a5, s4
    mul a5, a5, t4
    srai a5, a5, 16                 # u at the end
    sd a5, 168(sp)
    mul a6, s10, s7
    add a6, a6, s5
    mul a6, a6, t4
    srai a6, a6, 16                 # v at the end
    sd a6, 184(sp)
    ld a6, POLY_IZB(a0)
    add a6, a6, s2
    li t4, IZ_MIN
    bge a6, t4, 23f
    mv a6, t4
23:
.ifdef COUNT
    count_add COUNT_DIVIDES, a7, t4
.endif
    li t4, 1
    slli t4, t4, Z_SHIFT
    div t4, t4, a6                  # z a row below the start
    ld a6, POLY_UZB(a0)
    add a6, a6, s4
    mul a6, a6, t4
    srai a6, a6, 16
    sub a6, a6, s8
    srai a7, a6, 63
    xor a6, a6, a7
    sub a6, a6, a7                  # |du| down
    ld a7, POLY_VZB(a0)
    add a7, a7, s5
    mul a7, a7, t4
    srai a7, a7, 16
    sub a7, a7, s9
    srai t4, a7, 63
    xor a7, a7, t4
    sub a7, a7, t4                  # |dv| down
    bge a6, a7, 24f
    mv a6, a7
24:
    sd a6, 208(sp)                  # the step down a row at the start
    ld a7, POLY_IZB(a0)
    add a7, a7, t3                  # 1/z a row below the end
    li t4, IZ_MIN
    bge a7, t4, 25f
    mv a7, t4
25:
.ifdef COUNT
    count_add COUNT_DIVIDES, a6, t4
.endif
    li t4, 1
    slli t4, t4, Z_SHIFT
    div t4, t4, a7                  # z a row below the end
    mul a6, s10, s6
    add a6, a6, s4
    ld a7, POLY_UZB(a0)
    add a6, a6, a7
    mul a6, a6, t4
    srai a6, a6, 16
    ld a7, 168(sp)
    sub a6, a6, a7
    srai a7, a6, 63
    xor a6, a6, a7
    sub a6, a6, a7                  # |du| down at the end
    mul a7, s10, s7
    add a7, a7, s5
    ld t3, POLY_VZB(a0)
    add a7, a7, t3
    mul a7, a7, t4
    srai a7, a7, 16
    ld t3, 184(sp)
    sub a7, a7, t3
    srai t3, a7, 63
    xor a7, a7, t3
    sub a7, a7, t3                  # |dv| down at the end
    bge a6, a7, 26f
    mv a6, a7
26:
    ld a7, 208(sp)
    sub t3, a6, a7
.ifdef COUNT
    count_add COUNT_DIVIDES, a6, a7
.endif
    div t3, t3, s10
    sd t3, 216(sp)                  # the row step's change a pixel
    ld t3, 16(sp)
    andi t3, t3, POLY_TILED
    beqz t3, 29f
    ld a7, POLY_LUMEL(a0)
    srli a7, a7, LUMEL_K_SHIFT
    addi a7, a7, 16                 # k + 16: a coordinate to its cell
    sra a1, s8, a7
    bltz a1, 29f
    ld a5, 168(sp)
    sra a2, a5, a7
    bltz a2, 29f
    ld t4, POLY_TILE_COLS(a0)
    bge a1, t4, 29f
    bge a2, t4, 29f
    sra a1, s9, a7
    bltz a1, 29f
    ld a6, 184(sp)
    sra a2, a6, a7
    bltz a2, 29f
    ld t4, POLY_TILE_ROWS(a0)
    bge a1, t4, 29f
    bge a2, t4, 29f
    ld t3, POLY_TILE_READY(a0)
    addi t3, t3, -1
    sd t3, 200(sp)
29:
    ld a0, CTX_COMMAND(tp)
    ld t3, POLY_MIP_COUNT(a0)
    addi t3, t3, -1
    sd t3, 224(sp)                  # the chain's last level, every block's bound
    ld a1, POLY_TEX(a0)
    ld a2, POLY_VMASK(a0)
    ld a3, POLY_UMASK(a0)
    ld a4, POLY_WSHIFT(a0)
    ld t3, 16(sp)
    andi t3, t3, POLY_LIT
    beqz t3, 30f
    ld t3, CTX_COMMAND(tp)
    ld t4, POLY_LUMAP(t3)
    bnez t4, 20f
    ld t4, POLY_FLAT_BRIGHT(t3)
    sd t4, 160(sp)                  # the brightness entering the next block
    li s0, 0                        # the step a pixel
    li t4, -1
    sd t4, 152(sp)                  # an interval that never ends
    j 30f
20:
    li t3, -1
    sd t3, 160(sp)                  # the brightness entering the first block: unsampled yet
    sd zero, 152(sp)                # the interval's pixels left: none, so one starts
30:
    li s11, BLOCK
    ble s10, s11, 31f
    j 32f
31:
    mv s11, s10
32:
    beqz s3, 34f
    mul t3, s11, s3
    add t3, t3, s2                  # 1/z at the end
    li t4, IZ_MIN
    bge t3, t4, 33f
    mv t3, t4
33:
.ifdef COUNT
    count_add COUNT_DIVIDES, a5, a6
.endif
    li t4, 1
    slli t4, t4, Z_SHIFT
    div t4, t4, t3                  # z at the end
    j 35f
34:
    ld t4, 232(sp)                  # 1/z flat along the row: the span's z
.ifdef COUNT
    mul a5, s11, s3
    add a5, a5, s2                  # the reference: 1/z at the end as computed
    li a6, IZ_MIN
    bge a5, a6, 3401f
    mv a5, a6
3401:
    li a6, 1
    slli a6, a6, Z_SHIFT
    div a5, a6, a5
    count_add COUNT_AVOIDED, a6, a7
    beq a5, t4, 35f
    count_add COUNT_MISMATCHES, a6, a7
.endif
35:
    mul t3, s11, s6
    add t3, t3, s4                  # u/z at the end
    mul t3, t3, t4
    srai t3, t3, 16                 # u at the end
    mul t5, s11, s7
    add t5, t5, s5                  # v/z at the end
    mul t5, t5, t4
    srai t5, t5, 16                 # v at the end
    sub t6, t5, s9
    sub t4, t3, s8
    li a5, BLOCK
    bne s11, a5, 36f
.ifdef COUNT
    div a6, t6, s11                 # dv's reference, the divide the shift replaces
    div a7, t4, s11                 # du's
    bgez t6, 3601f
    andi a0, t6, (BLOCK - 1)
    beqz a0, 3601f
    count_add COUNT_NEGATIVE_V, a0, t2
3601:
    bgez t4, 3602f
    andi a0, t4, (BLOCK - 1)
    beqz a0, 3602f
    count_add COUNT_NEGATIVE_U, a0, t2
3602:
.endif
    srai a5, t6, 63
    andi a5, a5, (BLOCK - 1)
    add t6, t6, a5
    srai t6, t6, BLOCK_SHIFT        # dv a pixel, rounded toward zero as a divide
    srai a5, t4, 63
    andi a5, a5, (BLOCK - 1)
    add t4, t4, a5
    srai t4, t4, BLOCK_SHIFT        # du a pixel
.ifdef COUNT
    count_add COUNT_SHIFTED, a0, t2
    count_add COUNT_AVOIDED, a0, t2, 2
    beq a6, t6, 3603f
    count_add COUNT_MISMATCHES, a0, t2
3603:
    beq a7, t4, 3604f
    count_add COUNT_MISMATCHES, a0, t2
3604:
.endif
    j 37f
36:
.ifdef COUNT
    count_add COUNT_SHORT, a0, t2
    count_add COUNT_DIVIDES, a0, t2, 2
.endif
    div t6, t6, s11                 # dv a pixel
    div t4, t4, s11                 # du a pixel
37:
    sd t3, 0(sp)
    sd t5, 8(sp)
    mv t5, t4
    mv t2, s11
    srai a6, t5, 63
    xor a7, t5, a6
    sub a7, a7, a6                  # |du|
    srai a6, t6, 63
    xor a0, t6, a6
    sub a0, a0, a6                  # |dv|
    bge a7, a0, 432f
    mv a7, a0
432:
    ld a0, 208(sp)                  # the step down a row here
    bge a7, a0, 433f
    mv a7, a0
433:
    ld a0, 216(sp)
    mul a0, a0, s11
    ld a6, 208(sp)
    add a6, a6, a0
    sd a6, 208(sp)                  # and at the next block
    srli a7, a7, 17
    ld a0, 224(sp)                  # the chain's last level
    li a6, 0
434:
    beqz a7, 435f
    bge a6, a0, 435f
    addi a6, a6, 1
    srli a7, a7, 1
    j 434b
435:
    sd a6, 192(sp)                  # the block's level
    li t4, 0                        # the pixels past the depth test this block
    ld t3, 16(sp)
    andi a5, t3, POLY_LIT
    bnez a5, 44f
    li a5, POLY_MASKED
    beq t3, a5, 500f
    j 400f
44:
    ld a5, 200(sp)
    bltz a5, 4300f
    ld a6, 192(sp)
    bgt a6, a5, 4300f               # the level not whole in the tiles: the chain's at it
    j 80f
4300:
    ld t3, 160(sp)
    ld a5, 152(sp)
    bnez a5, 49f
    bgez t3, 431f
    mv a5, s8
    mv a6, s9
    lumel_sample
    sd a5, 160(sp)
    ld a0, 176(sp)
    addi a0, a0, 1
    sd a0, 176(sp)
431:
    srai a5, t5, 63
    xor a0, t5, a5
    sub a0, a0, a5                  # |du|
    srai a5, t6, 63
    xor a6, t6, a5
    sub a6, a6, a5                  # |dv|
    bge a0, a6, 441f
    mv a0, a6
441:
    ld a5, CTX_COMMAND(tp)
    ld a5, POLY_LUMEL(a5)
    srli a5, a5, LUMEL_K_SHIFT      # k
    addi a7, a5, (15 - INTERVAL_SHIFT_MAX)
    srl a0, a0, a7                  # the step in half lumels over four blocks
    li t2, (BLOCK << 2)             # the interval's pixels: four blocks
    beqz a0, 442f
    li t2, (BLOCK << 1)             # two
    li a6, 1
    beq a0, a6, 442f
    li t2, BLOCK                    # one
442:
    ble t2, s10, 443f
    mv t2, s10                      # cut short by the span's end
443:
    beq t2, s11, 445f
    beqz s3, 4440f
    mul t3, t2, s3
    add t3, t3, s2                  # 1/z at the interval's end
    li t4, IZ_MIN
    bge t3, t4, 444f
    mv t3, t4
444:
.ifdef COUNT
    count_add COUNT_DIVIDES, a5, a6
.endif
    li t4, 1
    slli t4, t4, Z_SHIFT
    div t4, t4, t3                  # z there
    j 4441f
4440:
    ld t4, 232(sp)                  # 1/z flat along the row: the span's z
.ifdef COUNT
    mul a5, t2, s3
    add a5, a5, s2                  # the reference: 1/z at the interval's end as computed
    li a6, IZ_MIN
    bge a5, a6, 4442f
    mv a5, a6
4442:
    li a6, 1
    slli a6, a6, Z_SHIFT
    div a5, a6, a5
    count_add COUNT_AVOIDED, a6, a7
    beq a5, t4, 4441f
    count_add COUNT_MISMATCHES, a6, a7
.endif
4441:
    mul a5, t2, s6
    add a5, a5, s4
    mul a5, a5, t4
    srai a5, a5, 16                 # u
    mul a6, t2, s7
    add a6, a6, s5
    mul a6, a6, t4
    srai a6, a6, 16                 # v
    j 446f
445:
    ld a5, 0(sp)
    ld a6, 8(sp)
446:
    lumel_sample
    ld t3, 160(sp)                  # the brightness at the interval's start
    sd a5, 160(sp)                  # its end sample, the next interval's start
    ld a0, 176(sp)
    addi a0, a0, 1
    sd a0, 176(sp)
    li a7, (INTERVAL_SHIFT_MAX - 2)
    li t4, BLOCK
    beq t2, t4, 447f
    li a7, (INTERVAL_SHIFT_MAX - 1)
    li t4, (BLOCK << 1)
    beq t2, t4, 447f
    li a7, INTERVAL_SHIFT_MAX
    li t4, (BLOCK << 2)
    bne t2, t4, 448f
447:
    sub a5, a5, t3
    la a0, k_lane_bias
    ld a6, 0(a0)
    add a5, a5, a6
    la a0, k_lane_masks
    addi t4, a7, -(INTERVAL_SHIFT_MAX - 2)
    slli t4, t4, 3
    add a0, a0, t4
    ld a0, 0(a0)
    and a5, a5, a0
    srl a5, a5, a7
    srl a6, a6, a7
    sub s0, a5, a6                  # the step a pixel
    j 449f
448:
.ifdef COUNT
    count_add COUNT_DIVIDES, a7, t4, 3
.endif
    li a0, ((1 << CHANNEL_BITS) - 1)
    and a6, a5, a0
    and t4, t3, a0
    sub a6, a6, t4
    div s0, a6, t2
    srli a6, a5, CHANNEL_BITS
    and a6, a6, a0
    srli t4, t3, CHANNEL_BITS
    and t4, t4, a0
    sub a6, a6, t4
    div a6, a6, t2
    slli a6, a6, CHANNEL_BITS
    add s0, s0, a6
    srli a6, a5, (2 * CHANNEL_BITS)
    srli t4, t3, (2 * CHANNEL_BITS)
    sub a6, a6, t4
    div a6, a6, t2
    slli a6, a6, (2 * CHANNEL_BITS)
    add s0, s0, a6
449:
    mv a5, t2                       # the interval's pixels
    mv t2, s11                      # the block's, for the loop
49:
    sub a5, a5, s11
    sd a5, 152(sp)                  # the interval's pixels left after this block
    mip_bind
    li t4, 0
    ld a5, 16(sp)
    andi a5, a5, POLY_MASKED
    bnez a5, 55f
45:
    lwu a7, 0(t1)
    bgeu a7, s2, 46f
    addi t4, t4, 1
    srl a5, s9, s5
    and a5, a5, a2
    sll a5, a5, a4
    srl a6, s8, s5
    and a6, a6, a3
    slli a6, a6, 2
    add a5, a5, a6
    add a5, a5, a1
    lw a0, 0(a5)
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
    owner_pixel a6
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
    j 61f
55:
    lwu a7, 0(t1)
    bgeu a7, s2, 56f
    addi t4, t4, 1
    srl a5, s9, s5
    and a5, a5, a2
    sll a5, a5, a4
    srl a6, s8, s5
    and a6, a6, a3
    slli a6, a6, 2
    add a5, a5, a6
    add a5, a5, a1
    lw a0, 0(a5)
    srli a6, a0, 31
    beqz a6, 56f
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
    owner_pixel a6
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
61:
    ld t5, 152(sp)
    beqz t5, 60f
    sd t3, 160(sp)
    j 60f
80:
    li t4, 0
    sd s5, 40(sp)
    ld a0, CTX_COMMAND(tp)
    ld a5, 192(sp)                  # the block's level
    slli a6, a5, 3
    add a6, a6, a0
    ld a1, POLY_TILES(a6)           # the level's atlas
    ld a4, POLY_TILE_COLS_SHIFT(a0)
    ld a3, POLY_LUMEL(a0)
    srli a3, a3, LUMEL_K_SHIFT      # k
    addi t3, a3, 16                 # a coordinate to its cell
    addi s0, a5, 16                 # a coordinate to its texel at the level
    sub a3, a3, a5                  # the cell's texels a side at the level, as a shift
    li a2, 1
    sll a2, a2, a3
    addi a2, a2, -1                 # the texels of a cell less one, at the level
    slli s5, a3, 1
    addi s5, s5, 2                  # a tile's bytes as a shift
    ld a6, 16(sp)
    andi a6, a6, POLY_MASKED
    bnez a6, 85f
81:
    lwu a7, 0(t1)
    bgeu a7, s2, 82f
    addi t4, t4, 1
    srl a5, s9, t3                  # the cell's row
    sll a7, a5, a4
    srl a0, s8, t3                  # and column
    add a7, a7, a0                  # the tile's index
    sll a7, a7, s5                  # the tile
    srl a5, s9, s0                  # v at the level
    and a5, a5, a2
    sll a5, a5, a3
    srl a6, s8, s0                  # u
    and a6, a6, a2
    add a5, a5, a6
    slli a5, a5, 2
    add a7, a7, a5
    add a7, a7, a1
    lw a0, 0(a7)
    owner_pixel a0
    sw a0, 0(t0)
    sw s2, 0(t1)
82:
    add s2, s2, s3
    add s8, s8, t5
    add s9, s9, t6
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 81b
    j 83f
85:
    lwu a7, 0(t1)
    bgeu a7, s2, 86f
    addi t4, t4, 1
    srl a5, s9, t3
    sll a7, a5, a4
    srl a0, s8, t3
    add a7, a7, a0
    sll a7, a7, s5
    srl a5, s9, s0
    and a5, a5, a2
    sll a5, a5, a3
    srl a6, s8, s0
    and a6, a6, a2
    add a5, a5, a6
    slli a5, a5, 2
    add a7, a7, a5
    add a7, a7, a1
    lw a0, 0(a7)
    srli a5, a0, 31
    beqz a5, 86f
    owner_pixel a0
    sw a0, 0(t0)
    sw s2, 0(t1)
86:
    add s2, s2, s3
    add s8, s8, t5
    add s9, s9, t6
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 85b
83:
    ld a6, CTX_TILED_PIXELS(tp)
    add a6, a6, s11
    sd a6, CTX_TILED_PIXELS(tp)
    sd zero, 152(sp)
    li a5, -1
    sd a5, 160(sp)
    j 60f
400:
    mip_bind
40:
    lwu a7, 0(t1)
    bgeu a7, s2, 41f
    addi t4, t4, 1
    srl a5, s9, s5
    and a5, a5, a2
    sll a5, a5, a4
    srl a6, s8, s5
    and a6, a6, a3
    slli a6, a6, 2
    add a5, a5, a6
    add a5, a5, a1
    lw a0, 0(a5)
    owner_pixel a0
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
500:
    mip_bind
50:
    lwu a7, 0(t1)
    bgeu a7, s2, 51f
    addi t4, t4, 1
    srl a5, s9, s5
    and a5, a5, a2
    sll a5, a5, a4
    srl a6, s8, s5
    and a6, a6, a3
    slli a6, a6, 2
    add a5, a5, a6
    add a5, a5, a1
    lw a0, 0(a5)
    srli a6, a0, 31
    beqz a6, 51f
    owner_pixel a0
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
    ld s5, 40(sp)                   # v/z back from the block's spill
    sub t3, s11, t4
    ld t5, 144(sp)
    add t5, t5, t3
    sd t5, 144(sp)
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
.ifdef COUNT
    count_add COUNT_DIVIDES, a5, a6, 2
.endif
    ld t3, CTX_COMMAND(tp)
    lwu t4, POLY_TEXWI(t3)
    slli t3, t4, 16
    li t5, SCREEN_W
    div t5, t3, t5                  # u's step a pixel, 16.16
    la t3, sky_uoff
    ld s8, 0(t3)
    mul s8, s8, t4                  # the offset in texels
    mul t3, t5, a0
    add s8, s8, t3                  # u at the first pixel
    ld t3, CTX_COMMAND(tp)
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
    li t4, 0                        # the pixels past the depth test
71:
    lwu a7, 0(t1)
    bgeu a7, s2, 72f
    addi t4, t4, 1
    srai a6, s8, 16
    and a6, a6, a3
    slli a6, a6, 2
    add a5, s9, a6
    add a5, a5, a1
    lw a0, 0(a5)
    owner_pixel a0
    sw a0, 0(t0)
    sw s2, 0(t1)
72:
    add s8, s8, t5
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 71b
    sub t3, s10, t4
    sd t3, 144(sp)
90:
    ld t4, CTX_REJECTED(tp)
    ld t5, 144(sp)
    add t4, t4, t5
    sd t4, CTX_REJECTED(tp)
    ld t4, CTX_SAMPLES(tp)
    ld t5, 176(sp)
    add t4, t4, t5
    sd t4, CTX_SAMPLES(tp)
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
    addi sp, sp, 240
    ret

.section .bss
.balign 8
.ifdef COUNT
count_stats:
    .skip COUNT_SIZE
.endif
vert_count:
    .skip 8
edge_count:
    .skip 8
edge_ymin:
    .skip 4
edge_ymax:
    .skip 4
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
scratch_end:
.balign 16
span_records:
    .skip (SPAN_RECORDS * SPAN_RECORD_SIZE)
span_count:
    .skip 8
command_count:
    .skip 8
.ifdef DEBUG
packet_command_cap:
    .skip 4
packet_span_cap:
    .skip 4
.endif
.balign 64
raster_context:
    .skip CTX_SIZE
.balign 16
commands:
    .skip (MAX_COMMANDS * POLY_SIZE)
command_runs:
    .skip (MAX_COMMANDS * 4)
.balign 64
zbuf:
    .skip ZBUF_BYTES
