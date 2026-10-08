.section .text

.macro tile_wrote address, count
.ifdef DEBUG
    la \address, tile_writes
    ld \count, 0(\address)
    addi \count, \count, 1
    sd \count, 0(\address)       # a tag or an entry written
.endif
.endm

.macro tile_edge dst, column
    slli t4, \column, 3
    add t5, s9, t4
    ld t5, 0(t5)                    # the node above
    add t6, s10, t4
    ld t6, 0(t6)                    # and below
    li t4, 256
    sub t4, t4, s11
    mul t5, t5, t4
    mul t6, t6, s11
    add \dst, t5, t6                # the cell's edge on the row, packed
.endm

tiles_init:
    addi sp, sp, -80
    sd ra, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    sd s7, 24(sp)
    sd s8, 16(sp)
    sd s9, 8(sp)
    li s2, 0                        # the surface
    li s3, 0                        # the directory's entries so far
    li s8, 0                        # the maps with a directory
    li s9, 0                        # the mapped surfaces past it
1:
    li t0, LUMAP_COUNT
    bgeu s2, t0, 20f
    li t0, LUMAP_SIZE
    mul t0, s2, t0
    la t1, lumaps
    add s4, t0, t1                  # its lumel map
    ld t0, LUMAP_BASE(s4)
    beqz t0, 19f                    # unmapped: no directory
    li t0, LUMAP_PLANES
    bgeu s2, t0, 2f
    srli a0, s2, 1
    call sector_at
    andi t0, s2, 1
    li t1, SURFACE_SIZE
    mul t0, t0, t1
    add a0, a0, t0
    lw a0, (SECTOR_FLOOR_SURFACE + SURFACE_MATERIAL)(a0)
    j 3f
2:
    li t0, LUMAP_PLANES
    sub a0, s2, t0
    call wall_at
    lw a0, (WALL_SURFACE + SURFACE_MATERIAL)(a0)
3:
    mv s5, a0                       # its material
    call material_bind
    beqz a0, 19f                    # no texture: no directory
    li t0, TS_SIZE
    mul t0, s2, t0
    la t1, tile_surfaces
    add s6, t0, t1                  # its record
    la t0, poly
    ld s7, POLY_MIP_COUNT(t0)       # the chain's levels
    ld t1, LUMAP_K(s4)
    ld t2, LUMAP_W(s4)
    sll t2, t2, t1                  # the map's texels across at level 0
    ld t3, LUMAP_H(s4)
    sll t3, t3, t1                  # and down
    mv t4, s3                       # the entries with this map's
    li t5, 0                        # the level
4:
    bgeu t5, s7, 6f
    addi t6, t5, TILE_SHIFT         # a tile's level 0 texels a side, as a shift
    li a1, 1
    sll a1, a1, t6
    addi a1, a1, -1
    add a2, t2, a1
    srl a2, a2, t6                  # the tiles across
    add a3, t3, a1
    srl a3, a3, t6                  # and down
    li a1, 0xffff
    bgtu a2, a1, 18f                # a grid past sixteen bits a side
    bgtu a3, a1, 18f
    slli a4, t5, 3
    add a4, a4, s6                  # the level's grid
    sw t4, (TS_GRIDS + TS_GRID_BASE)(a4)
    sh a2, (TS_GRIDS + TS_GRID_W)(a4)
    sh a3, (TS_GRIDS + TS_GRID_H)(a4)
    mul a2, a2, a3
    add t4, t4, a2
    li a1, TILE_DIRECTORY_ENTRIES
    bgtu t4, a1, 18f                # past the directory
    addi t5, t5, 1
    j 4b
6:
    mv s3, t4
    sb s7, TS_LEVELS(s6)            # the levels the directory holds, its last
    ld t1, LUMAP_K(s4)
    sb t1, TS_K(s6)
    sw s5, TS_MATERIAL(s6)
    la t0, poly
    ld t1, POLY_WSHIFT(t0)
    sb t1, TS_WSHIFT(s6)
    ld t1, POLY_UMASK(t0)
    sw t1, TS_UMASK(s6)
    ld t1, POLY_VMASK(t0)
    sw t1, TS_VMASK(s6)
    addi s8, s8, 1
    j 19f
18:
    addi s9, s9, 1                  # counted, the lit loop's for good
19:
    addi s2, s2, 1
    j 1b
20:
    la t0, tile_entries
    sd s3, 0(t0)
    la t0, tile_maps
    sd s8, 0(t0)
    la t0, tile_uncached
    sd s9, 0(t0)
    la t0, tile_free
    li t1, TILE_SLOTS
21:
    addi t1, t1, -1
    sw t1, 0(t0)                    # the slots free, slot 0 on top
    addi t0, t0, 4
    bnez t1, 21b
    li t1, TILE_SLOTS
    la t0, tile_free_count
    sd t1, 0(t0)
    la t0, tile_effective
    sd t1, 0(t0)
    li t1, -1
    la t0, tile_building
    sd t1, 0(t0)                    # no tile in construction
    li s2, 0                        # the context
22:
    li t0, TILE_CONTEXTS
    bgeu s2, t0, 23f
    mv a0, s2
    call tile_context
    li t0, TA_SIZE
    mul t0, s2, t0
    la t1, tile_admission
    add t0, t0, t1
    sd t0, CTX_TILE_ADMIT(a0)       # its admission
    li t1, TA_TOUCHED
    add t0, t0, t1
    sd t0, CTX_TILE_TOUCHED(a0)     # and its touched slots
    addi s2, s2, 1
    j 22b
23:
    la t0, tile_merge_heads
    li t1, LUMAP_COUNT
    li t2, -1
24:
    sd t2, 0(t0)                    # every surface's merged chain none
    addi t0, t0, 8
    addi t1, t1, -1
    bnez t1, 24b
    li t1, TILE_GUARANTEE
    la t0, tile_pending_guarantee
    sd t1, 0(t0)
    li t1, TILE_RING
    la t0, tile_pending_ring
    sd t1, 0(t0)
    li t1, TILE_SLOTS
    la t0, tile_pending_effective
    sd t1, 0(t0)
    li t1, TILE_MERGE_US
    la t0, tile_pending_merge
    sd t1, 0(t0)
    li t1, 1
    la t0, tile_config_changed
    sb t1, 0(t0)                    # the first boundary's configuration record
    la t0, tile_tables_end
    la t1, tile_pool
    sub t0, t0, t1
    la t1, tile_memory
    sd t0, 0(t1)                    # TILE_MEMORY's bytes, every table and the pool
    li t1, TILE_POOL_BYTES
    sub t0, t0, t1
    li t1, TILE_DIRECTORY_ENTRIES
    sub t1, t1, s3
    slli t1, t1, 2
    sub t0, t0, t1                  # the tables, the directory at this map's entries
    la t1, tile_fixed
    sd t0, 0(t1)
    la t1, tile_memory_peak
    sd t0, 0(t1)
.ifdef DEBUG
    la a0, line
    la a1, msg_tile_pool
    call append_str
    li a1, TILE_SIDE
    call append_dec
    la a1, word_tile_slots
    call append_str
    li a1, TILE_SLOTS
    call append_dec
    la a1, word_tile_of
    call append_str
    li a1, TILE_BYTES
    call append_dec
    la a1, word_tile_directory
    call append_str
    mv a1, s3
    call append_dec
    la a1, word_tile_entries_over
    call append_str
    mv a1, s8
    call append_dec
    la a1, word_tile_maps_and
    call append_str
    mv a1, s9
    call append_dec
    la a1, word_tile_uncached
    call append_str
    la t0, tile_fixed
    ld a1, 0(t0)
    call append_dec
    la a1, word_tile_of
    call append_str
    la t0, tile_memory
    ld a1, 0(t0)
    call append_dec
    la a1, word_tile_bytes
    call append_str
    call line_end
.endif
    ld ra, 72(sp)
    ld s2, 64(sp)
    ld s3, 56(sp)
    ld s4, 48(sp)
    ld s5, 40(sp)
    ld s6, 32(sp)
    ld s7, 24(sp)
    ld s8, 16(sp)
    ld s9, 8(sp)
    addi sp, sp, 80
    ret

