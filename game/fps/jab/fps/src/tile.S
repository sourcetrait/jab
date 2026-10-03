.section .text

tiles_reset:
    la t0, tile_cursor
    la t1, tile_arena
    sd t1, 0(t0)
    la t0, tilemaps
    li t1, (LUMAP_COUNT * TILE_SIZE)
    add t1, t1, t0
1:
    sd zero, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 1b
    ret

tiles_bind:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    la t0, poly
    ld t1, POLY_MODE(t0)
    andi t1, t1, POLY_LIT
    beqz t1, 9f
    ld s2, POLY_LUMAP(t0)
    beqz s2, 9f
    ld t1, LUMAP_BASE(s2)
    beqz t1, 9f
    la t1, lumaps
    sub t1, s2, t1
    li t2, LUMAP_SIZE
    divu t1, t1, t2
    li t2, TILE_SIZE
    mul t1, t1, t2
    la s3, tilemaps
    add s3, s3, t1
    ld t1, TILE_BASE(s3)
    bnez t1, 2f
    mv a0, s3
    mv a1, s2
    call tiles_alloc
2:
    ld t1, TILE_BASE(s3)
    bltz t1, 9f
3:
    ld t1, TILE_READY(s3)
    ld t2, TILE_LEVELS(s3)
    bgeu t1, t2, 5f
    la t0, tile_budget
    ld t2, 0(t0)
    ld t5, LUMAP_K(s2)
    beqz t1, 31f
    sub t5, t5, t1
    addi t5, t5, 1                  # the coarser cell's texels, four reads each
31:
    slli t5, t5, 1
    li t6, 1
    sll t6, t6, t5
    bltu t2, t6, 5f
    sub t2, t2, t6
    sd t2, 0(t0)
    ld a2, TILE_CURSOR(s3)
    mv a0, s3
    mv a1, s2
    mv a3, t1
    beqz t1, 32f
    call tile_shrink
    j 33f
32:
    call tile_build
33:
    la t0, stats
    ld t1, STAT_TILES_BUILT(t0)
    addi t1, t1, 1
    sd t1, STAT_TILES_BUILT(t0)
    ld t1, TILE_CURSOR(s3)
    addi t1, t1, 1
    ld t2, TILE_COLS_SHIFT(s3)
    li t3, 1
    sll t3, t3, t2
    addi t3, t3, -1                 # the column mask
    and t4, t1, t3
    ld t2, TILE_COLS(s3)
    bltu t4, t2, 35f
    or t1, t1, t3
    addi t1, t1, 1
35:
    ld t2, TILE_CELLS(s3)
    bltu t1, t2, 34f
    li t1, 0
    ld t2, TILE_READY(s3)
    addi t2, t2, 1
    sd t2, TILE_READY(s3)           # the level whole
34:
    sd t1, TILE_CURSOR(s3)
    j 3b
5:
    ld t1, TILE_READY(s3)
    beqz t1, 9f
    la t0, poly
    ld t2, POLY_MODE(t0)
    ori t2, t2, POLY_TILED
    sd t2, POLY_MODE(t0)
    sd t1, POLY_TILE_READY(t0)
    ld t1, TILE_COLS_SHIFT(s3)
    sd t1, POLY_TILE_COLS_SHIFT(t0)
    ld t1, TILE_COLS(s3)
    sd t1, POLY_TILE_COLS(t0)
    ld t1, TILE_ROWS(s3)
    sd t1, POLY_TILE_ROWS(t0)
    li t2, 0
52:
    li t3, TILE_LEVEL_COUNT
    bgeu t2, t3, 9f
    slli t3, t2, 3
    add t4, t3, s3
    add t5, t3, t0
    ld t1, TILE_BASE(t4)
    sd t1, POLY_TILES(t5)
    addi t2, t2, 1
    j 52b
9:
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

tiles_alloc:
    addi sp, sp, -16
    sd ra, 8(sp)
0:
    ld t1, LUMAP_W(a1)              # the cells across
    ld t2, LUMAP_H(a1)              # and down
    li t3, 0                        # the columns' shift
    li t4, 1
