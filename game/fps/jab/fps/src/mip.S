# The texture's mip chain: each material's coarser levels built at load from
# the level before by the tile shrink's rule under the level's alpha scale,
# so a span reads the level a block's footprint asks for, and a tile at a
# level and the lit loop at the same level draw the same texel

.section .rodata
.ifdef DEBUG
msg_mips:
    .asciz "fps: mips "
word_chains:
    .asciz " chains, "
word_levels:
    .asciz " levels, "
word_texels_in:
    .asciz " texels in "
word_ms_end:
    .asciz " ms"
.endif

.section .text

# A coarser texel from the two by two under it: alike alphas take the plain
# mean a channel and the alpha as it is; unalike, each channel's mean
# weighted by the alphas, so a transparent texel's colour counts for
# nothing, by one reciprocal of their sum, each product rounded to the
# nearest so an exact mean survives, the alpha their mean; the alpha then
# scaled by the level's factor and capped at 255
# a0 u32 The texel above left
# a7 u32 The texel above right
# t2 u32 The texel below left
# t3 u32 The texel below right
# s6 int The level's alpha scale, 16.16
# returns Clobbers t0, t4 to t6, a1, a3 to a5
#   a2 The texel
.macro texel_shrink
    srli t4, a0, 24                 # the four alphas
    srli t5, a7, 24
    srli t6, t2, 24
    srli a3, t3, 24
    add a1, t4, t5
    add a1, a1, t6
    add a1, a1, a3                  # their sum
    bne t4, t5, .Lshrink_unalike\@
    bne t4, t6, .Lshrink_unalike\@
    bne t4, a3, .Lshrink_unalike\@
    # alike: the plain mean a channel, the alpha theirs
    andi a2, a0, 0xff
    andi a4, a7, 0xff
    add a2, a2, a4
    andi a4, t2, 0xff
    add a2, a2, a4
    andi a4, t3, 0xff
    add a2, a2, a4
    srli a2, a2, 2                  # blue
    srli a4, a0, 8
    andi a4, a4, 0xff
    srli t0, a7, 8
    andi t0, t0, 0xff
    add a4, a4, t0
    srli t0, t2, 8
    andi t0, t0, 0xff
    add a4, a4, t0
    srli t0, t3, 8
    andi t0, t0, 0xff
    add a4, a4, t0
    srli a4, a4, 2
    slli a4, a4, 8
    or a2, a2, a4                   # green
    srli a4, a0, 16
    andi a4, a4, 0xff
    srli t0, a7, 16
    andi t0, t0, 0xff
    add a4, a4, t0
    srli t0, t2, 16
    andi t0, t0, 0xff
    add a4, a4, t0
    srli t0, t3, 16
    andi t0, t0, 0xff
    add a4, a4, t0
    srli a4, a4, 2
    slli a4, a4, 16
    or a2, a2, a4                   # red
    mv a5, t4                       # the alpha
    j .Lshrink_scale\@
.Lshrink_unalike\@:
    # unalike: each channel's mean weighted by the alphas, so a
    # transparent texel's colour counts for nothing, by one reciprocal
    # of their sum, each product rounded to the nearest so an exact
    # mean survives; the alpha their mean
    li t0, (1 << 24)
    divu t0, t0, a1                 # the reciprocal of the sum, 8.24
    andi a2, a0, 0xff
    mul a2, a2, t4
    andi a4, a7, 0xff
    mul a4, a4, t5
    add a2, a2, a4
    andi a4, t2, 0xff
    mul a4, a4, t6
    add a2, a2, a4
    andi a4, t3, 0xff
    mul a4, a4, a3
    add a2, a2, a4
    mul a2, a2, t0
    li a4, (1 << 23)
    add a2, a2, a4
    srli a2, a2, 24                 # blue
    srli a4, a0, 8
    andi a4, a4, 0xff
    mul a4, a4, t4
    srli a5, a7, 8
    andi a5, a5, 0xff
    mul a5, a5, t5
    add a4, a4, a5
    srli a5, t2, 8
    andi a5, a5, 0xff
    mul a5, a5, t6
    add a4, a4, a5
    srli a5, t3, 8
    andi a5, a5, 0xff
    mul a5, a5, a3
    add a4, a4, a5
    mul a4, a4, t0
    li a5, (1 << 23)
    add a4, a4, a5
    srli a4, a4, 24
    slli a4, a4, 8
    or a2, a2, a4                   # green
    srli a4, a0, 16
    andi a4, a4, 0xff
    mul a4, a4, t4
    srli a5, a7, 16
    andi a5, a5, 0xff
    mul a5, a5, t5
    add a4, a4, a5
    srli a5, t2, 16
    andi a5, a5, 0xff
    mul a5, a5, t6
    add a4, a4, a5
    srli a5, t3, 16
    andi a5, a5, 0xff
    mul a5, a5, a3
    add a4, a4, a5
    mul a4, a4, t0
    li a5, (1 << 23)
    add a4, a4, a5
    srli a4, a4, 24
    slli a4, a4, 16
    or a2, a2, a4                   # red
    srli a5, a1, 2                  # the alpha, the mean