tile_context:
    beqz a0, 1f
    addi a0, a0, -1
    slli a0, a0, CTX_SHIFT
    la t0, worker_contexts
    add a0, a0, t0
    ret
1:
    la a0, raster_context
    ret


tiles_forget:
    li t0, 0                        # the slot
    la t1, tile_tags
    la t2, tile_slots
    la t3, tile_directory
1:
    li t4, TILE_SLOTS
    bgeu t0, t4, 3f
    slli t4, t0, 2
    add t4, t4, t1
    lwu t5, 0(t4)                   # its tag
    andi t6, t5, 0xff
    beqz t6, 2f                     # free already
    li a0, SLOT_READY
    bne t6, a0, 11f
    li a0, SLOT_SIZE
    mul a0, t0, a0
    add a0, a0, t2
    lwu a0, SLOT_KEY(a0)
    slli a0, a0, 2
    add a0, a0, t3                  # its tile's entry
    lwu a1, 0(a0)
    srli a2, t5, 16
    slli a2, a2, 16
    addi a3, t0, 1
    or a2, a2, a3                   # the entry naming this slot
    bne a1, a2, 11f
    sw zero, 0(a0)                  # cleared before the generation advances
    tile_wrote a4, a5
11:
    srli t5, t5, 16
    addi t5, t5, 1
    slli t5, t5, 48
    srli t5, t5, 32                 # the next generation, FREE
    sw t5, 0(t4)
    tile_wrote a4, a5
2:
    addi t0, t0, 1
    j 1b
3:
    la t0, tile_effective
    ld t1, 0(t0)                    # the slots the pool may use
    la t0, tile_free_count
    sd t1, 0(t0)
    la t0, tile_free
4:
    beqz t1, 5f
    addi t1, t1, -1
    sw t1, 0(t0)                    # every one free, slot 0 on top
    addi t0, t0, 4
    j 4b
5:
    la t0, tile_used
    sd zero, 0(t0)
    li t1, -1
    la t0, tile_building
    sd t1, 0(t0)
    la t0, stats
    ld t1, STAT_TILE_RESETS(t0)
    addi t1, t1, 1
    sd t1, STAT_TILE_RESETS(t0)
    ret

tile_boundary:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    rdtime s2                       # the boundary's start
    call tile_configure
    la t0, tile_pass
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)                    # this pass, its builds' mark
    la t0, tile_forget
    lbu t1, 0(t0)
    beqz t1, 1f
    sb zero, 0(t0)
    call tiles_forget               # the console's L
1:
    la t0, tile_flags
    ld t1, 0(t0)
    andi t1, t1, CONFIG_UNLIMITED
    li t2, TILE_UNLIMITED
    mv t3, t2
    mv t4, t2
    bnez t1, 2f
    li t2, (TILE_ALLOWANCE_US * US_TICKS)
    add t2, t2, s2                  # the allowance's end
    la t3, tile_merge_us
    ld t3, 0(t3)
    li t5, US_TICKS
    mul t3, t3, t5
    add t3, t3, s2                  # the merge's share's
    li t4, TILE_QUOTA
2:
    la t0, tile_deadline
    sd t2, 0(t0)
    la t0, tile_merge_deadline
    sd t3, 0(t0)
    la t0, tile_quota_left
    sd t4, 0(t0)
    call tile_batch                 # the frame before's requests counted
.ifdef DEBUG
    la t0, tile_cold
    lbu t1, 0(t0)
    beqz t1, 21f
    sb zero, 0(t0)
    la t0, tile_batch_admitted
    ld t1, 0(t0)
    la t0, stats
    sd t1, STAT_TILE_UNPROCESSED(t0)    # a cold start: the batch discarded whole
    call tile_trace_note
    call tile_fold
    j 3f
21:
.endif
    call tile_merge                 # and merged
.ifdef DEBUG
    call tile_trace_note
.endif
    call tile_fold                  # the slots read since, CLOCK's references
    la t0, tile_flags
    ld t1, 0(t0)
    andi t1, t1, CONFIG_FROZEN
    bnez t1, 3f
    rdtime s3
    call tile_construct
    rdtime t0
    sub t0, t0, s3
    la t1, stats
    sd t0, STAT_TILE_BUILD_TICKS(t1)
3:
    call tile_discard               # the requests not served
    call tile_stamp                 # this frame's stamp, its requests'
    call tile_occupancy
    rdtime t0
    sub t1, t0, s2
    la t2, stats
    sd t1, STAT_TILE_TICKS(t2)      # the whole boundary
    la t3, tile_flags
    ld t3, 0(t3)
    andi t3, t3, CONFIG_UNLIMITED
    bnez t3, 9f
    li t3, (TILE_ALLOWANCE_US * US_TICKS)
    sub t1, t1, t3
    blez t1, 9f
    sd t1, STAT_TILE_OVERRUN(t2)    # past the allowance
9:
.ifdef DEBUG
    call tile_trace_print           # after the boundary's time is taken
.endif
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

.ifdef DEBUG
tile_stall:
    addi sp, sp, -16
    sd ra, 8(sp)
    call tile_batch
    la t0, tile_batch_admitted
    ld t1, 0(t0)
    la t0, stats
    sd t1, STAT_TILE_UNPROCESSED(t0)    # the batch discarded whole
    call tile_discard
    call tile_stamp
    call tile_occupancy
    ld ra, 8(sp)
    addi sp, sp, 16
    ret
.endif

tile_stamp:
    la t0, frame_clock
    ld t1, CLOCK_SNAPSHOT(t0)
    addi t1, t1, 1
    la t0, tile_frame
    sd t1, 0(t0)
    ret

tile_configure:
    la t0, tile_config_changed
    lbu t1, 0(t0)
    beqz t1, 9f
    sb zero, 0(t0)
    la t0, tile_pending_effective
    ld t1, 0(t0)
    la t0, tile_effective
    ld t2, 0(t0)
    beq t1, t2, 1f
    sd t1, 0(t0)                    # a new slot cap
    li t1, 1
    la t0, tile_forget
    sb t1, 0(t0)                    # every tile forgotten, the free slots the cap's
1:
    la t0, tile_pending_merge
    ld t1, 0(t0)
    la t0, tile_merge_us
    sd t1, 0(t0)
    la t0, tile_config_record
    sw t1, CONFIG_MERGE(t0)
    la t0, tile_pending_flags
    ld t1, 0(t0)
    la t0, tile_flags
    sd t1, 0(t0)
    la t0, tile_pending_guarantee
    ld t2, 0(t0)
    la t0, tile_guarantee
    sd t2, 0(t0)
    la t0, tile_pending_ring
    ld t3, 0(t0)
    la t0, tile_ring
    sd t3, 0(t0)
    la t4, tile_config_record
    li t5, REPORT_CONFIG
    sw t5, REPORT_KIND(t4)
    la t5, frame_clock
    ld t5, CLOCK_SNAPSHOT(t5)
    sw t5, CONFIG_FRAME(t4)         # the frame whose boundary first uses it
    li t5, TILE_SHIFT
    sw t5, CONFIG_SHIFT(t4)
    li t5, TILE_BYTES
    sw t5, CONFIG_BYTES(t4)
    li t5, TILE_SLOTS
    sw t5, CONFIG_SLOTS(t4)
    la t5, tile_effective
    ld t5, 0(t5)
    sw t5, CONFIG_EFFECTIVE(t4)
    li t5, TILE_QUOTA
    sw t5, CONFIG_QUOTA(t4)
    li t5, TILE_ALLOWANCE_US
    sw t5, CONFIG_ALLOWANCE(t4)
    sw t1, CONFIG_FLAGS(t4)
    sw t2, CONFIG_GUARANTEE(t4)
    sw t3, CONFIG_RING(t4)
    li t5, TILE_RECENT
    sw t5, CONFIG_RECENT(t4)
    la t5, tile_entries
    ld t5, 0(t5)
    slli t5, t5, 2
    sw t5, CONFIG_DIRECTORY(t4)
    la t5, tile_memory
    ld t5, 0(t5)
    sw t5, CONFIG_MEMORY(t4)
    li t5, REPORT_SCHEMA_VERSION
    sw t5, REPORT_SCHEMA(t4)
    li t5, REPORT_SIZE
    jab.sys.api.write t4, t5
