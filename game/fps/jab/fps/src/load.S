# load.S: the map held to its format, and what a run carries beside
# it. map_parse takes the header and the section directory: the magic,
# every section within the file at its kind's record size and on a
# word boundary, each kind once and every kind present, the counts
# within the build's limits; each section's address and count go into
# `sections`. map_check holds the records to the format's rules: every
# name within the names table, every index in range, every loop three
# walls or more running around its sector, every portal exact, every
# entity inside the sector the file names by the loops and the spawn
# between its planes too, at least one spawn. materials_load decodes
# every material's texture off the disk into the pixel arena at the
# path its name composes, a missing one named on the UART and counted;
# ambients_load reads every ambient piece into its arena,
# soundfont_load puts the generic disk's soundfont into the
# synthesizer when the disk carries it, and ambient_follow plays the
# piece of the camera's sector. A fault says so on the UART and exits
# with its code.

.section .rodata
.balign 8
# A kind's record size and the most of it this build holds, by kind
# from 1, and the kind's word
kind_sizes:
    .word 1, MATERIAL_SIZE, VERTEX_SIZE, SECTOR_SIZE, LOOP_SIZE
    .word WALL_SIZE, PORTAL_SIZE, ENTITY_SIZE, AMBIENT_SIZE, SECTOR_LIGHT_SIZE
kind_limits:
    .word MAX_NAMES, MAX_MATERIALS, MAX_VERTICES, MAX_SECTORS, MAX_LOOPS
    .word MAX_WALLS, MAX_PORTALS, MAX_ENTITIES, MAX_AMBIENTS, MAX_SECTOR_LIGHTS
.balign 8
kind_words:
    .dword word_kind_names, word_kind_materials, word_kind_vertices
    .dword word_kind_sectors, word_kind_loops, word_kind_walls
    .dword word_kind_portals, word_kind_entities, word_kind_ambients
    .dword word_kind_sector_lights
k_slack_d:
    .double 0.001

.section .text

# map_parse: the header and the section directory held to the format,
# every section's address and count into `sections`; a fault exits.
map_parse:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    la s2, map
    la t0, map_bytes
    ld s3, 0(t0)
    li t0, MAP_HEADER_SIZE
    bltu s3, t0, short_file
    lwu t0, MAP_MAGIC_AT(s2)
    li t1, MAP_MAGIC
    bne t0, t1, bad_magic
    lwu s4, MAP_SECTION_COUNT(s2)   # the entries
    li t0, KIND_COUNT
    bgtu s4, t0, directory_count
    slli t0, s4, 4
    addi t0, t0, MAP_HEADER_SIZE
    bgtu t0, s3, short_file
    # the table and the kinds seen cleared
    la t0, sections
    li t1, (KIND_COUNT * SECTION_ENTRY)
    add t1, t1, t0
1:
    sd zero, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 1b
    la t0, kind_seen
    sd zero, 0(t0)
    sd zero, 8(t0)
    addi s5, s2, MAP_HEADER_SIZE    # the entry
2:
    beqz s4, 5f
    lwu t0, ENTRY_KIND(s5)
    beqz t0, directory_kind
    li t1, KIND_COUNT
    bgtu t0, t1, directory_kind
    addi t2, t0, -1                 # the kind from 0
    la t3, kind_seen
    add t3, t3, t2
    lbu t4, 0(t3)
    bnez t4, directory_twice
    li t4, 1
    sb t4, 0(t3)
    lwu t3, ENTRY_OFFSET(s5)
    andi t4, t3, 3
    bnez t4, directory_aligned
    lwu t4, ENTRY_SIZE(s5)
    la t5, kind_sizes
    slli t6, t2, 2
    add t5, t5, t6
    lwu t5, 0(t5)
    bne t4, t5, directory_size
    lwu t5, ENTRY_COUNT(s5)
    la t6, kind_limits
    slli t1, t2, 2
    add t6, t6, t1
    lwu t6, 0(t6)
    bgtu t5, t6, 3f
    mul t4, t4, t5                  # the section's bytes
    add t4, t4, t3                  # its end
    bgtu t4, s3, short_file
    add t3, t3, s2                  # its address
    la t4, sections
    li t6, SECTION_ENTRY
    mul t6, t2, t6
    add t4, t4, t6
    sd t3, SECTION_AT(t4)
    sd t5, SECTION_COUNT(t4)
    addi s5, s5, ENTRY_BYTES
    addi s4, s4, -1
    j 2b
