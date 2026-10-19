.ifdef SNAPSHOTS

.macro snapshot_of index, dst, scratch
    li \scratch, SNAPSHOT_SIZE
    mul \dst, \index, \scratch
    la \scratch, snapshots
    add \dst, \dst, \scratch
.endm

.section .text

snapshots_init:
    la t0, snapshots
    li t1, SNAPSHOT_NONE
    li t2, (SNAPSHOT_RING + 1)
    li t3, SNAPSHOT_SIZE
1:
    sw t1, SNAP_FRAME(t0)           # no frame held
    add t0, t0, t3
    addi t2, t2, -1
    bnez t2, 1b
    la t0, snapshot_ring
    li t1, 0
    li t3, SNAPSHOT_RING
2:
    sw t1, 0(t0)                    # slot k holds buffer k
    addi t0, t0, 4
    addi t1, t1, 1
    bltu t1, t3, 2b
    la t0, snapshot_drawn
    sw t3, 0(t0)                    # the buffer past the ring, the frame in hand's
    la t0, snapshot_head
    sw zero, 0(t0)
    la t0, crc_table
    li t1, 0                        # the byte
    li t5, 0xedb88320
3:
    mv t2, t1
    li t3, 8
4:
    andi t4, t2, 1
    neg t4, t4
    and t4, t4, t5
    srli t2, t2, 1
    xor t2, t2, t4
    addi t3, t3, -1
    bnez t3, 4b
    sw t2, 0(t0)
    addi t0, t0, 4
    addi t1, t1, 1
    li t3, 256
    bltu t1, t3, 3b
    ret

snapshot_begin:
    la t0, snapshot_drawn
    lwu t1, 0(t0)
    snapshot_of t1, t2, t3
    sw a0, SNAP_FRAME(t2)
    li t1, -1
    sw t1, SNAP_SEQUENCE(t2)        # no packet yet
    sw zero, SNAP_SPAN_COUNT(t2)
    sw zero, SNAP_ACTOR_COUNT(t2)
    ret

.ifdef LEVELS
snapshot_spans:
    la t0, snapshot_drawn
    lwu t1, 0(t0)
    snapshot_of t1, t2, t3
    lw t1, SNAP_SEQUENCE(t2)
    addi t1, t1, 1
    sw t1, SNAP_SEQUENCE(t2)        # this packet's sequence in its frame
    la t0, span_count
    ld t1, 0(t0)
    sw t1, SNAP_SPAN_COUNT(t2)
    li t3, SNAP_SPANS
    add t3, t3, t2                  # the table
    la t0, span_records
    beqz t1, 2f
1:
    lhu t4, SPAN_X0(t0)
    sh t4, 0(t3)
    lhu t4, SPAN_X1(t0)
    sh t4, 2(t3)
    lhu t4, SPAN_ROW(t0)
    sh t4, 4(t3)
    addi t0, t0, SPAN_RECORD_SIZE
    addi t3, t3, SPAN_ENTRY
    addi t1, t1, -1
    bnez t1, 1b
2:
    ret
.endif

snapshot_actor:
    la t0, snapshot_drawn
    lwu t1, 0(t0)
    snapshot_of t1, t2, t3
    lwu t1, SNAP_ACTOR_COUNT(t2)
    li t3, MAX_ACTORS
    bgeu t1, t3, 1f                 # full
    addi t3, t1, 1
    sw t3, SNAP_ACTOR_COUNT(t2)
    li t3, SNAP_ACTOR_SIZE
    mul t3, t1, t3
    add t3, t3, t2
    addi t3, t3, SNAP_ACTORS        # the entry
    la t0, actors
    sub t1, a0, t0
    li t4, ACTOR_SIZE
    divu t1, t1, t4
    sw t1, SNAP_ACTOR_INDEX(t3)     # the index its OWNER surface carries
    la t0, actor_entity
    lw t1, ENTITY_X(t0)
    sw t1, SNAP_ACTOR_X(t3)
    lw t1, ENTITY_Y(t0)
    sw t1, SNAP_ACTOR_Y(t3)
    lw t1, ENTITY_Z(t0)
    sw t1, SNAP_ACTOR_Z(t3)
    lw t1, ENTITY_YAW(t0)
    sw t1, SNAP_ACTOR_YAW(t3)
    lw t1, ENTITY_WIDTH(t0)
    sw t1, SNAP_ACTOR_WIDTH(t3)
    lw t1, ENTITY_HEIGHT(t0)
    sw t1, SNAP_ACTOR_HEIGHT(t3)
    lw t1, ENTITY_MATERIAL(t0)
    sw t1, SNAP_ACTOR_MATERIAL(t3)
    lw t1, ENTITY_FLAGS(t0)
    sw t1, SNAP_ACTOR_FLAGS(t3)
    lw t1, ACTOR_ROW(a0)
    sw t1, SNAP_ACTOR_ROW(t3)
1:
    ret

snapshot_present:
    la t0, frame_clock
    ld t1, CLOCK_FLIP_STATUS(t0)
    bnez t1, 1f                     # unpresented: the ring stands
    la t0, snapshot_head
    lwu t1, 0(t0)                   # the oldest slot
    slli t2, t1, 2
    la t3, snapshot_ring
    add t2, t2, t3
    lwu t3, 0(t2)
    la t4, snapshot_drawn
    lwu t5, 0(t4)
    sw t5, 0(t2)                    # the frame presented takes the slot
    sw t3, 0(t4)                    # and the slot's buffer takes the next frame
    addi t1, t1, 1
    li t2, SNAPSHOT_RING
    bltu t1, t2, 2f
    li t1, 0
2:
    sw t1, 0(t0)
1:
    ret

snapshot_export:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s2, 0(sp)
    li s2, 0                        # the slots written, the oldest first
