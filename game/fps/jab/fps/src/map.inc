# map.inc: the Jab FPS map, <name>.jabfps.map, as byte offsets, the
# format the loader reads in place: a header, a section directory the
# loader validates, and packed sections; every field 32-bit and
# little-endian, floats singles, positions metres, the world z up. The
# program's own limits on what a map may hold are here as well.
.set MAP_MAGIC, 0x0042414a          # JAB and a zero
.set MAP_MAGIC_AT, 0
.set MAP_SECTION_COUNT, 4
.set MAP_HEADER_SIZE, 8
# A directory entry: the kind, the offset from the file's start, the
# record size, the record count
.set ENTRY_KIND, 0
.set ENTRY_OFFSET, 4
.set ENTRY_SIZE, 8
.set ENTRY_COUNT, 12
.set ENTRY_BYTES, 16
# The kinds
.set KIND_NAMES, 1
.set KIND_MATERIALS, 2
.set KIND_VERTICES, 3
.set KIND_SECTORS, 4
.set KIND_LOOPS, 5
.set KIND_WALLS, 6
.set KIND_PORTALS, 7
.set KIND_ENTITIES, 8
.set KIND_AMBIENTS, 9
.set KIND_SECTOR_LIGHTS, 10
.set KIND_COUNT, 10
# A material: its name, an offset into the names table, the romfs stem
# the texture loads from with .png appended; flags
.set MATERIAL_NAME, 0
.set MATERIAL_FLAGS, 4
.set MATERIAL_SIZE, 8
# A vertex: x, y
.set VERTEX_X, 0
.set VERTEX_Y, 4
.set VERTEX_SIZE, 8
# A surface: the material or -1, the scales in repeats a metre, the
# offsets in repeats, flags (bit 0 solid, bit 1 masked, bit 2 sky)
.set SURFACE_MATERIAL, 0
.set SURFACE_U_SCALE, 4
.set SURFACE_V_SCALE, 8
.set SURFACE_U_OFFSET, 12
.set SURFACE_V_OFFSET, 16
.set SURFACE_FLAGS, 20
.set SURFACE_SIZE, 24
.set SURFACE_SOLID, 1
.set SURFACE_MASKED, 2
.set SURFACE_SKY, 4
# A sector: the floor and ceiling planes as a, b, c with z = a x + b y
# + c; the two surfaces; the loops, consecutive; the bounds; the tag;
# the ambient or -1; the light list, consecutive in the sector lights
.set SECTOR_FLOOR, 0
.set SECTOR_CEILING, 12
.set SECTOR_FLOOR_SURFACE, 24
.set SECTOR_CEILING_SURFACE, 48
.set SECTOR_FIRST_LOOP, 72
.set SECTOR_LOOP_COUNT, 76
.set SECTOR_MIN_X, 80
.set SECTOR_MIN_Y, 84
.set SECTOR_MAX_X, 88
.set SECTOR_MAX_Y, 92
.set SECTOR_TAG, 96
.set SECTOR_AMBIENT, 100
.set SECTOR_FIRST_LIGHT, 104
.set SECTOR_LIGHT_COUNT, 108
.set SECTOR_SIZE, 112
.set PLANE_A, 0
.set PLANE_B, 4
.set PLANE_C, 8
# A loop: its walls, consecutive in order around it
.set LOOP_FIRST_WALL, 0
.set LOOP_WALL_COUNT, 4
.set LOOP_SIZE, 8
# A wall: vertex a to vertex b with its sector on the left; the
# surface; the anchor, the world height where v is 0; its portals,
# consecutive and sorted from the top down; the tag
.set WALL_A, 0
.set WALL_B, 4
.set WALL_SECTOR, 8
.set WALL_SURFACE, 12
.set WALL_ANCHOR, 36
.set WALL_FIRST_PORTAL, 40
.set WALL_PORTAL_COUNT, 44
.set WALL_TAG, 48
.set WALL_SIZE, 52
# A portal: the sector across and its wall running the edge back
.set PORTAL_SECTOR, 0
.set PORTAL_WALL, 4
.set PORTAL_SIZE, 8
# An entity: the class, the position, the angles in degrees, the size,
# the material or -1, the colour, the radius, the spread, flags (bit 0
# facing the camera, bit 1 flat, bit 2 two-sided, bit 3 solid), the
# tag, the target or -1, the sector
.set ENTITY_CLASS, 0
.set ENTITY_X, 4
.set ENTITY_Y, 8
.set ENTITY_Z, 12
.set ENTITY_YAW, 16
.set ENTITY_PITCH, 20
.set ENTITY_WIDTH, 24
.set ENTITY_HEIGHT, 28
.set ENTITY_MATERIAL, 32
.set ENTITY_R, 36
.set ENTITY_G, 40
.set ENTITY_B, 44
.set ENTITY_RADIUS, 48
.set ENTITY_SPREAD, 52
.set ENTITY_FLAGS, 56
.set ENTITY_TAG, 60
.set ENTITY_TARGET, 64
.set ENTITY_SECTOR, 68
.set ENTITY_SIZE, 72
.set CLASS_SPAWN, 0
.set CLASS_LIGHT, 1
.set CLASS_SPRITE, 2
.set CLASS_WAYPOINT, 3
.set CLASS_ANDROID, 4
.set CLASS_MAGAZINE, 5
.set CLASS_COUNT, 6
.set ENTITY_CAMERA, 1
.set ENTITY_FLAT, 2
.set ENTITY_TWO_SIDED, 4
.set ENTITY_SOLID, 8
# An ambient: its name, the MIDI's romfs stem
.set AMBIENT_NAME, 0
.set AMBIENT_SIZE, 4
# A sector light: an entity index
.set SECTOR_LIGHT_SIZE, 4
# What a map may hold in this build, each a number to raise
.set MAX_SECTORS, 1024
.set MAX_LOOPS, 4096
.set MAX_WALLS, 8192
.set MAX_VERTICES, 8192
.set MAX_PORTALS, 8192
.set MAX_ENTITIES, 1024
.set MAX_MATERIALS, 256
.set MAX_AMBIENTS, 64
.set MAX_SECTOR_LIGHTS, 16384
.set MAX_NAMES, 65536