3:
    la a1, kind_words
    slli t2, t2, 3
    add a1, a1, t2
    ld a1, 0(a1)
    j too_many
5:
    # every kind present
    la t0, kind_seen
    li t1, 0
6:
    li t2, KIND_COUNT
    bgeu t1, t2, 7f
    add t2, t0, t1
    lbu t2, 0(t2)
    beqz t2, directory_missing
    addi t1, t1, 1
    j 6b
7:
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 48
    ret

directory_count:
    la a1, word_directory_count
    j bad_directory

directory_kind:
    la a1, word_directory_kind
    j bad_directory

directory_twice:
    la a1, word_directory_twice
    j bad_directory

directory_aligned:
    la a1, word_directory_aligned
    j bad_directory

directory_size:
    la a1, word_directory_size
    j bad_directory

directory_missing:
    la a1, word_directory_missing
    j bad_directory

# name_check: a0 becomes 1 when the names table holds a NUL-terminated
# name at the offset a0, else 0. Clobbers t0 to t3.
name_check:
    section_count KIND_NAMES, t1
    bgeu a0, t1, 8f
    section_at KIND_NAMES, t0
    add t2, t0, a0                  # the name
    add t1, t0, t1                  # the table's end
1:
    bgeu t2, t1, 8f
    lbu t3, 0(t2)
    beqz t3, 9f
    addi t2, t2, 1
    j 1b
8:
    li a0, 0
    ret
9:
    li a0, 1
    ret

# map_check: the records held to the format's rules; the first record
# that breaks one is named on the UART and the program exits 11. The
# first spawn's index and the sprite count are taken on the way.
map_check:
    addi sp, sp, -112
    sd ra, 104(sp)
    sd s2, 96(sp)
    sd s3, 88(sp)
    sd s4, 80(sp)
    sd s5, 72(sp)
    sd s6, 64(sp)
    sd s7, 56(sp)
    sd s8, 48(sp)
    sd s9, 40(sp)
    sd s10, 32(sp)
    fsd fs0, 24(sp)
    fsd fs1, 16(sp)
    fsd fs2, 8(sp)
    # the names of the materials and the ambients within the table
    section_count KIND_MATERIALS, s7
    li s2, 0
1:
    bgeu s2, s7, 3f
    mv a0, s2
    call material_at
    lwu a0, MATERIAL_NAME(a0)
    call name_check
    bnez a0, 2f
    la a1, word_material
    mv a2, s2
    la a3, word_name_past
    j check_failed
2:
    addi s2, s2, 1
    j 1b
3:
    section_count KIND_AMBIENTS, s7
    li s2, 0
4:
    bgeu s2, s7, 6f
    li t0, AMBIENT_SIZE
    mul a0, s2, t0
    section_at KIND_AMBIENTS, t0
    add a0, a0, t0
    lwu a0, AMBIENT_NAME(a0)
    call name_check
    bnez a0, 5f
    la a1, word_ambient
    mv a2, s2
    la a3, word_name_past
    j check_failed
5:
    addi s2, s2, 1
    j 4b
6:
    # the sectors: their loops, lights, ambient, and materials in range;
    # every loop three walls or more, each wall the sector's own and
    # leading to the next around it
    section_count KIND_SECTORS, s7
    li s2, 0
10:
    bgeu s2, s7, 30f
    mv a0, s2
    call sector_at
    mv s3, a0
    lwu t0, SECTOR_FIRST_LOOP(s3)
    lwu t1, SECTOR_LOOP_COUNT(s3)
    beqz t1, 11f
    add t2, t0, t1
    section_count KIND_LOOPS, t3
    bgtu t2, t3, 11f
    j 12f
11:
    la a1, word_sector
    mv a2, s2
    la a3, word_loops_range
    j check_failed
12:
    lwu t0, SECTOR_FIRST_LIGHT(s3)
    lwu t1, SECTOR_LIGHT_COUNT(s3)
    add t2, t0, t1
    section_count KIND_SECTOR_LIGHTS, t3
    bleu t2, t3, 13f
    la a1, word_sector
    mv a2, s2
    la a3, word_lights_range
    j check_failed
