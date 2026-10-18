# map.inc

The Jab FPS map, <name>.jabfps.map, as byte offsets, and the program's limits
on what a map may hold.

The offsets mirror the map format: every number 32-bit and little-endian,
floats singles, positions metres, z up; a surface is 24 bytes wherever it
appears, a sector light 4. The limits are this build's, each a number to
raise; the loader refuses a count past one with exit 8.

## .set MAP_MAGIC

`u32`: the file's first word, JAB and a zero.

## .set MAP_MAGIC_AT

`u32`: the magic's offset.

## .set MAP_SECTION_COUNT

`u32`: the section directory's entries.

## .set MAP_HEADER_SIZE

The header's bytes, the directory following it.

## .set ENTRY_KIND

`u32`: a directory entry's kind, a KIND_*.

## .set ENTRY_OFFSET

`u32`: the section's offset from the file's start.

## .set ENTRY_SIZE

`u32`: the section's record size.

## .set ENTRY_COUNT

`u32`: the section's record count.

## .set ENTRY_BYTES

A directory entry's bytes.

## .set KIND_NAMES

`u32`: the names table.

## .set KIND_MATERIALS

`u32`: the materials.

## .set KIND_VERTICES

`u32`: the vertices.

## .set KIND_SECTORS

`u32`: the sectors.

## .set KIND_LOOPS

`u32`: the loops.

## .set KIND_WALLS

`u32`: the walls.

## .set KIND_PORTALS

`u32`: the portals.

## .set KIND_ENTITIES

`u32`: the entities.

## .set KIND_AMBIENTS

`u32`: the ambients.

## .set KIND_SECTOR_LIGHTS

`u32`: the sector lights.

## .set KIND_COUNT

The kinds, numbered from 1.

## .set MATERIAL_NAME

`u32`: a material's name, an offset into the names table.

The name is the romfs stem the texture loads from, with .png appended.

## .set MATERIAL_FLAGS

`u32`: a material's flags.

## .set MATERIAL_SIZE

A material's bytes.

## .set VERTEX_X

`f32`: a vertex's x.

## .set VERTEX_Y

`f32`: a vertex's y.

## .set VERTEX_SIZE

A vertex's bytes.

## .set SURFACE_MATERIAL

`i32`: a surface's material or -1.

## .set SURFACE_U_SCALE

`f32`: the repeats a metre along u.

## .set SURFACE_V_SCALE

`f32`: the repeats a metre along v.

## .set SURFACE_U_OFFSET

`f32`: u's offset in repeats.

## .set SURFACE_V_OFFSET

`f32`: v's offset in repeats.

## .set SURFACE_FLAGS

`u32`: the flags, SURFACE_SOLID, SURFACE_MASKED, and SURFACE_SKY.

## .set SURFACE_SIZE

A surface's bytes.

## .set SURFACE_SOLID

`u32`: bit 0, solid.

## .set SURFACE_MASKED

`u32`: bit 1, masked.

## .set SURFACE_SKY

`u32`: bit 2, sky.

## .set SECTOR_FLOOR

`3 f32`: the floor plane, a, b, c with z = a x + b y + c.

## .set SECTOR_CEILING

`3 f32`: the ceiling plane, a, b, c.

## .set SECTOR_FLOOR_SURFACE

`24 u8`: the floor's surface.

## .set SECTOR_CEILING_SURFACE

`24 u8`: the ceiling's surface.

## .set SECTOR_FIRST_LOOP

`u32`: the sector's first loop, its loops consecutive.

## .set SECTOR_LOOP_COUNT

`u32`: the sector's loops.

## .set SECTOR_MIN_X

`f32`: the bounds' least x.

## .set SECTOR_MIN_Y

`f32`: the bounds' least y.

## .set SECTOR_MAX_X

`f32`: the bounds' greatest x.

## .set SECTOR_MAX_Y

`f32`: the bounds' greatest y.

## .set SECTOR_TAG

`u32`: the sector's tag.

## .set SECTOR_AMBIENT

`i32`: the sector's ambient or -1.

## .set SECTOR_FIRST_LIGHT

`u32`: the sector's first sector light, its list consecutive.

## .set SECTOR_LIGHT_COUNT

`u32`: the sector's sector lights.

## .set SECTOR_SIZE

A sector's bytes.