9:
    ret

tile_batch:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s2, 48(sp)
    sd s3, 40(sp)
    sd s4, 32(sp)
    sd s5, 24(sp)
    sd s6, 16(sp)
    la t0, tile_frame
    ld t1, 0(t0)                    # the batch's stamp
    addi t1, t1, -1                 # its frame, all ones at the first boundary
    la t0, tile_batch_frame
    sd t1, 0(t0)
    li s2, 0                        # its requests admitted
    li s3, 0                        # its greatest ring
    li s4, 0                        # its requesting surfaces
    li s5, 0                        # the context
1:
    li t0, TILE_CONTEXTS
    bgeu s5, t0, 5f
    mv a0, s5
    call tile_context
    ld s6, CTX_TILE_ADMIT(a0)       # its admission
    lwu t0, TA_RING_FILL(s6)
    add s2, s2, t0
    bgeu s3, t0, 2f
    mv s3, t0
2:
    lwu t1, TA_LISTED(s6)
    li t2, TA_LIST
    add t2, t2, s6                  # its first listed surface
    slli t1, t1, 2
    add t1, t1, t2                  # past its last
    li t3, TA_TIERS
    add t3, t3, s6                  # its tiers
3:
    bgeu t2, t1, 4f
    lwu t4, 0(t2)                   # a surface
    li t5, TT_SIZE
    mul t5, t4, t5
    add t5, t5, t3
    lwu t5, TT_COUNT(t5)
    add s2, s2, t5                  # its tier's requests
    srli t5, t4, 6
    slli t5, t5, 3
    la t6, tile_requesting
    add t5, t5, t6
    ld t6, 0(t5)
    li a1, 1
    sll a1, a1, t4
    and a2, t6, a1
    bnez a2, 31f
    or t6, t6, a1
    sd t6, 0(t5)                    # in the union
    addi s4, s4, 1
31:
    addi t2, t2, 4
    j 3b
4:
    addi s5, s5, 1
    j 1b
5:
    la t0, tile_batch_admitted
    sd s2, 0(t0)
    la t0, tile_batch_ring
    sd s3, 0(t0)
    la t0, tile_batch_surfaces
    sd s4, 0(t0)
    la t0, tile_processed
    sd zero, 0(t0)
    ld ra, 56(sp)
    ld s2, 48(sp)
    ld s3, 40(sp)
    ld s4, 32(sp)
    ld s5, 24(sp)
    ld s6, 16(sp)
    addi sp, sp, 64
    ret

tile_merge:
    addi sp, sp, -96
    sd ra, 88(sp)
    sd s2, 80(sp)
    sd s3, 72(sp)
    sd s4, 64(sp)
    sd s5, 56(sp)
    sd s6, 48(sp)
    sd s7, 40(sp)
    sd s8, 32(sp)
    sd s9, 24(sp)
    la t0, tile_frame
    ld s2, 0(t0)                    # the batch's stamp
    beqz s2, 90f                    # the first boundary: no batch
    la t0, tile_merge_cursor
    ld s3, 0(t0)                    # the surface the tiers start at
    li s4, 0                        # the words visited
10:
    li t0, (LUMAP_COUNT / 64)
    bgtu s4, t0, 30f                # every word, the start's last: the tiers merged
    srli t1, s3, 6
    add t1, t1, s4
    bltu t1, t0, 101f
    sub t1, t1, t0                  # the visit's word, wrapped
101:
    slli t2, t1, 3
    la t3, tile_requesting
    add t2, t2, t3
    ld s5, 0(t2)                    # the word's requesting surfaces
    slli s6, t1, 6                  # its first surface
    andi t2, s3, 63
    li t3, -1
    sll t3, t3, t2                  # the start's word from the start on
    beqz s4, 102f
    bne s4, t0, 11f
    not t3, t3                      # and last, before it
102:
    and s5, s5, t3
11:
    beqz s5, 20f
    andi t0, s5, 1
    beqz t0, 19f
    li s7, 0                        # the context
12:
    li t0, TILE_CONTEXTS
    bgeu s7, t0, 18f
    mv a0, s7
    call tile_context
    ld t0, CTX_TILE_ADMIT(a0)
    li t1, TT_SIZE
    mul t1, s6, t1
    add t0, t0, t1
    li t1, TA_TIERS
    add s8, t0, t1                  # the surface's tier in the context
    lwu t0, TT_STAMP(s8)
    bne t0, s2, 17f                 # none in the batch
    li s9, 0                        # the key
13:
    lwu t0, TT_COUNT(s8)
    bgeu s9, t0, 17f
    slli t0, s9, 2
    add t0, t0, s8
    lwu a0, TT_KEYS(t0)
    mv a1, s6
    call tile_merge_key
    bnez a0, 80f                    # the list full: resumed at this surface
    addi s9, s9, 1
    j 13b
17:
    addi s7, s7, 1
    j 12b
18:
    rdtime t0
    la t1, tile_merge_deadline
    ld t1, 0(t1)
    bltu t0, t1, 19f
    addi s6, s6, 1                  # the merge's share spent: resumed past this surface
    j 80f
19:
    srli s5, s5, 1
    addi s6, s6, 1
    j 11b
20:
    addi s4, s4, 1
    j 10b
30:
    addi s6, s3, 1                  # whole: the next boundary starts a surface on
    li t0, LUMAP_COUNT
    bltu s6, t0, 31f
    li s6, 0
31:
    la t0, tile_merge_cursor
    sd s6, 0(t0)
    la t0, tile_context_cursor
    ld s8, 0(t0)                    # the context the rings start at
    la t0, tile_ring_cursor
    ld s7, 0(t0)                    # and its entry
    li s4, 0                        # the contexts visited
40:
    li t0, TILE_CONTEXTS
    bgtu s4, t0, 50f                # every context, the start's last: the rings merged
    add s3, s8, s4
    bltu s3, t0, 401f
    sub s3, s3, t0                  # the visit's context, wrapped
401:
    mv a0, s3
    call tile_context
    ld s5, CTX_TILE_ADMIT(a0)
    lwu s9, TA_RING_FILL(s5)        # past its last entry
    li s6, 0                        # the entry
    beqz s4, 402f
    li t0, TILE_CONTEXTS
    bne s4, t0, 41f
    bgeu s7, s9, 41f
    mv s9, s7                       # the start's context last, before its entry
    j 41f
402:
    mv s6, s7                       # the start's context first, from its entry on
41:
    bgeu s6, s9, 45f
    slli t0, s6, 3
    add t0, t0, s5
    li t1, TA_RING
    add t0, t0, t1
    ld t1, 0(t0)
    slli a0, t1, 32
    srli a0, a0, 32                 # its key
    srli a1, t1, 32                 # its surface
    call tile_merge_key
    bnez a0, 85f                    # the list full: resumed at this entry
    addi s6, s6, 1
    andi t0, s6, 15
    bnez t0, 41b
    rdtime t0
    la t1, tile_merge_deadline
    ld t1, 0(t1)
    bltu t0, t1, 41b
    j 85f                           # the merge's share spent: resumed at this entry
45:
    addi s4, s4, 1
    j 40b
50:
    addi s3, s8, 1                  # whole: the next boundary starts a context on
    li t0, TILE_CONTEXTS
    bltu s3, t0, 51f
    li s3, 0
51:
    la t0, tile_context_cursor
    sd s3, 0(t0)
    la t0, tile_ring_cursor
    sd zero, 0(t0)                  # at its first entry
    j 90f
80:
    li t0, LUMAP_COUNT
    bltu s6, t0, 81f
    li s6, 0
81:
    la t0, tile_merge_cursor
    sd s6, 0(t0)                    # the next boundary resumes there
    j 90f
85:
    la t0, tile_context_cursor
    sd s3, 0(t0)
    la t0, tile_ring_cursor
    sd s6, 0(t0)                    # the next boundary resumes there
