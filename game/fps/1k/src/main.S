.include "jab.inc"
.include "jab_f32.inc"
.include "jab_f64.inc"
.include "jab_rng.inc"
.include "src/map.inc"
.include "src/render.inc"

.set MAP_BYTES, (1024 * 1024)
.set FILE_BYTES, (2 * 1024 * 1024)
.set PIXEL_BYTES, (64 * 1024 * 1024)
.set AMBIENT_BYTES, (4 * 1024 * 1024)
.set FONT_BYTES, (160 * 1024 * 1024)
.set PAGE_BYTES, (1024 * 1024)
.set NAME_BYTES, 64
.set PATH_BYTES, 256
.set LINE_BYTES, 512
.set DIGITS_BYTES, 24
.set TITLE_SCALE, (JAB_TEXT_SCALE_ONE * 4)
.set TITLE_CELL, (JAB_TEXT_WIDTH * 4)
.set TITLE_HEIGHT, (JAB_TEXT_HEIGHT * 4)
.set TITLE_Y, ((JAB_DISPLAY_HEIGHT - TITLE_HEIGHT) / 2)
.set TITLE_COLOR, 0x00ebe6dc
.set MS_TICKS, (JAB_TIME_HZ / 1000)
.set US_TICKS, (JAB_TIME_HZ / 1000000)
.set LOAD_TOO_BIG, 101
.set LOAD_ARENA_FULL, 102
.set CLOCK_ORIGIN, 0
.set CLOCK_START, 8
.set CLOCK_REPORT, 16
.set CLOCK_HUD, 24
.set CLOCK_MIX, 32
.set CLOCK_FLIP, 40
.set CLOCK_FLIP_DONE, 48
.set CLOCK_AWAIT, 56
.set CLOCK_FLIP_STATUS, 64
.set CLOCK_SIZE, 72

.section .text
.global _start
_start:
    rdtime s11                      # the start
    jab.sys.display.open
    bnez a0, no_display
    jab.sys.sound.open
    bnez a0, no_sound
    jab.sys.block.find serial_fps
    beqz a0, no_disk
    mv s0, a0                       # the program's disk
    la a0, name
    li a1, (NAME_BYTES - 1)
    mv a2, s0
    la a3, path_name
    call read_file
    beqz a0, no_name
    la t0, name
    add t1, t0, a0
    sb zero, 0(t1)
1:
    beq t1, t0, 2f
    lbu t2, -1(t1)
    li t3, ' '
    bgtu t2, t3, 2f
    addi t1, t1, -1
    sb zero, 0(t1)
    j 1b
2:
    la a0, map_path
    la a1, word_map_dir
    call append_str
    la a1, name
    call append_str
    la a1, word_map_ext
    call append_str
    sb zero, 0(a0)
    la a0, name
    call str_len
    li t1, TITLE_CELL
    mul t1, a1, t1
    addi t1, t1, 1
    li t2, JAB_DISPLAY_WIDTH
    sub t2, t2, t1
    srli a1, t2, 1
    li a2, TITLE_Y
    li a3, TITLE_COLOR
    li a4, JAB_TEXT_BOLD
    li a5, TITLE_SCALE
    li a7, JAB_SYS_DISPLAY_TEXT
    ecall
    jab.sys.display.await
    jab.sys.display.flip
    la a0, map
    li a1, MAP_BYTES
    mv a2, s0
    la a3, map_path
    call read_file
    beqz a0, no_map
    li t0, MAP_BYTES
    bgeu a0, t0, map_too_big
    la t0, map_bytes
    sd a0, 0(t0)
    call map_parse
    call map_check
    call materials_load
    call frames_load
    call alphas_measure
    call mips_build
    call ambients_load
    call sounds_load
    call soundfont_load
    call lights_gather
    call lumaps_bake
    call tiles_reset
    la t0, tile_budget_frame
    li t1, TILE_BUDGET
    sd t1, 0(t0)
    call actors_place
    call player_reset
    call camera_spawn
    call camera_axes
    call clear_screen
    jab.sys.display.await
    jab.sys.display.flip
.ifdef DEBUG
    rdtime t0
    sub t0, t0, s11
    li t1, MS_TICKS
    divu s5, t0, t1                 # the milliseconds
    call load_report
.endif
    li s8, 0                        # the frames drawn
    rdtime s7                       # the frame before's time
    la t0, frame_clock
    sd s11, CLOCK_ORIGIN(t0)        # the program's start