1:
    bgeu t4, t1, 2f
    slli t4, t4, 1
    addi t3, t3, 1
    j 1b
2:
    sll t5, t2, t3                  # the cells: the rows by the padded columns
    ld t6, LUMAP_K(a1)
    addi a4, t6, 1                  # the levels: k + 1 or TILE_LEVEL_COUNT
    li a5, TILE_LEVEL_COUNT
    bleu a4, a5, 21f
    mv a4, a5
21:
    slli t6, t6, 1
    addi t6, t6, 2                  # level 0's tile bytes as a shift
    sll t0, t5, t6                  # level 0's atlas bytes
    li a3, TILE_ATLAS_MAX
    bleu t0, a3, 22f
    li a3, -1
    sd a3, TILE_BASE(a0)
    j 9f
22:
    mv a6, t0
    li a3, 1
23:
    bgeu a3, a4, 24f
    slli a5, a3, 1
    srl a5, t0, a5
    add a6, a6, a5
    addi a3, a3, 1
    j 23b
24:
    la t4, tile_cursor
    ld t4, 0(t4)
    add t4, t4, a6
    la a5, tile_arena
    li a6, TILE_ARENA_BYTES
    add a5, a5, a6
    bleu t4, a5, 6f
    la t4, stats
    ld t5, STAT_TILE_RESETS(t4)
    addi t5, t5, 1
    sd t5, STAT_TILE_RESETS(t4)
    call tiles_reset
    j 0b
6:
    sd t3, TILE_COLS_SHIFT(a0)
    sd t1, TILE_COLS(a0)
    sd t2, TILE_ROWS(a0)
    sd t5, TILE_CELLS(a0)
    sd a4, TILE_LEVELS(a0)
    sd zero, TILE_READY(a0)
    sd zero, TILE_CURSOR(a0)
    la t6, tile_cursor
    ld t4, 0(t6)                    # the arena's cursor
    ld t2, LUMAP_K(a1)
    slli t2, t2, 1
    addi t2, t2, 2                  # the level's tile bytes as a shift
    li a2, 0                        # the level
62:
    bgeu a2, a4, 63f
    slli t1, a2, 3
    add t1, t1, a0
    sd t4, TILE_BASE(t1)
    sll t0, t5, t2
    add t4, t4, t0
    addi t2, t2, -2
    addi a2, a2, 1
    j 62b
63:
    sd t4, 0(t6)
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.balign CODE_PAGE
tile_build:
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
    mv s2, a0
    mv s3, a1
    ld t0, TILE_COLS_SHIFT(s2)
    srl s7, a2, t0                  # the cell's row
    li t1, 1
    sll t1, t1, t0
    addi t1, t1, -1
    and s6, a2, t1                  # and column
    ld s9, LUMAP_K(s3)              # k
    li s8, 1
    sll s8, s8, s9                  # the cell's texels a side
    ld t1, LUMAP_BASE(s3)
    ld t2, LUMAP_W(s3)
    slli t2, t2, 3                  # a row's bytes
    mul t3, s7, t2
    add t1, t1, t3
    slli t3, s6, 3
    add t1, t1, t3                  # the node above left
    ld t3, 0(t1)
    sd t3, 0(sp)
    ld t4, LUMAP_W(s3)
    addi t5, s6, 1
    bltu t5, t4, 1f
    li t5, 0
    j 2f
1:
    li t5, 8
2:
    add t6, t1, t5
    ld t3, 0(t6)
    sd t3, 8(sp)                    # above right
    ld t4, LUMAP_H(s3)
    addi t6, s7, 1
    bltu t6, t4, 3f
    li t2, 0
3:
    add t1, t1, t2
    ld t3, 0(t1)
    sd t3, 16(sp)                   # below left
    add t6, t1, t5
    ld t3, 0(t6)
    sd t3, 24(sp)                   # below right
    ld t1, TILE_BASE(s2)
    slli t4, s9, 1
    addi t4, t4, 2
    sll t3, a2, t4
    add s4, t1, t3                  # the tile's first row
    sll s11, s6, s9                 # the cell's first texel along u
    sll s6, s7, s9                  # and along v
    li s7, 0                        # the row
