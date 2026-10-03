.include "jab.inc"

.set DURATION, (JAB_TIME_HZ * 3)
.set PIXELS, (JAB_DISPLAY_WIDTH * JAB_DISPLAY_HEIGHT)
.set ZBUF_BYTES, (PIXELS * 4)
.set POLY_X, 0
.set POLY_Y, 4
.set POLY_IZ, 8
.set POLY_UZ, 12
.set POLY_VZ, 16
.set POLY_BR, 20
.set POLY_VERTEX, 24
.set POLY_VERTICES, 4
.set BLOCK, 16
.set POLY_FIXED, 1
.set POLY_LIT, 2
.set POLY_INTEGER, 4
.set DEPTH_BITS, 26
.set Z_SHIFT, (DEPTH_BITS + 16)
.set TEX_BITS, 6
.set TEX_SIDE, (1 << TEX_BITS)
.set TEX_MASK, (TEX_SIDE - 1)
.set TEX_ROW_BYTES, (TEX_SIDE * 4)
.set TEX_ROW_SHIFT, (TEX_BITS + 2)
.set TEX_STEP, 0x8000
.set SPAN, 16
.set SPANS, (JAB_DISPLAY_WIDTH / SPAN)
.set LINE_BYTES, 128
.set DIGITS_BYTES, 24

.section .text
.global _start
_start:
    jab.sys.display.open
    bnez a0, no_display
    call make_texture
    la a0, frame_fill
    la a1, name_fill
    li a2, 0
    call mode_run
    la a0, frame_texture
    la a1, name_texture
    li a2, 0
    call mode_run
    la a0, frame_perspective
    la a1, name_perspective
    li a2, 0
    call mode_run
    la a0, frame_polygon
    la a1, name_polygon
    li a2, 0
    call mode_run
    la a0, frame_fixed
    la a1, name_fixed
    li a2, 0
    call mode_run
    la a0, frame_integer
    la a1, name_integer
    li a2, 0
    call mode_run
    la a0, frame_lit
    la a1, name_lit
    li a2, 0
    call mode_run
.ifdef VECTOR
    la a0, frame_vector
    la a1, name_vector
    li a2, 0
    call mode_run
.endif
    la a0, frame_texture
    la a1, name_textureflip
    li a2, 1
    call mode_run
idle:
    jab.sys.display.await
    j idle

no_display:
    jab.sys.uart.print msg_no_display
    jab.sys.exit 1

mode_run:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    mv s0, a0
    mv s1, a1
    mv s2, a2
    li s3, 0                    # frames rendered
    li s4, 0                    # flips shown
    rdtime s5                   # when the mode began
1:
    la t0, frames
    sd s3, 0(t0)
    jalr s0
    addi s3, s3, 1
    beqz s2, 2f
    jab.sys.display.flip
    bnez a0, 2f
    addi s4, s4, 1
2:
    rdtime t0
    sub t0, t0, s5
    li t1, DURATION
    bltu t0, t1, 1b
    la t1, elapsed
    sd t0, 0(t1)
    la a0, line
    mv a1, s1
    call append_str
    la a1, word_frames
    call append_str
    mv a1, s3
    call append_dec
    la a1, word_shown
    call append_str
    mv a1, s4
    call append_dec
    la a1, word_ticks
    call append_str
    la a1, elapsed
    ld a1, 0(a1)
    call append_dec
    la a1, word_pixels
    call append_str
    li a1, PIXELS
    call append_dec
    li t0, '\n'
    sb t0, 0(a0)
    sb zero, 1(a0)
    jab.sys.uart.print line
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 64
    ret

append_str:
1:
    lbu t0, 0(a1)
    beqz t0, 2f
    sb t0, 0(a0)
    addi a0, a0, 1
    addi a1, a1, 1
    j 1b
2:
    ret

append_dec:
    la t0, digits
    addi t0, t0, DIGITS_BYTES   # built backwards from the scratch's end
    li t1, 10