13:
    lw t0, SECTOR_AMBIENT(s3)
    section_count KIND_AMBIENTS, t1
    blt t0, t1, 14f
    la a1, word_sector
    mv a2, s2
    la a3, word_ambient_range
    j check_failed
14:
    lw t0, (SECTOR_FLOOR_SURFACE + SURFACE_MATERIAL)(s3)
    lw t1, (SECTOR_CEILING_SURFACE + SURFACE_MATERIAL)(s3)
    section_count KIND_MATERIALS, t2
    bge t0, t2, 15f
    bge t1, t2, 15f
    j 16f
15:
    la a1, word_sector
    mv a2, s2
    la a3, word_materials_range
    j check_failed
16:
    lwu s4, SECTOR_FIRST_LOOP(s3)
    lwu s5, SECTOR_LOOP_COUNT(s3)
    add s5, s5, s4                  # past the last loop
17:
    bgeu s4, s5, 29f
    mv a0, s4
    call loop_at
    lwu s8, LOOP_FIRST_WALL(a0)
    lwu s9, LOOP_WALL_COUNT(a0)
    li t0, 3
    bgeu s9, t0, 18f
    la a1, word_loop
    mv a2, s4
    la a3, word_under_three
    j check_failed
18:
    add s9, s9, s8                  # past the last wall
    section_count KIND_WALLS, t0
    bleu s9, t0, 19f
    la a1, word_loop
    mv a2, s4
    la a3, word_walls_range
    j check_failed
19:
    mv s10, s8                      # the wall
20:
    bgeu s10, s9, 28f
    mv a0, s10
    call wall_at
    mv s6, a0
    lwu t0, WALL_SECTOR(s6)
    beq t0, s2, 21f
    la a1, word_wall
    mv a2, s10
    la a3, word_other_sector
    j check_failed
21:
    addi a0, s10, 1
    bltu a0, s9, 22f
    mv a0, s8
22:
    call wall_at                    # the next around the loop
    lwu t0, WALL_B(s6)
    lwu t1, WALL_A(a0)
    beq t0, t1, 23f
    la a1, word_wall
    mv a2, s10
    la a3, word_not_next
    j check_failed
23:
    addi s10, s10, 1
    j 20b
28:
    addi s4, s4, 1
    j 17b
29:
    addi s2, s2, 1
    j 10b
30:
    # the walls: vertices, sector, portals, and material in range, and
    # every portal exact: its wall in its sector, another sector than
    # the wall's, running the same two vertices back
    section_count KIND_WALLS, s7
    li s2, 0
31:
    bgeu s2, s7, 50f
    mv a0, s2
    call wall_at
    mv s3, a0
    lwu t0, WALL_A(s3)
    lwu t1, WALL_B(s3)
    section_count KIND_VERTICES, t2
    bgeu t0, t2, 32f
    bgeu t1, t2, 32f
    beq t0, t1, 32f
    j 33f
32:
    la a1, word_wall
    mv a2, s2
    la a3, word_vertices_range
    j check_failed
33:
    lwu t0, WALL_SECTOR(s3)
    section_count KIND_SECTORS, t1
    bltu t0, t1, 34f
    la a1, word_wall
    mv a2, s2
    la a3, word_sector_range
    j check_failed
34:
    lwu t0, WALL_FIRST_PORTAL(s3)
    lwu t1, WALL_PORTAL_COUNT(s3)
    add t2, t0, t1
    section_count KIND_PORTALS, t3
    bleu t2, t3, 35f
    la a1, word_wall
    mv a2, s2
    la a3, word_portals_range
    j check_failed
35:
    lw t0, (WALL_SURFACE + SURFACE_MATERIAL)(s3)
    section_count KIND_MATERIALS, t1
    blt t0, t1, 36f
    la a1, word_wall
    mv a2, s2
    la a3, word_material_range
    j check_failed
36:
    lwu s4, WALL_FIRST_PORTAL(s3)
    lwu s5, WALL_PORTAL_COUNT(s3)
    add s5, s5, s4