frame:
    rdtime s9                       # the frame's start, the await's end
    beqz s8, 1f
    mv a0, s9
    addi a1, s8, -1
    call frame_records              # the frame before's two records
1:
    rdtime t0
    la t1, frame_clock
    sd s9, CLOCK_START(t1)
    sub t2, t0, s9
    sd t2, CLOCK_REPORT(t1)         # the records, the reporting so far
    sub t1, t0, s7
    mv s7, t0
    fcvt.s.l fa0, t1
    la t0, k_seconds_a_tick
    flw ft0, 0(t0)
    fmul.s fa0, fa0, ft0            # the seconds since the frame before
    la t0, k_dt_max
    flw ft0, 0(t0)
    fmin.s fa0, fa0, ft0
    la t0, frame_seconds
    fsw fa0, 0(t0)
    rdtime s9
    call camera_look
    call console_read
    call camera_locate
    call camera_basis
    call actors_tick
    call player_pickups
    call ambient_follow
    rdtime t0
    sub t0, t0, s9
    li t1, US_TICKS
    divu t0, t0, t1
    la t1, game_us
    sw t0, 0(t1)                    # the game's microseconds
    rdtime s9
    call world_draw
    rdtime t0
    sub s10, t0, s9                 # the frame's ticks
    li t1, US_TICKS
    divu t0, s10, t1
    la t1, frame_us
    sw t0, 0(t1)                    # the drawing's microseconds
    rdtime s9
.ifndef OWNER
    call hud_draw
.endif
    rdtime t0
    la t1, frame_clock
    sub t2, t0, s9
    sd t2, CLOCK_HUD(t1)
    mv s9, t0
    call mixer_update
    rdtime t0
    la t1, frame_clock
    sub t2, t0, s9
    sd t2, CLOCK_MIX(t1)
    mv s9, t0
    jab.sys.display.flip
    rdtime t0
    la t1, frame_clock
    sd a0, CLOCK_FLIP_STATUS(t1)
    sub t2, t0, s9
    sd t2, CLOCK_FLIP(t1)
    sd t0, CLOCK_FLIP_DONE(t1)
    mv s9, t0
    call state_report
.ifdef DEBUG
    la t0, report_pending
    lbu t1, 0(t0)
    sb zero, 0(t0)
    beqz s8, 2f
    beqz t1, 1f
2:
    call frame_report
.ifdef COUNT
    call count_report
.endif
    call sectors_report
1:
.endif
    rdtime t0
    la t1, frame_clock
    sub t2, t0, s9
    ld t3, CLOCK_REPORT(t1)
    add t3, t3, t2
    sd t3, CLOCK_REPORT(t1)
    sd t0, CLOCK_AWAIT(t1)          # the critical path's end, the await's start
    addi s8, s8, 1
    jab.sys.await (JAB_AWAIT_DISPLAY | JAB_AWAIT_PAD)
    j frame

no_display:
    jab.sys.uart.print msg_no_display
    jab.sys.exit 1

no_sound:
    jab.sys.uart.print msg_no_sound
    jab.sys.exit 2

no_disk:
    jab.sys.uart.print msg_no_disk
    jab.sys.exit 3

no_name:
    jab.sys.uart.print msg_no_name
    jab.sys.exit 4

no_map:
    call line_map
    la a1, word_not_on_disk
    call append_str
    call line_end
    jab.sys.exit 5

bad_magic:
    call line_map
    la a1, word_not_map
    call append_str
    call line_end
    jab.sys.exit 6

short_file:
    call line_map
    la a1, word_ends_at
    call append_str
    la t0, map_bytes
    ld a1, 0(t0)
    call append_dec
    la a1, word_before_structures
    call append_str
    call line_end
    jab.sys.exit 7

map_too_big:
    call line_map
    la a1, word_not_fit
    call append_str
    li a1, MAP_BYTES
    call append_dec
    la a1, word_bytes
    call append_str
    call line_end
    jab.sys.exit 7

too_many:
    mv s6, a1
    call line_map
    la a1, word_holds_more
    call append_str
    mv a1, s6
    call append_str
    la a1, word_than_build
    call append_str
    call line_end
    jab.sys.exit 8

path_too_long:
    mv s6, a0
    la a0, line
    la a1, msg_material
    call append_str
    mv a1, s6
    call append_dec
    la a1, word_name_too_long
    call append_str
    call line_end
    jab.sys.exit 9