1:
    remu t2, a1, t1
    divu a1, a1, t1
    addi t2, t2, '0'
    addi t0, t0, -1
    sb t2, 0(t0)
    bnez a1, 1b
    la t3, digits
    addi t3, t3, DIGITS_BYTES
2:
    lbu t2, 0(t0)
    sb t2, 0(a0)
    addi a0, a0, 1
    addi t0, t0, 1
    bltu t0, t3, 2b
    ret

make_texture:
    la t0, texture
    li t1, 0                    # y
    li t6, TEX_SIDE
1:
    li t2, 0                    # x
2:
    xor t3, t1, t2
    andi t3, t3, 8
    li t4, 0x00ff8040
    bnez t3, 3f
    li t4, 0x000040ff
3:
    slli t5, t2, 2
    andi t5, t5, 0xff
    slli t5, t5, 8
    xor t4, t4, t5
    sw t4, 0(t0)
    addi t0, t0, 4
    addi t2, t2, 1
    bltu t2, t6, 2b
    addi t1, t1, 1
    bltu t1, t6, 1b
    ret

frame_fill:
    la t0, frames
    ld t0, 0(t0)
    li t1, 0x0f0f0f
    mul t0, t0, t1
    li t1, 0xffffff
    and t0, t0, t1
    slli t1, t0, 32
    or t2, t0, t1               # two pixels
    li t0, JAB_DISPLAY_BASE
    li t1, JAB_DISPLAY_BASE + JAB_DISPLAY_SIZE
1:
    sd t2, 0(t0)
    sd t2, 8(t0)
    sd t2, 16(t0)
    sd t2, 24(t0)
    sd t2, 32(t0)
    sd t2, 40(t0)
    sd t2, 48(t0)
    sd t2, 56(t0)
    addi t0, t0, 64
    bltu t0, t1, 1b
    ret

frame_texture:
    la t0, frames
    ld t0, 0(t0)
    slli t6, t0, 16             # u at a row's start
    li t1, JAB_DISPLAY_BASE
    li t5, 0                    # the row
    li a2, TEX_STEP
    li a3, JAB_DISPLAY_WIDTH
    li a4, JAB_DISPLAY_HEIGHT
    la a5, texture
1:
    add t2, t5, t0
    andi t2, t2, TEX_MASK
    slli t2, t2, TEX_ROW_SHIFT
    add t3, a5, t2              # the texture row
    mv t2, t6
    mv t4, a3
2:
    srli a0, t2, 16
    andi a0, a0, TEX_MASK
    slli a0, a0, 2
    add a0, a0, t3
    lw a0, 0(a0)
    sw a0, 0(t1)
    add t2, t2, a2
    addi t1, t1, 4
    addi t4, t4, -1
    bnez t4, 2b
    addi t5, t5, 1
    bltu t5, a4, 1b
    ret

frame_perspective:
    la t0, frames
    ld t0, 0(t0)
    li t1, JAB_DISPLAY_BASE
    li t5, 0                    # the row
    li a2, JAB_DISPLAY_HEIGHT
    la a5, texture
    li a6, 0x40000000           # the numerator a span's 1/z divides
1:
    add t2, t5, t0
    andi t2, t2, TEX_MASK
    slli t2, t2, TEX_ROW_SHIFT
    add t3, a5, t2              # the texture row
    addi a3, t5, 1              # 1/z at the row's start, never 0
    slli a3, a3, 8
    li a4, SPANS
2:
    divu t6, a6, a3             # z
    addi a3, a3, 16             # 1/z on
    srli a7, t6, 4              # u at the span's start, 16.16
    srli t4, t6, 12             # u's step a pixel
    ori t4, t4, 1
    li t2, SPAN
3:
    srli a0, a7, 16
    andi a0, a0, TEX_MASK
    slli a0, a0, 2
    add a0, a0, t3
    lw a0, 0(a0)
    sw a0, 0(t1)
    add a7, a7, t4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 3b
    addi a4, a4, -1
    bnez a4, 2b
    addi t5, t5, 1
    bltu t5, a2, 1b
    ret