90:
    la t0, tile_merged_count
    ld t1, 0(t0)
    la t2, stats
    sd t1, STAT_TILE_MERGED(t2)
    la t0, tile_batch_admitted
    ld t3, 0(t0)
    la t0, tile_processed
    ld t4, 0(t0)
    sub t3, t3, t4
    sd t3, STAT_TILE_UNPROCESSED(t2)    # left past the merge's share
    ld ra, 88(sp)
    ld s2, 80(sp)
    ld s3, 72(sp)
    ld s4, 64(sp)
    ld s5, 56(sp)
    ld s6, 48(sp)
    ld s7, 40(sp)
    ld s8, 32(sp)
    ld s9, 24(sp)
    addi sp, sp, 96
    ret

tile_merge_key:
    la t0, tile_merged_count
    ld t1, 0(t0)                    # the list's entries
    srli t2, a0, 6
    slli t2, t2, 3
    la t3, tile_merge_bits
    add t2, t2, t3                  # the key's word
    ld t3, 0(t2)
    li t4, 1
    sll t4, t4, a0
    and t5, t3, t4
    bnez t5, 8f                     # merged already: a duplicate
    li t5, TILE_MERGE
    bgeu t1, t5, 9f                 # the list full: unprocessed
    or t3, t3, t4
    sd t3, 0(t2)                    # merged
    la t2, tile_merged
    slli t3, t1, 3
    add t3, t3, t2                  # its entry
    li t4, -1
    slli t4, t4, 32
    or t4, t4, a0
    sd t4, 0(t3)                    # the key, no next yet
    slli t4, a1, 3
    la t5, tile_merge_heads
    add t4, t4, t5                  # the surface's chain
    lwu t5, 0(t4)                   # its head
    li t6, -1
    srli t6, t6, 32                 # none
    bne t5, t6, 1f
    sw t1, 0(t4)                    # its first: head and tail
    sw t1, 4(t4)
    la t5, tile_order_count
    ld t6, 0(t5)
    slli a2, t6, 2
    la a3, tile_merge_order
    add a2, a2, a3
    sw a1, 0(a2)                    # in the merge's order
    addi t6, t6, 1
    sd t6, 0(t5)
    j 2f
1:
    lwu t5, 4(t4)                   # its tail
    slli t5, t5, 3
    add t5, t5, t2
    sw t1, 4(t5)                    # the tail's next
    sw t1, 4(t4)                    # the new tail
2:
    addi t1, t1, 1
    sd t1, 0(t0)
8:
    la t2, tile_processed
    ld t3, 0(t2)
    addi t3, t3, 1
    sd t3, 0(t2)
    li a0, 0
    ret
9:
    li a0, 1
    ret

tile_fold:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s2, 0(sp)
    li s2, 0                        # the context
1:
    li t0, TILE_CONTEXTS
    bgeu s2, t0, 9f
    mv a0, s2
    call tile_context
    ld t0, CTX_TILE_TOUCHED(a0)     # its touched slots
    li t1, 0                        # the word
2:
    li t2, (TILE_SLOTS / 64)
    bgeu t1, t2, 8f
    slli t2, t1, 3
    add t2, t2, t0
    ld t3, 0(t2)
    beqz t3, 7f
    sd zero, 0(t2)
    slli t4, t1, 6                  # its first slot
    li t6, SLOT_SIZE
    mul t6, t4, t6
    la t5, tile_slots
    add t5, t5, t6                  # its record
    li a1, 1
3:
    beqz t3, 7f
    andi t6, t3, 1
    beqz t6, 4f
    sb a1, SLOT_REFERENCE(t5)       # read since its last sweep
4:
    srli t3, t3, 1
    addi t5, t5, SLOT_SIZE
    j 3b
7:
    addi t1, t1, 1
    j 2b
8:
    addi s2, s2, 1
    j 1b
9:
    ld ra, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 16
    ret

tile_construct:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s2, 48(sp)
    sd s3, 40(sp)
    sd s4, 32(sp)
    sd s5, 24(sp)
    sd s6, 16(sp)
    la t0, tile_building
    ld a0, 0(t0)
    bltz a0, 1f
    call tile_build                 # the tile in construction first
    beqz a0, 90f                    # unfinished: the budget is spent
    la t0, tile_building
    ld a0, 0(t0)
    call tile_publish
    li t1, -1
    la t0, tile_building
    sd t1, 0(t0)
    call tile_spent
    bnez a0, 90f
1:
    la t0, tile_order_count
    ld s2, 0(t0)                    # the merged surfaces
    beqz s2, 90f
    la t0, tile_merged_count
    ld s3, 0(t0)                    # the keys left
    la t0, tile_build_cursor
    ld t1, 0(t0)
    la t2, tile_merge_order
    li s4, 0                        # the rotation's start
    li t3, LUMAP_COUNT              # its distance past the cursor
    li t4, 0                        # the order's entry
2:
    bgeu t4, s2, 4f
    slli t5, t4, 2
    add t5, t5, t2
    lwu t5, 0(t5)
    sub t6, t5, t1
    bgez t6, 3f
    li a1, LUMAP_COUNT
    add t6, t6, a1                  # past the cursor in rotation
3:
    bgeu t6, t3, 31f
    mv t3, t6
    mv s4, t4
31:
    addi t4, t4, 1
    j 2b
4:
    beqz s3, 90f                    # every key taken
    slli t0, s4, 2
    la t1, tile_merge_order
    add t0, t0, t1
    lwu s5, 0(t0)                   # the surface in turn
    slli t0, s5, 3
    la t1, tile_merge_heads
    add s6, t0, t1                  # its chain
    lwu t0, 0(s6)                   # its next key's entry
    li t1, -1
    srli t1, t1, 32
    beq t0, t1, 6f                  # its keys taken: the next surface
    slli t1, t0, 3
    la t2, tile_merged
    add t1, t1, t2
    ld t2, 0(t1)
    srli t3, t2, 32
    sw t3, 0(s6)                    # its chain past it
    addi s3, s3, -1
    addi t3, s5, 1
    li t4, LUMAP_COUNT
    bltu t3, t4, 5f
    li t3, 0
5:
    la t4, tile_build_cursor
    sd t3, 0(t4)                    # the rotation resumes after it
    slli a0, t2, 32
    srli a0, a0, 32                 # the key
    mv a1, s5
    call tile_make
    bnez a0, 90f                    # the budget spent, or no slot to take
6:
    addi s4, s4, 1
    bltu s4, s2, 4b
    li s4, 0
    j 4b
90:
    ld ra, 56(sp)
    ld s2, 48(sp)
    ld s3, 40(sp)
    ld s4, 32(sp)
    ld s5, 24(sp)
    ld s6, 16(sp)
    addi sp, sp, 64
    ret

tile_spent:
    la t0, tile_quota_left
    ld t1, 0(t0)
    blez t1, 1f
    rdtime t1
    la t0, tile_deadline
    ld t0, 0(t0)
    bgeu t1, t0, 1f
    li a0, 0
    ret
1:
    li a0, 1
    ret

tile_make:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    mv s2, a0                       # the key
    mv s3, a1                       # its surface
    slli t0, s2, 2
    la t1, tile_directory
    add t0, t0, t1
    lwu t0, 0(t0)                   # its entry
    slli t1, t0, 48
    srli t1, t1, 48
    beqz t1, 1f
    addi t1, t1, -1
    slli t1, t1, 2
    la t2, tile_tags
    add t1, t1, t2
    lwu t1, 0(t1)
    srli t2, t0, 16
    slli t2, t2, 16
    ori t2, t2, SLOT_READY
    beq t1, t2, 80f                 # built already
1:
    la t0, tile_free_count
    ld t1, 0(t0)
    beqz t1, 2f
    addi t1, t1, -1
    sd t1, 0(t0)
    slli t1, t1, 2
    la t2, tile_free
    add t1, t1, t2
    lwu s4, 0(t1)                   # a free slot
    j 3f
2:
    call tile_evict
    bltz a0, 90f                    # no slot to take: the build stops
    mv s4, a0
3:
    li t0, TS_SIZE
    mul t0, s3, t0
    la t1, tile_surfaces
    add t0, t0, t1                  # the surface's record
    lbu t1, TS_LEVELS(t0)
    li t2, 0                        # the level
