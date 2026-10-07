.ifdef CENSUS
.set CENSUS_SIZES, 3
.set CENSUS_SIDE_SHIFT, 5
.set CENSUS_WINDOW, 120
.set CENSUS_SHORT, 30
.set CENSUS_ENTRIES, (8 * 1024 * 1024)
.set CENSUS_SAMPLED_SHIFT, 24
.set CENSUS_CONTEXT_SHIFT, 48
.set CENSUS_CLASS_SHIFT, 51
.set CENSUS_KNOWN_BIT, 54
.set CENSUS_UNIFORM_BIT, 55
.set CENSUS_PLANE, 0
.set CENSUS_WALL, 1
.set CENSUS_OPENING, 2
.set CENSUS_LINE_BYTES, 16384
.set CS_LEVELS, 0
.set CS_K, 1
.set CS_W, 4
.set CS_H, 8
.set CS_LUMELS, 16
.set CS_GRIDS, 24
.set CS_GRID_BASE, 0
.set CS_GRID_W, 4
.set CS_GRID_H, 8
.set CS_GRID_SIZE, 12
.set CS_SIZE, 384
.set CT_ELIGIBLE, 0
.set CT_ELIGIBLE_PIXELS, 8
.set CT_STRADDLING, 16
.set CT_STRADDLING_PIXELS, 24
.set CT_OUTSIDE, 32
.set CT_DEMAND, 40
.set CT_CLASSES, 48
.set CT_SAMPLED, 72
.set CT_UNIFORM, 80
.set CT_SURFACES, 88
.set CT_REQUESTS, 96
.set CT_DISTINCT, (CT_REQUESTS + CENSUS_CONTEXTS * 8)
.set CT_LISTED, (CT_DISTINCT + CENSUS_CONTEXTS * 8)
.set CT_SIZE, (CT_LISTED + CENSUS_CONTEXTS * 8)

.if (CS_GRIDS + CENSUS_SIZES * MIP_LEVELS * CS_GRID_SIZE) > CS_SIZE
.error "a surface's census record holds a grid a size and a level"
.endif
.if CENSUS_CONTEXTS > 3
.error "an entry holds three contexts' bits"
.endif

.section .text

census_init:
    addi sp, sp, -96
    sd ra, 88(sp)
    sd s0, 80(sp)
    sd s1, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    sd s7, 24(sp)
    sd s8, 16(sp)
    li s0, 0                        # the surface
    li s1, 0                        # the directory's entries so far
1:
    li t0, LUMAP_COUNT
    bgeu s0, t0, 30f
    li t0, LUMAP_SIZE
    mul t0, s0, t0
    la t1, lumaps
    add s2, t0, t1                  # its lumel map
    li t0, CS_SIZE
    mul t0, s0, t0
    la t1, census_surfaces
    add s3, t0, t1                  # its census record
    ld t0, LUMAP_BASE(s2)
    beqz t0, 29f                    # unmapped: no levels
    li t0, LUMAP_PLANES
    bgeu s0, t0, 2f
    srli a0, s0, 1
    call sector_at
    andi t0, s0, 1
    li t1, SURFACE_SIZE
    mul t0, t0, t1
    add a0, a0, t0
    lw t0, (SECTOR_FLOOR_SURFACE + SURFACE_MATERIAL)(a0)
    j 3f
2:
    li t0, LUMAP_PLANES
    sub a0, s0, t0
    call wall_at
    lw t0, (WALL_SURFACE + SURFACE_MATERIAL)(a0)
3:
    bltz t0, 29f                    # no material: no levels
    la t1, material_mip_count
    slli t0, t0, 3
    add t1, t1, t0
    ld s4, 0(t1)                    # the material's chain, its levels
    sb s4, CS_LEVELS(s3)
    ld s5, LUMAP_K(s2)
    sb s5, CS_K(s3)
    ld s6, LUMAP_W(s2)
    sw s6, CS_W(s3)
    ld s7, LUMAP_H(s2)
    sw s7, CS_H(s3)
    ld t0, LUMAP_BASE(s2)
    sd t0, CS_LUMELS(s3)
    sll s6, s6, s5                  # the map's texels across at level 0
    sll s7, s7, s5                  # and down
    li s8, 0                        # the size