frame_polygon:
    li a0, 0
    j poly_frame

frame_fixed:
    li a0, POLY_FIXED
    j poly_frame

frame_integer:
    li a0, (POLY_FIXED | POLY_INTEGER)
    j poly_frame

frame_lit:
    li a0, (POLY_FIXED | POLY_INTEGER | POLY_LIT)
    j poly_frame

poly_frame:
    addi sp, sp, -208
    sd ra, 200(sp)
    sd s0, 192(sp)
    sd s1, 184(sp)
    sd s2, 176(sp)
    sd s3, 168(sp)
    sd s4, 160(sp)
    sd s5, 152(sp)
    sd s6, 144(sp)
    sd s7, 136(sp)
    sd s8, 128(sp)
    sd s9, 120(sp)
    sd s10, 112(sp)
    sd s11, 104(sp)
    fsd fs0, 96(sp)
    fsd fs1, 88(sp)
    fsd fs2, 80(sp)
    fsd fs3, 72(sp)
    fsd fs4, 64(sp)
    fsd fs5, 56(sp)
    fsd fs6, 48(sp)
    fsd fs7, 40(sp)
    fsd fs8, 32(sp)
    fsd fs9, 24(sp)
    fsd fs10, 16(sp)
    fsd fs11, 8(sp)
    mv s0, a0                       # lit
    la t0, zbuf
    li t1, ZBUF_BYTES
    add t1, t1, t0
1:
    sd zero, 0(t0)
    sd zero, 8(t0)
    sd zero, 16(t0)
    sd zero, 24(t0)
    addi t0, t0, 32
    bltu t0, t1, 1b
    li s1, 0                        # the row
10:
    li t0, JAB_DISPLAY_HEIGHT
    bge s1, t0, 90f
    fcvt.s.w fs0, s1
    la t0, k_half
    flw ft0, 0(t0)
    fadd.s fs0, fs0, ft0            # the row's centre
    li s2, 0                        # the edge
    li s3, 0                        # the crossings found
11:
    li t0, POLY_VERTICES
    bge s2, t0, 20f
    li t1, POLY_VERTEX
    mul t2, s2, t1
    la t3, poly
    add t2, t2, t3                  # the edge's first vertex
    addi t4, s2, 1
    andi t4, t4, (POLY_VERTICES - 1)
    mul t4, t4, t1
    add t4, t4, t3                  # its second
    flw ft1, POLY_Y(t2)
    flw ft2, POLY_Y(t4)
    fle.s t5, ft1, fs0
    fle.s t6, ft2, fs0
    beq t5, t6, 19f                 # the row's centre is not between
    li t0, 2
    bge s3, t0, 19f
    fsub.s ft3, fs0, ft1
    fsub.s ft4, ft2, ft1
    fdiv.s ft3, ft3, ft4            # how far along the edge
    la t5, cross
    li t6, POLY_VERTEX
    mul t6, s3, t6
    add t5, t5, t6                  # the crossing's slot
    li t6, 0                        # the attribute
12:
    li t0, POLY_VERTEX
    bge t6, t0, 13f
    add t0, t2, t6
    flw ft5, 0(t0)
    add t0, t4, t6
    flw ft6, 0(t0)
    fsub.s ft6, ft6, ft5
    fmadd.s ft5, ft3, ft6, ft5
    add t0, t5, t6
    fsw ft5, 0(t0)
    addi t6, t6, 4
    j 12b
13:
    addi s3, s3, 1
19:
    addi s2, s2, 1
    j 11b
20:
    li t0, 2
    blt s3, t0, 89f                 # no span on this row
    la s4, cross                    # the left end
    addi s5, s4, POLY_VERTEX        # the right end
    flw ft0, POLY_X(s4)
    flw ft1, POLY_X(s5)
    fle.s t0, ft0, ft1
    bnez t0, 21f
    mv t1, s4
    mv s4, s5
    mv s5, t1
    fmv.s ft2, ft0
    fmv.s ft0, ft1
    fmv.s ft1, ft2