10:
    bgeu s7, s8, 90f
    slli t0, s7, 8
    srl t0, t0, s9                  # the fraction
    li t1, 256
    sub t1, t1, t0
    ld t4, 0(sp)
    mul t4, t4, t1
    ld t5, 16(sp)
    mul t5, t5, t0
    add t3, t4, t5                  # the start
    ld t4, 8(sp)
    mul t4, t4, t1
    ld t5, 24(sp)
    mul t5, t5, t0
    add t4, t4, t5                  # the end
    li a0, ((1 << CHANNEL_BITS) - 1)
    and a5, t3, a0
    and a6, t4, a0
    sub a6, a6, a5
    div s10, a6, s8
    srli a5, t3, CHANNEL_BITS
    and a5, a5, a0
    srli a6, t4, CHANNEL_BITS
    and a6, a6, a0
    sub a6, a6, a5
    div a6, a6, s8
    slli a6, a6, CHANNEL_BITS
    add s10, s10, a6
    srli a5, t3, (2 * CHANNEL_BITS)
    srli a6, t4, (2 * CHANNEL_BITS)
    sub a6, a6, a5
    div a6, a6, s8
    slli a6, a6, (2 * CHANNEL_BITS)
    add s10, s10, a6
    la t0, poly
    ld a1, POLY_TEX(t0)
    ld a2, POLY_VMASK(t0)
    ld a3, POLY_UMASK(t0)
    ld a4, POLY_WSHIFT(t0)
    add t5, s6, s7
    and t5, t5, a2
    sll t5, t5, a4
    add s5, a1, t5
    mv t2, s8                       # the texels left
    mv t6, s11                      # the texel along u
    mv t1, s4                       # the tile's texel
11:
    and a5, t6, a3
    slli a5, a5, 2
    add a5, a5, s5
    lw a0, 0(a5)
    slli a5, t3, (64 - 3 * CHANNEL_BITS)
    srli a5, a5, (64 - CHANNEL_BITS + 8)    # blue's brightness, 8.8
    andi a6, a0, 0xff
    mul a6, a6, a5
    srli a6, a6, 8
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
    sw a6, 0(t1)
    add t3, t3, s10
    addi t6, t6, 1
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 11b
    slli t0, s8, 2
    add s4, s4, t0
    addi s7, s7, 1
    j 10b
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
    addi sp, sp, 144
    ret

tile_shrink:
    addi sp, sp, -80
    sd ra, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    sd s7, 24(sp)
    sd s8, 16(sp)
    ld t0, LUMAP_K(a1)
    sub t0, t0, a3                  # the tile's texels a side at the level, as a shift
    li s4, 1
    sll s4, s4, t0                  # the texels a side
    slli t2, t0, 1
    addi t2, t2, 2
    slli t3, a3, 3
    add t3, t3, a0
    ld s2, TILE_BASE(t3)
    sll t5, a2, t2
    add s2, s2, t5                  # the tile
    ld s3, -8(t3)                   # the level below's atlas, TILE_BASE a level back
    addi t2, t2, 2
    sll t6, a2, t2
    add s3, s3, t6                  # its tile
    slli s5, s4, 3                  # the finer tile's row pitch in bytes, twice the texels
    la t0, poly
    lw t0, POLY_MATERIAL(t0)
    li t1, ALPHA_MATERIAL_SIZE
    mul t0, t0, t1
    la t1, material_alpha
    add t0, t0, t1
    slli t1, a3, 2
    add t0, t0, t1
    lwu s6, 0(t0)
    li s7, 0                        # the row
1:
    bgeu s7, s4, 9f
    li s8, 0                        # the texel along the row
2:
    bgeu s8, s4, 3f
    slli a6, s8, 3
    add a6, a6, s3                  # the finer texel above left
    lwu a0, 0(a6)
    lwu a7, 4(a6)
    add a6, a6, s5
    lwu t2, 0(a6)
    lwu t3, 4(a6)
    texel_shrink
    slli a6, s8, 2
    add a6, a6, s2
    sw a2, 0(a6)
    addi s8, s8, 1
    j 2b