4:
    li t0, CENSUS_SIZES
    bgeu s8, t0, 28f
    li t2, 0                        # the level
5:
    bgeu t2, s4, 27f
    addi t3, s8, CENSUS_SIDE_SHIFT
    add t3, t3, t2                  # a tile's level 0 texels a side, as a shift
    li t4, 1
    sll t4, t4, t3
    addi t4, t4, -1
    add t5, s6, t4
    srl t5, t5, t3                  # the tiles across
    add t6, s7, t4
    srl t6, t6, t3                  # and down
    li t0, MIP_LEVELS
    mul t0, s8, t0
    add t0, t0, t2
    li t1, CS_GRID_SIZE
    mul t0, t0, t1
    add t0, t0, s3                  # the level's grid at the size
    sw s1, (CS_GRIDS + CS_GRID_BASE)(t0)
    sw t5, (CS_GRIDS + CS_GRID_W)(t0)
    sw t6, (CS_GRIDS + CS_GRID_H)(t0)
    mul t5, t5, t6
    add s1, s1, t5
    la t0, census_used
    slli t1, s8, 3
    add t0, t0, t1
    ld t1, 0(t0)
    add t1, t1, t5
    sd t1, 0(t0)                    # the size's entries
    addi t2, t2, 1
    j 5b
27:
    addi s8, s8, 1
    j 4b
28:
    la t0, census_maps
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
29:
    addi s0, s0, 1
    j 1b
30:
    li t0, CENSUS_ENTRIES
    bleu s1, t0, 31f
    jab.sys.uart.print msg_census_full
    jab.sys.exit 14
31:
    li s0, 0                        # the context
32:
    li t0, CENSUS_CONTEXTS
    bgeu s0, t0, 33f
    mv a0, s0
    call census_context
    li t0, (CENSUS_SLOTS * CENSUS_RECORD)
    mul t1, s0, t0
    la t2, census_slots
    add t1, t1, t2
    sd t1, CTX_CENSUS_BASE(a0)
    sd t1, CTX_CENSUS_NEXT(a0)
    add t1, t1, t0
    sd t1, CTX_CENSUS_END(a0)
    sd zero, CTX_CENSUS_DROPPED(a0)
    addi s0, s0, 1
    j 32b
33:
    la a0, census_line
    la a1, msg_census_directory
    call append_str
    la t0, census_maps
    ld a1, 0(t0)
    call append_dec
    la a1, word_census_maps
    call append_str
    li s0, 0                        # the size
34:
    li t0, CENSUS_SIZES
    bgeu s0, t0, 35f
    la a1, word_census_semicolon
    call append_str
    addi t0, s0, CENSUS_SIDE_SHIFT
    li a1, 1
    sll a1, a1, t0
    call append_dec
    la a1, word_census_entries
    call append_str
    la t0, census_used
    slli t1, s0, 3
    add t0, t0, t1
    ld a1, 0(t0)
    call append_dec
    la a1, word_census_bytes
    call append_str
    la t0, census_used
    slli t1, s0, 3
    add t0, t0, t1
    ld a1, 0(t0)
    slli a1, a1, 2                  # an entry's u32
    call append_dec
    addi s0, s0, 1
    j 34b
35:
    call census_line_end
    ld ra, 88(sp)
    ld s0, 80(sp)
    ld s1, 72(sp)
    ld s2, 64(sp)
    ld s3, 56(sp)
    ld s4, 48(sp)
    ld s5, 40(sp)
    ld s6, 32(sp)
    ld s7, 24(sp)
    ld s8, 16(sp)
    addi sp, sp, 96
    ret

census_context:
    beqz a0, 1f
    addi a0, a0, -1
    li t0, CTX_SIZE
    mul a0, a0, t0
    la t0, worker_contexts
    add a0, a0, t0
    ret
1:
    la a0, raster_context
    ret