21:
    la t0, k_half
    flw ft2, 0(t0)
    fsub.s ft3, ft0, ft2
    fcvt.w.s s6, ft3, rup           # the first pixel
    bgez s6, 22f
    li s6, 0
22:
    fsub.s ft3, ft1, ft2
    fcvt.w.s s7, ft3, rup           # the pixel past the last
    li t0, JAB_DISPLAY_WIDTH
    ble s7, t0, 23f
    mv s7, t0
23:
    bge s6, s7, 89f
    fsub.s ft3, ft1, ft0            # the width
    flw ft4, POLY_IZ(s4)
    flw ft5, POLY_IZ(s5)
    fsub.s fs5, ft5, ft4
    fdiv.s fs5, fs5, ft3            # d(1/z)
    flw ft4, POLY_UZ(s4)
    flw ft5, POLY_UZ(s5)
    fsub.s fs6, ft5, ft4
    fdiv.s fs6, fs6, ft3            # d(u/z)
    flw ft4, POLY_VZ(s4)
    flw ft5, POLY_VZ(s5)
    fsub.s fs7, ft5, ft4
    fdiv.s fs7, fs7, ft3            # d(v/z)
    flw ft4, POLY_BR(s4)
    flw ft5, POLY_BR(s5)
    fsub.s fs8, ft5, ft4
    fdiv.s fs8, fs8, ft3            # d(brightness)
    fcvt.s.w ft4, s6
    fadd.s ft4, ft4, ft2
    fsub.s ft4, ft4, ft0            # from the left end to the centre
    flw fs1, POLY_IZ(s4)
    fmadd.s fs1, ft4, fs5, fs1      # 1/z
    flw fs2, POLY_UZ(s4)
    fmadd.s fs2, ft4, fs6, fs2      # u/z
    flw fs3, POLY_VZ(s4)
    fmadd.s fs3, ft4, fs7, fs3      # v/z
    flw fs4, POLY_BR(s4)
    fmadd.s fs4, ft4, fs8, fs4      # brightness
    la t0, k_one
    flw ft4, 0(t0)
    fdiv.s ft5, ft4, fs1            # z
    fmul.s ft6, fs2, ft5
    fmul.s ft7, fs3, ft5
    la t0, k_sixty_four_k
    flw fs9, 0(t0)
    fmul.s ft6, ft6, fs9
    fmul.s ft7, ft7, fs9
    fcvt.w.s s8, ft6, rdn           # u
    fcvt.w.s s9, ft7, rdn           # v
    la t0, k_depth_scale
    flw ft4, 0(t0)
    fmul.s ft5, fs1, ft4
    fcvt.w.s s2, ft5, rne
    fmul.s ft5, fs5, ft4
    fcvt.w.s s3, ft5, rne
    fmul.s ft5, fs4, fs9
    fcvt.w.s a3, ft5, rdn
    fmul.s ft5, fs8, fs9
    fcvt.w.s a4, ft5, rdn
    li t0, JAB_DISPLAY_PITCH
    mul t0, s1, t0
    slli t1, s6, 2
    add t0, t0, t1
    la t1, zbuf
    add t1, t1, t0                  # the depth
    li t2, JAB_DISPLAY_BASE
    add t0, t0, t2                  # the pixel
    sub s10, s7, s6                 # the pixels left
    fmul.s ft5, fs2, fs9
    fcvt.l.s s4, ft5, rne
    fmul.s ft5, fs6, fs9
    fcvt.l.s s6, ft5, rne
    fmul.s ft5, fs3, fs9
    fcvt.l.s s5, ft5, rne
    fmul.s ft5, fs7, fs9
    fcvt.l.s s7, ft5, rne
    la a1, texture
    li a6, 0x00ff00ff
    li a2, 0x0000ff00