37:
    bgeu s4, s5, 49f
    mv a0, s4
    call portal_at
    mv s6, a0
    lwu t0, PORTAL_SECTOR(s6)
    lwu t1, PORTAL_WALL(s6)
    section_count KIND_SECTORS, t2
    bgeu t0, t2, 38f
    section_count KIND_WALLS, t2
    bgeu t1, t2, 38f
    j 39f
38:
    la a1, word_portal
    mv a2, s4
    la a3, word_out_of_range
    j check_failed
39:
    mv a0, t1
    call wall_at                    # the wall across
    lwu t0, WALL_SECTOR(a0)
    lwu t1, PORTAL_SECTOR(s6)
    bne t0, t1, 40f
    lwu t1, WALL_SECTOR(s3)
    beq t0, t1, 40f
    lwu t0, WALL_A(a0)
    lwu t1, WALL_B(s3)
    bne t0, t1, 40f
    lwu t0, WALL_B(a0)
    lwu t1, WALL_A(s3)
    bne t0, t1, 40f
    j 41f
40:
    la a1, word_portal
    mv a2, s4
    la a3, word_not_exact
    j check_failed
41:
    addi s4, s4, 1
    j 37b
49:
    addi s2, s2, 1
    j 31b
50:
    # the entities: class, material, target, and sector in range, each
    # inside its sector by the loops, the spawn between its planes too;
    # the first spawn and the sprites counted
    li t0, -1
    la t1, spawn_index
    sw t0, 0(t1)
    la t1, sprite_count
    sw zero, 0(t1)
    section_count KIND_ENTITIES, s7
    li s2, 0
51:
    bgeu s2, s7, 70f
    mv a0, s2
    call entity_at
    mv s3, a0
    lwu t0, ENTITY_CLASS(s3)
    li t1, CLASS_COUNT
    bltu t0, t1, 52f
    la a1, word_entity
    mv a2, s2
    la a3, word_class_unknown
    j check_failed
52:
    lw t0, ENTITY_MATERIAL(s3)
    section_count KIND_MATERIALS, t1
    bge t0, t1, 53f
    lw t0, ENTITY_TARGET(s3)
    bge t0, s7, 53f
    lw t0, ENTITY_SECTOR(s3)
    bltz t0, 53f
    section_count KIND_SECTORS, t1
    bge t0, t1, 53f
    j 54f
53:
    la a1, word_entity
    mv a2, s2
    la a3, word_references_range
    j check_failed
54:
    flw fa0, ENTITY_X(s3)
    fcvt.d.s fs0, fa0
    flw fa1, ENTITY_Y(s3)
    fcvt.d.s fs1, fa1
    flw fa2, ENTITY_Z(s3)
    fcvt.d.s fs2, fa2
    lw a0, ENTITY_SECTOR(s3)
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call sector_holds_plan
    bnez a0, 55f
    la a1, word_entity
    mv a2, s2
    la a3, word_outside_sector
    j check_failed
55:
    lwu t0, ENTITY_CLASS(s3)
    li t1, CLASS_SPRITE
    bne t0, t1, 56f
    la t1, sprite_count
    lwu t2, 0(t1)
    addi t2, t2, 1
    sw t2, 0(t1)
    j 59f
56:
    li t1, CLASS_SPAWN
    bne t0, t1, 59f
    la t1, spawn_index
    lw t2, 0(t1)
    bgez t2, 57f
    sw s2, 0(t1)
57:
    # between the planes, with a thousandth's slack
    lw a0, ENTITY_SECTOR(s3)
    li a1, 0
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height               # the floor
    la t0, k_slack_d
    fld ft0, 0(t0)
    fsub.d fa0, fa0, ft0
    flt.d t1, fs2, fa0
    bnez t1, 58f
    lw a0, ENTITY_SECTOR(s3)
    li a1, 1
    fmv.d fa0, fs0
    fmv.d fa1, fs1
    call plane_height               # the ceiling
    la t0, k_slack_d
    fld ft0, 0(t0)
    fadd.d fa0, fa0, ft0
    flt.d t1, fa0, fs2
    beqz t1, 59f
58:
    la a1, word_entity
    mv a2, s2
    la a3, word_outside_planes
    j check_failed
59:
    addi s2, s2, 1
    j 51b