load_failed:
    mv s6, a1
    mv s7, a0
    la a0, line
    la a1, msg_load_failed
    call append_str
    mv a1, s7
    call append_dec
    la a1, word_code
    call append_str
    mv a1, s6
    call append_dec
    call line_end
    jab.sys.exit 10

check_failed:
    mv s6, a1
    mv s7, a2
    mv s8, a3
    call line_map
    la a1, word_colon
    call append_str
    mv a1, s6
    call append_str
    mv a1, s7
    call append_dec
    mv a1, s8
    call append_str
    call line_end
    jab.sys.exit 11

map_lacks:
    mv s6, a1
    call line_map
    mv a1, s6
    call append_str
    call line_end
    jab.sys.exit 11

bad_directory:
    mv s6, a1
    call line_map
    la a1, word_directory
    call append_str
    mv a1, s6
    call append_str
    call line_end
    jab.sys.exit 12

line_map:
    la a0, line
    la a1, msg_prefix
    mv t1, ra
    call append_str
    la a1, map_path
    call append_str
    mv ra, t1
    ret

line_end:
    li t0, '\n'
    sb t0, 0(a0)
    sb zero, 1(a0)
    jab.sys.uart.print line
    ret

frame_records:
    mv t5, a1                       # the frame's number, past the writes
    la t0, frame_clock
    la t1, record_pair
    li t2, REPORT_FRAME
    sw t2, REPORT_KIND(t1)
    sw t5, REPORT_FRAME_NUMBER(t1)
    li t2, REPORT_SCHEMA_VERSION
    sw t2, REPORT_SCHEMA(t1)
    li t6, US_TICKS
    ld t2, CLOCK_START(t0)
    ld t3, CLOCK_ORIGIN(t0)
    sub t4, t2, t3
    divu t4, t4, t6
    sd t4, TIME_START(t1)
    ld t3, CLOCK_AWAIT(t0)
    sub t4, t3, t2
    divu t4, t4, t6
    sw t4, TIME_CRITICAL(t1)
    sub t4, a0, t3
    divu t4, t4, t6
    sw t4, TIME_AWAIT(t1)
    la t2, game_us
    lwu t3, 0(t2)
    sw t3, TIME_GAME(t1)
    la t2, frame_us
    lwu t3, 0(t2)
    sw t3, TIME_DRAW(t1)
    ld t3, CLOCK_HUD(t0)
    divu t3, t3, t6
    sw t3, TIME_HUD(t1)
    ld t3, CLOCK_MIX(t0)
    divu t3, t3, t6
    sw t3, TIME_MIX(t1)
    ld t3, CLOCK_FLIP(t0)
    divu t3, t3, t6
    sw t3, TIME_FLIP(t1)
    ld t3, CLOCK_REPORT(t0)
    divu t3, t3, t6
    sw t3, TIME_REPORT(t1)
    ld t3, CLOCK_FLIP_DONE(t0)
    ld t4, CLOCK_ORIGIN(t0)
    sub t3, t3, t4
    divu t3, t3, t6
    sd t3, TIME_FLIP_DONE(t1)
    ld t3, CLOCK_FLIP_STATUS(t0)
    sw t3, TIME_FLIP_STATUS(t1)
    addi t1, t1, REPORT_SIZE        # the draw record
    li t2, REPORT_DRAW
    sw t2, REPORT_KIND(t1)
    sw t5, REPORT_FRAME_NUMBER(t1)
    li t2, REPORT_SCHEMA_VERSION
    sw t2, REPORT_SCHEMA(t1)
    la t0, stats
    ld t3, STAT_CLEAR_TICKS(t0)
    divu t3, t3, t6
    sw t3, DRAW_CLEAR(t1)
    ld t3, STAT_PORTAL_TICKS(t0)
    divu t3, t3, t6
    sw t3, DRAW_PORTALS(t1)
    ld t3, STAT_PLANE_TICKS(t0)
    divu t3, t3, t6
    sw t3, DRAW_PLANES(t1)
    ld t3, STAT_WALL_TICKS(t0)
    divu t3, t3, t6
    sw t3, DRAW_WALLS(t1)
    ld t3, STAT_SPRITE_TICKS(t0)
    divu t3, t3, t6
    sw t3, DRAW_SPRITES(t1)
    ld t3, STAT_TILE_TICKS(t0)
    divu t3, t3, t6
    sw t3, DRAW_TILES(t1)
    ld t3, STAT_TILES_BUILT(t0)
    sw t3, DRAW_TILES_BUILT(t1)
    ld t3, STAT_TILE_RESETS(t0)
    sw t3, DRAW_TILE_RESETS(t1)
    ld t3, STAT_TILED_PIXELS(t0)
    sw t3, DRAW_TILED_PIXELS(t1)
    ld t3, STAT_LIT_PIXELS(t0)
    sw t3, DRAW_LIT_PIXELS(t1)
    ld t3, STAT_SPANS(t0)
    sw t3, DRAW_SPANS(t1)
    la t2, tile_cursor
    ld t3, 0(t2)
    la t2, tile_arena
    sub t3, t3, t2
    sw t3, DRAW_TILE_BYTES(t1)
    la t2, tile_peak
    ld t3, 0(t2)
    sw t3, DRAW_TILE_PEAK(t1)
    la t0, record_pair
    li t1, (REPORT_SIZE * 2)
    jab.sys.api.write t0, t1
    la t0, measure_end
    lbu t1, 0(t0)
    beqz t1, 9f
    sb zero, 0(t0)
    la t0, end_record               # the measurement closed on this frame
    li t1, REPORT_END
    sw t1, REPORT_KIND(t0)
    sw t5, REPORT_FRAME_NUMBER(t0)
    li t1, REPORT_SCHEMA_VERSION
    sw t1, REPORT_SCHEMA(t0)
    li t1, REPORT_SIZE
    jab.sys.api.write t0, t1
