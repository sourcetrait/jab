# The engine's own records and limits beyond the map's, read after map.inc
.set SCREEN_W, JAB_DISPLAY_WIDTH
.set SCREEN_H, JAB_DISPLAY_HEIGHT
.set SCREEN_PITCH, JAB_DISPLAY_PITCH
.set ZBUF_BYTES, (SCREEN_W * SCREEN_H * 4)
# A page of code under QEMU: a function whose loops run a pixel or a sample
# is aligned to one and kept under one, which the test holds
.set CODE_PAGE, 4096
# The sections as the loader placed them, an entry a kind from 1: the
# section's address in the map buffer and its record count, 64 bits
# each
.set SECTION_AT, 0
.set SECTION_COUNT, 8
.set SECTION_ENTRY, 16
# The camera: the eye, floats; the yaw, pitch, and roll in radians; then
# the basis derived from them each frame, right, up, and forward, three
# floats each
.set CAM_X, 0
.set CAM_Y, 4
.set CAM_Z, 8
.set CAM_YAW, 12
.set CAM_PITCH, 16
.set CAM_ROLL, 20
.set CAM_RIGHT, 24
.set CAM_UP, 36
.set CAM_FORWARD, 48
.set CAM_SIZE, 60
# The camera as doubles, written with the basis each frame for the surface
# mathematics, at twice the camera's offsets
.set CAMD_X, 0
.set CAMD_RIGHT, 48
.set CAMD_UP, 72
.set CAMD_FORWARD, 96
.set CAMD_SIZE, 120
# A polygon before clipping, its points world positions of three
# floats; a sector's loop is one polygon, so it holds a room's whole
# ring; clipping against the near plane can add one point an edge
.set MAX_VERTS, 256
.set MAX_CLIPPED, (MAX_VERTS * 2)
.set VERT_SIZE, 12
.set PVERT_SIZE, 8
# An edge of a projected polygon: its top and bottom y, its x at the
# top, and x's change a row, floats; a sector's planes put every loop's
# edges in one list
.set MAX_EDGES, 2048
.set EDGE_Y0, 0
.set EDGE_Y1, 4
.set EDGE_X0, 8
.set EDGE_DXDY, 12
.set EDGE_SIZE, 16
# The surface in hand, as the rasteriser reads it: the texture's pixels
# and its wraps, the affine coefficients of 1/z (6.26), u/z and v/z
# (48.16) over the screen as 64-bit fixed point, each C carrying the
# half-pixel offsets so a value at a pixel is C + A * column + B * row,
# the mode, and the texture's size as floats
.set POLY_TEX, 0
.set POLY_UMASK, 8
.set POLY_VMASK, 16
.set POLY_WSHIFT, 24
.set POLY_IZA, 32
.set POLY_IZB, 40
.set POLY_IZC, 48
.set POLY_UZA, 56
.set POLY_UZB, 64
.set POLY_UZC, 72
.set POLY_VZA, 80
.set POLY_VZB, 88
.set POLY_VZC, 96
.set POLY_MODE, 104
.set POLY_TEXW, 112
.set POLY_TEXH, 116
.set POLY_TEXWI, 120
.set POLY_TEXHI, 124
# The unit normal facing the camera, floats, and the surface's sector,
# for the light
.set POLY_LNX, 128
.set POLY_LNY, 132
.set POLY_LNZ, 136
.set POLY_SECTOR, 140
# Set for a surface lit at no angle, a sprite facing the camera: every
# light within reach lights it by its falloff alone
.set POLY_FLAT_LIT, 144
# The polygon's own light list, the sector's culled to the lights whose
# sphere meets its world box and which lie ahead of its plane: a count
# byte, then that many light indices, as a sector's list is shaped,
# SECTOR_LIGHTS_SIZE bytes
.set POLY_LIGHTS, 152
# The surface's lumel map record, 0 for none
.set POLY_LUMAP, 184
.set POLY_SIZE, 192
# A brightness word packs three 16.16 channels CHANNEL_BITS apart, which
# integer addition steps exactly while every lane stays in range; a
# lumel packs the same three channels in 256ths, 0 to 256, so four
# lumels summed under weights adding to 256 are a brightness word
.set CHANNEL_BITS, 21
# A surface's lumel map: its lumels in the arena, 0 for none; its columns
# and rows; a texel coordinate to a lumel coordinate, lu = (u * RU >> 32)
# - OU in 16.16 and lv the same; the clamps ((W - 1) << 16) - 1 and the
# same of H, so a sample and the lumel past it both lie in the map
.set LUMAP_BASE, 0
.set LUMAP_W, 8
.set LUMAP_H, 16
.set LUMAP_RU, 24
.set LUMAP_OU, 32
.set LUMAP_RV, 40
.set LUMAP_OV, 48
.set LUMAP_UMAX, 56
.set LUMAP_VMAX, 64
.set LUMAP_SIZE, 72
# The maps by surface: a sector's floor at twice its index and its
# ceiling after, then the walls; a lumel is one word, the grid's spacing
# in metres is k_lumel_d, and the arena holds every map
.set LUMAP_PLANES, (MAX_SECTORS * 2)
.set LUMAP_COUNT, (LUMAP_PLANES + MAX_WALLS)
.set LUMEL_BYTES, 8
.set LUMEL_ARENA_BYTES, (8 * 1024 * 1024)
# The grid a map is baked over: the origin, the u axis's step a lumel,
# and the v axis's step, doubles; the unit normal into the room, singles
.set GRID_O, 0
.set GRID_U, 24
.set GRID_V, 48
.set GRID_N, 72
.set GRID_SIZE, 84
.set POLY_TEXTURED, 0
.set POLY_MASKED, 1
.set POLY_SKY, 2
# A flag over the textured and masked modes: the span lit
.set POLY_LIT, 4
# A light as the engine holds it, floats: the position, the colour, the
# radius squared and one over the radius, the spotlight's unit axis and
# the cosine of its spread (under -1 for a point light)
.set MAX_LIGHTS, 256
.set LIGHT_X, 0
.set LIGHT_Y, 4
.set LIGHT_Z, 8
.set LIGHT_R, 12
.set LIGHT_G, 16
.set LIGHT_B, 20
.set LIGHT_RADIUS2, 24
.set LIGHT_AXIS, 28
.set LIGHT_COS, 40
.set LIGHT_OVER_RADIUS, 44
.set LIGHT_SIZE, 48
# A sector's lights: a count byte, then that many light indices
.set SECTOR_LIGHTS_MAX, 31
.set SECTOR_LIGHTS_SIZE, 32
# The plane in hand, floats: its normal, a point on it, and the world
# gradients and offsets of u and v in texture repeats
.set PLANE_N, 0
.set PLANE_Q, 12
.set PLANE_AU, 24
.set PLANE_U0, 36
.set PLANE_AV, 40
.set PLANE_V0, 52
.set PLANE_SIZE, 56
# The plane in hand as doubles, widened once a polygon, at twice its offsets
.set PLANED_N, 0
.set PLANED_Q, 24
.set PLANED_AU, 48
.set PLANED_U0, 72
.set PLANED_AV, 80
.set PLANED_V0, 104
.set PLANED_SIZE, 112
# The depth: 1/z as an integer in 6.26, z as 2^42 over it in 48.16, a
# span in blocks of BLOCK pixels; a 1/z under IZ_MIN is clamped to it
# for the divide, a sky pixel stores SKY_DEPTH so anything drawn later
# overwrites it
.set DEPTH_BITS, 26
.set Z_SHIFT, (DEPTH_BITS + 16)
.set BLOCK, 16
.set IZ_MIN, 4096
.set SKY_DEPTH, 1
# How the portal test samples an opening: every second column, every
# fourth row
.set PORTAL_STEP_X, 2
.set PORTAL_STEP_Y, 4
# The frame's counts and its ticks by phase, 64 bits each
.set STAT_SECTORS, 0
.set STAT_WALLS, 8
.set STAT_PIECES, 16
.set STAT_PLANES, 24
.set STAT_OPENINGS, 32
.set STAT_CLEAR_TICKS, 40
.set STAT_PLANE_TICKS, 48
.set STAT_WALL_TICKS, 56
.set STAT_PORTAL_TICKS, 64
.set STAT_SPRITES, 72
.set STAT_SPRITE_TICKS, 80
# The spans filled and the pixels they entered, the lit ones among them,
# the ticks the light's evaluation took, and the pixels the depth test
# rejected
.set STAT_SPANS, 88
.set STAT_PIXELS, 96
.set STAT_LIT_SPANS, 104
.set STAT_LIT_PIXELS, 112
.set STAT_LIGHT_TICKS, 120
.set STAT_REJECTED, 128
.set STAT_SIZE, 136
# The records over the API, 64 bytes each: the state a frame, kind
# REPORT_STATE, the camera's sector, the eye, the yaw, pitch, and roll
# in degrees, the drawing's and the game's microseconds, zero to the
# end; the console's answer, kind REPORT_CONSOLE, the command's byte;
# an event carries the state's fields and its own from REPORT_FIELD0:
# a round of the player's (what it met, the actor, its health after),
# an android's event (the event, the actor, its row), the player struck
# (the damage, the health after), a pickup (the rounds after), a
# trace's answer (the kind met, the distance and the point in
# millimetres)
.set REPORT_KIND, 0
.set REPORT_SECTOR, 4
.set REPORT_X, 8
.set REPORT_Y, 12
.set REPORT_Z, 16
.set REPORT_YAW, 20
.set REPORT_PITCH, 24
.set REPORT_ROLL, 28
.set REPORT_FRAME_US, 32
.set REPORT_GAME_US, 36
.set REPORT_FIELD0, 40
.set REPORT_FIELD1, 44
.set REPORT_FIELD2, 48
.set REPORT_FIELD3, 52
.set REPORT_FIELD4, 56
.set REPORT_SIZE, 64
.set REPORT_STATE, 1
.set REPORT_ROUND, 2
.set REPORT_ANDROID, 3
.set REPORT_HURT, 4
.set REPORT_PICKUP, 5
.set REPORT_TRACE, 6
.set REPORT_CONSOLE, 11
# An android's events over the API
.set EVENT_ROUSED, 1
.set EVENT_FIRED, 2
.set EVENT_STRUCK, 3
.set EVENT_DESTROYED, 4
.set EVENT_FALLEN, 5
.set EVENT_WAYPOINT, 6