4:
    bgeu t2, t1, 85f                # no grid of the surface holds it
    slli t3, t2, 3
    add t3, t3, t0
    lwu t4, (TS_GRIDS + TS_GRID_BASE)(t3)
    lhu t5, (TS_GRIDS + TS_GRID_W)(t3)
    lhu t6, (TS_GRIDS + TS_GRID_H)(t3)
    mul t6, t6, t5
    sub a2, s2, t4                  # the key within the level's grid
    bltu a2, t6, 5f
    addi t2, t2, 1
    j 4b
5:
    divu a3, a2, t5                 # its row
    mul a4, a3, t5
    sub a2, a2, a4                  # its column
    li t0, SLOT_SIZE
    mul t0, s4, t0
    la t1, tile_slots
    add t0, t0, t1                  # the slot's record
    sw s2, SLOT_KEY(t0)
    sw s3, SLOT_SURFACE(t0)
    sw a2, SLOT_TX(t0)
    sw a3, SLOT_TY(t0)
    sb t2, SLOT_LEVEL(t0)
    sb zero, SLOT_REFERENCE(t0)
    sh zero, SLOT_ROW(t0)
    slli t1, s4, 2
    la t2, tile_tags
    add t1, t1, t2
    lwu t2, 0(t1)
    srli t2, t2, 16
    slli t2, t2, 16
    ori t2, t2, SLOT_BUILDING
    sw t2, 0(t1)                    # in construction, its generation kept
    tile_wrote t3, t4
    la t0, tile_used
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
    la t0, tile_building
    sd s4, 0(t0)
    mv a0, s4
    call tile_build
    beqz a0, 90f                    # unfinished: kept BUILDING, the budget spent
    mv a0, s4
    call tile_publish
    li t1, -1
    la t0, tile_building
    sd t1, 0(t0)
80:
    call tile_spent
    j 99f
85:
    la t0, tile_free_count
    ld t1, 0(t0)
    slli t2, t1, 2
    la t3, tile_free
    add t2, t2, t3
    sw s4, 0(t2)                    # the slot back, free
    addi t1, t1, 1
    sd t1, 0(t0)
    li a0, 0
    j 99f
90:
    li a0, 1
99:
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 48
    ret

tile_evict:
    addi sp, sp, -16
    sd ra, 8(sp)
    la t0, tile_effective
    ld t1, 0(t0)                    # the slots it sweeps
    slli t2, t1, 1                  # two sweeps at most
    la t0, tile_hand
    ld t3, 0(t0)                    # the hand
    la t4, tile_pass
    ld t4, 0(t4)                    # this pass
1:
    beqz t2, 8f
    addi t2, t2, -1
    mv a0, t3
    addi t3, t3, 1
    bltu t3, t1, 2f
    li t3, 0
2:
    slli t5, a0, 2
    la t6, tile_tags
    add t5, t5, t6
    lwu t5, 0(t5)
    andi t5, t5, 0xff
    li t6, SLOT_READY
    bne t5, t6, 1b                  # free or in construction
    li t5, SLOT_SIZE
    mul t5, a0, t5
    la t6, tile_slots
    add t5, t5, t6
    lwu t6, SLOT_BUILT(t5)
    beq t6, t4, 1b                  # built this pass
    lbu t6, SLOT_REFERENCE(t5)
    beqz t6, 3f
    sb zero, SLOT_REFERENCE(t5)     # read: spared one sweep
    j 1b
3:
    la t0, tile_hand
    sd t3, 0(t0)
    sd a0, 0(sp)
    call tile_retire
    ld a0, 0(sp)
    j 9f
8:
    la t0, tile_hand
    sd t3, 0(t0)
    li a0, -1
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

tile_retire:
    slli t0, a0, 2
    la t1, tile_tags
    add t0, t0, t1                  # its tag
    lwu t1, 0(t0)
    li t2, SLOT_SIZE
    mul t2, a0, t2
    la t3, tile_slots
    add t2, t2, t3
    lwu t2, SLOT_KEY(t2)
    slli t2, t2, 2
    la t3, tile_directory
    add t2, t2, t3                  # its tile's entry
    lwu t3, 0(t2)
    srli t4, t1, 16
    slli t4, t4, 16
    addi t5, a0, 1
    or t4, t4, t5                   # the entry naming this slot
    bne t3, t4, 1f
.ifdef DEBUG
    la t5, tile_flags
    ld t5, 0(t5)
    andi t5, t5, CONFIG_STALE
    bnez t5, 1f                     # the stale knob: the entry left naming the slot
.endif
    sw zero, 0(t2)                  # cleared before the generation advances
    tile_wrote t5, t6
1:
    srli t1, t1, 16
    addi t1, t1, 1
    slli t1, t1, 48
    srli t1, t1, 32                 # the next generation, FREE
    sw t1, 0(t0)
    tile_wrote t5, t6
    la t0, tile_used
    ld t1, 0(t0)
    addi t1, t1, -1
    sd t1, 0(t0)
    la t0, stats
    ld t1, STAT_TILE_EVICTED(t0)
    addi t1, t1, 1
    sd t1, STAT_TILE_EVICTED(t0)
    ret

tile_publish:
    slli t0, a0, 2
    la t1, tile_tags
    add t0, t0, t1
    lwu t1, 0(t0)
    srli t1, t1, 16
    slli t1, t1, 16                 # its generation
    ori t2, t1, SLOT_READY
    sw t2, 0(t0)                    # whole
    tile_wrote t3, t4
    li t2, SLOT_SIZE
    mul t2, a0, t2
    la t3, tile_slots
    add t2, t2, t3
    la t3, tile_pass
    ld t3, 0(t3)
    sw t3, SLOT_BUILT(t2)
    sb zero, SLOT_REFERENCE(t2)     # unread until a frame reads it
    lwu t3, SLOT_KEY(t2)
    slli t3, t3, 2
    la t4, tile_directory
    add t3, t3, t4
    addi t4, a0, 1
    or t4, t4, t1
    sw t4, 0(t3)                    # the entry: the slot plus one, its generation
    tile_wrote t5, t6
    la t0, stats
    ld t1, STAT_TILES_BUILT(t0)
    addi t1, t1, 1
    sd t1, STAT_TILES_BUILT(t0)
    ret

tile_discard:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s2, 0(sp)
    la t0, tile_merged_count
    ld t1, 0(t0)
    sd zero, 0(t0)
    la t2, tile_merged
    la t3, tile_merge_bits
1:
    beqz t1, 2f
    addi t1, t1, -1
    slli t4, t1, 3
    add t4, t4, t2
    lwu t4, 0(t4)                   # a merged key
    srli t5, t4, 6
    slli t5, t5, 3
    add t5, t5, t3
    ld t6, 0(t5)
    li a1, 1
    sll a1, a1, t4
    not a1, a1
    and t6, t6, a1
    sd t6, 0(t5)                    # its bit cleared
    j 1b
2:
    la t0, tile_order_count
    ld t1, 0(t0)
    sd zero, 0(t0)
    la t2, tile_merge_order
    la t3, tile_merge_heads
    li t4, -1
3:
    beqz t1, 4f
    addi t1, t1, -1
    slli t5, t1, 2
    add t5, t5, t2
    lwu t5, 0(t5)
    slli t5, t5, 3
    add t5, t5, t3
    sd t4, 0(t5)                    # its chain none
    j 3b
4:
    la t0, tile_requesting
    li t1, (LUMAP_COUNT / 64)
5:
    sd zero, 0(t0)
    addi t0, t0, 8
    addi t1, t1, -1
    bnez t1, 5b
    li s2, 0                        # the context
6:
    li t0, TILE_CONTEXTS
    bgeu s2, t0, 9f
    mv a0, s2
    call tile_context
    ld t0, CTX_TILE_ADMIT(a0)
    sw zero, TA_LISTED(t0)
    sw zero, TA_RING_FILL(t0)       # its requests discarded
    addi s2, s2, 1
    j 6b
9:
    ld ra, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 16
    ret

tile_occupancy:
    la t0, tile_used
    ld t1, 0(t0)
    slli t1, t1, TILE_BYTES_SHIFT   # the pool's bytes in use
    la t0, tile_peak
    ld t2, 0(t0)
    bgeu t2, t1, 1f
    sd t1, 0(t0)
1:
    la t0, tile_fixed
    ld t2, 0(t0)
    add t1, t1, t2                  # the memory in use
    la t0, tile_memory_peak
    ld t2, 0(t0)
    bgeu t2, t1, 2f
    sd t1, 0(t0)
