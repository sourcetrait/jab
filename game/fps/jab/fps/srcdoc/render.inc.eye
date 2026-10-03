set SCREEN_W [1] :the screen's width in pixels
set SCREEN_H [2] :the screen's height in pixels
set SCREEN_PITCH [3] :a screen row's bytes
set ZBUF_BYTES [4] :the depth buffer's bytes, a word a pixel
set CODE_PAGE [5] :a page of code under QEMU, the alignment and the bound of a function whose loops run a pixel or a sample
set SECTION_AT address [6] :a section's address in the map buffer
set SECTION_COUNT u64 [7] :the section's record count
set SECTION_ENTRY [8] :a sections entry's bytes, an entry a kind from 1
set CAM_X f32 [9] :the eye's x
set CAM_Y f32 [10] :the eye's y
set CAM_Z f32 [11] :the eye's z
set CAM_YAW f32 [12] :the yaw in radians
set CAM_PITCH f32 [13] :the pitch in radians
set CAM_ROLL f32 [14] :the roll in radians
set CAM_RIGHT 3 f32 [15] :the basis's right, derived from the angles each frame
set CAM_UP 3 f32 [16] :the basis's up
set CAM_FORWARD 3 f32 [17] :the basis's forward
set CAM_SIZE [18] :the camera's bytes
set CAMD_X 3 f64 [19] :the eye as doubles
set CAMD_RIGHT 3 f64 [20] :the right as doubles
set CAMD_UP 3 f64 [21] :the up as doubles
set CAMD_FORWARD 3 f64 [22] :the forward as doubles
set CAMD_SIZE [23] :camera_d's bytes, at twice the camera's offsets
set MAX_VERTS [24] :a polygon's world points before clipping at most
set MAX_CLIPPED [25] :its points after the near plane at most, which can add one an edge
set VERT_SIZE [26] :a world point's bytes, three floats
set PVERT_SIZE [27] :a projected point's bytes, x and y floats
set MAX_EDGES [28] :the edge list's edges at most
set EDGE_Y0 f32 [29] :an edge's top y
set EDGE_Y1 f32 [30] :its bottom y
set EDGE_X0 f32 [31] :its x at the top
set EDGE_DXDY f32 [32] :x's change a row
set EDGE_SIZE [33] :an edge's bytes
set POLY_TEX address [34] :the surface in hand's texture pixels
set POLY_UMASK u64 [35] :u's wrap mask
set POLY_VMASK u64 [36] :v's wrap mask
set POLY_WSHIFT u64 [37] :a texture row's bytes as a shift
set POLY_IZA i64 [38] :1/z's change a column, 6.26
set POLY_IZB i64 [39] :1/z's change a row
set POLY_IZC i64 [40] :1/z at the screen's origin with the half pixel
set POLY_UZA i64 [41] :u/z's change a column, 48.16
set POLY_UZB i64 [42] :u/z's change a row
set POLY_UZC i64 [43] :u/z at the screen's origin with the half pixel
set POLY_VZA i64 [44] :v/z's change a column, 48.16
set POLY_VZB i64 [45] :v/z's change a row
set POLY_VZC i64 [46] :v/z at the screen's origin with the half pixel
set POLY_MODE u64 [47] :a POLY_TEXTURED, POLY_MASKED, or POLY_SKY, with POLY_LIT and POLY_TILED over it
set POLY_TEXW f32 [48] :the texture's width
set POLY_TEXH f32 [49] :the texture's height
set POLY_TEXWI u32 [50] :the texture's width as an integer
set POLY_TEXHI u32 [51] :the texture's height as an integer
set POLY_LNX f32 [52] :the unit normal facing the camera, its x, for the light
set POLY_LNY f32 [53] :the normal's y
set POLY_LNZ f32 [54] :the normal's z
set POLY_SECTOR u32 [55] :the surface's sector, for the light
set POLY_FLAT_LIT u64 [56] :set for a surface lit at no angle, a sprite facing the camera, every light within reach lighting it by its falloff alone
set POLY_LIGHTS 32 u8 [57] :the polygon's own light list, a count byte then that many light indices
set POLY_LUMAP address [58] :the surface's lumel map record, 0 for a polygon with no map, a sprite lit flat by POLY_FLAT_BRIGHT
set POLY_LUMEL u64 [59] :the read's one word for a mapped polygon, packed by the LUMEL_* shifts
set POLY_FLAT_BRIGHT u64 [60] :the brightness word of a polygon with no map
set POLY_TILES 4 address [61] :each level's atlas, TILE_LEVEL_COUNT of them
set POLY_TILE_READY u64 [62] :the levels built whole, which a span's levels stay under
set POLY_TILE_COLS_SHIFT u64 [63] :a cell row's tiles as a shift, the columns padded to a power of two
set POLY_TILE_COLS u64 [64] :the cells across, which a span's ends lie within
set POLY_TILE_ROWS u64 [65] :the cells down, which a span's ends lie within
set POLY_MATERIAL u32 [66] :the material bound, for the level's alpha scale at a tile's build
set POLY_SURFACE u64 [67] :the surface the polygon is, for the span record and the owner build
set POLY_MIPS address [68] :the material's chain, its table of a level's texels eight bytes a level
set POLY_MIP_COUNT u64 [69] :the levels the chain has, which a block's level is held under
set POLY_SIZE [70] :the polygon in hand's bytes
set LUMEL_OFFSET_BITS [71] :the read's word's low bits holding the lumels' offset into the arena
set LUMEL_ROWBYTES_SHIFT [72] :the place of a row's bytes in the read's word
set LUMEL_ROWS_SHIFT [73] :the place of the rows in the read's word
set LUMEL_K_SHIFT [74] :the place of k in the read's word
set LUMEL_K_MAX [75] :k at most
set CHANNEL_BITS [76] :the distance between a brightness word's three 16.16 channels
set LUMAP_BASE address [77] :a lumel map's lumels in the arena, 0 for none
set LUMAP_W u64 [78] :its columns
set LUMAP_H u64 [79] :its rows
set LUMAP_U0 i64 [80] :the texel u of its first node
set LUMAP_V0 i64 [81] :the texel v of its first node
set LUMAP_K u64 [82] :k, a lumel being 2^k texels along both axes
set LUMAP_SIZE [83] :a lumel map record's bytes
set LUMAP_PLANES [84] :the planes' maps, a sector's floor at twice its index and its ceiling after
set LUMAP_COUNT [85] :every surface's map, the walls after the planes
set LUMEL_BYTES [86] :a lumel's bytes
set LUMEL_ARENA_BYTES [87] :the arena holding every map's lumels
set SURFACE_SPRITES [88] :the first map sprite's surface index, a map sprite at it plus its entity
set SURFACE_ACTORS [89] :the first actor's surface index, an actor at it plus its index
set RECT_X0 i32 [90] :a screen rectangle's first column
set RECT_X1 i32 [91] :the column past its last
set RECT_Y0 i32 [92] :its first row
set RECT_Y1 i32 [93] :the row past its last
set RECT_SIZE [94] :a rectangle's bytes, empty when an end is at or before its start
set FLOW_RING [95] :the flow's queue, a ring of sector indices twice the sectors long
set FLOW_RING_MASK [96] :the ring's index mask
set SPAN_ROW u16 [97] :a span record's row
set SPAN_X0 u16 [98] :the span's first pixel
set SPAN_X1 u16 [99] :the pixel past its last
set SPAN_MODE u16 [100] :the polygon's mode
set SPAN_SURFACE u32 [101] :the surface, the stable index
set SPAN_POLY u32 [102] :the polygon's serial in the frame, telling a masked opening's fill from its wall's pieces
set SPAN_RECORD_SIZE [103] :a span record's bytes
set SPAN_RECORDS [104] :the records a frame holds, the count running on past them
set GRID_O 3 f64 [105] :the world point at texel (0, 0) of the surface's mapping
set GRID_U 3 f64 [106] :the world step a texel along u
set GRID_V 3 f64 [107] :the world step a texel along v
set GRID_N 3 f32 [108] :the unit normal into the room
set GRID_SIZE [109] :the bake's frame's bytes
set INTERVAL_SHIFT_MAX [110] :the shift of a lit span's longest sample interval, four blocks
set POLY_TEXTURED u64 [111] :the mode textured
set POLY_MASKED u64 [112] :the mode masked
set POLY_SKY u64 [113] :the mode the sky
set POLY_LIT u64 [114] :a flag over the textured and masked modes, the span lit
set POLY_TILED u64 [115] :a flag over a lit mode, the surface's tiles read
set TILE_LEVEL_COUNT [116] :the levels of a surface's tiles at most
set TILE_BASE 4 address [117] :each level's atlas, 0 before it is reserved and -1 for a surface past TILE_ATLAS_MAX
set TILE_READY u64 [118] :the levels built whole
set TILE_CURSOR u64 [119] :the next cell to build at the level in hand
set TILE_LEVELS u64 [120] :the levels the surface has, TILE_LEVEL_COUNT or k + 1, the fewer
set TILE_COLS_SHIFT u64 [121] :a cell row's tiles as a shift
set TILE_COLS u64 [122] :the cells across, the map's nodes
set TILE_ROWS u64 [123] :the cells down, the map's nodes
set TILE_CELLS u64 [124] :the cells, the rows by the padded columns
set TILE_SIZE [125] :a tile record's bytes
set TILE_ARENA_BYTES [126] :the tile arena's bytes
set TILE_ATLAS_MAX [127] :the largest level 0 atlas, a surface past it staying on the lit loop
set TILE_BUDGET [128] :the texture's texels a frame's builds may read
set TILE_BUDGET_UNBOUND [129] :a budget no frame reaches
set MIP_LEVELS [130] :a chain's levels at most
set MIP_ENTRY [131] :a material's chain table's bytes, a level's texels eight bytes a level
set MIP_ARENA_BYTES [132] :the chains' arena's bytes
set ALPHA_PASS u8 [133] :the alpha at or above which a masked texel passes, at every level
set ALPHA_SCALE_BITS [134] :an alpha scale's fraction bits
set ALPHA_SCALE_ONE u32 [135] :a scale of one, the levels passing as the texture does
set ALPHA_SCALE_TOP u32 [136] :2^23, a scale being ceil(ALPHA_SCALE_TOP / T)
set ALPHA_LEVEL_SIZE [137] :a level's scale's bytes
set ALPHA_MATERIAL_SIZE [138] :a material's scales' bytes, a scale a level of the chain
set ALPHA_PLANE_BYTES [139] :the scratch a level's alphas take at the search, a texture past it left at one
set ALPHA_SHARE [140] :the unit the debug line reports a share in
set MAX_LIGHTS [141] :the lights the engine holds at most
set LIGHT_X f32 [142] :a light's x
set LIGHT_Y f32 [143] :its y
set LIGHT_Z f32 [144] :its z
set LIGHT_R f32 [145] :its colour's red
set LIGHT_G f32 [146] :its colour's green
set LIGHT_B f32 [147] :its colour's blue
set LIGHT_RADIUS2 f32 [148] :its radius squared
set LIGHT_AXIS 3 f32 [149] :a spotlight's unit axis
set LIGHT_COS f32 [150] :the cosine of its spread, under -1 for a point light
set LIGHT_OVER_RADIUS f32 [151] :one over its radius
set LIGHT_SIZE [152] :a light's bytes
set SECTOR_LIGHTS_MAX [153] :a sector's lights at most
set SECTOR_LIGHTS_SIZE [154] :a sector's list's bytes, a count byte then that many light indices
set PLANE_N 3 f32 [155] :the plane in hand's normal
set PLANE_Q 3 f32 [156] :a point on it
set PLANE_AU 3 f32 [157] :u's world gradient in texture repeats
set PLANE_U0 f32 [158] :u's offset in texture repeats
set PLANE_AV 3 f32 [159] :v's world gradient in texture repeats
set PLANE_V0 f32 [160] :v's offset in texture repeats
set PLANE_SIZE [161] :the plane in hand's bytes
set PLANED_N 3 f64 [162] :the normal as doubles
set PLANED_Q 3 f64 [163] :the point as doubles
set PLANED_AU 3 f64 [164] :u's gradient as doubles
set PLANED_U0 f64 [165] :u's offset as a double
set PLANED_AV 3 f64 [166] :v's gradient as doubles
set PLANED_V0 f64 [167] :v's offset as a double
set PLANED_SIZE [168] :plane_d's bytes, at twice the plane's offsets
set DEPTH_BITS [169] :1/z's fraction bits, 6.26
set Z_SHIFT [170] :z as 2^Z_SHIFT over 1/z, 48.16
set BLOCK [171] :a span block's pixels
set IZ_MIN u32 [172] :the least 1/z a divide takes, a smaller one clamped to it
set SKY_DEPTH u32 [173] :the depth a sky pixel stores, so anything drawn later overwrites it
set STAT_SECTORS u64 [174] :the frame's sectors drawn
set STAT_WALLS u64 [175] :its walls drawn
set STAT_PIECES u64 [176] :its wall pieces filled
set STAT_PLANES u64 [177] :its planes filled
set STAT_OPENINGS u64 [178] :its openings flowed
set STAT_CLEAR_TICKS u64 [179] :the depth clear's ticks
set STAT_PLANE_TICKS u64 [180] :the planes' ticks
set STAT_WALL_TICKS u64 [181] :the walls' ticks
set STAT_PORTAL_TICKS u64 [182] :the flow's ticks
set STAT_SPRITES u64 [183] :the sprites filled
set STAT_SPRITE_TICKS u64 [184] :the sprites' and actors' ticks
set STAT_SPANS u64 [185] :the spans filled
set STAT_PIXELS u64 [186] :the pixels they entered
set STAT_LIT_SPANS u64 [187] :the lit spans among them
set STAT_LIT_PIXELS u64 [188] :the lit pixels among them
set STAT_LIGHT_TICKS u64 [189] :the ticks the light's evaluation took
set STAT_REJECTED u64 [190] :the pixels the depth test rejected
set STAT_SAMPLES u64 [191] :the lumel samples the lit spans read
set STAT_TILES_BUILT u64 [192] :the tiles built this frame
set STAT_TILED_PIXELS u64 [193] :the pixels read from tiles
set STAT_TILE_RESETS u64 [194] :the tile arena's resets since the load, never zeroed by the frame
set STAT_SIZE [195] :the stats' bytes
set REPORT_KIND u32 [196] :a record's kind over the API, a REPORT_*
set REPORT_SECTOR i32 [197] :the camera's sector, or the console's command byte
set REPORT_X f32 [198] :the eye's x
set REPORT_Y f32 [199] :the eye's y
set REPORT_Z f32 [200] :the eye's z
set REPORT_YAW f32 [201] :the yaw in degrees
set REPORT_PITCH f32 [202] :the pitch in degrees
set REPORT_ROLL f32 [203] :the roll in degrees
set REPORT_FRAME_US u32 [204] :the last frame's drawing in microseconds
set REPORT_GAME_US u32 [205] :the last frame's game in microseconds
set REPORT_FIELD0 i32 [206] :an event's first field
set REPORT_FIELD1 i32 [207] :an event's second field
set REPORT_FIELD2 i32 [208] :an event's third field
set REPORT_FIELD3 i32 [209] :an event's fourth field
set REPORT_FIELD4 i32 [210] :an event's fifth field
set REPORT_SIZE [211] :a record's bytes, zero to the end
set REPORT_STATE u32 [212] :the state, a record a frame
set REPORT_ROUND u32 [213] :a round of the player's, what it met, the actor, its health after
set REPORT_ANDROID u32 [214] :an android's event, the event, the actor, its row
set REPORT_HURT u32 [215] :the player struck, the damage, the health after
set REPORT_PICKUP u32 [216] :a pickup, the rounds after
set REPORT_TRACE u32 [217] :a trace's answer, the kind met, the distance and the point in millimetres
set REPORT_CONSOLE u32 [218] :the console's answer, the command's byte
set EVENT_ROUSED u32 [219] :an android roused
set EVENT_FIRED u32 [220] :an android's round fired
set EVENT_STRUCK u32 [221] :an android struck
set EVENT_DESTROYED u32 [222] :an android destroyed
set EVENT_FALLEN u32 [223] :an android fallen, its magazine dropped
set EVENT_WAYPOINT u32 [224] :an android at its waypoint
set MAX_ACTORS [226] :the actors in play at most
set ACTOR_CLASS u32 [227] :an actor's class, an ACTOR_*, ACTOR_NONE free
set ACTOR_FLAGS u32 [228] :the flags, ACTOR_SOLID, ACTOR_SHOOTABLE, ACTOR_ROUSED, ACTOR_SIGHTED, and ACTOR_FIRST
set ACTOR_X f64 [229] :the feet's x
set ACTOR_Y f64 [230] :the feet's y
set ACTOR_Z f64 [231] :the feet's z
set ACTOR_YAW f32 [232] :the yaw in radians
set ACTOR_SECTOR i32 [233] :the sector
set ACTOR_ROW u32 [234] :the row
set ACTOR_TIMER f32 [235] :the row's timer in seconds
set ACTOR_HEALTH i32 [236] :the health
set ACTOR_TARGET i32 [237] :the target waypoint entity or -1
set ACTOR_FALL f64 [238] :the fall speed
set ACTOR_SEEN_X f64 [239] :the last sight's x, the player's feet
set ACTOR_SEEN_Y f64 [240] :the last sight's y
set ACTOR_SEEN_Z f64 [241] :the last sight's z
set ACTOR_BLOCKED f32 [242] :the seconds blocked
set ACTOR_FRAME u32 [243] :a spark's frame
set ACTOR_LOST f32 [244] :the seconds since the sight was lost
set ACTOR_ENTITY u32 [245] :the entity it came from
set ACTOR_SIZE [246] :an actor's bytes
set ACTOR_NONE u32 [247] :free
set ACTOR_ANDROID u32 [248] :an android
set ACTOR_MAGAZINE u32 [249] :a magazine
set ACTOR_SPARK u32 [250] :a spark
set ACTOR_SOLID u32 [251] :a body the others are pushed out of
set ACTOR_SHOOTABLE u32 [252] :a round can strike it
set ACTOR_ROUSED u32 [253] :roused
set ACTOR_SIGHTED u32 [254] :the player sighted
set ACTOR_FIRST u32 [255] :the first round after rousing, which is certain, the rest by chance
set FIRE_CHANCE [256] :a round's chance in 256 after the first
set SET_STAND u32 [257] :the android's standing set
set SET_WALK1 u32 [258] :its walk's first set
set SET_WALK2 u32 [259] :its walk's second set
set SET_WALK3 u32 [260] :its walk's third set
set SET_WALK4 u32 [261] :its walk's fourth set
set SET_AIM u32 [262] :its aiming set
set SET_FIRE u32 [263] :its firing set
set SET_STRUCK u32 [264] :its struck set
set SET_FALLEN u32 [265] :the fallen frame, a set of one
set FRAME_FALLEN [266] :the fallen frame's index, after the eight rotating sets of eight
set FRAME_SPARK1 [267] :the first of the three sparks' frames
set FRAME_MAGAZINE [268] :the magazine's frame
set FRAME_COUNT [269] :the engine's images
set SPARK_FRAMES [270] :a spark's frames
set ROW_SET u32 [271] :a row's frame set
set ROW_MS i32 [272] :the milliseconds it lasts, -1 for a held row
set ROW_ACTION u32 [273] :the action on entry, an ACT_*
set ROW_NEXT u32 [274] :the row next
set ROW_SIZE [275] :a row's bytes
set ROW_STAND u32 [276] :standing
set ROW_PATROL1 u32 [277] :a patrol's first step
set ROW_PATROL2 u32 [278] :a patrol's second step
set ROW_PATROL3 u32 [279] :a patrol's third step
set ROW_PATROL4 u32 [280] :a patrol's fourth step
set ROW_ALERT u32 [281] :alerted
set ROW_AIM u32 [282] :aiming
set ROW_FIRE u32 [283] :firing
set ROW_SEARCH1 u32 [284] :a search's first step
set ROW_SEARCH2 u32 [285] :a search's second step
set ROW_SEARCH3 u32 [286] :a search's third step
set ROW_SEARCH4 u32 [287] :a search's fourth step
set ROW_STRUCK u32 [288] :struck
set ROW_DESTROYED u32 [289] :destroyed
set ROW_FALLEN u32 [290] :fallen, held
set ACT_NONE u32 [291] :nothing on entry, action_none
set ACT_LOOK u32 [292] :action_look
set ACT_WALK u32 [293] :action_walk
set ACT_ALERT u32 [294] :action_alert
set ACT_AIM u32 [295] :action_aim
set ACT_FIRE u32 [296] :action_fire
set ACT_SEEK u32 [297] :action_seek
set ACT_STRUCK u32 [298] :action_struck
set ACT_DESTROY u32 [299] :action_destroy
set ACT_FALL u32 [300] :action_fall
set ANDROID_HEALTH i32 [301] :an android's health at the start
set AIM_OX f64 [302] :the actor's eye's x
set AIM_OY f64 [303] :the actor's eye's y
set AIM_OZ f64 [304] :the actor's eye's z
set AIM_DX f64 [305] :the unit direction's x toward the player's eye
set AIM_DY f64 [306] :the unit direction's y
set AIM_DZ f64 [307] :the unit direction's z
set AIM_DIST f64 [308] :the distance
set AIM_SIZE [309] :the line's bytes
set TRACE_NONE u64 [310] :nothing met
set TRACE_PLANE u64 [311] :a plane met
set TRACE_PIECE u64 [312] :a wall piece met
set TRACE_ANDROID u64 [313] :an android met
set TRACE_PLAYER u64 [314] :the player met
set TRACE_KIND u64 [315] :what the ray met, a TRACE_*
set TRACE_DIST f64 [316] :the distance
set TRACE_PX f64 [317] :the point's x
set TRACE_PY f64 [318] :the point's y
set TRACE_PZ f64 [319] :the point's z
set TRACE_ACTOR address [320] :the actor met
set TRACE_SECTOR u64 [321] :the sector the ray ended in
set TRACE_SIZE [322] :a trace's answer's bytes
set TRACE_TO_PLAYER u64 [323] :the trace tests the player's capsule too
set TRIGGER_BIT u32 [324] :the pad's key that fires, the right trigger's button, as its bit in the state record's keys
set ROUND_DAMAGE i32 [325] :what the G-1's round takes from its target, on either side
set SOUND_G1_SHOT u64 [326] :the G-1's shot
set SOUND_G1_RELOAD u64 [327] :the G-1's reload
set SOUND_G1_EMPTY u64 [328] :the G-1 empty
set SOUND_G1_BOLT u64 [329] :the G-1's bolt
set SOUND_FOOTSTEP1 u64 [330] :a footstep
set SOUND_FOOTSTEP2 u64 [331] :the other footstep
set SOUND_SERVO u64 [332] :an android's servo
set SOUND_ALERT u64 [333] :an android's alert
set SOUND_SPARK u64 [334] :a spark
set SOUND_STRUCK u64 [335] :an android struck
set SOUND_DESTROY u64 [336] :an android destroyed
set SOUND_PICKUP u64 [337] :a pickup
set SOUND_DOOR_OPEN u64 [338] :a door opening
set SOUND_DOOR_CLOSE u64 [339] :a door closing
set SOUND_GATE u64 [340] :a gate
set SOUND_RESPAWN u64 [341] :a respawn
set SOUND_COUNT [342] :the engine's stems
macro owner_pixel reg reg,surface 32(sp) u64 > pixel reg u64 [344:348]
 reg :the register a pixel loop is about to store
 surface :span_fill's slot holding the polygon's surface index
 pixel :under OWNER the surface's index in place of its colour, else the register as it was
macro section_at kind imm,reg reg > section reg address [350:353]
 kind :a KIND_*
macro section_count kind imm,reg reg > count reg u64 [355:358]
 kind :a KIND_*