70:
    la t0, spawn_index
    lw t0, 0(t0)
    bgez t0, 71f
    la a1, word_no_spawn
    j map_lacks
71:
    # the sector lights: each an entity that is a light
    section_count KIND_SECTOR_LIGHTS, s7
    section_at KIND_SECTOR_LIGHTS, s3
    li s2, 0
72:
    bgeu s2, s7, 79f
    lwu a0, 0(s3)
    section_count KIND_ENTITIES, t0
    bltu a0, t0, 73f
    la a1, word_sector_light
    mv a2, s2
    la a3, word_out_of_range
    j check_failed
73:
    call entity_at
    lwu t0, ENTITY_CLASS(a0)
    li t1, CLASS_LIGHT
    beq t0, t1, 74f
    la a1, word_sector_light
    mv a2, s2
    la a3, word_not_light
    j check_failed
74:
    addi s3, s3, SECTOR_LIGHT_SIZE
    addi s2, s2, 1
    j 72b
79:
    ld ra, 104(sp)
    ld s2, 96(sp)
    ld s3, 88(sp)
    ld s4, 80(sp)
    ld s5, 72(sp)
    ld s6, 64(sp)
    ld s7, 56(sp)
    ld s8, 48(sp)
    ld s9, 40(sp)
    ld s10, 32(sp)
    fld fs0, 24(sp)
    fld fs1, 16(sp)
    fld fs2, 8(sp)
    addi sp, sp, 112
    ret

# materials_load: every material's texture read off the disk at
# /<name>.png through material_read, its record into material_record;
# the counts into texture_count and missing_count.
materials_load:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    la t0, pixel_cursor
    la t1, pixels
    sd t1, 0(t0)
    la t0, texture_count
    sw zero, 0(t0)
    la t0, missing_count
    sw zero, 0(t0)
    section_count KIND_MATERIALS, s2
    li s3, 0                        # the material
1:
    bgeu s3, s2, 90f
    mv a0, s3
    call material_at
    lwu a0, MATERIAL_NAME(a0)
    call name_at
    mv s4, a0                       # the name
    call str_len
    addi t0, a1, 6                  # the slash, .png, and the terminator
    li t1, PATH_BYTES
    mv a0, s3
    bgtu t0, t1, path_too_long
    la a0, tile_path
    la a1, word_slash
    call append_str
    mv a1, s4
    call append_str
    la a1, word_png_ext
    call append_str
    sb zero, 0(a0)
    mv a0, s3
    la a1, msg_material
    call material_read
    la t0, material_record
    slli t1, s3, 3
    add t0, t0, t1
    sd a0, 0(t0)
    la t0, missing_count
    beqz a0, 2f
    la t0, texture_count
2:
    lwu t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    addi s3, s3, 1
    j 1b
90:
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 48
    ret

# material_read: the texture at the path in tile_path read whole off
# the disk and decoded into the pixel arena as the material a0, the
# index the UART names it by after the message at a1; a0 becomes its
# record, or 0 when the file is not there, that named on the UART as
# missing; a load that fails exits.
material_read:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    mv s2, a0                       # the index
    mv s5, a1                       # the message
    la a0, file
    li a1, FILE_BYTES
    mv a2, s0
    la a3, tile_path
    call read_file
    bnez a0, 30f
    # missing: named on the UART
    la a0, line
    mv a1, s5
    call append_str
    mv a1, s2
    call append_dec
    la a1, word_space
    call append_str
    la a1, tile_path
    call append_str
    la a1, word_missing_file
    call append_str
    call line_end
    li a0, 0
    j 90f
30:
    mv s3, a0                       # the file's bytes
    li t0, FILE_BYTES
    li a1, LOAD_TOO_BIG
    mv a0, s2
    bgeu s3, t0, load_failed
    la t0, file
    mv t1, s3
    jab.png.size t0, t1
    bnez a2, 35f
    # the record's capacity: the header, then a row's pixels and its
    # span for every row
    slli t0, a0, 2
    addi t0, t0, 4
    mul t0, t0, a1
    addi s4, t0, JAB_SPRITE_PIXELS
    la t1, pixel_cursor
    ld t2, 0(t1)
    add t3, t2, s4
    la t4, pixels
    li t5, PIXEL_BYTES
    add t4, t4, t5
    li a1, LOAD_ARENA_FULL
    mv a0, s2
    bgtu t3, t4, load_failed
    sd t3, 0(t1)
    sd t2, 0(sp)
    mv a0, t2
    la a1, file
    mv a2, s3
    mv a3, s4
    li a4, 1
    li a7, JAB_SYS_SPRITE_PNG
    ecall
    mv a1, a0
    mv a0, s2
    bnez a1, load_failed
    ld a0, 0(sp)
    j 90f