2:
    ret

tile_request:
    ld a2, CTX_TILE_ADMIT(tp)       # the context's admission
    la a3, tile_frame
    lwu a3, 0(a3)                   # the frame's stamp
    slli a4, a0, (64 - TILE_RECENT_SHIFT)
    srli a4, a4, (64 - TILE_RECENT_SHIFT - 3)
    add a4, a4, a2
    li a5, TA_FILTER
    add a4, a4, a5                  # the key's filter entry
    slli a5, a3, 32
    or a5, a5, a0                   # the key under the frame's stamp
    ld a6, 0(a4)
    beq a6, a5, 8f                  # asked already this frame
    sd a5, 0(a4)
    li a4, TT_SIZE
    mul a4, a1, a4
    li a5, TA_TIERS
    add a4, a4, a5
    add a4, a4, a2                  # the surface's tier
    lwu a5, TT_STAMP(a4)
    beq a5, a3, 1f
    sw a3, TT_STAMP(a4)             # the surface's first request this frame
    sw zero, TT_COUNT(a4)
    lwu a5, TA_LISTED(a2)
    slli a6, a5, 2
    add a6, a6, a2
    li a7, TA_LIST
    add a6, a6, a7
    sw a1, 0(a6)                    # listed
    addi a5, a5, 1
    sw a5, TA_LISTED(a2)
1:
    lwu a5, TT_COUNT(a4)
    addi a6, a4, TT_KEYS
    slli a7, a5, 2
    add a7, a7, a6                  # past its last key
2:
    beq a6, a7, 3f
    lwu a3, 0(a6)
    beq a3, a0, 8f                  # one of its own: asked already
    addi a6, a6, 4
    j 2b
3:
    la a6, tile_guarantee
    ld a6, 0(a6)                    # the guarantee in force
    bgeu a5, a6, 4f                 # its tier full: the open ring
    sw a0, 0(a7)
    addi a5, a5, 1
    sw a5, TT_COUNT(a4)
    j 6f
4:
    lwu a5, TA_RING_FILL(a2)
    la a6, tile_ring
    ld a6, 0(a6)                    # the ring in force
    bgeu a5, a6, 7f                 # full: dropped
    slli a6, a5, 3
    add a6, a6, a2
    li a7, TA_RING
    add a6, a6, a7
    slli a7, a1, 32
    or a7, a7, a0
    sd a7, 0(a6)
    addi a5, a5, 1
    sw a5, TA_RING_FILL(a2)
6:
    ld a5, CTX_TILE_ADMITTED(tp)
    addi a5, a5, 1
    sd a5, CTX_TILE_ADMITTED(tp)
    ret
7:
    ld a5, CTX_TILE_DROPPED(tp)
    addi a5, a5, 1
    sd a5, CTX_TILE_DROPPED(tp)
    ret
8:
    ld a5, CTX_TILE_FILTERED(tp)
    addi a5, a5, 1
    sd a5, CTX_TILE_FILTERED(tp)
    ret

.ifdef DEBUG
tile_check:
    la t0, tile_writes
    ld t0, 0(t0)
    la t1, tile_writes_frozen
    ld t1, 0(t1)
    bne t0, t1, 1f
    ret
1:
    jab.sys.uart.print msg_tile_flight
    jab.sys.exit 15

tile_trace_note:
    la t0, tile_trace
    lbu t0, 0(t0)
    bnez t0, 1f
    ret
1:
    la t0, tile_requesting
    la t1, tile_trace_requesting
    li t2, (LUMAP_COUNT / 64)
2:
    ld t3, 0(t0)
    sd t3, 0(t1)                    # the batch's surfaces, kept past the discard
    addi t0, t0, 8
    addi t1, t1, 8
    addi t2, t2, -1
    bnez t2, 2b
    li t0, 0                        # the merge order's entry
    la t6, tile_trace_merged
3:
    la t1, tile_order_count
    ld t1, 0(t1)
    bgeu t0, t1, 9f
    slli t1, t0, 2
    la t2, tile_merge_order
    add t1, t1, t2
    lwu t2, 0(t1)                   # a merged surface
    slli t1, t2, 3
    la t3, tile_merge_heads
    add t1, t1, t3
    lwu t1, 0(t1)                   # its first key's entry
    li t3, 0                        # its keys
    li t4, -1
    srli t4, t4, 32
4:
    beq t1, t4, 5f
    addi t3, t3, 1
    slli t1, t1, 3
    la t5, tile_merged
    add t1, t1, t5
    lwu t1, 4(t1)                   # the next
    j 4b
5:
    sw t2, 0(t6)
    sw t3, 4(t6)                    # kept before construction takes them
    addi t6, t6, 8
    addi t0, t0, 1
    j 3b
9:
    la t1, tile_trace_merged_count
    sd t0, 0(t1)
    ret

tile_trace_print:
    la t0, tile_trace
    lbu t0, 0(t0)
    bnez t0, 1f
    ret
1:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    la a1, word_trace_requesting
    call tile_trace_open
    li s2, 0                        # the surface
10:
    li t0, LUMAP_COUNT
    bgeu s2, t0, 19f
    srli t0, s2, 6
    slli t0, t0, 3
    la t1, tile_trace_requesting
    add t0, t0, t1
    ld t0, 0(t0)
    srl t0, t0, s2
    andi t0, t0, 1
    beqz t0, 18f
    mv a1, s2
    li a2, -1
    call tile_trace_item            # in the batch
18:
    addi s2, s2, 1
    j 10b
19:
    call tile_trace_close
    la a1, word_trace_merged
    call tile_trace_open
    li s2, 0                        # the merged surface
20:
    la t0, tile_trace_merged_count
    ld t0, 0(t0)
    bgeu s2, t0, 29f
    slli t0, s2, 3
    la t1, tile_trace_merged
    add t0, t0, t1
    lwu a1, 0(t0)
    lwu a2, 4(t0)                   # with its keys
    call tile_trace_item
    addi s2, s2, 1
    j 20b
29:
    call tile_trace_close
    la a1, word_trace_built
    call tile_trace_open
    li s2, 0                        # the slot
30:
    li t0, TILE_SLOTS
    bgeu s2, t0, 39f
    slli t0, s2, 2
    la t1, tile_tags
    add t0, t0, t1
    lwu t0, 0(t0)
    andi t0, t0, 0xff
    li t1, SLOT_READY
    bne t0, t1, 38f
    li t0, SLOT_SIZE
    mul t0, s2, t0
    la t1, tile_slots
    add t0, t0, t1
    lwu t1, SLOT_BUILT(t0)
    la t2, tile_pass
    ld t2, 0(t2)
    bne t1, t2, 38f                 # built before this pass
    lwu a1, SLOT_SURFACE(t0)
    li a2, -1
    call tile_trace_item
38:
    addi s2, s2, 1
    j 30b
39:
    call tile_trace_close
    ld ra, 24(sp)
    ld s2, 16(sp)
    addi sp, sp, 32
    ret

tile_trace_open:
    la t0, tile_trace_kind
    sd a1, 0(t0)
tile_trace_head:
    addi sp, sp, -16
    sd ra, 8(sp)
    la a0, line
    la a1, msg_tile_trace
    call append_str
    la t0, frame_clock
    ld a1, CLOCK_SNAPSHOT(t0)
    call append_dec
    la t0, tile_trace_kind
    ld a1, 0(t0)
    call append_str
    la t0, tile_trace_at
    sd a0, 0(t0)
    la t0, tile_trace_items
    sd zero, 0(t0)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

tile_trace_item:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    mv s2, a1
    mv s3, a2
    la t0, tile_trace_items
    ld t0, 0(t0)
    li t1, TILE_TRACE_ITEMS
    bltu t0, t1, 1f
    call tile_trace_close           # the line full: the list goes on in another
    call tile_trace_head
1:
    la t0, tile_trace_at
    ld a0, 0(t0)
    li t1, ' '
    sb t1, 0(a0)
    addi a0, a0, 1
    mv a1, s2
    call append_dec
    bltz s3, 2f
    li t1, ':'
    sb t1, 0(a0)
    addi a0, a0, 1
    mv a1, s3
    call append_dec