census_frame:
    addi sp, sp, -112
    sd ra, 104(sp)
    sd s0, 96(sp)
    sd s1, 88(sp)
    sd s2, 80(sp)
    sd s3, 72(sp)
    sd s4, 64(sp)
    sd s5, 56(sp)
    sd s6, 48(sp)
    sd s7, 40(sp)
    sd s8, 32(sp)
    sd s9, 24(sp)
    sd s10, 16(sp)
    sd s11, 8(sp)
    sd a0, 0(sp)                    # the frame
    addi s0, a0, 1                  # its stamp
    li t0, CENSUS_WINDOW
    remu s1, a0, t0                 # its slot in the window
    la t0, census_totals
    li t1, (CENSUS_SIZES * CT_SIZE)
    add t1, t1, t0
1:
    sd zero, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 1b
    la t0, census_blocks
    sd zero, 0(t0)
    sd zero, 8(t0)
    sd zero, 16(t0)
    li t0, 0                        # the size
2:
    li t1, CENSUS_SIZES
    bgeu t0, t1, 3f
    li t1, CENSUS_WINDOW
    mul t1, t0, t1
    add t1, t1, s1
    slli t1, t1, 3
    la t2, census_ring
    add t1, t1, t2
    sd zero, 0(t1)                  # the slot's frame 120 before, out of every window
    addi t0, t0, 1
    j 2b
3:
    li s2, 0                        # the context
4:
    li t0, CENSUS_CONTEXTS
    bgeu s2, t0, 9f
    mv a0, s2
    call census_context
    ld s3, CTX_CENSUS_BASE(a0)      # its first record
    ld s4, CTX_CENSUS_NEXT(a0)      # past its last
    ld t0, CTX_CENSUS_DROPPED(a0)
    sd s3, CTX_CENSUS_NEXT(a0)      # emptied for the next frame
    sd zero, CTX_CENSUS_DROPPED(a0)
    la t1, census_blocks
    ld t2, 16(t1)
    add t2, t2, t0
    sd t2, 16(t1)
5:
    bgeu s3, s4, 8f
    call census_block
    addi s3, s3, CENSUS_RECORD
    j 5b
8:
    addi s2, s2, 1
    j 4b
9:
    ld a0, 0(sp)
    call census_print
    ld ra, 104(sp)
    ld s0, 96(sp)
    ld s1, 88(sp)
    ld s2, 80(sp)
    ld s3, 72(sp)
    ld s4, 64(sp)
    ld s5, 56(sp)
    ld s6, 48(sp)
    ld s7, 40(sp)
    ld s8, 32(sp)
    ld s9, 24(sp)
    ld s10, 16(sp)
    ld s11, 8(sp)
    addi sp, sp, 112
    ret

census_block:
    addi sp, sp, -16
    sd ra, 8(sp)
    lwu s5, CENSUS_SURFACE(s3)
    lbu s6, CENSUS_LEVEL(s3)
    lbu s7, CENSUS_PIXELS(s3)
    lbu s8, CENSUS_PASSED(s3)
    la t0, census_blocks
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
    beqz s8, 1f
    ld t1, 8(t0)
    addi t1, t1, 1
    sd t1, 8(t0)                    # a pixel past the depth test
1:
    li t0, LUMAP_COUNT
    bgeu s5, t0, 8f
    li t0, CS_SIZE
    mul t0, s5, t0
    la t1, census_surfaces
    add s9, t0, t1                  # its census record
    lbu t0, CS_LEVELS(s9)
    bgeu s6, t0, 8f                 # a level the directory does not hold
    li s10, CENSUS_PLANE
    li t0, LUMAP_PLANES
    bltu s5, t0, 2f
    li s10, CENSUS_WALL
    lbu t0, CENSUS_MASKED(s3)
    beqz t0, 2f
    li s10, CENSUS_OPENING
2:
    li s11, 0                       # the size
3:
    li t0, CENSUS_SIZES
    bgeu s11, t0, 9f
    call census_tiles
    addi s11, s11, 1
    j 3b
8:
    la t0, census_blocks
    ld t1, 16(t0)
    addi t1, t1, 1
    sd t1, 16(t0)                   # a record the census cannot place, counted as dropped
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