3:
    slli a6, s4, 2
    add s2, s2, a6                  # the tile's next row
    add s3, s3, s5
    add s3, s3, s5                  # the finer tile's, two rows on
    addi s7, s7, 1
    j 1b
9:
    ld ra, 72(sp)
    ld s2, 64(sp)
    ld s3, 56(sp)
    ld s4, 48(sp)
    ld s5, 40(sp)
    ld s6, 32(sp)
    ld s7, 24(sp)
    ld s8, 16(sp)
    addi sp, sp, 80
    ret

alphas_measure:
    addi sp, sp, -128
    sd ra, 120(sp)
    sd s2, 112(sp)
    sd s3, 104(sp)
    sd s4, 96(sp)
    sd s5, 88(sp)
    sd s6, 80(sp)
    sd s7, 72(sp)
    sd s8, 64(sp)
    sd s9, 56(sp)
    sd s10, 48(sp)
    sd s11, 40(sp)
    la t0, material_alpha
    li t1, (MAX_MATERIALS * ALPHA_MATERIAL_SIZE)
    add t1, t1, t0
    li t2, ALPHA_SCALE_ONE
1:
    sw t2, 0(t0)
    addi t0, t0, ALPHA_LEVEL_SIZE
    bltu t0, t1, 1b
    la t0, frame_base
    lwu s2, 0(t0)
    addi s2, s2, FRAME_COUNT        # every record: the map's materials and the engine's images
    li s3, 0                        # the material
2:
    bgeu s3, s2, 90f
    li t1, ALPHA_MATERIAL_SIZE
    mul t0, s3, t1
    la t1, material_alpha
    add s4, t0, t1                  # its scales
    la t0, material_record
    slli t1, s3, 3
    add t0, t0, t1
    ld s5, 0(t0)                    # its texture
    beqz s5, 8f
    lwu s6, JAB_SPRITE_WIDTH(s5)
    lwu s7, JAB_SPRITE_HEIGHT(s5)
    li t0, 8
    bltu s6, t0, 8f
    bltu s7, t0, 8f
    mv a0, s6
    mv a1, s7
    call mip_levels
    la t0, alpha_chain_levels
    sd a0, 0(t0)                    # the chain's levels, the scales to find
    mul s8, s6, s7                  # the texels
    srli t0, s8, 2
    li t1, ALPHA_PLANE_BYTES
    bgtu t0, t1, 8f
    call alpha_hist_clear
    addi t0, s5, (JAB_SPRITE_PIXELS + 3)
    mv t1, s8
    la t2, alpha_hist
3:
    lbu t3, 0(t0)
    slli t3, t3, 3
    add t3, t3, t2
    ld t4, 0(t3)
    addi t4, t4, 1
    sd t4, 0(t3)
    addi t0, t0, 4
    addi t1, t1, -1
    bnez t1, 3b
    call alpha_hist_pass
    mv s9, a0                       # the target count
    la t0, alpha_cover
    li t1, ALPHA_SHARE
    mul t2, s9, t1
    divu t2, t2, s8
    sd t2, 0(t0)
    sd zero, 8(t0)
    sd zero, 16(t0)
    sd zero, 24(t0)
    beq s9, s8, 8f                  # full at every level: one, no line
    beqz s9, 7f                     # empty at every level: one
    addi s10, s5, (JAB_SPRITE_PIXELS + 3)
    li s11, 4
    sd s6, 0(sp)                    # the level's width
    sd s7, 8(sp)                    # and height
    li t0, 1
    sd t0, 16(sp)                   # the level
4:
    ld t0, 16(sp)
    la t1, alpha_chain_levels
    ld t1, 0(t1)
    bgeu t0, t1, 7f
    ld a0, 0(sp)
    srli a0, a0, 1
    sd a0, 0(sp)
    ld a1, 8(sp)
    srli a1, a1, 1
    sd a1, 8(sp)
    la a2, alpha_plane_a
    andi t1, t0, 1
    bnez t1, 41f
    la a2, alpha_plane_b