.Lshrink_scale\@:
    # the alpha scaled by the level's factor, capped
    mul a5, a5, s6
    srli a5, a5, ALPHA_SCALE_BITS
    li a4, 255
    bleu a5, a4, .Lshrink_capped\@
    mv a5, a4
.Lshrink_capped\@:
    slli a5, a5, 24
    or a2, a2, a5
.endm

# The levels a texture's chain has: one, and one more for every halving
# while both sides stay two texels or more, MIP_LEVELS at most
# a0 int The width
# a1 int The height
# returns Clobbers t0, t1, a1
#   a0 The levels
mip_levels:
    li t0, 1
1:
    li t1, MIP_LEVELS
    bgeu t0, t1, 9f
    li t1, 2
    bltu a0, t1, 9f
    bltu a1, t1, 9f
    srli a0, a0, 1
    srli a1, a1, 1
    addi t0, t0, 1
    j 1b
9:
    mv a0, t0
    ret

# Every material's chain built, the map's and the engine's images': level
# 0 the record's own texels, each coarser level half a side from the one
# before by texel_shrink under the level's alpha scale, into the arena
# while both sides stay two texels or more and the arena holds it; the
# levels a material has into material_mip_count, one for the texture
# alone; a line on the UART of a debug build
mips_build:
    addi sp, sp, -160
    sd ra, 152(sp)
    sd s2, 144(sp)
    sd s3, 136(sp)
    sd s4, 128(sp)
    sd s5, 120(sp)
    sd s6, 112(sp)
    sd s7, 104(sp)
    sd s8, 96(sp)
    sd s9, 88(sp)
    sd s10, 80(sp)
    sd s11, 72(sp)
    rdtime s10
    la t0, mip_cursor
    la t1, mip_arena
    sd t1, 0(t0)
    sd zero, 40(sp)                 # the chains, materials with a level past 0
    sd zero, 48(sp)                 # the levels built
    sd zero, 56(sp)                 # the texels built
    la t0, frame_base
    lwu s2, 0(t0)
    addi s2, s2, FRAME_COUNT        # every record: the map's materials and the engine's images
    li s3, 0                        # the material
1:
    bgeu s3, s2, 90f
    la t0, material_mips
    li t1, MIP_ENTRY
    mul t1, s3, t1
    add s4, t0, t1                  # its table
    la t0, material_mip_count
    slli t1, s3, 3
    add s5, t0, t1                  # its count
    li t0, 1
    sd t0, 0(s5)                    # the texture alone until a level is built
    la t0, material_record
    slli t1, s3, 3
    add t0, t0, t1
    ld t0, 0(t0)
    sd zero, 0(s4)
    beqz t0, 8f
    addi t1, t0, JAB_SPRITE_PIXELS
    sd t1, 0(s4)                    # level 0, the texture's own
    lwu t2, JAB_SPRITE_WIDTH(t0)
    sd t2, 0(sp)                    # the level in hand's width
    lwu t2, JAB_SPRITE_HEIGHT(t0)
    sd t2, 8(sp)                    # and height
    sd t1, 16(sp)                   # its texels
    li t2, 1
    sd t2, 24(sp)                   # the level to build