35:
    mv a1, a2
    mv a0, s2
    j load_failed
90:
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 48
    ret

# frames_load: the engine's own images, the android's frames, the
# sparks, and the magazine, read off the disk at /sprite/<stem>.png
# through material_read into the material records after the map's, the
# first at frame_base; `fps: frames N loaded, M missing` on the UART.
# The records must fit under the build's material count.
frames_load:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    section_count KIND_MATERIALS, t0
    la t1, frame_base
    sw t0, 0(t1)
    addi t1, t0, FRAME_COUNT
    li t2, MAX_MATERIALS
    la a1, word_kind_materials
    bgtu t1, t2, too_many
    li s2, 0                        # the frame
    li s4, 0                        # loaded
    li s5, 0                        # missing
1:
    li t0, FRAME_COUNT
    bgeu s2, t0, 9f
    la a0, tile_path
    la a1, word_sprite_dir
    call append_str
    li t0, FRAME_FALLEN
    bgeu s2, t0, 2f
    # a rotating set: android/<set>_<r>
    la a1, word_android_dir
    call append_str
    srli t0, s2, 3
    la t1, frame_sets
    slli t0, t0, 3
    add t1, t1, t0
    ld a1, 0(t1)
    call append_str
    li t0, '_'
    sb t0, 0(a0)
    addi a0, a0, 1
    andi t0, s2, 7
    addi t0, t0, '0'
    sb t0, 0(a0)
    addi a0, a0, 1
    j 3f
2:
    addi t0, s2, -FRAME_FALLEN
    la t1, frame_singles
    slli t0, t0, 3
    add t1, t1, t0
    ld a1, 0(t1)
    call append_str
3:
    la a1, word_png_ext
    call append_str
    sb zero, 0(a0)
    la t0, frame_base
    lwu s3, 0(t0)
    add s3, s3, s2                  # the material index
    mv a0, s2
    la a1, msg_frame_missing
    call material_read
    la t0, material_record
    slli t1, s3, 3
    add t0, t0, t1
    sd a0, 0(t0)
    beqz a0, 4f
    addi s4, s4, 1
    j 5f
4:
    addi s5, s5, 1
5:
    addi s2, s2, 1
    j 1b
9:
    la a0, line
    la a1, msg_frames
    call append_str
    mv a1, s4
    call append_dec
    la a1, word_loaded_comma
    call append_str
    mv a1, s5
    call append_dec
    la a1, word_missing
    call append_str
    call line_end
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 48
    ret

# ambients_load: every ambient piece read off the disk at /<name>.mid
# into its arena, its bytes and their count into ambient_at and
# ambient_bytes; a piece not there, too long a name, or one that does
# not fit is named on the UART and left as none. Nothing plays yet.
ambients_load:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    la t0, ambient_cursor
    la t1, ambient_arena
    sd t1, 0(t0)
    li t0, -1
    la t1, ambient_playing
    sw t0, 0(t1)
    section_count KIND_AMBIENTS, s2
    li s3, 0                        # the ambient
1:
    bgeu s3, s2, 90f
    li t0, AMBIENT_SIZE
    mul a0, s3, t0
    section_at KIND_AMBIENTS, t0
    add a0, a0, t0
    lwu a0, AMBIENT_NAME(a0)
    call name_at
    mv s4, a0
    call str_len
    addi t0, a1, 6
    li t1, PATH_BYTES
    bleu t0, t1, 2f
    la a1, word_name_too_long
    li a2, 0
    j 7f
