.include "jab.inc"
.include "jab_jobs.inc"
.include "jab_f32.inc"
.include "jab_f64.inc"
.include "jab_rng.inc"
.include "jab_manifest.inc"
.include "src/map.inc"
.include "src/render.inc"

.set MAP_BYTES, (1024 * 1024)
.set FILE_BYTES, (2 * 1024 * 1024)
.set PIXEL_BYTES, (64 * 1024 * 1024)
.set AMBIENT_BYTES, (4 * 1024 * 1024)
.set FONT_BYTES, (160 * 1024 * 1024)
.set PAGE_BYTES, (1024 * 1024)
.set NAME_BYTES, 64
.set TITLE_BYTES, 64
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
.set CLOCK_SIMULATION, 72
.set CLOCK_WAIT, 80
.set CLOCK_PACING, 88
.set CLOCK_WAKES, 96
.set CLOCK_PRESSES, 104
.set CLOCK_ATTEMPTS, 112
.set CLOCK_REFUSALS, 120
.set CLOCK_CADENCE, 128
.set CLOCK_DRAW, 136
.set CLOCK_SNAPSHOT, 144
.set CLOCK_FLIP_STAMP, 152
.set CLOCK_FLIP_TICK, 160
.set CLOCK_FLIP_ORDINAL, 168
.set CLOCK_FIRST_ORDINAL, 176
.set CLOCK_FLIP_START, 184
.set CLOCK_SIZE, 192
.set FLIP_EARLY, 1
.set FLIP_NONE, 255

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
    mv a1, a0
    la a0, name
    call text_trim
    la a0, map_path
    la a1, word_map_dir
    call append_str
    la a1, name
    call append_str
    la a1, word_map_ext
    call append_str
    sb zero, 0(a0)
    la a0, title
    li a1, (TITLE_BYTES - 1)
    mv a2, s0
    la a3, path_title
    call read_file
    mv a1, a0
    la a0, title
    call text_trim
    bnez a1, 1f
    la a0, name                     # no title: the name in its place
1:
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
    rdtime t3                       # the title's flip call's start
    jab.sys.display.flip
    rdtime t1                       # the title's flip end
    la t0, load_record
    sd a1, LOAD_TITLE_STAMP(t0)     # its receipt: the decision's stamp
    sw a3, LOAD_TITLE_ORDINAL(t0)   # and the present ordinal
    la t2, known_ordinal
    sd a3, 0(t2)
    la t2, bounds_record
    sd t3, BOUNDS_TITLE_START(t2)   # the call's bounds in ticks
    sd t1, BOUNDS_TITLE_END(t2)
    sub t1, t1, s11
    li t2, US_TICKS
    divu t1, t1, t2
    sd t1, LOAD_TITLE_END(t0)       # microseconds from the start, the frame records' origin
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
    call tiles_init                 # the tile pool's directory, slots, and contexts
    call actors_place
    call player_reset
    call camera_spawn
    call camera_axes
    call clear_screen
    jab.sys.display.await
    rdtime t3                       # the cleared screen's flip call's start
    jab.sys.display.flip
    rdtime t1                       # the cleared screen's flip end
    la t0, load_record
    sd a1, LOAD_CLEAR_STAMP(t0)
    sw a3, LOAD_CLEAR_ORDINAL(t0)
    la t2, known_ordinal
    sd a3, 0(t2)
    la t2, bounds_record
    sd t3, BOUNDS_CLEAR_START(t2)   # the call's bounds in ticks
    sd t1, BOUNDS_CLEAR_END(t2)
    sub t1, t1, s11
    li t2, US_TICKS
    divu t1, t1, t2
    sd t1, LOAD_CLEAR_END(t0)
.ifdef DEBUG
    rdtime t0
    sub t0, t0, s11
    li t1, MS_TICKS
    divu s5, t0, t1                 # the milliseconds
    call load_report
.endif
    call workers_start              # the raster's workers, asleep until a round
.ifdef SERVICE
    call service_init               # no message applied, no service running
.endif
.ifdef CENSUS
    call census_init                # the census's directory and the contexts' slots
.endif
.ifdef SNAPSHOTS
    call snapshots_init             # the presented frames' ring, empty
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
    sd zero, CLOCK_WAIT(t1)
    sd zero, CLOCK_PACING(t1)
    sd zero, CLOCK_FLIP(t1)
    sd zero, CLOCK_WAKES(t1)
    sd zero, CLOCK_PRESSES(t1)
    sd zero, CLOCK_ATTEMPTS(t1)
    sd zero, CLOCK_REFUSALS(t1)
    li t2, FLIP_NONE
    sd t2, CLOCK_FLIP_STATUS(t1)    # kept by a frame that reaches no flip
    sd zero, CLOCK_FLIP_STAMP(t1)   # and its receipt: no decision observed
    sd zero, CLOCK_FLIP_TICK(t1)
    la t2, known_ordinal
    ld t2, 0(t2)
    sd t2, CLOCK_FLIP_ORDINAL(t1)   # the last ordinal the program knows, in both
    sd t2, CLOCK_FIRST_ORDINAL(t1)
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
.ifdef SERVICE
    call service_frame              # the simulation boundary: messages applied, the next quota paced
.endif
    rdtime s9
    call camera_look
    call console_read
    call load_send                  # frame 0 alone: the load's presents and the nonce
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
    la t1, frame_clock
    sd s9, CLOCK_SIMULATION(t1)     # the simulation's time, camera_look's start
    sd s8, CLOCK_SNAPSHOT(t1)       # the frame whose simulation the drawing is given
.ifdef SERVICE
    la t0, service_word
    ld t2, 0(t0)
    la t0, service_record
    sd t2, SVC_WORD(t0)             # the snapshot's service word, the packet's
.endif
.ifdef SNAPSHOTS
    mv a0, s8
    call snapshot_begin             # the frame's own snapshot opened
.endif
    rdtime s9
.ifdef DEBUG
    call draw_or_stall              # an S's stall in place of the drawing
.else
    call world_draw
.endif
    rdtime t0
    sub s10, t0, s9                 # the frame's ticks
    li t1, US_TICKS
    divu t0, s10, t1
    la t1, frame_us
    sw t0, 0(t1)                    # the drawing's microseconds
    la t1, frame_clock
    sd s10, CLOCK_DRAW(t1)          # and its ticks, the raster's taken from them once
    rdtime s9
.ifdef DEBUG
    mv a0, s8                       # the frame's number, for the stamp
.endif
.ifdef OWNER
.ifdef DEBUG
    call hud_stamp_draw             # an owner build's stamp alone, no crosshair
.endif
.else
.ifdef LEVELS
    call hud_stamp_draw             # a levels build's too
.else
    call hud_draw
.endif
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
    li t2, CADENCE_IF_EARLY
    sd t2, CLOCK_CADENCE(t1)        # the cadence the frame presents under
    mv a0, s9
    call pacing_step                # wait only if early, then flip
    mv s9, a0                       # the step's end
.ifdef SNAPSHOTS
    call snapshot_present           # a presented frame's snapshot into the ring
.endif
    call state_report
.ifdef CENSUS
    mv a0, s8
    call census_frame               # the frame's blocks counted, its lines on the UART
.endif
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
    j frame                         # the next frame at once, its wait before its flip

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
    la t1, clock_records
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
    ld t2, CLOCK_WAIT(t0)
    sub t4, t4, t2                  # the wait apart
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
    la t2, tile_used
    ld t3, 0(t2)
    slli t3, t3, TILE_BYTES_SHIFT
    sw t3, DRAW_TILE_BYTES(t1)      # the pool's bytes in use at the boundary's end
    la t2, tile_peak
    ld t3, 0(t2)
    sw t3, DRAW_TILE_PEAK(t1)
    addi t1, t1, REPORT_SIZE        # the presentation record
    la t0, frame_clock
    li t2, REPORT_PRESENT
    sw t2, REPORT_KIND(t1)
    sw t5, REPORT_FRAME_NUMBER(t1)
    li t2, REPORT_SCHEMA_VERSION
    sw t2, REPORT_SCHEMA(t1)
    ld t2, CLOCK_SIMULATION(t0)
    ld t3, CLOCK_ORIGIN(t0)
    sub t4, t2, t3
    divu t4, t4, t6
    sd t4, PRESENT_SIMULATION(t1)
    sub t4, a0, t3
    divu t4, t4, t6
    sd t4, PRESENT_NEXT_START(t1)   # the next frame's start, as it was read
    ld t2, CLOCK_WAIT(t0)
    divu t2, t2, t6
    sw t2, PRESENT_WAIT(t1)
    ld t2, CLOCK_PACING(t0)
    divu t2, t2, t6
    sw t2, PRESENT_PACING(t1)
    ld t2, CLOCK_WAKES(t0)
    sw t2, PRESENT_WAKES(t1)
    ld t2, CLOCK_PRESSES(t0)
    sw t2, PRESENT_WAIT_PRESSES(t1)
    ld t2, CLOCK_ATTEMPTS(t0)
    sw t2, PRESENT_FLIP_ATTEMPTS(t1)
    ld t2, CLOCK_REFUSALS(t0)
    sw t2, PRESENT_REFUSALS(t1)
    ld t2, CLOCK_CADENCE(t0)
    sw t2, PRESENT_CADENCE(t1)
    addi t1, t1, REPORT_SIZE        # the packet record
    li t2, REPORT_PACKET
    sw t2, REPORT_KIND(t1)
    sw t5, REPORT_FRAME_NUMBER(t1)
    li t2, REPORT_SCHEMA_VERSION
    sw t2, REPORT_SCHEMA(t1)
    la t3, stats
    ld t4, STAT_RASTER_TICKS(t3)
    ld t2, CLOCK_DRAW(t0)
    sub t2, t2, t4
    divu t2, t2, t6
    sw t2, PACKET_PREPARATION(t1)   # the drawing less its raster, converted once
    divu t4, t4, t6
    sw t4, PACKET_RASTER(t1)        # every render of the frame's packets, flushes and the resolve in them
    ld t2, STAT_COMMANDS(t3)
    sw t2, PACKET_COMMANDS(t1)
    li t4, POLY_SIZE
    mul t2, t2, t4
    ld t4, STAT_SPANS(t3)
    li a1, SPAN_RECORD_SIZE
    mul t4, t4, a1
    add t2, t2, t4
    sw t2, PACKET_BYTES(t1)         # the commands and span records the frame's packets held
    ld t2, STAT_FLUSHES(t3)
    sw t2, PACKET_FLUSHES(t1)
    sw zero, PACKET_INVALIDATED(t1) # no binding to invalidate: the commands carry no tiles
    ld t2, CLOCK_SNAPSHOT(t0)
    sw t2, PACKET_SNAPSHOT(t1)      # the frame whose simulation the packets were prepared from
    la t3, round_workers
    lwu t2, 0(t3)
    sw t2, PACKET_WORKERS(t1)       # the frame's workers, 0 for the serial backend
    la t3, round_grain
    lwu t2, 0(t3)
    sw t2, PACKET_GRAIN(t1)
    la t3, stats
    ld t2, STAT_SLOWEST(t3)
    divu t2, t2, t6
    sw t2, PACKET_SLOWEST(t1)       # the rounds' times, each converted once
    ld t2, STAT_BUSY(t3)
    divu t2, t2, t6
    sw t2, PACKET_BUSY(t1)
    ld t2, STAT_DISPATCH(t3)
    divu t2, t2, t6
    sw t2, PACKET_DISPATCH(t1)
    ld t2, STAT_BARRIER(t3)
    divu t2, t2, t6
    sw t2, PACKET_BARRIER(t1)
    addi t1, t1, REPORT_SIZE        # the tile record
    li t2, REPORT_TILE
    sw t2, REPORT_KIND(t1)
    sw t5, REPORT_FRAME_NUMBER(t1)
    li t2, REPORT_SCHEMA_VERSION
    sw t2, REPORT_SCHEMA(t1)
    ld t2, STAT_TILE_ADMITTED(t3)
    sw t2, TILES_ADMITTED(t1)       # this frame's requests, admitted while it rendered
    ld t2, STAT_TILE_DROPPED(t3)
    sw t2, TILES_DROPPED(t1)
    ld t2, STAT_TILE_FILTERED(t3)
    sw t2, TILES_FILTERED(t1)
    la t2, tile_batch_frame
    ld t2, 0(t2)
    sw t2, TILES_SOURCE(t1)         # the batch its boundary consumed, the frame before's
    la t2, tile_batch_admitted
    ld t2, 0(t2)
    sw t2, TILES_BATCH(t1)
    ld t2, STAT_TILE_MERGED(t3)
    sw t2, TILES_MERGED(t1)
    ld t2, STAT_TILE_UNPROCESSED(t3)
    sw t2, TILES_UNPROCESSED(t1)
    ld t2, STAT_TILE_EVICTED(t3)
    sw t2, TILES_EVICTED(t1)
    ld t2, STAT_TILE_BUILD_TICKS(t3)
    divu t2, t2, t6
    sw t2, TILES_BUILD(t1)
    ld t2, STAT_TILE_OVERRUN(t3)
    divu t2, t2, t6
    sw t2, TILES_OVERRUN(t1)
    ld t2, STAT_TILE_HITS(t3)
    sw t2, TILES_HITS(t1)
    ld t2, STAT_TILE_STRADDLING(t3)
    sw t2, TILES_STRADDLING(t1)
    ld t2, STAT_TILE_MISSES(t3)
    sw t2, TILES_MISSES(t1)
    addi t1, t1, REPORT_SIZE        # the storage record, at the boundary's end
    li t2, REPORT_STORAGE
    sw t2, REPORT_KIND(t1)
    sw t5, REPORT_FRAME_NUMBER(t1)
    li t2, REPORT_SCHEMA_VERSION
    sw t2, REPORT_SCHEMA(t1)
    la t2, tile_used
    ld t2, 0(t2)
    sw t2, STORE_USED(t1)
    slli t2, t2, TILE_BYTES_SHIFT
    la t4, tile_fixed
    ld t4, 0(t4)
    add t2, t2, t4
    sw t2, STORE_MEMORY(t1)         # the memory in use, the tables and the slots
    la t2, tile_effective
    ld t2, 0(t2)
    sw t2, STORE_EFFECTIVE(t1)
    la t2, tile_building
    ld t2, 0(t2)
    slti t2, t2, 0
    xori t2, t2, 1
    sw t2, STORE_BUILDING(t1)       # one tile in construction at most
    la t2, tile_batch_ring
    ld t2, 0(t2)
    sw t2, STORE_RING(t1)
    la t2, tile_batch_surfaces
    ld t2, 0(t2)
    sw t2, STORE_SURFACES(t1)
    ld t2, STAT_TILE_MERGED(t3)
    sw t2, STORE_MERGED(t1)
    la t2, tile_memory_peak
    ld t2, 0(t2)
    sw t2, STORE_PEAK(t1)
    addi t1, t1, REPORT_SIZE        # the harts record, each a mask by hart
    li t2, REPORT_HARTS
    sw t2, REPORT_KIND(t1)
    sw t5, REPORT_FRAME_NUMBER(t1)
    li t2, REPORT_SCHEMA_VERSION
    sw t2, REPORT_SCHEMA(t1)
    la t2, workers_online
    ld t2, 0(t2)
    sw t2, HARTS_ONLINE(t1)         # the online secondaries
    la t2, workers_floor
    lwu t2, 0(t2)
    sw t2, HARTS_FLOOR(t1)          # the count reserved
    la t2, frame_grant
    ld t2, 0(t2)
    sw t2, HARTS_GRANT(t1)          # the grant read at the frame's latch
    la t2, frame_claimed
    ld t2, 0(t2)
    sw t2, HARTS_CLAIMED(t1)        # the harts under the program's claim, read with it
    la t2, workers_mask
    ld t2, 0(t2)
    sw t2, HARTS_STARTED(t1)        # the harts holding a raster worker
    la t2, round_harts
    ld t2, 0(t2)
    sw t2, HARTS_ACTIVE(t1)         # the harts the frame dispatched to
    la t2, frame_reported
    ld t2, 0(t2)
    sw t2, HARTS_REPORTED(t1)       # the harts whose workers completed its jobs
    addi t1, t1, REPORT_SIZE        # the receipt record, the frame's flips as the kernel answered them
    li t2, REPORT_RECEIPT
    sw t2, REPORT_KIND(t1)
    sw t5, REPORT_FRAME_NUMBER(t1)
    li t2, REPORT_SCHEMA_VERSION
    sw t2, REPORT_SCHEMA(t1)
    la t0, frame_clock
    ld t2, CLOCK_FLIP_STAMP(t0)
    sd t2, RECEIPT_STAMP(t1)        # the final attempt's decision stamp
    ld t2, CLOCK_FLIP_TICK(t0)
    sd t2, RECEIPT_TICK(t1)         # the eligibility tick it read
    ld t2, CLOCK_FLIP_ORDINAL(t0)
    sd t2, RECEIPT_ORDINAL(t1)      # the present ordinal the final attempt returned
    ld t2, CLOCK_FIRST_ORDINAL(t0)
    sd t2, RECEIPT_FIRST(t1)        # the ordinal the first attempt found
    ld t2, CLOCK_ATTEMPTS(t0)
    beqz t2, 4f                     # no attempt, no call to bound
    ld t2, CLOCK_FLIP_START(t0)
    sd t2, RECEIPT_CALL_START(t1)   # the final attempt's call, its start in ticks
    ld t2, CLOCK_FLIP_DONE(t0)
    sd t2, RECEIPT_CALL_END(t1)     # and its end
    j 5f
4:
    sd zero, RECEIPT_CALL_START(t1)
    sd zero, RECEIPT_CALL_END(t1)
5:
    sw zero, 56(t1)                 # zeros to the schema
.ifdef SERVICE
    addi t1, t1, REPORT_SIZE        # the service record, the frame's boundary and its packet
    la t2, service_record
    li t3, 0
6:
    add t4, t2, t3
    ld t4, 0(t4)
    add a2, t1, t3
    sd t4, 0(a2)
    addi t3, t3, 8
    li t4, REPORT_SIZE
    bltu t3, t4, 6b
    li t2, REPORT_SERVICE
    sw t2, REPORT_KIND(t1)
    sw t5, REPORT_FRAME_NUMBER(t1)
    li t2, SERVICE_SCHEMA
    sw t2, REPORT_SCHEMA(t1)
.endif
    la t0, clock_records
    li t1, (REPORT_SIZE * REPORT_FRAME_RECORDS)
    jab.sys.api.write t0, t1
.ifdef DEBUG
    la t0, job_cancel
    lbu t1, 0(t0)
    beqz t1, 8f
    la t0, rounds_record            # the J's cancel standing: the frame's witness
    li t1, REPORT_ROUNDS
    sw t1, REPORT_KIND(t0)
    sw t5, REPORT_FRAME_NUMBER(t0)
    la t2, stats
    ld t1, STAT_ROUNDS(t2)
    sw t1, ROUNDS_ROUNDS(t0)
    ld t1, STAT_CANCELLED(t2)
    sw t1, ROUNDS_CANCELLED(t0)
    li t1, REPORT_SIZE
    jab.sys.api.write t0, t1
8:
.endif
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

load_send:
    bnez s8, 9f                     # frame 0 alone
    la t0, load_record
    li t1, REPORT_LOAD
    sw t1, REPORT_KIND(t0)
    la t1, capture_nonce
    ld t1, 0(t1)
    sd t1, LOAD_NONCE(t0)           # the I's nonce, 0 where none came before this frame's state
    li t1, REPORT_SCHEMA_VERSION
    sw t1, REPORT_SCHEMA(t0)
    la t2, bounds_record            # the load's calls' bounds, the record after it
    li t1, REPORT_BOUNDS
    sw t1, REPORT_KIND(t2)
    la t1, frame_clock
    ld t1, CLOCK_ORIGIN(t1)
    sd t1, BOUNDS_ORIGIN(t2)        # the frame records' origin, the program's start
    li t1, REPORT_SCHEMA_VERSION
    sw t1, REPORT_SCHEMA(t2)
    li t1, (REPORT_SIZE * 2)
    jab.sys.api.write t0, t1        # the load record, then its bounds
9:
    ret

flip_attempt:
    rdtime t0
    jab.sys.display.flip
    rdtime t1
    la t2, frame_clock
    sd a0, CLOCK_FLIP_STATUS(t2)
    sd a1, CLOCK_FLIP_STAMP(t2)     # the kernel's receipt: the decision's stamp
    sd a2, CLOCK_FLIP_TICK(t2)      # the eligibility tick it read
    sd a3, CLOCK_FLIP_ORDINAL(t2)   # the present ordinal as the call returned
    la t3, known_ordinal
    sd a3, 0(t3)
    sub t3, t1, t0
    ld t4, CLOCK_FLIP(t2)
    add t4, t4, t3
    sd t4, CLOCK_FLIP(t2)           # every attempt's call
    sd t1, CLOCK_FLIP_DONE(t2)
    sd t0, CLOCK_FLIP_START(t2)     # this attempt's call's start, the final's kept
    ld t4, CLOCK_ATTEMPTS(t2)
    bnez t4, 3f
    sd a3, CLOCK_FIRST_ORDINAL(t2)  # the ordinal the frame's first attempt found
3:
    addi t4, t4, 1
    sd t4, CLOCK_ATTEMPTS(t2)
    li t3, FLIP_EARLY
    bne a0, t3, 1f
    ld t4, CLOCK_REFUSALS(t2)
    addi t4, t4, 1
    sd t4, CLOCK_REFUSALS(t2)       # an attempt answered as early
1:
    mv a1, t1
    ret

pacing_step:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s2, 0(sp)
    mv s2, a0                       # the step's start
.ifdef DEBUG
    la t0, flip_first
    lbu t1, 0(t0)
    sb zero, 0(t0)
    beqz t1, 1f
    call flip_attempt               # an S's forced attempt, before any wait
    li t0, FLIP_EARLY
    bne a0, t0, 8f
1:
.endif
    jab.sys.display.ready
    bnez a0, 5f                     # ready: the flip
3:
    call pacing_await
    andi t0, a0, JAB_AWAIT_DISPLAY
    beqz t0, 3b                     # a wake on the pad alone, consumed: wait again
5:
    call flip_attempt
    li t0, FLIP_EARLY
    beq a0, t0, 3b                  # refused as early: the wait, then a flip again
8:
    rdtime a0                       # the step's end
    la t0, frame_clock
    sub t1, a0, s2
    ld t2, CLOCK_WAIT(t0)
    sub t1, t1, t2
    ld t2, CLOCK_FLIP(t0)
    sub t1, t1, t2
    sd t1, CLOCK_PACING(t0)         # the step less its awaits and its flips
    ld ra, 8(sp)
    ld s2, 0(sp)
    addi sp, sp, 16
    ret

pacing_await:
    addi sp, sp, -16
    sd ra, 8(sp)
    rdtime t5
    jab.sys.await (JAB_AWAIT_DISPLAY | JAB_AWAIT_PAD)
    rdtime t0
    sub t0, t0, t5
    la t1, frame_clock
    ld t2, CLOCK_WAIT(t1)
    add t2, t2, t0
    sd t2, CLOCK_WAIT(t1)           # the time inside the await alone
    andi t0, a0, JAB_AWAIT_DISPLAY
    bnez t0, 9f                     # the display's tick: the wait ends
    sd a0, 0(sp)
    call pad_consume                # a wake on the pad alone, consumed
    ld a0, 0(sp)
9:
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

pad_consume:
    la t0, frame_clock
    ld t1, CLOCK_WAKES(t0)
    addi t1, t1, 1
    sd t1, CLOCK_WAKES(t0)
1:
    jab.sys.pad.input
    beqz a0, 2f
    li t0, JAB_EV_KEY
    bne a0, t0, 1b
    li t0, JAB_KEY_PRESSED
    bne a2, t0, 1b
    addi t0, a1, -JAB_BTN_GAMEPAD
    li t1, 32
    bgeu t0, t1, 1b
    li t1, 1
    sll t1, t1, t0
    la t2, pad_latched
    lwu t3, 0(t2)
    or t3, t3, t1
    sw t3, 0(t2)                    # for camera_look's presses
    la t2, frame_clock
    ld t3, CLOCK_PRESSES(t2)
    addi t3, t3, 1
    sd t3, CLOCK_PRESSES(t2)
    j 1b
2:
.ifdef DEBUG
    la t0, consume_spin
    lwu t1, 0(t0)
    beqz t1, 4f
    li t2, US_TICKS
    mul t1, t1, t2
    rdtime t2
    add t1, t1, t2
3:
    rdtime t2
    bltu t2, t1, 3b                 # an S's known work inside the consume
4:
.endif
    ret

.ifdef DEBUG
draw_or_stall:
    la t0, stall_once
    lwu a0, 0(t0)
    sw zero, 0(t0)                  # this frame's own stall, taken once
    bnez a0, 1f
    la t0, stall_on
    lbu t1, 0(t0)
    bnez t1, 2f
    j world_draw                    # no stall: the drawing, returning to the loop
2:
    la t0, stall_us
    lwu a0, 0(t0)
1:
    addi sp, sp, -16
    sd ra, 8(sp)
    li t1, US_TICKS
    mul a0, a0, t1
    rdtime t1
    add a0, a0, t1
    sd a0, 0(sp)                    # the stall's end
    la t1, stats
    li t2, 0
3:
    li t3, STAT_TILE_RESETS
    beq t2, t3, 4f                  # the resets since the load stay
    add t3, t1, t2
    sd zero, 0(t3)
4:
    addi t2, t2, 8
    li t3, STAT_SIZE
    bltu t2, t3, 3b
    call tile_stall                 # the frame before's requests discarded, nothing drawn to serve
    la t1, span_count
    sd zero, 0(t1)
    ld a0, 0(sp)
5:
    rdtime t1
    bltu t1, a0, 5b
    ld ra, 8(sp)
    addi sp, sp, 16
    ret
.endif

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
    la a1, word_comma
    call append_str
    la t0, stats
    ld a1, STAT_RASTER_TICKS(t0)
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
    la a1, word_slots
    call append_str
    la t0, tile_used
    ld a1, 0(t0)
    call append_dec
    la a1, word_commands
    call append_str
    la t0, stats
    ld a1, STAT_COMMANDS(t0)
    call append_dec
    la a1, word_flushes
    call append_str
    la t0, stats
    ld a1, STAT_FLUSHES(t0)
    call append_dec
    la a1, word_workers
    call append_str
    la t0, round_workers
    lwu a1, 0(t0)
    call append_dec
    la a1, word_grain
    call append_str
    la t0, round_grain
    lwu a1, 0(t0)
    call append_dec
    la a1, word_rounds
    call append_str
    la t0, stats
    ld a1, STAT_ROUNDS(t0)
    call append_dec
    la a1, word_bands
    call append_str
    sd zero, 0(sp)                  # the slot
91:
    ld t0, 0(sp)
    beqz t0, 92f
    la a1, word_space
    call append_str
    ld t0, 0(sp)
92:
    slli t0, t0, 3
    la t1, stats
    add t1, t1, t0
    ld a1, STAT_BANDS(t1)
    call append_dec                 # a count a hart, hart 1's first
    ld t0, 0(sp)
    addi t0, t0, 1
    sd t0, 0(sp)
    li t1, GFX_SLOTS
    bltu t0, t1, 91b
    la a1, word_dispatch
    call append_str
    la t0, stats
    ld a1, STAT_DISPATCH(t0)
    li t0, US_TICKS
    divu a1, a1, t0
    call append_dec
    la a1, word_barrier
    call append_str
    la t0, stats
    ld a1, STAT_BARRIER(t0)
    li t0, US_TICKS
    divu a1, a1, t0
    call append_dec
    la a1, word_slowest
    call append_str
    la t0, stats
    ld a1, STAT_SLOWEST(t0)
    li t0, US_TICKS
    divu a1, a1, t0
    call append_dec
    la a1, word_busy
    call append_str
    la t0, stats
    ld a1, STAT_BUSY(t0)
    li t0, US_TICKS
    divu a1, a1, t0
    call append_dec
    la a1, word_cancelled
    call append_str
    la t0, stats
    ld a1, STAT_CANCELLED(t0)
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
    la a1, word_count_reentry_two
    call append_str
    la t0, count_stats
    ld a1, COUNT_REENTRY_TWO(t0)
    call append_dec
    la a1, word_count_reentry_four
    call append_str
    la t0, count_stats
    ld a1, COUNT_REENTRY_FOUR(t0)
    call append_dec
    la a1, word_count_reentry_cut
    call append_str
    la t0, count_stats
    ld a1, COUNT_REENTRY_CUT(t0)
    call append_dec
    la a1, word_count_reentry_end
    call append_str
.ifdef FOOTPRINT
    la a1, word_count_saturated
    call append_str
    la t0, count_stats
    ld a1, COUNT_SATURATED(t0)
    call append_dec
.endif
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

text_trim:
    add t1, a0, a1
    sb zero, 0(t1)
1:
    beq t1, a0, 2f
    lbu t2, -1(t1)
    li t3, ' '
    bgtu t2, t3, 2f
    addi t1, t1, -1
    sb zero, 0(t1)
    j 1b
2:
    sub a1, t1, a0
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
title:
    .skip TITLE_BYTES
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
clock_records:
    .skip (REPORT_SIZE * REPORT_FRAME_RECORDS)
end_record:
    .skip REPORT_SIZE
load_record:
    .skip REPORT_SIZE
bounds_record:
    .skip REPORT_SIZE
known_ordinal:
    .skip 8
.ifdef DEBUG
rounds_record:
    .skip REPORT_SIZE
.endif
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
path_title:
    .asciz "/map/title"
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
word_space:
    .asciz " "
.ifdef DEBUG
msg_ambient:
    .asciz "fps: ambient "
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
    .asciz " uncovered; clear, planes, walls, portals, sprites, raster us "
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
word_slots:
    .asciz ", slots "
word_commands:
    .asciz ", commands "
word_flushes:
    .asciz ", flushes "
word_workers:
    .asciz ", workers "
word_grain:
    .asciz ", grain "
word_rounds:
    .asciz ", rounds "
word_bands:
    .asciz ", bands "
word_dispatch:
    .asciz ", dispatch us "
word_barrier:
    .asciz ", barrier us "
word_slowest:
    .asciz ", slowest us "
word_busy:
    .asciz ", busy us "
word_cancelled:
    .asciz ", cancelled "
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
word_count_reentry_two:
    .asciz "; re-entries "
word_count_reentry_four:
    .asciz " in two blocks, "
word_count_reentry_cut:
    .asciz " in four, "
word_count_reentry_end:
    .asciz " cut short"
.ifdef FOOTPRINT
word_count_saturated:
    .asciz "; saturated "
.endif
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
.include "src/workers.S"
.include "src/census.S"
.include "src/snapshot.S"
.ifdef SERVICE
.include "src/service.S"
.endif