1:
    la t0, snapshot_head
    lwu t1, 0(t0)
    add t1, t1, s2
    li t2, SNAPSHOT_RING
    bltu t1, t2, 2f
    sub t1, t1, t2
2:
    slli t1, t1, 2
    la t0, snapshot_ring
    add t1, t1, t0
    lwu a0, 0(t1)
    call snapshot_write
    addi s2, s2, 1
    li t2, SNAPSHOT_RING
    bltu s2, t2, 1b
    ld ra, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 16
    ret

snapshot_write:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    snapshot_of a0, s2, t0
    lwu t0, SNAP_FRAME(s2)
    li t1, SNAPSHOT_NONE
    beq t0, t1, 9f                  # an empty slot
    la s3, snapshot_stage           # the record in hand
    li s4, 0                        # the entry
    lwu s5, SNAP_SPAN_COUNT(s2)
1:
    bgeu s4, s5, 4f
    mv a0, s3
    call record_clear
    li t0, REPORT_SPANS
    sw t0, REPORT_KIND(s3)
    lwu t0, SNAP_FRAME(s2)
    sw t0, REPORT_FRAME_NUMBER(s3)
    sw s4, SPANS_FIRST(s3)
    sub t1, s5, s4                  # the entries left
    li t2, SPANS_A_RECORD
    bleu t1, t2, 2f
    mv t1, t2
2:
    li t2, SPAN_ENTRY
    mul t3, s4, t2
    li t4, SNAP_SPANS
    add t3, t3, t4
    add t3, t3, s2                  # the record's first entry
    mul t1, t1, t2                  # and its entries' bytes
    addi t4, s3, SPANS_ENTRIES
3:
    lbu t5, 0(t3)
    sb t5, 0(t4)
    addi t3, t3, 1
    addi t4, t4, 1
    addi t1, t1, -1
    bnez t1, 3b
    li t0, REPORT_SCHEMA_VERSION
    sw t0, REPORT_SCHEMA(s3)
    addi s3, s3, REPORT_SIZE
    addi s4, s4, SPANS_A_RECORD
    j 1b
4:
    li s4, 0                        # the actor
    lwu s5, SNAP_ACTOR_COUNT(s2)
5:
    bgeu s4, s5, 7f
    mv a0, s3
    call record_clear
    li t0, REPORT_ACTOR
    sw t0, REPORT_KIND(s3)
    lwu t0, SNAP_FRAME(s2)
    sw t0, REPORT_FRAME_NUMBER(s3)
    li t0, SNAP_ACTOR_SIZE
    mul t1, s4, t0
    add t1, t1, s2
    addi t1, t1, SNAP_ACTORS        # the entry, its words as the record carries them
    addi t2, s3, ACTOR_RECORD
    li t3, (SNAP_ACTOR_SIZE / 4)
6:
    lw t4, 0(t1)
    sw t4, 0(t2)
    addi t1, t1, 4
    addi t2, t2, 4
    addi t3, t3, -1
    bnez t3, 6b
    li t0, REPORT_SCHEMA_VERSION
    sw t0, REPORT_SCHEMA(s3)
    addi s3, s3, REPORT_SIZE
    addi s4, s4, 1
    j 5b
7:
    mv a0, s3
    call record_clear
    li t0, REPORT_SNAPSHOT
    sw t0, REPORT_KIND(s3)
    lwu t0, SNAP_FRAME(s2)
    sw t0, REPORT_FRAME_NUMBER(s3)
    lwu t0, SNAP_SEQUENCE(s2)
    sw t0, SNAPSHOT_SEQUENCE(s3)
    lwu t0, SNAP_SPAN_COUNT(s2)
    sw t0, SNAPSHOT_COUNT(s3)
    lwu t0, SNAP_ACTOR_COUNT(s2)
    sw t0, SNAPSHOT_ACTORS(s3)
    li a0, 0xffffffff
    li a1, SNAP_SPANS
    add a1, a1, s2
    lwu t0, SNAP_SPAN_COUNT(s2)
    li t1, SPAN_ENTRY
    mul a2, t0, t1
    call crc32
    li t0, 0xffffffff
    xor a0, a0, t0
    sw a0, SNAPSHOT_CRC(s3)         # the table's CRC-32, its entries in order
    li t0, REPORT_SCHEMA_VERSION
    sw t0, REPORT_SCHEMA(s3)
    addi s3, s3, REPORT_SIZE
    la t0, snapshot_stage
    sub t1, s3, t0
    jab.sys.api.write t0, t1
9:
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 48
    ret

record_clear:
    sd zero, 0(a0)
    sd zero, 8(a0)
    sd zero, 16(a0)
    sd zero, 24(a0)
    sd zero, 32(a0)
    sd zero, 40(a0)
    sd zero, 48(a0)
    sd zero, 56(a0)
    ret

crc32:
    beqz a2, 2f
    la t0, crc_table
1:
    lbu t1, 0(a1)
    xor t1, t1, a0
    andi t1, t1, 0xff
    slli t1, t1, 2
    add t1, t1, t0
    lwu t1, 0(t1)
    srli a0, a0, 8
    xor a0, a0, t1
    addi a1, a1, 1
    addi a2, a2, -1
    bnez a2, 1b
2:
    ret

.section .bss
.balign 8
snapshots:
    .skip ((SNAPSHOT_RING + 1) * SNAPSHOT_SIZE)
snapshot_stage:
    .skip (SNAPSHOT_STAGE * REPORT_SIZE)
snapshot_ring:
    .skip (SNAPSHOT_RING * 4)
crc_table:
    .skip (256 * 4)
snapshot_drawn:
    .skip 4
snapshot_head:
    .skip 4

.endif