## .set PLANE_A

`f32`: a plane's a.

## .set PLANE_B

`f32`: a plane's b.

## .set PLANE_C

`f32`: a plane's c.

## .set LOOP_FIRST_WALL

`u32`: a loop's first wall, its walls consecutive in order around it.

## .set LOOP_WALL_COUNT

`u32`: the loop's walls.

## .set LOOP_SIZE

A loop's bytes.

## .set WALL_A

`u32`: a wall's first vertex, its sector on the left from a to b.

## .set WALL_B

`u32`: the wall's second vertex.

## .set WALL_SECTOR

`u32`: the wall's sector.

## .set WALL_SURFACE

`24 u8`: the wall's surface.

## .set WALL_ANCHOR

`f32`: the world height where v is 0.

## .set WALL_FIRST_PORTAL

`u32`: the wall's first portal, its portals consecutive and sorted from the top down.

## .set WALL_PORTAL_COUNT

`u32`: the wall's portals.

## .set WALL_TAG

`u32`: the wall's tag.

## .set WALL_SIZE

A wall's bytes.

## .set PORTAL_SECTOR

`u32`: a portal's sector across.

## .set PORTAL_WALL

`u32`: the wall across, running the edge back.

## .set PORTAL_SIZE

A portal's bytes.

## .set ENTITY_CLASS

`u32`: an entity's class, a CLASS_*.

## .set ENTITY_X

`f32`: the position's x.

## .set ENTITY_Y

`f32`: the position's y.

## .set ENTITY_Z

`f32`: the position's z.

## .set ENTITY_YAW

`f32`: the yaw in degrees.

## .set ENTITY_PITCH

`f32`: the pitch in degrees.

## .set ENTITY_WIDTH

`f32`: the width.

## .set ENTITY_HEIGHT

`f32`: the height.

## .set ENTITY_MATERIAL

`i32`: the material or -1.

## .set ENTITY_R

`f32`: the colour's red.

## .set ENTITY_G

`f32`: the colour's green.

## .set ENTITY_B

`f32`: the colour's blue.

## .set ENTITY_RADIUS

`f32`: the radius.

## .set ENTITY_SPREAD

`f32`: the spread.

## .set ENTITY_FLAGS

`u32`: the flags, ENTITY_CAMERA, ENTITY_FLAT, ENTITY_TWO_SIDED, and ENTITY_SOLID.

## .set ENTITY_TAG

`u32`: the entity's tag.

## .set ENTITY_TARGET

`i32`: the target entity or -1.

## .set ENTITY_SECTOR

`i32`: the entity's sector.

## .set ENTITY_SIZE

An entity's bytes.

## .set CLASS_SPAWN

`u32`: a spawn.

## .set CLASS_LIGHT

`u32`: a light.

## .set CLASS_SPRITE

`u32`: a sprite.

## .set CLASS_WAYPOINT

`u32`: a waypoint.

## .set CLASS_ANDROID

`u32`: an android.

## .set CLASS_MAGAZINE

`u32`: a magazine.

## .set CLASS_COUNT

The classes.

## .set ENTITY_CAMERA

`u32`: bit 0, facing the camera.

## .set ENTITY_FLAT

`u32`: bit 1, flat.

## .set ENTITY_TWO_SIDED

`u32`: bit 2, two-sided.

## .set ENTITY_SOLID

`u32`: bit 3, solid.

## .set AMBIENT_NAME

`u32`: an ambient's name, the MIDI's romfs stem, an offset into the names table.

## .set AMBIENT_SIZE

An ambient's bytes.

## .set SECTOR_LIGHT_SIZE

A sector light's bytes, an entity index.

## .set MAX_SECTORS

The sectors a map may hold in this build.

## .set MAX_LOOPS

The loops a map may hold.

## .set MAX_WALLS

The walls a map may hold.

## .set MAX_VERTICES

The vertices a map may hold.

## .set MAX_PORTALS

The portals a map may hold.

## .set MAX_ENTITIES

The entities a map may hold.

## .set MAX_MATERIALS

The materials a map may hold, with the engine's images after them.

## .set MAX_AMBIENTS

The ambients a map may hold.

## .set MAX_SECTOR_LIGHTS

The sector lights a map may hold.

## .set MAX_NAMES

The names table's bytes a map may hold.