2:
    la a0, tile_path
    la a1, word_slash
    call append_str
    mv a1, s4
    call append_str
    la a1, word_mid_ext
    call append_str
    sb zero, 0(a0)
    la t0, ambient_cursor
    ld a0, 0(t0)                    # the buffer
    la t1, ambient_arena
    li t2, AMBIENT_BYTES
    add t1, t1, t2
    sub s5, t1, a0                  # its room
    mv a1, s5
    mv a2, s0
    la a3, tile_path
    call read_file
    bnez a0, 3f
    la a1, word_missing_file
    li a2, 1
    j 7f
3:
    bltu a0, s5, 4f
    la a1, word_not_fit_arena
    li a2, 1
    j 7f
4:
    # kept, the cursor moved on to a word boundary
    la t0, ambient_cursor
    ld t1, 0(t0)
    la t2, ambient_at
    slli t3, s3, 3
    add t2, t2, t3
    sd t1, 0(t2)
    la t2, ambient_bytes
    add t2, t2, t3
    sd a0, 0(t2)
    add t1, t1, a0
    addi t1, t1, 3
    andi t1, t1, -4
    sd t1, 0(t0)
    j 9f
7:
    # named on the UART: `fps: ambient N <path> missing`, or with no
    # path when a2 is 0
    mv s5, a1
    mv s4, a2
    la a0, line
    la a1, msg_ambient
    call append_str
    mv a1, s3
    call append_dec
    beqz s4, 8f
    la a1, word_space
    call append_str
    la a1, tile_path
    call append_str
8:
    mv a1, s5
    call append_str
    call line_end
9:
    addi s3, s3, 1
    j 1b
90:
    ld ra, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    ld s5, 8(sp)
    addi sp, sp, 48
    ret

# soundfont_load: the generic disk's soundfont, FluidR3 GM at its path
# on the disk of serial mix, read in pages into its arena and put into
# the synthesizer, its counts on the UART; without the disk or the
# file the chip voices play, and the UART says so.
soundfont_load:
    addi sp, sp, -32
    sd ra, 24(sp)
    jab.block.find serial_mix
    beqz a0, 8f
    mv a2, a0
    la a0, font
    li a1, FONT_BYTES
    la a3, path_font
    call read_file
    beqz a0, 8f
    la t0, font
    mv t1, a0
    jab.midi.soundfont t0, t1
    bnez a0, 7f
    sd a1, 0(sp)
    sd a2, 8(sp)
    sd a3, 16(sp)
    la a0, line
    la a1, msg_soundfont
    call append_str
    ld a1, 0(sp)
    call append_dec
    la a1, word_presets
    call append_str
    ld a1, 8(sp)
    call append_dec
    la a1, word_instruments
    call append_str
    ld a1, 16(sp)
    call append_dec
    la a1, word_samples
    call append_str
    call line_end
    j 9f
7:
    sd a0, 0(sp)
    la a0, line
    la a1, msg_soundfont_refused
    call append_str
    ld a1, 0(sp)
    call append_dec
    call line_end
    j 9f
8:
    jab.uart.print msg_no_soundfont
9:
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

# ambient_follow: the piece of the camera's sector played: when its
# ambient is not the one playing, the one playing stops and the new one
# starts, said on the UART with its index, or the code the player
# refused it with; a piece that has ended starts again; a sector with
# no ambient, or the camera in none, plays nothing.
ambient_follow:
    addi sp, sp, -32
    sd ra, 24(sp)
    la t0, cam_sector
    lw a0, 0(t0)
    section_count KIND_SECTORS, t1
    li t2, -1
    bgeu a0, t1, 1f
    call sector_at
    lw t2, SECTOR_AMBIENT(a0)
1:
    la t0, ambient_playing
    lw t1, 0(t0)
    beq t1, t2, 5f
    sw t2, 0(t0)
    bltz t2, 3f
    la t3, ambient_at
    slli t4, t2, 3
    add t3, t3, t4
    ld a0, 0(t3)
    beqz a0, 3f
    la t3, ambient_bytes
    add t3, t3, t4
    ld a1, 0(t3)
    sd t2, 0(sp)
    jab.midi.play a0, a1
    sd a0, 8(sp)
    la a0, line
    la a1, msg_ambient
    call append_str
    ld a1, 0(sp)
    call append_dec
    ld t0, 8(sp)
    beqz t0, 2f
    la a1, word_refused
    call append_str
    ld a1, 8(sp)
    call append_dec
    j 21f
