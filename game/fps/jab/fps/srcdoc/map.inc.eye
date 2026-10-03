set MAP_MAGIC u32 [1] :the file's first word, JAB and a zero
set MAP_MAGIC_AT u32 [2] :the magic's offset
set MAP_SECTION_COUNT u32 [3] :the section directory's entries
set MAP_HEADER_SIZE [4] :the header's bytes, the directory following it
set ENTRY_KIND u32 [5] :a directory entry's kind, a KIND_*
set ENTRY_OFFSET u32 [6] :the section's offset from the file's start
set ENTRY_SIZE u32 [7] :the section's record size
set ENTRY_COUNT u32 [8] :the section's record count
set ENTRY_BYTES [9] :a directory entry's bytes
set KIND_NAMES u32 [10] :the names table
set KIND_MATERIALS u32 [11] :the materials
set KIND_VERTICES u32 [12] :the vertices
set KIND_SECTORS u32 [13] :the sectors
set KIND_LOOPS u32 [14] :the loops
set KIND_WALLS u32 [15] :the walls
set KIND_PORTALS u32 [16] :the portals
set KIND_ENTITIES u32 [17] :the entities
set KIND_AMBIENTS u32 [18] :the ambients
set KIND_SECTOR_LIGHTS u32 [19] :the sector lights
set KIND_COUNT [20] :the kinds, numbered from 1
set MATERIAL_NAME u32 [21] :a material's name, an offset into the names table
set MATERIAL_FLAGS u32 [22] :a material's flags
set MATERIAL_SIZE [23] :a material's bytes
set VERTEX_X f32 [24] :a vertex's x
set VERTEX_Y f32 [25] :a vertex's y
set VERTEX_SIZE [26] :a vertex's bytes
set SURFACE_MATERIAL i32 [27] :a surface's material or -1
set SURFACE_U_SCALE f32 [28] :the repeats a metre along u
set SURFACE_V_SCALE f32 [29] :the repeats a metre along v
set SURFACE_U_OFFSET f32 [30] :u's offset in repeats
set SURFACE_V_OFFSET f32 [31] :v's offset in repeats
set SURFACE_FLAGS u32 [32] :the flags, SURFACE_SOLID, SURFACE_MASKED, and SURFACE_SKY
set SURFACE_SIZE [33] :a surface's bytes
set SURFACE_SOLID u32 [34] :bit 0, solid
set SURFACE_MASKED u32 [35] :bit 1, masked
set SURFACE_SKY u32 [36] :bit 2, sky
set SECTOR_FLOOR 3 f32 [37] :the floor plane, a, b, c with z = a x + b y + c
set SECTOR_CEILING 3 f32 [38] :the ceiling plane, a, b, c
set SECTOR_FLOOR_SURFACE 24 u8 [39] :the floor's surface
set SECTOR_CEILING_SURFACE 24 u8 [40] :the ceiling's surface
set SECTOR_FIRST_LOOP u32 [41] :the sector's first loop, its loops consecutive
set SECTOR_LOOP_COUNT u32 [42] :the sector's loops
set SECTOR_MIN_X f32 [43] :the bounds' least x
set SECTOR_MIN_Y f32 [44] :the bounds' least y
set SECTOR_MAX_X f32 [45] :the bounds' greatest x
set SECTOR_MAX_Y f32 [46] :the bounds' greatest y
set SECTOR_TAG u32 [47] :the sector's tag
set SECTOR_AMBIENT i32 [48] :the sector's ambient or -1
set SECTOR_FIRST_LIGHT u32 [49] :the sector's first sector light, its list consecutive
set SECTOR_LIGHT_COUNT u32 [50] :the sector's sector lights
set SECTOR_SIZE [51] :a sector's bytes
set PLANE_A f32 [52] :a plane's a
set PLANE_B f32 [53] :a plane's b
set PLANE_C f32 [54] :a plane's c
set LOOP_FIRST_WALL u32 [55] :a loop's first wall, its walls consecutive in order around it
set LOOP_WALL_COUNT u32 [56] :the loop's walls
set LOOP_SIZE [57] :a loop's bytes
set WALL_A u32 [58] :a wall's first vertex, its sector on the left from a to b
set WALL_B u32 [59] :the wall's second vertex
set WALL_SECTOR u32 [60] :the wall's sector
set WALL_SURFACE 24 u8 [61] :the wall's surface
set WALL_ANCHOR f32 [62] :the world height where v is 0
set WALL_FIRST_PORTAL u32 [63] :the wall's first portal, its portals consecutive and sorted from the top down
set WALL_PORTAL_COUNT u32 [64] :the wall's portals
set WALL_TAG u32 [65] :the wall's tag
set WALL_SIZE [66] :a wall's bytes
set PORTAL_SECTOR u32 [67] :a portal's sector across
set PORTAL_WALL u32 [68] :the wall across, running the edge back
set PORTAL_SIZE [69] :a portal's bytes
set ENTITY_CLASS u32 [70] :an entity's class, a CLASS_*
set ENTITY_X f32 [71] :the position's x
set ENTITY_Y f32 [72] :the position's y
set ENTITY_Z f32 [73] :the position's z
set ENTITY_YAW f32 [74] :the yaw in degrees
set ENTITY_PITCH f32 [75] :the pitch in degrees
set ENTITY_WIDTH f32 [76] :the width
set ENTITY_HEIGHT f32 [77] :the height
set ENTITY_MATERIAL i32 [78] :the material or -1
set ENTITY_R f32 [79] :the colour's red
set ENTITY_G f32 [80] :the colour's green
set ENTITY_B f32 [81] :the colour's blue
set ENTITY_RADIUS f32 [82] :the radius
set ENTITY_SPREAD f32 [83] :the spread
set ENTITY_FLAGS u32 [84] :the flags, ENTITY_CAMERA, ENTITY_FLAT, ENTITY_TWO_SIDED, and ENTITY_SOLID
set ENTITY_TAG u32 [85] :the entity's tag
set ENTITY_TARGET i32 [86] :the target entity or -1
set ENTITY_SECTOR i32 [87] :the entity's sector
set ENTITY_SIZE [88] :an entity's bytes
set CLASS_SPAWN u32 [89] :a spawn
set CLASS_LIGHT u32 [90] :a light
set CLASS_SPRITE u32 [91] :a sprite
set CLASS_WAYPOINT u32 [92] :a waypoint
set CLASS_ANDROID u32 [93] :an android
set CLASS_MAGAZINE u32 [94] :a magazine
set CLASS_COUNT [95] :the classes
set ENTITY_CAMERA u32 [96] :bit 0, facing the camera
set ENTITY_FLAT u32 [97] :bit 1, flat
set ENTITY_TWO_SIDED u32 [98] :bit 2, two-sided
set ENTITY_SOLID u32 [99] :bit 3, solid
set AMBIENT_NAME u32 [100] :an ambient's name, the MIDI's romfs stem, an offset into the names table
set AMBIENT_SIZE [101] :an ambient's bytes
set SECTOR_LIGHT_SIZE [102] :a sector light's bytes, an entity index
set MAX_SECTORS [103] :the sectors a map may hold in this build
set MAX_LOOPS [104] :the loops a map may hold
set MAX_WALLS [105] :the walls a map may hold
set MAX_VERTICES [106] :the vertices a map may hold
set MAX_PORTALS [107] :the portals a map may hold
set MAX_ENTITIES [108] :the entities a map may hold
set MAX_MATERIALS [109] :the materials a map may hold, with the engine's images after them
set MAX_AMBIENTS [110] :the ambients a map may hold
set MAX_SECTOR_LIGHTS [111] :the sector lights a map may hold
set MAX_NAMES [112] :the names table's bytes a map may hold