9:
    ret

.ifdef DEBUG
load_report:
    addi sp, sp, -16
    sd ra, 8(sp)
    la a0, line
    la a1, msg_prefix
    call append_str
    la a1, name
    call append_str
    la a1, word_loaded
    call append_str
    mv a1, s5
    call append_dec
    la a1, word_ms
    call append_str
    section_count KIND_SECTORS, a1
    call append_dec
    la a1, word_sectors
    call append_str
    section_count KIND_WALLS, a1
    call append_dec
    la a1, word_walls
    call append_str
    section_count KIND_VERTICES, a1
    call append_dec
    la a1, word_vertices
    call append_str
    section_count KIND_PORTALS, a1
    call append_dec
    la a1, word_portals
    call append_str
    section_count KIND_ENTITIES, a1
    call append_dec
    la a1, word_entities
    call append_str
    la t0, light_count
    lwu a1, 0(t0)
    call append_dec
    la a1, word_lights
    call append_str
    la t0, lumap_count
    ld a1, 0(t0)
    call append_dec
    la a1, word_lumel_maps
    call append_str
    la t0, sprite_count
    lwu a1, 0(t0)
    call append_dec
    la a1, word_sprites
    call append_str
    section_count KIND_MATERIALS, a1
    call append_dec
    la a1, word_materials
    call append_str
    la t0, texture_count
    lwu a1, 0(t0)
    call append_dec
    la a1, word_textures
    call append_str
    la t0, missing_count
    lwu a1, 0(t0)
    call append_dec
    la a1, word_missing
    call append_str
    call line_end
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