2:
    la a1, word_playing
    call append_str
21:
    call line_end
    j 9f
3:
    jab.midi.stop
    j 9f
5:
    bltz t2, 9f
    la t3, ambient_at
    slli t4, t2, 3
    add t3, t3, t4
    ld t5, 0(t3)
    beqz t5, 9f
    sd t2, 0(sp)
    jab.midi.playing
    bnez a0, 9f
    ld t2, 0(sp)
    la t3, ambient_at
    slli t4, t2, 3
    add t3, t3, t4
    ld a0, 0(t3)
    la t3, ambient_bytes
    add t3, t3, t4
    ld a1, 0(t3)
    jab.midi.play a0, a1
9:
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

.section .bss
.balign 8
kind_seen:
    .skip 16
ambient_playing:
    .skip 4
# The material index of the engine's first image, after the map's
frame_base:
    .skip 4

.section .rodata
word_kind_names:
    .asciz "names"
word_kind_materials:
    .asciz "materials"
word_kind_vertices:
    .asciz "vertices"
word_kind_sectors:
    .asciz "sectors"
word_kind_loops:
    .asciz "loops"
word_kind_walls:
    .asciz "walls"
word_kind_portals:
    .asciz "portals"
word_kind_entities:
    .asciz "entities"
word_kind_ambients:
    .asciz "ambients"
word_kind_sector_lights:
    .asciz "sector lights"
word_directory_count:
    .asciz "holds more sections than the format has kinds"
word_directory_kind:
    .asciz "names a kind the format lacks"
word_directory_twice:
    .asciz "names a kind twice"
word_directory_aligned:
    .asciz "puts a section off a word boundary"
word_directory_size:
    .asciz "gives a section a record size the format does not"
word_directory_missing:
    .asciz "lacks a kind"
word_material:
    .asciz "material "
word_ambient:
    .asciz "ambient "
word_sector:
    .asciz "sector "
word_loop:
    .asciz "loop "
word_wall:
    .asciz "wall "
word_portal:
    .asciz "portal "
word_entity:
    .asciz "entity "
word_sector_light:
    .asciz "sector light "
word_name_past:
    .asciz "'s name lies past the names table"
word_loops_range:
    .asciz "'s loops are out of range"
word_lights_range:
    .asciz "'s lights are out of range"
word_ambient_range:
    .asciz "'s ambient is out of range"
word_materials_range:
    .asciz "'s materials are out of range"
word_under_three:
    .asciz " has under three walls"
word_walls_range:
    .asciz "'s walls are out of range"
word_other_sector:
    .asciz " belongs to another sector than its loop's"
word_not_next:
    .asciz " does not lead to the next around its loop"
word_vertices_range:
    .asciz "'s vertices are out of range or the same"
word_sector_range:
    .asciz "'s sector is out of range"
word_portals_range:
    .asciz "'s portals are out of range"
word_material_range:
    .asciz "'s material is out of range"
word_out_of_range:
    .asciz " is out of range"
word_not_exact:
    .asciz " is not exact"
word_class_unknown:
    .asciz "'s class is not one the format has"
word_references_range:
    .asciz "'s references are out of range"
word_outside_sector:
    .asciz " is not in its sector"
word_outside_planes:
    .asciz " is not between its sector's planes"
word_not_light:
    .asciz " is not a light"
word_no_spawn:
    .asciz " has no spawn"
serial_mix:
    .asciz "mix"
path_font:
    .asciz "/mix/snd/font/FluidR3_GM.sf2"
msg_soundfont:
    .asciz "fps: soundfont "
word_presets:
    .asciz " presets, "
word_instruments:
    .asciz " instruments, "
word_samples:
    .asciz " samples"
msg_soundfont_refused:
    .asciz "fps: soundfont refused "
msg_no_soundfont:
    .asciz "fps: soundfont none, the chip voices play\n"
word_playing:
    .asciz " playing"
word_refused:
    .asciz " refused "
word_sprite_dir:
    .asciz "/sprite/"
word_android_dir:
    .asciz "android/"
msg_frames:
    .asciz "fps: frames "
msg_frame_missing:
    .asciz "fps: frame "
word_loaded_comma:
    .asciz " loaded, "
