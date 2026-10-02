# The lit texture cached a surface at a time, in levels: a surface's
# atlas a level, a tile one lumel cell at the texture's resolution at
# level 0 and half a side each level after, each level 0 texel the
# texture's times the lumel brightness bilinear across the cell and each
# coarser texel the average of four below it; a surface is built whole, a
# level at a time from the finest, under a budget a frame, and a lit span
# reads the levels built whole in place of the texture and the map; the
# arena reset whole when an atlas does not fit

.section .text

# Every surface's tiles forgotten and the arena emptied: at load, and when
# an atlas does not fit
# returns Clobbers t0, t1
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

# The lit, mapped polygon in hand bound to its tiles: the atlases reserved
# on first sight, the surface's next cells built at the level in hand
# under the frame's budget, and the mode's tiled flag and the read's
# fields set once a level is whole; a surface whose atlas is too large
# stays on the lit loop
# returns Clobbers t0 to t6, a0 to a7
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
    # the record at the map's index
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
    # the next cells at the level in hand while the budget holds: a
    # level 0 cell costs its square of the texture's texels, a coarser
    # one four reads a texel of its own; a level whole moves the hand to
    # the next, and a cell the budget cannot hold whole waits
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

# A surface's atlases, one a level, reserved from the arena: the cells
# across and down are the map's nodes, the columns padded to a power of
# two so a cell row is a shift, the rows as they are; the levels are
# TILE_LEVEL_COUNT or k + 1, the fewer, each atlas a quarter of the one
# before; a level 0 atlas past TILE_ATLAS_MAX marks the record never;
# atlases the arena cannot hold reset it first
# a0 address The record
# a1 address The map
# returns Clobbers t0 to t6, a2 to a6
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
    # the atlases' bytes over the levels, each a quarter of the last
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
    # the arena full: emptied, every surface forgotten, and this one
    # reserved at its start; counted for the frame line
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
    # each level's atlas from the arena's cursor
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

# One cell of the surface in hand built into its level 0 tile: the
# brightness at each texel bilinear across the cell from its four nodes,
# the far nodes the greatest where the cell is the last, stepped along a
# row by each lane's change over the cell's texels; the texture's texel
# there scaled by it, each channel as the lit loop scales one, into the
# tile
# a0 address The record
# a1 address The map
# a2 int The cell's tile index, its column in the low TILE_COLS_SHIFT bits
# returns Clobbers t0 to t6, a0 to a7
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
    # the four nodes, the far ones the greatest at the map's end
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
    # the tile by its index, and the cell's first texel
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
    # the brightness at the row's start and end, the nodes weighted by
    # the row's fraction in 256ths, the lanes whole
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
    # the step a texel: each lane's change over the cell's texels,
    # toward zero so no lane runs past its end, packed again
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
    # the texture's row
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

# One cell of the surface in hand built into its tile at a coarser level
# from the level below: each texel the average, a channel at a time, of
# the two by two texels under it, the alpha the first's
# a0 address The record
# a1 address The map
# a2 int The cell's tile index
# a3 int The level, 1 or more
# returns Clobbers t0 to t6, a0 to a7
tile_shrink:
    ld t0, LUMAP_K(a1)
    sub t0, t0, a3                  # the tile's texels a side at the level, as a shift
    li t1, 1
    sll t1, t1, t0                  # the texels a side
    slli t2, t0, 1
    addi t2, t2, 2
    slli t3, a3, 3
    add t3, t3, a0
    ld t4, TILE_BASE(t3)
    sll t5, a2, t2
    add t4, t4, t5                  # the tile
    ld t5, -8(t3)                   # the level below's atlas, TILE_BASE a level back
    addi t2, t2, 2
    sll t6, a2, t2
    add t5, t5, t6                  # its tile
    slli t6, t1, 3                  # the finer tile's row pitch in bytes, twice the texels
    li a4, 0                        # the row
1:
    bgeu a4, t1, 9f
    li a5, 0                        # the texel along the row
2:
    bgeu a5, t1, 3f
    slli a6, a5, 3
    add a6, a6, t5                  # the finer texel above left
    lw a0, 0(a6)
    lw a7, 4(a6)
    add a6, a6, t6
    lw t2, 0(a6)
    lw t3, 4(a6)
    # each channel's sum of the four, averaged
    andi a2, a0, 0xff
    andi a3, a7, 0xff
    add a2, a2, a3
    andi a3, t2, 0xff
    add a2, a2, a3
    andi a3, t3, 0xff
    add a2, a2, a3
    srli a2, a2, 2                  # blue
    srli a3, a0, 8
    andi a3, a3, 0xff
    srli t0, a7, 8
    andi t0, t0, 0xff
    add a3, a3, t0
    srli t0, t2, 8
    andi t0, t0, 0xff
    add a3, a3, t0
    srli t0, t3, 8
    andi t0, t0, 0xff
    add a3, a3, t0
    srli a3, a3, 2
    slli a3, a3, 8
    or a2, a2, a3                   # green
    srli a3, a0, 16
    andi a3, a3, 0xff
    srli t0, a7, 16
    andi t0, t0, 0xff
    add a3, a3, t0
    srli t0, t2, 16
    andi t0, t0, 0xff
    add a3, a3, t0
    srli t0, t3, 16
    andi t0, t0, 0xff
    add a3, a3, t0
    srli a3, a3, 2
    slli a3, a3, 16
    or a2, a2, a3                   # red
    srli a3, a0, 24
    slli a3, a3, 24
    or a2, a2, a3                   # the alpha kept
    slli a6, a5, 2
    add a6, a6, t4
    sw a2, 0(a6)
    addi a5, a5, 1
    j 2b
3:
    slli a6, t1, 2
    add t4, t4, a6                  # the tile's next row
    add t5, t5, t6
    add t5, t5, t6                  # the finer tile's, two rows on
    addi a4, a4, 1
    j 1b
9:
    ret

# Every lumel of every map set to the full brightness, one on each lane
# in a lumel's 256ths, for a debug build's console: a capture then reads
# the texture sampled as the lit one samples it, and the lit over it is
# the light alone
# returns Clobbers t0 to t5
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

.section .bss
.balign 8
# The arena's next free byte; the frame's budget left, in texels, and
# the budget a frame starts with, TILE_BUDGET until the console lifts it
tile_cursor:
    .skip 8
tile_budget:
    .skip 8
tile_budget_frame:
    .skip 8
# Every surface's tiles, at the map's index
tilemaps:
    .skip (LUMAP_COUNT * TILE_SIZE)
.balign 64
tile_arena:
    .skip TILE_ARENA_BYTES