census_tiles:
    addi sp, sp, -16
    sd ra, 8(sp)
    li t0, CT_SIZE
    mul t0, s11, t0
    la t1, census_totals
    add a7, t0, t1                  # the size's totals
    li t0, MIP_LEVELS
    mul t0, s11, t0
    add t0, t0, s6
    li t1, CS_GRID_SIZE
    mul t0, t0, t1
    add t0, t0, s9                  # the level's grid at the size
    lwu a4, (CS_GRIDS + CS_GRID_W)(t0)
    lwu a5, (CS_GRIDS + CS_GRID_H)(t0)
    lwu a6, (CS_GRIDS + CS_GRID_BASE)(t0)
    addi t6, s6, (16 + CENSUS_SIDE_SHIFT)
    add t6, t6, s11                 # a 16.16 coordinate to its tile
    ld a0, CENSUS_U(s3)
    ld a1, CENSUS_V(s3)
    addi t0, s7, -1
    ld t1, CENSUS_DU(s3)
    mul t1, t1, t0
    add t2, a0, t1                  # u at the last pixel
    ld t1, CENSUS_DV(s3)
    mul t1, t1, t0
    add t3, a1, t1                  # v at the last pixel
    sra a0, a0, t6
    sra a1, a1, t6                  # the first pixel's tile
    sra t2, t2, t6
    sra t3, t3, t6                  # the last pixel's
    bne a0, t2, 5f
    bne a1, t3, 5f
    bgeu a0, a4, 4f                 # past the grid, a negative index too
    bgeu a1, a5, 4f
    ld t0, CT_ELIGIBLE(a7)
    addi t0, t0, 1
    sd t0, CT_ELIGIBLE(a7)
    ld t0, CT_ELIGIBLE_PIXELS(a7)
    add t0, t0, s7
    sd t0, CT_ELIGIBLE_PIXELS(a7)
    beqz s8, 9f                     # no pixel past the depth test: no request
    mul t0, a1, a4
    add t0, t0, a0
    add t0, t0, a6                  # the tile's entry
    mv a2, a0
    mv a3, a1
    mv a0, t0
    mv a1, a7
    call census_request
    j 9f
4:
    ld t0, CT_OUTSIDE(a7)
    addi t0, t0, 1
    sd t0, CT_OUTSIDE(a7)
    j 9f
5:
    ld t0, CT_STRADDLING(a7)
    addi t0, t0, 1
    sd t0, CT_STRADDLING(a7)
    ld t0, CT_STRADDLING_PIXELS(a7)
    add t0, t0, s7
    sd t0, CT_STRADDLING_PIXELS(a7)
    beqz s8, 9f
    ld a0, CENSUS_U(s3)
    ld a1, CENSUS_V(s3)
    ld t4, CENSUS_DU(s3)
    ld t5, CENSUS_DV(s3)
    mv t3, s7                       # the pixels left
    li a2, -1
    li a3, -1                       # the tile before, none
6:
    sra t0, a0, t6
    sra t1, a1, t6
    bne t0, a2, 7f
    beq t1, a3, 8f                  # the pixel before's tile
7:
    mv a2, t0
    mv a3, t1
    bgeu t0, a4, 8f
    bgeu t1, a5, 8f
    mul t2, t1, a4
    add t2, t2, t0
    add t2, t2, a6
    slli t2, t2, 3
    la t0, census_entries
    add t2, t2, t0                  # the tile's entry
    ld t0, 0(t2)
    slli t1, t0, 16
    srli t1, t1, 40                 # its sampled stamp
    beq t1, s0, 8f
    slli t1, t1, CENSUS_SAMPLED_SHIFT
    sub t0, t0, t1
    slli t1, s0, CENSUS_SAMPLED_SHIFT
    add t0, t0, t1
    sd t0, 0(t2)
    ld t0, CT_SAMPLED(a7)
    addi t0, t0, 1
    sd t0, CT_SAMPLED(a7)
8:
    add a0, a0, t4
    add a1, a1, t5
    addi t3, t3, -1
    bnez t3, 6b
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