# An actor, the engine's own things in play: the class (0 free, an
# android, a magazine, a spark), flags, the feet as doubles, the yaw in
# radians, the sector, the row and its timer in seconds, health, the
# target waypoint entity or -1, the fall speed, the last sight's point,
# the time blocked, the spark's frame, the time since the sight was
# lost, and the entity it came from
.set MAX_ACTORS, 64
.set ACTOR_CLASS, 0
.set ACTOR_FLAGS, 4
.set ACTOR_X, 8
.set ACTOR_Y, 16
.set ACTOR_Z, 24
.set ACTOR_YAW, 32
.set ACTOR_SECTOR, 36
.set ACTOR_ROW, 40
.set ACTOR_TIMER, 44
.set ACTOR_HEALTH, 48
.set ACTOR_TARGET, 52
.set ACTOR_FALL, 56
.set ACTOR_SEEN_X, 64
.set ACTOR_SEEN_Y, 72
.set ACTOR_SEEN_Z, 80
.set ACTOR_BLOCKED, 88
.set ACTOR_FRAME, 92
.set ACTOR_LOST, 96
.set ACTOR_ENTITY, 100
.set ACTOR_SIZE, 104
.set ACTOR_NONE, 0
.set ACTOR_ANDROID, 1
.set ACTOR_MAGAZINE, 2
.set ACTOR_SPARK, 3
.set ACTOR_SOLID, 1
.set ACTOR_SHOOTABLE, 2
.set ACTOR_ROUSED, 4
.set ACTOR_SIGHTED, 8
# The first round after rousing is certain, the rest by chance
.set ACTOR_FIRST, 16
.set FIRE_CHANCE, 128
# The engine's images by frame index: the android's eight rotating sets
# of eight, then the fallen frame, the three sparks, and the magazine;
# a frame's material index is frame_base plus its frame index
.set SET_STAND, 0
.set SET_WALK1, 1
.set SET_WALK2, 2
.set SET_WALK3, 3
.set SET_WALK4, 4
.set SET_AIM, 5
.set SET_FIRE, 6
.set SET_STRUCK, 7
.set SET_FALLEN, 8
.set FRAME_FALLEN, 64
.set FRAME_SPARK1, 65
.set FRAME_MAGAZINE, 68
.set FRAME_COUNT, 69
.set SPARK_FRAMES, 3
# An android's row: the frame set, the milliseconds it lasts, -1 for a
# held row, the action on entry, and the row next
.set ROW_SET, 0
.set ROW_MS, 4
.set ROW_ACTION, 8
.set ROW_NEXT, 12
.set ROW_SIZE, 16
.set ROW_STAND, 0
.set ROW_PATROL1, 1
.set ROW_PATROL2, 2
.set ROW_PATROL3, 3
.set ROW_PATROL4, 4
.set ROW_ALERT, 5
.set ROW_AIM, 6
.set ROW_FIRE, 7
.set ROW_SEARCH1, 8
.set ROW_SEARCH2, 9
.set ROW_SEARCH3, 10
.set ROW_SEARCH4, 11
.set ROW_STRUCK, 12
.set ROW_DESTROYED, 13
.set ROW_FALLEN, 14
.set ACT_NONE, 0
.set ACT_LOOK, 1
.set ACT_WALK, 2
.set ACT_ALERT, 3
.set ACT_AIM, 4
.set ACT_FIRE, 5
.set ACT_SEEK, 6
.set ACT_STRUCK, 7
.set ACT_DESTROY, 8
.set ACT_FALL, 9
.set ANDROID_HEALTH, 100
# The line from an actor's eye to the player's, doubles: the eye, the
# unit direction, the distance
.set AIM_OX, 0
.set AIM_OY, 8
.set AIM_OZ, 16
.set AIM_DX, 24
.set AIM_DY, 32
.set AIM_DZ, 40
.set AIM_DIST, 48
.set AIM_SIZE, 56
# A trace's answer: what the ray met (nothing, a plane, a wall piece, an
# android, the player), the distance, the point, the actor met, and the
# sector the ray ended in, doubles and 64-bit fields
.set TRACE_NONE, 0
.set TRACE_PLANE, 1
.set TRACE_PIECE, 2
.set TRACE_ANDROID, 3
.set TRACE_PLAYER, 4
.set TRACE_KIND, 0
.set TRACE_DIST, 8
.set TRACE_PX, 16
.set TRACE_PY, 24
.set TRACE_PZ, 32
.set TRACE_ACTOR, 40
.set TRACE_SECTOR, 48
.set TRACE_SIZE, 56
# The trace tests the player's capsule too
.set TRACE_TO_PLAYER, 1
# The pad's key that fires, the right trigger's button, as its bit in
# the state record's keys
.set TRIGGER_BIT, (1 << (JAB_BTN_TR2 - JAB_BTN_GAMEPAD))
# The G-1's round on either side: what a round takes from its target
.set ROUND_DAMAGE, 25
# The sounds the content holds, by index into the engine's stems
.set SOUND_G1_SHOT, 0
.set SOUND_G1_RELOAD, 1
.set SOUND_G1_EMPTY, 2
.set SOUND_G1_BOLT, 3
.set SOUND_FOOTSTEP1, 4
.set SOUND_FOOTSTEP2, 5
.set SOUND_SERVO, 6
.set SOUND_ALERT, 7
.set SOUND_SPARK, 8
.set SOUND_STRUCK, 9
.set SOUND_DESTROY, 10
.set SOUND_PICKUP, 11
.set SOUND_DOOR_OPEN, 12
.set SOUND_DOOR_CLOSE, 13
.set SOUND_GATE, 14
.set SOUND_RESPAWN, 15
.set SOUND_COUNT, 16

# A section's address in the map
# kind int The kind
# returns
#   reg The address
.macro section_at kind, reg
    la \reg, sections
    ld \reg, (SECTION_AT + SECTION_ENTRY * (\kind - 1))(\reg)
.endm

# A section's record count
# kind int The kind
# returns
#   reg The count
.macro section_count kind, reg
    la \reg, sections
    ld \reg, (SECTION_COUNT + SECTION_ENTRY * (\kind - 1))(\reg)
.endm