frame_report:
    addi sp, sp, -16
    sd ra, 8(sp)
    la a0, line
    la a1, msg_frame
    call append_str
    li t0, US_TICKS
    divu a1, s10, t0
    call append_dec
    la a1, word_us
    call append_str
    la t0, stats
    ld a1, STAT_SECTORS(t0)
    call append_dec
    la a1, word_sectors
    call append_str
    la t0, stats
    ld a1, STAT_WALLS(t0)
    call append_dec
    la a1, word_walls
    call append_str
    la t0, stats
    ld a1, STAT_PIECES(t0)
    call append_dec
    la a1, word_pieces
    call append_str
    la t0, stats
    ld a1, STAT_PLANES(t0)
    call append_dec
    la a1, word_planes
    call append_str
    la t0, stats
    ld a1, STAT_OPENINGS(t0)
    call append_dec
    la a1, word_openings
    call append_str
    la t0, stats
    ld a1, STAT_SPRITES(t0)
    call append_dec
    la a1, word_sprites
    call append_str
    sd a0, 0(sp)
    call uncovered
    mv a1, a0
    ld a0, 0(sp)
    call append_dec
    la a1, word_uncovered
    call append_str
    la t0, stats
    ld a1, STAT_CLEAR_TICKS(t0)
    li t0, US_TICKS
    divu a1, a1, t0
    call append_dec
    la a1, word_comma
    call append_str
    la t0, stats
    ld a1, STAT_PLANE_TICKS(t0)
    li t0, US_TICKS
    divu a1, a1, t0
    call append_dec
    la a1, word_comma
    call append_str
    la t0, stats
    ld a1, STAT_WALL_TICKS(t0)
    li t0, US_TICKS
    divu a1, a1, t0
    call append_dec
    la a1, word_comma
    call append_str
    la t0, stats
    ld a1, STAT_PORTAL_TICKS(t0)
    li t0, US_TICKS
    divu a1, a1, t0
    call append_dec
    la a1, word_comma
    call append_str
    la t0, stats
    ld a1, STAT_SPRITE_TICKS(t0)
    li t0, US_TICKS
    divu a1, a1, t0
    call append_dec
    la a1, word_spans
    call append_str
    la t0, stats
    ld a1, STAT_SPANS(t0)
    call append_dec
    la a1, word_pixels
    call append_str
    la t0, stats
    ld a1, STAT_PIXELS(t0)
    call append_dec
    la a1, word_lit_spans
    call append_str
    la t0, stats
    ld a1, STAT_LIT_SPANS(t0)
    call append_dec
    la a1, word_lit_pixels
    call append_str
    la t0, stats
    ld a1, STAT_LIT_PIXELS(t0)
    call append_dec
    la a1, word_light_us
    call append_str
    la t0, stats
    ld a1, STAT_LIGHT_TICKS(t0)
    li t0, US_TICKS
    divu a1, a1, t0
    call append_dec
    la a1, word_rejected
    call append_str
    la t0, stats
    ld a1, STAT_REJECTED(t0)
    call append_dec
    la a1, word_lumel_samples
    call append_str
    la t0, stats
    ld a1, STAT_SAMPLES(t0)
    call append_dec
    la a1, word_tiles_built
    call append_str
    la t0, stats
    ld a1, STAT_TILES_BUILT(t0)
    call append_dec
    la a1, word_tiled
    call append_str
    la t0, stats
    ld a1, STAT_TILED_PIXELS(t0)
    call append_dec
    la a1, word_resets
    call append_str
    la t0, stats
    ld a1, STAT_TILE_RESETS(t0)
    call append_dec
    call line_end
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.ifdef COUNT
count_report:
    addi sp, sp, -16
    sd ra, 8(sp)
    la a0, line
    la a1, msg_count
    call append_str
    la t0, count_stats
    ld a1, COUNT_DIVIDES(t0)
    call append_dec
    la a1, word_count_avoided
    call append_str
    la t0, count_stats
    ld a1, COUNT_AVOIDED(t0)
    call append_dec
    la a1, word_count_shifted
    call append_str
    la t0, count_stats
    ld a1, COUNT_SHIFTED(t0)
    call append_dec
    la a1, word_count_short
    call append_str
    la t0, count_stats
    ld a1, COUNT_SHORT(t0)
    call append_dec
    la a1, word_count_negative_u
    call append_str
    la t0, count_stats
    ld a1, COUNT_NEGATIVE_U(t0)
    call append_dec
    la a1, word_count_negative_v
    call append_str
    la t0, count_stats
    ld a1, COUNT_NEGATIVE_V(t0)
    call append_dec
    la a1, word_count_flat
    call append_str
    la t0, count_stats
    ld a1, COUNT_FLAT(t0)
    call append_dec
    la a1, word_count_mismatches
    call append_str
    la t0, count_stats
    ld a1, COUNT_MISMATCHES(t0)
    call append_dec
    call line_end
    ld ra, 8(sp)
    addi sp, sp, 16
    ret
.endif

sectors_report:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s2, 16(sp)
    sd s3, 8(sp)
    la a0, line
    la a1, msg_sectors
    call append_str
    la t0, walk_tail
    ld s3, 0(t0)
    li s2, 0
1:
    bgeu s2, s3, 2f
    la t0, walk_fifo
    slli t1, s2, 2
    add t0, t0, t1
    lwu a1, 0(t0)
    call append_dec
    la a1, word_space
    call append_str
    addi s2, s2, 1
    j 1b