census_request:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd a1, 32(sp)                   # the totals
    slli t0, a0, 3
    la t1, census_entries
    add t0, t0, t1
    sd t0, 24(sp)                   # the entry
    ld t1, 0(t0)
    slli t2, t1, 40
    srli t2, t2, 40                 # its demand stamp
    beq t2, s0, 1f
    mv a0, t0
    call census_first_demand
1:
    ld a1, 32(sp)
    ld t0, 24(sp)
    ld t1, 0(t0)
    addi t2, s10, CENSUS_CLASS_SHIFT
    li t3, 1
    sll t3, t3, t2
    and t4, t1, t3
    bnez t4, 2f
    or t1, t1, t3                   # its class's first request this frame
    slli t2, s10, 3
    add t2, t2, a1
    ld t3, CT_CLASSES(t2)
    addi t3, t3, 1
    sd t3, CT_CLASSES(t2)
2:
    slli t2, s2, 3
    add t2, t2, a1
    ld t3, CT_REQUESTS(t2)
    addi t3, t3, 1
    sd t3, CT_REQUESTS(t2)
    addi t2, s2, CENSUS_CONTEXT_SHIFT
    li t3, 1
    sll t3, t3, t2
    and t4, t1, t3
    bnez t4, 3f
    or t1, t1, t3                   # its context's first request this frame
    sd t1, 0(t0)
    call census_context_surface
    ld a1, 32(sp)
    ld t0, 24(sp)
    ld t1, 0(t0)
3:
    slli t2, t1, 16
    srli t2, t2, 40                 # its sampled stamp
    beq t2, s0, 4f
    slli t2, t2, CENSUS_SAMPLED_SHIFT
    sub t1, t1, t2
    slli t2, s0, CENSUS_SAMPLED_SHIFT
    add t1, t1, t2
    ld t3, CT_SAMPLED(a1)
    addi t3, t3, 1
    sd t3, CT_SAMPLED(a1)
4:
    sd t1, 0(t0)
    ld ra, 40(sp)
    addi sp, sp, 48
    ret

census_first_demand:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd a0, 16(sp)                   # the entry
    sd a1, 8(sp)                    # the totals
    ld t0, 0(a0)
    slli t1, t0, 40
    srli t1, t1, 40                 # the stamp it was last demanded at
    beqz t1, 2f
    addi t1, t1, -1                 # that frame
    addi t2, s0, -1                 # this one
    sub t2, t2, t1
    li t3, CENSUS_WINDOW
    bgeu t2, t3, 2f                 # past the window: its slot emptied since
    remu t1, t1, t3
    li t2, CENSUS_WINDOW
    mul t2, s11, t2
    add t2, t2, t1
    slli t2, t2, 3
    la t3, census_ring
    add t2, t2, t3
    ld t3, 0(t2)
    addi t3, t3, -1
    sd t3, 0(t2)                    # out of its frame's count
2:
    li t2, CENSUS_WINDOW
    mul t2, s11, t2
    add t2, t2, s1
    slli t2, t2, 3
    la t3, census_ring
    add t2, t2, t3
    ld t3, 0(t2)
    addi t3, t3, 1
    sd t3, 0(t2)                    # into this frame's
    slli t1, t0, 40
    srli t1, t1, 40
    sub t0, t0, t1
    or t0, t0, s0                   # this frame's stamp
    li t1, 0x3f
    slli t1, t1, CENSUS_CONTEXT_SHIFT
    not t1, t1
    and t0, t0, t1                  # its contexts and classes cleared for the frame
    sd t0, 0(a0)
    ld t3, CT_DEMAND(a1)
    addi t3, t3, 1
    sd t3, CT_DEMAND(a1)
    srli t1, t0, CENSUS_KNOWN_BIT
    andi t1, t1, 1
    bnez t1, 3f
    call census_uniform             # once a tile
    ld t2, 16(sp)
    ld t0, 0(t2)
    li t1, 1
    slli t1, t1, CENSUS_KNOWN_BIT
    or t0, t0, t1
    slli t1, a0, CENSUS_UNIFORM_BIT
    or t0, t0, t1
    sd t0, 0(t2)
    ld a1, 8(sp)