30:
    li s11, BLOCK
    ble s10, s11, 31f
    j 32f
31:
    mv s11, s10
32:
    li a7, POLY_INTEGER
    and a7, s0, a7
    bnez a7, 35f
    fcvt.s.w ft4, s11
    fmadd.s fs10, ft4, fs5, fs1     # 1/z at the block's end
    fmadd.s ft5, ft4, fs6, fs2      # u/z there
    fmadd.s ft6, ft4, fs7, fs3      # v/z there
    la t3, k_one
    flw ft7, 0(t3)
    fdiv.s ft7, ft7, fs10           # z there
    fmul.s ft5, ft5, ft7
    fmul.s ft6, ft6, ft7
    fmul.s ft5, ft5, fs9
    fmul.s ft6, ft6, fs9
    fcvt.w.s t3, ft5, rdn           # u at the end
    fcvt.w.s t4, ft6, rdn           # v at the end
    j 36f
35:
    mul t3, s11, s3
    add t3, t3, s2                  # 1/z at the block's end, 6.26
    li t4, 1
    slli t4, t4, Z_SHIFT
    div t4, t4, t3                  # z there, 48.16
    mul t3, s11, s6
    add t3, t3, s4                  # u/z there, 48.16
    mul t3, t3, t4
    srai t3, t3, 16                 # u at the end, 16.16
    mul a5, s11, s7
    add a5, a5, s5                  # v/z there
    mul a5, a5, t4
    srai a5, a5, 16                 # v at the end
    mv t4, a5
36:
    sub t5, t3, s8
    div t5, t5, s11                 # du a pixel
    sub t6, t4, s9
    div t6, t6, s11                 # dv a pixel
    sd t3, 0(sp)
    sd t4, 8(sp)
    fsd fs10, 16(sp)
    fmv.s fa0, fs1                  # 1/z a pixel, float
    fmv.s fa1, fs5
    mv t2, s11
    li a7, POLY_LIT
    and a7, s0, a7
    bnez a7, 50f
    li a7, POLY_FIXED
    and a7, s0, a7
    bnez a7, 45f
40:
    srli a0, s9, 16
    andi a0, a0, TEX_MASK
    slli a0, a0, TEX_ROW_SHIFT
    srli a7, s8, 16
    andi a7, a7, TEX_MASK
    slli a7, a7, 2
    add a0, a0, a7
    add a0, a0, a1
    lw a0, 0(a0)
    flw ft0, 0(t1)
    flt.s a7, ft0, fa0
    beqz a7, 41f
    sw a0, 0(t0)
    fsw fa0, 0(t1)
41:
    fadd.s fa0, fa0, fa1
    add s8, s8, t5
    add s9, s9, t6
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 40b
    j 60f
45:
    srli a0, s9, 16
    andi a0, a0, TEX_MASK
    slli a0, a0, TEX_ROW_SHIFT
    srli a7, s8, 16
    andi a7, a7, TEX_MASK
    slli a7, a7, 2
    add a0, a0, a7
    add a0, a0, a1
    lw a0, 0(a0)
    lw a7, 0(t1)
    bgeu a7, s2, 46f
    sw a0, 0(t0)
    sw s2, 0(t1)
46:
    add s2, s2, s3
    add s8, s8, t5
    add s9, s9, t6
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 45b
    j 60f
50:
    srli a0, s9, 16
    andi a0, a0, TEX_MASK
    slli a0, a0, TEX_ROW_SHIFT
    srli a7, s8, 16
    andi a7, a7, TEX_MASK
    slli a7, a7, 2
    add a0, a0, a7
    add a0, a0, a1
    lw a0, 0(a0)
    srli a7, a3, 8
    and a5, a0, a6
    mul a5, a5, a7
    srli a5, a5, 8
    and a5, a5, a6
    and a0, a0, a2
    mul a0, a0, a7
    srli a0, a0, 8
    and a0, a0, a2
    or a0, a0, a5
    lw a7, 0(t1)
    bgeu a7, s2, 51f
    sw a0, 0(t0)
    sw s2, 0(t1)