2:
    ld t2, 24(sp)
    li t3, MIP_LEVELS
    bgeu t2, t3, 7f
    ld a0, 0(sp)
    ld a1, 8(sp)
    li t3, 2
    bltu a0, t3, 7f
    bltu a1, t3, 7f
    srli a0, a0, 1                  # the level's width
    srli a1, a1, 1                  # and height
    mul t4, a0, a1                  # its texels
    slli t5, t4, 2                  # its bytes
    la t0, mip_cursor
    ld t6, 0(t0)
    add t3, t6, t5
    la a2, mip_arena
    li a3, MIP_ARENA_BYTES
    add a2, a2, a3
    bgtu t3, a2, 7f                 # the arena full: the chain ends here
    sd t3, 0(t0)
    slli t3, t2, 3
    add t3, t3, s4
    sd t6, 0(t3)                    # the level's texels
    mv s7, t6                       # the texel written
    ld s8, 16(sp)                   # the finer level's row in hand
    mv s9, a0                       # the level's texels a row
    slli s11, a0, 3                 # the finer level's row in bytes
    sd a0, 0(sp)
    sd a1, 8(sp)
    sd a1, 64(sp)                   # the rows left
    sd t4, 32(sp)                   # the level's texels, for the count
    # the level's alpha scale
    la t0, material_alpha
    li t3, ALPHA_MATERIAL_SIZE
    mul t3, s3, t3
    add t0, t0, t3
    slli t3, t2, 2
    add t0, t0, t3
    lwu s6, 0(t0)
3:
    ld t1, 64(sp)
    beqz t1, 6f
    mv t1, s9                       # the texels left in the row
    mv a6, s8                       # the finer texel above left
4:
    beqz t1, 5f
    lwu a0, 0(a6)
    lwu a7, 4(a6)
    add t2, a6, s11
    lwu t3, 4(t2)
    lwu t2, 0(t2)
    texel_shrink
    sw a2, 0(s7)
    addi s7, s7, 4
    addi a6, a6, 8
    addi t1, t1, -1
    j 4b
5:
    slli t0, s11, 1
    add s8, s8, t0                  # two finer rows on
    ld t1, 64(sp)
    addi t1, t1, -1
    sd t1, 64(sp)
    j 3b
6:
    # the level built: counted, and the next builds from it
    ld t0, 48(sp)
    addi t0, t0, 1
    sd t0, 48(sp)
    ld t0, 56(sp)
    ld t1, 32(sp)
    add t0, t0, t1
    sd t0, 56(sp)
    ld t2, 24(sp)
    slli t3, t2, 3
    add t3, t3, s4
    ld t3, 0(t3)
    sd t3, 16(sp)                   # the level's texels, the next's source
    addi t2, t2, 1
    sd t2, 24(sp)
    j 2b
7:
    # the chain ends: the count is the level in hand
    ld t2, 24(sp)
    sd t2, 0(s5)
    li t3, 1
    bleu t2, t3, 8f
    ld t0, 40(sp)
    addi t0, t0, 1
    sd t0, 40(sp)
8:
    addi s3, s3, 1
    j 1b
90:
.ifdef DEBUG
    rdtime t0
    sub t0, t0, s10
    li t1, MS_TICKS
    divu s10, t0, t1
    la a0, line
    la a1, msg_mips
    call append_str
    ld a1, 40(sp)
    call append_dec
    la a1, word_chains
    call append_str
    ld a1, 48(sp)
    call append_dec
    la a1, word_levels
    call append_str
    ld a1, 56(sp)
    call append_dec
    la a1, word_texels_in
    call append_str
    mv a1, s10
    call append_dec
    la a1, word_ms_end
    call append_str
    call line_end
.endif
    ld ra, 152(sp)
    ld s2, 144(sp)
    ld s3, 136(sp)
    ld s4, 128(sp)
    ld s5, 120(sp)
    ld s6, 112(sp)
    ld s7, 104(sp)
    ld s8, 96(sp)
    ld s9, 88(sp)
    ld s10, 80(sp)
    ld s11, 72(sp)
    addi sp, sp, 160
    ret

.section .bss
.balign 8
# Each material's chain: the texels of every level eight bytes a level,
# level 0 the record's own; the levels it has; the arena's next free byte
material_mips:
    .skip (MAX_MATERIALS * MIP_ENTRY)
material_mip_count:
    .skip (MAX_MATERIALS * 8)
mip_cursor:
    .skip 8
.balign 64
mip_arena:
    .skip MIP_ARENA_BYTES