2:
    call line_end
    ld ra, 24(sp)
    ld s2, 16(sp)
    ld s3, 8(sp)
    addi sp, sp, 32
    ret
.endif

sector_at:
    li t0, SECTOR_SIZE
    mul a0, a0, t0
    section_at KIND_SECTORS, t0
    add a0, a0, t0
    ret

loop_at:
    li t0, LOOP_SIZE
    mul a0, a0, t0
    section_at KIND_LOOPS, t0
    add a0, a0, t0
    ret

wall_at:
    li t0, WALL_SIZE
    mul a0, a0, t0
    section_at KIND_WALLS, t0
    add a0, a0, t0
    ret

vertex_at:
    li t0, VERTEX_SIZE
    mul a0, a0, t0
    section_at KIND_VERTICES, t0
    add a0, a0, t0
    ret

portal_at:
    li t0, PORTAL_SIZE
    mul a0, a0, t0
    section_at KIND_PORTALS, t0
    add a0, a0, t0
    ret

entity_at:
    li t0, ENTITY_SIZE
    mul a0, a0, t0
    section_at KIND_ENTITIES, t0
    add a0, a0, t0
    ret

material_at:
    li t0, MATERIAL_SIZE
    mul a0, a0, t0
    section_at KIND_MATERIALS, t0
    add a0, a0, t0
    ret

name_at:
    section_at KIND_NAMES, t0
    add a0, a0, t0
    ret

clear_screen:
    li a0, 0
fill_screen:
    slli t2, a0, 32
    or t2, t2, a0
    li t0, JAB_DISPLAY_BASE
    li t1, JAB_DISPLAY_SIZE
    add t1, t1, t0
1:
    sd t2, 0(t0)
    sd t2, 8(t0)
    addi t0, t0, 16
    bltu t0, t1, 1b
    ret

read_file:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    mv s0, a0                       # the buffer
    mv s1, a1                       # its room
    mv s2, a2                       # the disk
    la a0, rec
    mv a1, s2
    li a2, JAB_ROMFS_ROOT
    li a7, JAB_SYS_ROMFS_FIND
    ecall
    bnez a0, 8f
    la t0, rec
    lwu s3, JAB_ROMFS_OFFSET(t0)
    li s4, 0                        # the byte of the file to read from
    li a4, 0                        # how much is here
1:
    sub t4, s1, a4
    li t5, PAGE_BYTES
    bleu t4, t5, 2f
    mv t4, t5
2:
    beqz t4, 3f
    add t0, s0, a4
    mv t1, s2
    mv t2, s3
    mv t3, s4
    sd a4, 8(sp)
    jab.sys.romfs.read t0, t1, t2, t3, t4
    ld a4, 8(sp)
    beqz a0, 3f
    add a4, a4, a0
    mv s4, a1
    bnez s4, 1b
3:
    mv a0, a4
    j 9f
8:
    li a0, 0
9:
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 64
    ret

str_len:
    li a1, 0
1:
    add t0, a0, a1
    lbu t0, 0(t0)
    beqz t0, 2f
    addi a1, a1, 1
    j 1b
2:
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
    addi t0, t0, DIGITS_BYTES
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

.section .bss
.balign 8
rec:
    .skip JAB_ROMFS_ENTRY
digits:
    .skip DIGITS_BYTES
line:
    .skip LINE_BYTES
name:
    .skip NAME_BYTES
map_path:
    .skip PATH_BYTES
tile_path:
    .skip PATH_BYTES
.balign 8
map_bytes:
    .skip 8
pixel_cursor:
    .skip 8
ambient_cursor:
    .skip 8
sections:
    .skip (KIND_COUNT * SECTION_ENTRY)
spawn_index:
    .skip 4
sprite_count:
    .skip 4
texture_count:
    .skip 4
missing_count:
    .skip 4
frame_us:
    .skip 4
game_us:
    .skip 4
frame_seconds:
    .skip 4
.balign 8
frame_clock:
    .skip CLOCK_SIZE
record_pair:
    .skip (REPORT_SIZE * 2)
end_record:
    .skip REPORT_SIZE
.balign 8
material_record:
    .skip (MAX_MATERIALS * 8)
ambient_at:
    .skip (MAX_AMBIENTS * 8)
ambient_bytes:
    .skip (MAX_AMBIENTS * 8)
.balign 8
map:
    .skip MAP_BYTES
.balign 8
file:
    .skip FILE_BYTES