51:
    add s2, s2, s3
    add s8, s8, t5
    add s9, s9, t6
    add a3, a3, a4
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 50b
60:
    ld s8, 0(sp)
    ld s9, 8(sp)
    fld fs1, 16(sp)
    fcvt.s.w ft4, s11
    fmadd.s fs2, ft4, fs6, fs2
    fmadd.s fs3, ft4, fs7, fs3
    mul t3, s11, s6
    add s4, s4, t3
    mul t3, s11, s7
    add s5, s5, t3
    sub s10, s10, s11
    bgtz s10, 30b
89:
    addi s1, s1, 1
    j 10b
90:
    ld ra, 200(sp)
    ld s0, 192(sp)
    ld s1, 184(sp)
    ld s2, 176(sp)
    ld s3, 168(sp)
    ld s4, 160(sp)
    ld s5, 152(sp)
    ld s6, 144(sp)
    ld s7, 136(sp)
    ld s8, 128(sp)
    ld s9, 120(sp)
    ld s10, 112(sp)
    ld s11, 104(sp)
    fld fs0, 96(sp)
    fld fs1, 88(sp)
    fld fs2, 80(sp)
    fld fs3, 72(sp)
    fld fs4, 64(sp)
    fld fs5, 56(sp)
    fld fs6, 48(sp)
    fld fs7, 40(sp)
    fld fs8, 32(sp)
    fld fs9, 24(sp)
    fld fs10, 16(sp)
    fld fs11, 8(sp)
    addi sp, sp, 208
    ret

.ifdef VECTOR
frame_vector:
    la t0, frames
    ld t0, 0(t0)
    li t1, 0x0f0f0f
    mul t0, t0, t1
    li t1, 0xffffff
    and t2, t0, t1
    li t0, JAB_DISPLAY_BASE
    li t3, PIXELS
    vsetvli t4, t3, e32, m8, ta, ma
    vmv.v.x v8, t2
1:
    vsetvli t4, t3, e32, m8, ta, ma
    vse32.v v8, (t0)
    slli t5, t4, 2
    add t0, t0, t5
    sub t3, t3, t4
    bnez t3, 1b
    ret
.endif

.section .bss
.balign 8
frames:
    .skip 8
elapsed:
    .skip 8
digits:
    .skip DIGITS_BYTES
line:
    .skip LINE_BYTES
.balign 4
texture:
    .skip TEX_SIDE * TEX_ROW_BYTES
cross:
    .skip (2 * POLY_VERTEX)
.balign 16
zbuf:
    .skip ZBUF_BYTES

.section .rodata
name_fill:
    .asciz "fill"
name_texture:
    .asciz "texture"
name_perspective:
    .asciz "perspective"
name_polygon:
    .asciz "polygon"
name_fixed:
    .asciz "fixed"
name_integer:
    .asciz "integer"
name_lit:
    .asciz "lit"
name_vector:
    .asciz "vector"
name_textureflip:
    .asciz "textureflip"
word_frames:
    .asciz " frames="
word_shown:
    .asciz " shown="
word_ticks:
    .asciz " ticks="
word_pixels:
    .asciz " pixels="
msg_no_display:
    .asciz "fillrate: no display\n"
.balign 4
poly:
    .float 0.0, -1620.0, 0.5, 0.0, 0.0, 1.0
    .float 1920.0, 0.0, 0.125, 96.0, 0.0, 0.25
    .float 1920.0, 1080.0, 0.125, 96.0, 72.0, 0.25
    .float 0.0, 2700.0, 0.5, 0.0, 288.0, 1.0
k_half:
    .float 0.5
k_one:
    .float 1.0
k_sixty_four_k:
    .float 65536.0
k_depth_scale:
    .float 67108864.0