3:
    srli t1, t0, CENSUS_UNIFORM_BIT
    andi t1, t1, 1
    beqz t1, 4f
    ld t3, CT_UNIFORM(a1)
    addi t3, t3, 1
    sd t3, CT_UNIFORM(a1)
4:
    li t1, LUMAP_COUNT
    mul t1, s11, t1
    add t1, t1, s5
    slli t1, t1, 2
    la t2, census_surface_seen
    add t1, t1, t2
    lwu t2, 0(t1)
    beq t2, s0, 5f
    sw s0, 0(t1)                    # the surface's first demand this frame
    ld t3, CT_SURFACES(a1)
    addi t3, t3, 1
    sd t3, CT_SURFACES(a1)
5:
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

census_uniform:
    lbu t0, CS_K(s9)                # k
    addi t1, s11, CENSUS_SIDE_SHIFT
    add t1, t1, s6                  # a tile's level 0 texels a side, as a shift
    sll t2, a2, t1
    srl t3, t2, t0                  # the first column's cell
    addi t4, a2, 1
    sll t4, t4, t1
    addi t4, t4, -1
    srl t4, t4, t0
    addi t4, t4, 1                  # the last column's far node
    lwu t5, CS_W(s9)
    addi t5, t5, -1                 # the greatest column
    bleu t3, t5, 1f
    mv t3, t5
1:
    bleu t4, t5, 2f
    mv t4, t5
2:
    sll t2, a3, t1
    srl a4, t2, t0                  # the first row's cell
    addi a5, a3, 1
    sll a5, a5, t1
    addi a5, a5, -1
    srl a5, a5, t0
    addi a5, a5, 1                  # the last row's far node
    lwu t2, CS_H(s9)
    addi t2, t2, -1                 # the greatest row
    bleu a4, t2, 3f
    mv a4, t2
3:
    bleu a5, t2, 4f
    mv a5, t2
4:
    lwu t6, CS_W(s9)
    slli t6, t6, 3                  # a row's bytes
    ld a6, CS_LUMELS(s9)
    mul t2, a4, t6
    add t2, t2, a6
    slli a7, t3, 3
    add a7, a7, t2
    ld a7, 0(a7)                    # the first node's lumel, which every node must hold
    mv t0, a4                       # the row
5:
    bgtu t0, a5, 8f
    mul t2, t0, t6
    add t2, t2, a6                  # the row's lumels
    mv t1, t3                       # the column
6:
    bgtu t1, t4, 7f
    slli t5, t1, 3
    add t5, t5, t2
    ld t5, 0(t5)
    bne t5, a7, 9f
    addi t1, t1, 1
    j 6b
7:
    addi t0, t0, 1
    j 5b
8:
    li a0, 1
    ret
9:
    li a0, 0
    ret

census_context_surface:
    li t0, CENSUS_CONTEXTS
    mul t0, s11, t0
    add t0, t0, s2
    li t1, LUMAP_COUNT
    mul t1, t0, t1                  # the size and context's rows
    add t2, t1, s5
    slli t2, t2, 3
    la t3, census_context_counts
    add t2, t2, t3                  # the surface's stamp and count
    lwu t3, 0(t2)
    beq t3, s0, 1f
    sw s0, 0(t2)
    sw zero, 4(t2)
    slli t3, s2, 3
    add t3, t3, a1
    ld t4, CT_LISTED(t3)
    add t5, t1, t4
    slli t5, t5, 2
    la t6, census_context_lists
    add t5, t5, t6
    sw s5, 0(t5)                    # listed in the order first requested
    addi t4, t4, 1
    sd t4, CT_LISTED(t3)
1:
    lwu t3, 4(t2)
    addi t3, t3, 1
    sw t3, 4(t2)
    slli t3, s2, 3
    add t3, t3, a1
    ld t4, CT_DISTINCT(t3)
    addi t4, t4, 1
    sd t4, CT_DISTINCT(t3)
    ret

census_working:
    li t0, CENSUS_WINDOW
    mul t1, a1, t0
    slli t1, t1, 3
    la t2, census_ring
    add t1, t1, t2                  # the size's window
    li t3, 0                        # the tiles
    li t4, 0                        # the frames back