2:
    la t0, tile_trace_at
    sd a0, 0(t0)
    la t0, tile_trace_items
    ld t1, 0(t0)
    addi t1, t1, 1
    sd t1, 0(t0)
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret

tile_trace_close:
    la t0, tile_trace_at
    ld a0, 0(t0)
    j line_end
.endif

.balign CODE_PAGE
tile_build:
    addi sp, sp, -208
    sd ra, 200(sp)
    sd s0, 192(sp)
    sd s2, 184(sp)
    sd s3, 176(sp)
    sd s4, 168(sp)
    sd s5, 160(sp)
    sd s6, 152(sp)
    sd s7, 144(sp)
    sd s8, 136(sp)
    sd s9, 128(sp)
    sd s10, 120(sp)
    sd s11, 112(sp)
    li t0, SLOT_SIZE
    mul t0, a0, t0
    la t1, tile_slots
    add t0, t0, t1
    sd t0, 0(sp)                    # the slot's record
    slli t1, a0, TILE_BYTES_SHIFT
    la t2, tile_pool
    add t1, t1, t2
    sd t1, 96(sp)                   # its tile
    lhu t1, SLOT_ROW(t0)
    sd t1, 104(sp)                  # the row in hand
    lwu t1, SLOT_TX(t0)
    slli t1, t1, TILE_SHIFT
    sd t1, 80(sp)                   # the tile's first column at its level
    lwu t1, SLOT_TY(t0)
    slli t1, t1, TILE_SHIFT
    sd t1, 88(sp)                   # and first row
    lbu t2, SLOT_LEVEL(t0)
    sd t2, 16(sp)                   # m
    lwu t1, SLOT_SURFACE(t0)
    li t3, TS_SIZE
    mul t3, t1, t3
    la t4, tile_surfaces
    add t3, t3, t4                  # the surface's record
    li t4, LUMAP_SIZE
    mul t4, t1, t4
    la t5, lumaps
    add t4, t4, t5                  # its lumel map
    lbu t5, TS_K(t3)
    sd t5, 8(sp)                    # k
    sub s0, t5, t2                  # k - m, a cell's texels at the level as a shift, below 0 past k
    ld t5, LUMAP_W(t4)
    addi t6, t5, -1
    sd t6, 24(sp)                   # the last node column
    slli t5, t5, 3
    sd t5, 48(sp)                   # a node row's bytes
    ld t5, LUMAP_H(t4)
    addi t5, t5, -1
    sd t5, 32(sp)                   # the last node row
    ld t5, LUMAP_BASE(t4)
    sd t5, 40(sp)                   # the nodes
    lwu t5, TS_UMASK(t3)
    srl s4, t5, t2                  # the level's masks
    lwu t5, TS_VMASK(t3)
    srl t5, t5, t2
    sd t5, 64(sp)
    lbu t5, TS_WSHIFT(t3)
    sub t5, t5, t2
    sd t5, 72(sp)                   # a texel row's bytes at the level as a shift
    lwu t5, TS_MATERIAL(t3)
    li t6, MIP_ENTRY
    mul t5, t5, t6
    la t6, material_mips
    add t5, t5, t6
    slli t6, t2, 3
    add t5, t5, t6
    ld t5, 0(t5)
    sd t5, 56(sp)                   # the chain's texels at the level
10:
    ld t0, 104(sp)                  # the row
    li t1, TILE_SIDE
    bgeu t0, t1, 80f                # whole
    ld t1, 88(sp)
    add t1, t1, t0                  # its row at the level
    ld t2, 64(sp)
    and t2, t1, t2
    ld t3, 72(sp)
    sll t2, t2, t3
    ld t3, 56(sp)
    add s3, t3, t2                  # the chain's row
    slli t2, t0, TILE_ROW_SHIFT
    ld t3, 96(sp)
    add s2, t3, t2                  # the tile's row
    slli t2, t1, 1
    addi t2, t2, 1
    ld t3, 16(sp)
    addi t3, t3, 15
    sll t2, t2, t3                  # v at the row's centre, 16.16 at level 0
    ld t3, 8(sp)
    addi t4, t3, 16
    srl t5, t2, t4                  # its node row
    ld t6, 32(sp)
    ld a0, 48(sp)
    bltu t5, t6, 11f
    mul t5, t6, a0
    ld t6, 40(sp)
    add s9, t6, t5                  # past the last node row: the last row's nodes
    mv s10, s9
    li s11, 0
    j 12f
11:
    addi t4, t3, 8
    srl s11, t2, t4
    andi s11, s11, 0xff             # v's fraction in 256ths, as lumel_sample takes it
    mul t5, t5, a0
    ld t6, 40(sp)
    add s9, t6, t5                  # the row's nodes above
    add s10, s9, a0                 # and below
12:
    ld s5, 80(sp)                   # the texel
    addi s6, s5, TILE_SIDE          # past the row's last
20:
    bgeu s5, s6, 70f
    bltz s0, 40f                    # a texel past a lumel cell
    srl t0, s5, s0                  # its centre's cell column
    ld t1, 24(sp)
    bgeu t0, t1, 30f                # at or past the last node
    tile_edge t2, t0                # the cell's left edge
    addi t0, t0, 1
    tile_edge t3, t0                # and its right
    addi t0, t0, -1
    sll t1, t0, s0
    sub t1, s5, t1                  # the texel within the cell
    li a0, 1
    sll a0, a0, s0
    sub a0, a0, t1                  # the cell's texels from it
    sub a1, s6, s5
    bleu a0, a1, 21f
    mv a0, a1                       # cut short by the row's end
21:
    slli t1, t1, 1
    addi t1, t1, 1                  # its centre in half texels from the cell's edge
    li s7, 0
    li s8, 0
    li a1, 0                        # the lane's shift
    li a2, ((1 << CHANNEL_BITS) - 1)
    addi a3, s0, 1
    li a4, 1
    sll a4, a4, a3
    addi a4, a4, -1                 # the centre's rounding toward zero
    li a5, 1
    sll a5, a5, s0
    addi a5, a5, -1                 # a step's
22:
    srl t4, t2, a1
    and t4, t4, a2                  # the lane at the left edge
    srl t5, t3, a1
    and t5, t5, a2
    sub t5, t5, t4                  # its change across the cell
    mul t6, t5, t1
    srai a6, t6, 63
    and a6, a6, a4
    add t6, t6, a6
    sra t6, t6, a3
    add t4, t4, t6                  # at the texel's centre, toward the left edge
    sll t4, t4, a1
    or s7, s7, t4
    srai a6, t5, 63
    and a6, a6, a5
    add t5, t5, a6
    sra t5, t5, s0                  # a texel's step, toward zero
    sll t5, t5, a1
    add s8, s8, t5
    addi a1, a1, CHANNEL_BITS
    li a6, (3 * CHANNEL_BITS)
    bltu a1, a6, 22b
    j 50f
30:
    ld t0, 24(sp)
    tile_edge s7, t0                # the clamp's limit, the last node column
    li s8, 0
    sub a0, s6, s5                  # the row's rest
    j 50f
40:
    slli t0, s5, 1
    addi t0, t0, 1
    ld t1, 16(sp)
    ld t2, 8(sp)
    sub t1, t1, t2
    addi t1, t1, -1
    sll t0, t0, t1                  # the node column under the texel's centre
    ld t1, 24(sp)
    bleu t0, t1, 41f
    mv t0, t1
41:
    tile_edge s7, t0
    li s8, 0
    li a0, 1
50:
    and t4, s5, s4
    slli t4, t4, 2
    add t4, t4, s3
    lwu a1, 0(t4)                   # the chain's texel at the level
    slli a2, s7, (64 - 3 * CHANNEL_BITS)
    srli a2, a2, (64 - CHANNEL_BITS + 8)    # blue's brightness, 8.8
    andi a3, a1, 0xff
    mul a3, a3, a2
    srli a3, a3, 8
    slli a2, s7, (64 - 2 * CHANNEL_BITS)
    srli a2, a2, (64 - CHANNEL_BITS + 8)    # green's
    srli a4, a1, 8
    andi a4, a4, 0xff
    mul a4, a4, a2
    srli a4, a4, 8
    slli a4, a4, 8
    or a3, a3, a4
    slli a2, s7, (64 - CHANNEL_BITS)
    srli a2, a2, (64 - CHANNEL_BITS + 8)    # red's
    srli a4, a1, 16
    andi a4, a4, 0xff
    mul a4, a4, a2
    srli a4, a4, 8
    slli a4, a4, 16
    or a3, a3, a4
    srli a4, a1, 24
    slli a4, a4, 24
    or a3, a3, a4                   # the alpha kept
    sw a3, 0(s2)
    add s7, s7, s8
    addi s5, s5, 1
    addi s2, s2, 4
    addi a0, a0, -1
    bnez a0, 50b
    j 20b