41:
    sd a2, 24(sp)                   # the level's plane
    call alpha_shrink
    ld a0, 0(sp)
    ld a1, 8(sp)
    mul a0, a0, a1                  # the level's texels
    sd a0, 32(sp)
    call alpha_search
    li t0, ALPHA_SCALE_TOP
    add t0, t0, a0
    addi t0, t0, -1
    divu t0, t0, a0
    ld t1, 16(sp)
    slli t2, t1, 2
    add t2, t2, s4
    sw t0, 0(t2)
    li t2, ALPHA_SHARE
    mul a1, a1, t2
    ld t2, 32(sp)
    divu a1, a1, t2
    la t3, alpha_cover
    slli t4, t1, 3
    add t3, t3, t4
    sd a1, 0(t3)
    ld t1, 24(sp)
    ld t2, 32(sp)
    add t2, t2, t1                  # past the plane's last
    li t3, 255
5:
    lbu t4, 0(t1)
    mul t4, t4, t0
    srli t4, t4, ALPHA_SCALE_BITS
    bleu t4, t3, 51f
    mv t4, t3
51:
    sb t4, 0(t1)
    addi t1, t1, 1
    bltu t1, t2, 5b
    ld s10, 24(sp)
    li s11, 1
    ld t0, 16(sp)
    addi t0, t0, 1
    sd t0, 16(sp)
    j 4b
7:
.ifdef DEBUG
    la a0, line
    la a1, msg_alpha
    call append_str
    sd a0, 32(sp)
    section_count KIND_MATERIALS, t0
    bgeu s3, t0, 71f
    mv a0, s3
    call material_at
    lwu a0, MATERIAL_NAME(a0)
    call name_at
    mv a1, a0
    ld a0, 32(sp)
    call append_str
    j 72f
71:
    ld a0, 32(sp)
    la a1, word_frame_name
    call append_str
    la t0, frame_base
    lwu a1, 0(t0)
    sub a1, s3, a1
    call append_dec
72:
    la a1, word_coverage
    call append_str
    la t0, alpha_cover
    ld a1, 0(t0)
    call append_dec
    la a1, word_space
    call append_str
    la t0, alpha_cover
    ld a1, 8(t0)
    call append_dec
    la a1, word_space
    call append_str
    la t0, alpha_cover
    ld a1, 16(t0)
    call append_dec
    la a1, word_space
    call append_str
    la t0, alpha_cover
    ld a1, 24(t0)
    call append_dec
    la a1, word_of_share
    call append_str
    lwu a1, 4(s4)
    call append_dec
    la a1, word_space
    call append_str
    lwu a1, 8(s4)
    call append_dec
    la a1, word_space
    call append_str
    lwu a1, 12(s4)
    call append_dec
    la a1, word_of_scale
    call append_str
    call line_end
.endif
8:
    addi s3, s3, 1
    j 2b
90:
    ld ra, 120(sp)
    ld s2, 112(sp)
    ld s3, 104(sp)
    ld s4, 96(sp)
    ld s5, 88(sp)
    ld s6, 80(sp)
    ld s7, 72(sp)
    ld s8, 64(sp)
    ld s9, 56(sp)
    ld s10, 48(sp)
    ld s11, 40(sp)
    addi sp, sp, 128
    ret

alpha_hist_clear:
    la t0, alpha_hist
    li t1, 256
1:
    sd zero, 0(t0)
    addi t0, t0, 8
    addi t1, t1, -1
    bnez t1, 1b
    ret

alpha_hist_pass:
    la t0, alpha_hist
    addi t0, t0, (ALPHA_PASS * 8)
    li t1, (256 - ALPHA_PASS)
    li a0, 0
1:
    ld t2, 0(t0)
    add a0, a0, t2
    addi t0, t0, 8
    addi t1, t1, -1
    bnez t1, 1b
    ret

alpha_shrink:
    la t1, alpha_hist
    li t2, 256
1:
    sd zero, 0(t1)
    addi t1, t1, 8
    addi t2, t2, -1
    bnez t2, 1b
    la t1, alpha_hist
    slli t0, a0, 1
    mul t0, t0, s11                 # the source's row bytes
    li t2, 0                        # the row
    mv t3, a2                       # the plane's cursor
    mv t4, s10                      # the source's row
2:
    bgeu t2, a1, 9f
    li t5, 0                        # the column
    mv t6, t4                       # the source's texel
3:
    bgeu t5, a0, 4f
    lbu a3, 0(t6)
    add a4, t6, s11
    lbu a4, 0(a4)
    add a3, a3, a4
    add a4, t6, t0
    lbu a5, 0(a4)
    add a3, a3, a5
    add a4, a4, s11
    lbu a4, 0(a4)
    add a3, a3, a4
    srli a3, a3, 2                  # the mean
    sb a3, 0(t3)
    slli a3, a3, 3
    add a3, a3, t1
    ld a4, 0(a3)
    addi a4, a4, 1
    sd a4, 0(a3)
    addi t3, t3, 1
    add t6, t6, s11
    add t6, t6, s11
    addi t5, t5, 1
    j 3b
4:
    add t4, t4, t0
    add t4, t4, t0
    addi t2, t2, 1
    j 2b
9:
    ret

alpha_search:
    la t0, alpha_hist
    li t1, 256                      # the threshold
    li t2, 0                        # the count at or above it
    li a2, -1                       # the best error, none yet
    li a3, 0                        # its threshold
    li a4, 0                        # its count
    li a5, 0                        # its distance from the pass
1:
    beqz t1, 9f
    li t3, 255
    bgtu t1, t3, 2f
    slli t3, t1, 3
    add t3, t3, t0
    ld t3, 0(t3)
    add t2, t2, t3
2:
    mul t4, t2, s8                  # the share, over the texture's texels
    mul t5, s9, a0                  # the target, over the level's
    sub t4, t4, t5
    bgez t4, 3f
    neg t4, t4                      # the error
3:
    addi t5, t1, -ALPHA_PASS
    bgez t5, 4f
    neg t5, t5                      # the distance from the pass
4:
    bltz a2, 5f                     # the first
    bltu t4, a2, 5f                 # a smaller error
    bne t4, a2, 6f
    bne t2, a4, 6f                  # the same error at a greater share: the lower stands
    bgeu t5, a5, 6f                 # the same share: the threshold nearer the pass
5:
    mv a2, t4
    mv a3, t1
    mv a4, t2
    mv a5, t5
6:
    addi t1, t1, -1
    j 1b
9:
    mv a0, a3
    mv a1, a4
    ret

lumels_bright:
    li t2, 256
    slli t3, t2, CHANNEL_BITS
    or t2, t2, t3
    slli t3, t3, CHANNEL_BITS
    or t2, t2, t3                   # the three lanes at one
    la t0, lumaps
    li t1, (LUMAP_COUNT * LUMAP_SIZE)
    add t1, t1, t0
1:
    bgeu t0, t1, 9f
    ld t3, LUMAP_BASE(t0)
    beqz t3, 2f
    ld t4, LUMAP_W(t0)
    ld t5, LUMAP_H(t0)
    mul t4, t4, t5
    slli t4, t4, 3
    add t4, t4, t3                  # past the map's last node
3:
    sd t2, 0(t3)
    addi t3, t3, 8
    bltu t3, t4, 3b
2:
    addi t0, t0, LUMAP_SIZE
    j 1b
9:
    ret

.section .rodata
.ifdef DEBUG
msg_alpha:
    .asciz "fps: alpha "
word_frame_name:
    .asciz "frame "
word_coverage:
    .asciz ": coverage "
word_of_share:
    .asciz " of 10000, scale "
word_of_scale:
    .asciz " of 65536"
.endif

.section .bss
.balign 8
tile_cursor:
    .skip 8
tile_budget:
    .skip 8
tile_budget_frame:
    .skip 8
tilemaps:
    .skip (LUMAP_COUNT * TILE_SIZE)
material_alpha:
    .skip (MAX_MATERIALS * ALPHA_MATERIAL_SIZE)
alpha_hist:
    .skip (256 * 8)
alpha_cover:
    .skip (MIP_LEVELS * 8)
alpha_chain_levels:
    .skip 8
alpha_plane_a:
    .skip ALPHA_PLANE_BYTES
alpha_plane_b:
    .skip ALPHA_PLANE_BYTES
.balign 64
tile_arena:
    .skip TILE_ARENA_BYTES