1:
    bgeu t4, a2, 9f
    bltu a0, t4, 9f                 # before the first frame
    sub t5, a0, t4
    remu t5, t5, t0
    slli t5, t5, 3
    add t5, t5, t1
    ld t5, 0(t5)
    add t3, t3, t5
    addi t4, t4, 1
    j 1b
9:
    mv a0, t3
    ret

census_print:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    mv s0, a0                       # the frame
    la a0, census_line
    la a1, msg_census_frame
    call append_str
    mv a1, s0
    call append_dec
    la a1, word_census_blocks
    call append_str
    la t0, census_blocks
    ld a1, 0(t0)
    call append_dec
    la a1, word_census_passing
    call append_str
    la t0, census_blocks
    ld a1, 8(t0)
    call append_dec
    la a1, word_census_dropped
    call append_str
    la t0, census_blocks
    ld a1, 16(t0)
    call append_dec
    call census_line_end
    li s1, 0                        # the size
1:
    li t0, CENSUS_SIZES
    bgeu s1, t0, 9f
    li t0, CT_SIZE
    mul t0, s1, t0
    la t1, census_totals
    add s2, t0, t1                  # its totals
    la a0, census_line
    la a1, msg_census
    call append_str
    addi t0, s1, CENSUS_SIDE_SHIFT
    li a1, 1
    sll a1, a1, t0
    call append_dec                 # the tile's side
    la a1, word_census_eligible
    call append_str
    ld a1, CT_ELIGIBLE(s2)
    call append_dec
    la a1, word_census_blocks_of
    call append_str
    ld a1, CT_ELIGIBLE_PIXELS(s2)
    call append_dec
    la a1, word_census_straddling
    call append_str
    ld a1, CT_STRADDLING(s2)
    call append_dec
    la a1, word_census_blocks_of
    call append_str
    ld a1, CT_STRADDLING_PIXELS(s2)
    call append_dec
    la a1, word_census_outside
    call append_str
    ld a1, CT_OUTSIDE(s2)
    call append_dec
    la a1, word_census_demand
    call append_str
    ld a1, CT_DEMAND(s2)
    call append_dec
    la a1, word_census_planes
    call append_str
    ld a1, (CT_CLASSES + 8 * CENSUS_PLANE)(s2)
    call append_dec
    la a1, word_census_walls
    call append_str
    ld a1, (CT_CLASSES + 8 * CENSUS_WALL)(s2)
    call append_dec
    la a1, word_census_openings
    call append_str
    ld a1, (CT_CLASSES + 8 * CENSUS_OPENING)(s2)
    call append_dec
    la a1, word_census_sampled
    call append_str
    ld a1, CT_SAMPLED(s2)
    call append_dec
    la a1, word_census_uniform
    call append_str
    ld a1, CT_UNIFORM(s2)
    call append_dec
    la a1, word_census_surfaces
    call append_str
    ld a1, CT_SURFACES(s2)
    call append_dec
    la a1, word_census_working
    call append_str
    mv s3, a0
    mv a0, s0
    mv a1, s1
    li a2, 1
    call census_working
    mv a1, a0
    mv a0, s3
    call append_dec
    la a1, word_census_comma
    call append_str
    mv s3, a0
    mv a0, s0
    mv a1, s1
    li a2, CENSUS_SHORT
    call census_working
    mv a1, a0
    mv a0, s3
    call append_dec
    la a1, word_census_comma
    call append_str
    mv s3, a0
    mv a0, s0
    mv a1, s1
    li a2, CENSUS_WINDOW
    call census_working
    mv a1, a0
    mv a0, s3
    call append_dec
    call census_line_end
    li s3, 0                        # the context
2:
    li t0, CENSUS_CONTEXTS
    bgeu s3, t0, 8f
    la a0, census_line
    la a1, msg_census
    call append_str
    addi t0, s1, CENSUS_SIDE_SHIFT
    li a1, 1
    sll a1, a1, t0
    call append_dec
    la a1, word_census_context
    call append_str
    mv a1, s3
    call append_dec
    la a1, word_census_requests
    call append_str
    slli t0, s3, 3
    add t0, t0, s2
    ld a1, CT_REQUESTS(t0)
    call append_dec
    la a1, word_census_distinct
    call append_str
    slli t0, s3, 3
    add t0, t0, s2
    ld a1, CT_DISTINCT(t0)
    call append_dec
    la a1, word_census_listed
    call append_str
    li s4, 0                        # the listed surface