.balign 8
pixels:
    .skip PIXEL_BYTES
.balign 8
ambient_arena:
    .skip AMBIENT_BYTES
.balign 8
font:
    .skip FONT_BYTES

.section .rodata
serial_fps:
    .asciz "fps"
path_name:
    .asciz "/map/name"
word_map_dir:
    .asciz "/map/"
word_map_ext:
    .asciz ".jabfps.map"
word_png_ext:
    .asciz ".png"
word_mid_ext:
    .asciz ".mid"
word_slash:
    .asciz "/"
msg_prefix:
    .asciz "fps: "
msg_material:
    .asciz "fps: material "
word_colon:
    .asciz ": "
word_not_on_disk:
    .asciz " is not on the disk"
word_not_map:
    .asciz " is not a Jab FPS map"
word_ends_at:
    .asciz " ends at "
word_before_structures:
    .asciz " bytes before its structures do"
word_not_fit:
    .asciz " does not fit in "
word_bytes:
    .asciz " bytes"
word_holds_more:
    .asciz " holds more "
word_than_build:
    .asciz " than this build holds"
word_name_too_long:
    .asciz "'s name is too long for a path"
msg_load_failed:
    .asciz "fps: a load failed on material "
word_code:
    .asciz " code "
word_directory:
    .asciz "'s section directory "
msg_no_display:
    .asciz "fps: no display\n"
msg_no_sound:
    .asciz "fps: no sound\n"
msg_no_disk:
    .asciz "fps: no disk of serial fps\n"
msg_no_name:
    .asciz "fps: the disk has no /map/name\n"
.ifdef DEBUG
msg_ambient:
    .asciz "fps: ambient "
word_space:
    .asciz " "
word_loaded:
    .asciz " loaded in "
word_ms:
    .asciz " ms: "
word_sectors:
    .asciz " sectors, "
word_walls:
    .asciz " walls, "
word_vertices:
    .asciz " vertices, "
word_portals:
    .asciz " portals, "
word_entities:
    .asciz " entities, "
word_lights:
    .asciz " lights, "
word_lumel_maps:
    .asciz " lumel maps, "
word_sprites:
    .asciz " sprites, "
word_materials:
    .asciz " materials, "
word_textures:
    .asciz " textures, "
word_missing:
    .asciz " missing"
word_missing_file:
    .asciz " missing"
word_not_fit_arena:
    .asciz " does not fit its arena"
msg_frame:
    .asciz "fps: frame in "
msg_sectors:
    .asciz "fps: sectors "
word_us:
    .asciz " us: "
word_pieces:
    .asciz " pieces, "
word_planes:
    .asciz " planes, "
word_openings:
    .asciz " openings, "
word_uncovered:
    .asciz " uncovered; clear, planes, walls, portals, sprites us "
word_comma:
    .asciz ", "
word_spans:
    .asciz "; spans "
word_pixels:
    .asciz ", pixels "
word_lit_spans:
    .asciz ", lit spans "
word_lit_pixels:
    .asciz ", lit pixels "
word_light_us:
    .asciz ", light us "
word_rejected:
    .asciz ", rejected "
word_lumel_samples:
    .asciz ", samples "
word_tiles_built:
    .asciz ", tiles built "
word_tiled:
    .asciz ", tiled "
word_resets:
    .asciz ", resets "
.ifdef COUNT
msg_count:
    .asciz "fps: count "
word_count_avoided:
    .asciz " divides, "
word_count_shifted:
    .asciz " avoided; blocks "
word_count_short:
    .asciz " shifted, "
word_count_negative_u:
    .asciz " short; negative steps off sixteen "
word_count_negative_v:
    .asciz " in u, "
word_count_flat:
    .asciz " in v; flat spans "
word_count_mismatches:
    .asciz "; mismatches "
.endif
.endif

.balign 4
k_seconds_a_tick:
    .float 0.0000001
k_dt_max:
    .float 0.05

.include "src/load.S"
.include "src/sector.S"
.include "src/camera.S"
.include "src/raster.S"
.include "src/world.S"
.include "src/sprite.S"
.include "src/light.S"
.include "src/mip.S"
.include "src/tile.S"
.include "src/body.S"
.include "src/console.S"
.include "src/actor.S"
.include "src/trace.S"
.include "src/mixer.S"
.include "src/player.S"
.include "src/hud.S"