70:
    ld t0, 104(sp)
    addi t0, t0, 1
    sd t0, 104(sp)                  # the row built
    la t1, tile_quota_left
    ld t2, 0(t1)
    addi t2, t2, -TILE_SIDE
    sd t2, 0(t1)
    li t3, TILE_SIDE
    bgeu t0, t3, 80f                # whole
    blez t2, 85f                    # the quota spent
    rdtime t3
    la t1, tile_deadline
    ld t1, 0(t1)
    bgeu t3, t1, 85f                # the allowance spent
    j 10b
80:
    li a0, 1
    j 90f
85:
    li a0, 0
90:
    ld t0, 0(sp)
    ld t1, 104(sp)
    sh t1, SLOT_ROW(t0)             # the next row to build
    ld ra, 200(sp)
    ld s0, 192(sp)
    ld s2, 184(sp)
    ld s3, 176(sp)
    ld s4, 168(sp)
    ld s5, 160(sp)
    ld s6, 152(sp)
    ld s7, 144(sp)
    ld s8, 136(sp)
    ld s9, 128(sp)
    ld s10, 120(sp)
    ld s11, 112(sp)
    addi sp, sp, 208
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
    mv a0, s6
    mv a1, s7
    call mip_levels
    li t0, 1
    bleu a0, t0, 8f                 # a chain with no level past 0: one, no line
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
    addi t3, t0, 8
    addi t4, t0, (MIP_LEVELS * 8)
6:
    sd zero, 0(t3)                  # every coarser level's share, none yet
    addi t3, t3, 8
    bltu t3, t4, 6b
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
    la t0, alpha_chain_levels
    ld s11, 0(t0)                   # the levels the line carries
    li s10, 0
73:
    beqz s10, 74f
    la a1, word_space
    call append_str
74:
    la t0, alpha_cover
    slli t1, s10, 3
    add t0, t0, t1
    ld a1, 0(t0)
    call append_dec
    addi s10, s10, 1
    bltu s10, s11, 73b
    la a1, word_of_share
    call append_str
    li s10, 1
75:
    li t0, 1
    beq s10, t0, 76f
    la a1, word_space
    call append_str
76:
    slli t0, s10, 2
    add t0, t0, s4
    lwu a1, 0(t0)
    call append_dec
    addi s10, s10, 1
    bltu s10, s11, 75b
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

.ifdef DEBUG
lumels_parity:
    li t2, 64
    slli t3, t2, CHANNEL_BITS
    or t2, t2, t3
    slli t3, t3, CHANNEL_BITS
    or t2, t2, t3                   # the three lanes at a quarter
    li t6, 256
    slli t3, t6, CHANNEL_BITS
    or t6, t6, t3
    slli t3, t3, CHANNEL_BITS
    or t6, t6, t3                   # and at one
    la t0, lumaps
    li t1, (LUMAP_COUNT * LUMAP_SIZE)
    add t1, t1, t0
1:
    bgeu t0, t1, 9f
    ld t3, LUMAP_BASE(t0)
    beqz t3, 2f
    ld t4, LUMAP_W(t0)
    ld t5, LUMAP_H(t0)
    li a0, 0                        # the row
3:
    bgeu a0, t5, 2f
    li a1, 0                        # the column
4:
    bgeu a1, t4, 5f
    add a2, a0, a1
    andi a2, a2, 1
    mv a3, t2                       # a node of even parity a quarter
    beqz a2, 6f
    mv a3, t6                       # an odd one one
6:
    sd a3, 0(t3)
    addi t3, t3, 8
    addi a1, a1, 1
    j 4b
5:
    addi a0, a0, 1
    j 3b
2:
    addi t0, t0, LUMAP_SIZE
    j 1b
9:
    ret
.endif

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
msg_tile_pool:
    .asciz "fps: tile pool: side "
word_tile_slots:
    .asciz ", slots "
word_tile_of:
    .asciz " of "
word_tile_directory:
    .asciz " bytes, directory "
word_tile_entries_over:
    .asciz " entries over "
word_tile_maps_and:
    .asciz " maps and "
word_tile_uncached:
    .asciz " uncached, memory "
word_tile_bytes:
    .asciz " bytes"
msg_tile_flight:
    .asciz "fps: tile pool changed in flight\n"
msg_tile_trace:
    .asciz "fps: tile pass "
word_trace_requesting:
    .asciz " requesting:"
word_trace_merged:
    .asciz " merged:"
word_trace_built:
    .asciz " built:"
.endif

.section .bss
.balign 8
tile_peak:
    .skip 8
tile_frame:
    .skip 8
tile_pass:
    .skip 8
tile_hand:
    .skip 8
tile_used:
    .skip 8
tile_deadline:
    .skip 8
tile_merge_deadline:
    .skip 8
tile_quota_left:
    .skip 8
tile_merge_cursor:
    .skip 8
tile_context_cursor:
    .skip 8
tile_ring_cursor:
    .skip 8
tile_build_cursor:
    .skip 8
tile_merged_count:
    .skip 8
tile_order_count:
    .skip 8
tile_processed:
    .skip 8
tile_batch_frame:
    .skip 8
tile_batch_admitted:
    .skip 8
tile_batch_ring:
    .skip 8
tile_batch_surfaces:
    .skip 8
tile_flags:
    .skip 8
tile_guarantee:
    .skip 8
tile_ring:
    .skip 8
tile_merge_us:
    .skip 8
tile_pending_flags:
    .skip 8
tile_pending_guarantee:
    .skip 8
tile_pending_ring:
    .skip 8
tile_pending_effective:
    .skip 8
tile_pending_merge:
    .skip 8
tile_entries:
    .skip 8
tile_maps:
    .skip 8
tile_uncached:
    .skip 8
tile_free_count:
    .skip 8
tile_effective:
    .skip 8
tile_building:
    .skip 8
tile_memory:
    .skip 8
tile_fixed:
    .skip 8
tile_memory_peak:
    .skip 8
.ifdef DEBUG
tile_writes:
    .skip 8
tile_writes_frozen:
    .skip 8
tile_trace_kind:
    .skip 8
tile_trace_at:
    .skip 8
tile_trace_items:
    .skip 8
tile_trace_merged_count:
    .skip 8
tile_trace_requesting:
    .skip (LUMAP_COUNT / 8)
tile_trace_merged:
    .skip (LUMAP_COUNT * 8)
tile_trace:
    .skip 1
tile_cold:
    .skip 1
.balign 8
.endif
tile_config_record:
    .skip REPORT_SIZE
tile_forget:
    .skip 1
tile_config_changed:
    .skip 1
.balign 8
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
.balign CODE_PAGE
tile_pool:
    .skip TILE_POOL_BYTES
tile_tags:
    .skip (TILE_SLOTS * 4)
tile_slots:
    .skip (TILE_SLOTS * SLOT_SIZE)
tile_free:
    .skip (TILE_SLOTS * 4)
tile_surfaces:
    .skip (LUMAP_COUNT * TS_SIZE)
tile_directory:
    .skip (TILE_DIRECTORY_ENTRIES * 4)
tile_merge_bits:
    .skip (TILE_DIRECTORY_ENTRIES / 8)
tile_merged:
    .skip (TILE_MERGE * 8)
tile_merge_heads:
    .skip (LUMAP_COUNT * 8)
tile_merge_order:
    .skip (LUMAP_COUNT * 4)
tile_requesting:
    .skip (LUMAP_COUNT / 8)
.balign 64
tile_admission:
    .skip (TILE_CONTEXTS * TA_SIZE)
tile_tables_end:
