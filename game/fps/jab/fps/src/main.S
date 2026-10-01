# fps: the game's program. The map's name is read off the program's disk
# and drawn bold in the middle of a black screen while the map loads:
# the file read whole, its header and section directory held to the
# format and every section placed, its records held to the format's
# rules (load.S), every material's texture decoded off the disk into
# the pixel arena and every ambient piece read, the soundfont loaded
# off the generic disk when it is there, the lights gathered
# (light.S), and the camera set at the spawn (camera.S). The load is
# reported on the UART with every count. Then the loop: every frame the
# pad read, the camera turned and the body walked by the time since the
# frame before (camera.S, body.S), the console read (console.S), the
# camera's sector followed and its basis derived, the actors run
# (actor.S), the sector's ambient followed, the world drawn from the
# camera through the portal walk (world.S) over the integer span
# (raster.S) with the sprites, the actors, and the light (sprite.S,
# actor.S, light.S), the crosshair over it (hud.S), the frame flipped,
# the state reported over the API, and the display's tick or the pad
# awaited; the first frame is
# reported on the UART with its phases and counts. The engine's own
# images, the android's frames among them, load after the map's
# materials (load.S). A step it cannot take says so on the UART and
# exits with its own code.
.include "jab.inc"
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
# The title: bold at four times the console's cell, centred; bold adds
# a pixel to the width
.set TITLE_SCALE, (JAB_TEXT_SCALE_ONE * 4)
.set TITLE_CELL, (JAB_TEXT_WIDTH * 4)
.set TITLE_HEIGHT, (JAB_TEXT_HEIGHT * 4)
.set TITLE_Y, ((JAB_DISPLAY_HEIGHT - TITLE_HEIGHT) / 2)
.set TITLE_COLOR, 0x00ebe6dc
.set MS_TICKS, (JAB_TIME_HZ / 1000)
.set US_TICKS, (JAB_TIME_HZ / 1000000)
# What a texture's load can fail with, beyond the kernel's own PNG codes
.set LOAD_TOO_BIG, 101
.set LOAD_ARENA_FULL, 102

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
    # the map's name, trailing whitespace dropped
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
    # the map's path: /map/<name>.jabfps.map
    la a0, map_path
    la a1, word_map_dir
    call append_str
    la a1, name
    call append_str
    la a1, word_map_ext
    call append_str
    sb zero, 0(a0)
    # the title, centred on the black screen
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
    # the map read whole, then held to its format
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
    call ambients_load
    call sounds_load
    call soundfont_load
    call lights_gather
    call actors_place
    call player_reset
    call camera_spawn
    call camera_axes
    # loaded: the screen cleared, the report
    call clear_screen
    jab.sys.display.await
    jab.sys.display.flip
    rdtime t0
    sub t0, t0, s11
    li t1, MS_TICKS
    divu s5, t0, t1                 # the milliseconds
    call load_report
    li s8, 0                        # the frames drawn
    rdtime s7                       # the frame before's time
frame:
    rdtime t0
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
    call hud_draw
    call mixer_update
    jab.sys.display.flip
    call state_report
    # the first frame's report, and the first after a console placement
    la t0, report_pending
    lbu t1, 0(t0)
    sb zero, 0(t0)
    beqz s8, 2f
    beqz t1, 1f
2:
    call frame_report
.ifdef DEBUG
    call sectors_report
.endif
1:
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

# short_file: the file ends before its structures do: `fps: <path> ends
# at N bytes before its structures do`, exit 7.
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

# too_many: the map holds more of a kind than this build does, the
# kind's word in a1: `fps: <path> holds more walls than this build
# holds`, exit 8.
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

# path_too_long: the material a0's name is too long for a path, exit 9.
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

# load_failed: the material a0's texture failed to load with the code
# a1, exit 10.
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

# check_failed: a record broke a rule of the format: a1 the record's
# word, a2 its index, a3 what is wrong with it: `fps: <path>: wall 12's
# vertices are out of range`, exit 11.
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

# map_lacks: the map lacks what a1 names: `fps: <path> has no spawn`,
# exit 11.
map_lacks:
    mv s6, a1
    call line_map
    mv a1, s6
    call append_str
    call line_end
    jab.sys.exit 11

# bad_directory: the section directory is broken as a1 says: `fps:
# <path>'s section directory names a kind twice`, exit 12.
bad_directory:
    mv s6, a1
    call line_map
    la a1, word_directory
    call append_str
    mv a1, s6
    call append_str
    call line_end
    jab.sys.exit 12

# line_map: the line begun with `fps: <map path>`; a0 becomes the
# cursor past it.
line_map:
    la a0, line
    la a1, msg_prefix
    mv t1, ra
    call append_str
    la a1, map_path
    call append_str
    mv ra, t1
    ret

# line_end: the line at a0 ended with a newline and printed on the UART.
line_end:
    li t0, '\n'
    sb t0, 0(a0)
    sb zero, 1(a0)
    jab.sys.uart.print line
    ret

# load_report: `fps: <name> loaded in <ms> ms: S sectors, W walls, V
# vertices, P portals, E entities, G lights, X sprites, M materials, T
# textures, U missing` on the UART, the milliseconds in s5.
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

# frame_report: `fps: frame in <us> us: S sectors, W walls, P pieces,
# F planes, O openings, X sprites, U uncovered; clear, planes, walls,
# portals, sprites us a, b, c, d, e` on the UART, the ticks in s10.
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
    call line_end
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

.ifdef DEBUG
# sectors_report: `fps: sectors a b c ...` on the UART, the sectors the
# last frame drew in the walk's order, for a capture's review.
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

# The map's records by index, each a0 becoming the record's address.
# Clobbers t0.
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

# name_at: a0 becomes the address of the name at the offset a0 in the
# names table. Clobbers t0.
name_at:
    section_at KIND_NAMES, t0
    add a0, a0, t0
    ret

# clear_screen: the framebuffer black.
clear_screen:
    li a0, 0
# fill_screen: the framebuffer the colour a0.
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

# read_file: the file at the path a3, an address, on disk a2, from its
# root, into the buffer a0 of a1 bytes, a page at a time; a0 becomes
# the bytes read, 0 when the file is not there.
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

# str_len: a1 becomes the length of the NUL-terminated string at a0,
# a0 kept. Clobbers t0.
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

# append_str: the NUL-terminated string at a1 copied to a0, which moves
# past it. Clobbers t0.
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

# append_dec: a1, unsigned, written in decimal at a0, which moves past
# the digits. Clobbers t0 to t3.
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
# The sections as the loader placed them, an entry a kind
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
# The seconds since the frame before, clamped
frame_seconds:
    .skip 4
.balign 8
# Each material's texture record in the pixel arena, 0 for none
material_record:
    .skip (MAX_MATERIALS * 8)
# Each ambient piece's bytes in its arena and their count, 0 for none
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
msg_ambient:
    .asciz "fps: ambient "
word_space:
    .asciz " "
word_colon:
    .asciz ": "
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
.include "src/body.S"
.include "src/console.S"
.include "src/actor.S"
.include "src/trace.S"
.include "src/mixer.S"
.include "src/player.S"
.include "src/hud.S"