3:
    slli t0, s3, 3
    add t0, t0, s2
    ld t1, CT_LISTED(t0)
    bgeu s4, t1, 4f
    li t0, CENSUS_CONTEXTS
    mul t0, s1, t0
    add t0, t0, s3
    li t1, LUMAP_COUNT
    mul t0, t0, t1                  # the size and context's rows
    add t1, t0, s4
    slli t1, t1, 2
    la t2, census_context_lists
    add t1, t1, t2
    lwu t1, 0(t1)                   # the surface
    add t0, t0, t1
    slli t0, t0, 3
    la t2, census_context_counts
    add t0, t0, t2
    lwu t2, 4(t0)                   # its distinct tiles
    sd t2, 0(sp)
    la a1, word_census_space
    call append_str
    ld a1, 0(sp)
    call append_dec
    addi s4, s4, 1
    j 3b
4:
    call census_line_end
    addi s3, s3, 1
    j 2b
8:
    addi s1, s1, 1
    j 1b
9:
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 64
    ret

census_line_end:
    li t0, '\n'
    sb t0, 0(a0)
    sb zero, 1(a0)
    jab.sys.uart.print census_line
    ret

.section .rodata
msg_census_full:
    .asciz "fps: census directory past its capacity\n"
msg_census_directory:
    .asciz "fps: census directory: "
word_census_maps:
    .asciz " maps"
word_census_semicolon:
    .asciz "; "
word_census_entries:
    .asciz ": entries "
word_census_bytes:
    .asciz ", bytes "
msg_census_frame:
    .asciz "fps: census frame "
word_census_blocks:
    .asciz ": blocks "
word_census_passing:
    .asciz ", passing "
word_census_dropped:
    .asciz ", dropped "
msg_census:
    .asciz "fps: census "
word_census_eligible:
    .asciz ": eligible "
word_census_blocks_of:
    .asciz " blocks "
word_census_straddling:
    .asciz " pixels, straddling "
word_census_outside:
    .asciz " pixels, outside "
word_census_demand:
    .asciz "; demand "
word_census_planes:
    .asciz ": planes "
word_census_walls:
    .asciz ", walls "
word_census_openings:
    .asciz ", openings "
word_census_sampled:
    .asciz "; sampled "
word_census_uniform:
    .asciz ", uniform "
word_census_surfaces:
    .asciz ", surfaces "
word_census_working:
    .asciz "; working "
word_census_comma:
    .asciz ", "
word_census_context:
    .asciz " context "
word_census_requests:
    .asciz ": requests "
word_census_distinct:
    .asciz ", distinct "
word_census_listed:
    .asciz "; surfaces"
word_census_space:
    .asciz " "

.section .bss
.balign 8
census_totals:
    .skip (CENSUS_SIZES * CT_SIZE)
census_blocks:
    .skip 24
census_used:
    .skip (CENSUS_SIZES * 8)
census_maps:
    .skip 8
census_ring:
    .skip (CENSUS_SIZES * CENSUS_WINDOW * 8)
census_surfaces:
    .skip (LUMAP_COUNT * CS_SIZE)
census_surface_seen:
    .skip (CENSUS_SIZES * LUMAP_COUNT * 4)
census_context_counts:
    .skip (CENSUS_SIZES * CENSUS_CONTEXTS * LUMAP_COUNT * 8)
census_context_lists:
    .skip (CENSUS_SIZES * CENSUS_CONTEXTS * LUMAP_COUNT * 4)
census_line:
    .skip CENSUS_LINE_BYTES
.balign 64
census_entries:
    .skip (CENSUS_ENTRIES * 8)
census_slots:
    .skip (CENSUS_CONTEXTS * CENSUS_SLOTS * CENSUS_RECORD)
.endif
