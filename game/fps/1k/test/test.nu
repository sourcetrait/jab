# fps's integration test, on our own content alone: Render One and
# Render Zero, `render_1` and `render_0`, and copies of them the test
# compiles with fixtures of its own. Each map's tree goes on the machine
# as a romfs image built here, the manifest's image being Render Zero's:
# the UART reports the load with its counts, which must be the tree's
# from map.nuon and tile.nuon; then the first frame with its phases and
# counts, every pixel of a view reached by a surface but a rounding's
# worth, and the same for the frames drawn from the poses the console
# places; the API's state records carry the camera in each pose's
# sector after its console record; QEMU has nothing to say. First the
# load screen: Render One's title drawn there, and with no title in its
# tree a map's name in its place. Then a sprite of the test's own
# texture on a copy of Render One with its lights dropped, its
# transparent half the wall behind as a copy without the sprite draws
# it, the alpha policy at load over the test's own textures, and a quad
# straddling the door sector's two portal walls drawn whole beside the
# doorway, outside the door's rectangle; Render One with its counts,
# the camera at the spawn with its eye over the floor there facing the
# spawn's way, the window, the grate, the door's line, the door, the
# ramp, and the hall's light, which lights the floor under it past the
# far wall, the hum heard and the plan views read, then the stair on it
# walked to the upper storey; Render Zero, the game's map, from its
# spawn and four poses, one under the down flight's sloped ceiling,
# with the sky read off the yard's capture and two traces answered, its
# flights and driveway walked from placed starts with the ambient
# following and their clock read, the three cadences on a schedule of
# stalls and trigger reports and on a timed walk (cadence-holds), the
# fight: an android roused and firing, struck down by four rounds from
# the console and one from the trigger, fallen, its magazine taken on a
# walk, the shots heard; the light's view independence, floor points of
# the bay read from the spawn at two yaws on a still copy of Render
# Zero, as lit and with every lumel full bright, the light alone the
# same from both yaws; the alpha policy rendered, a texture of the
# test's own on Render One's grate wall read from poses at three
# levels, each patch present in its exact colour where the oracle's
# scaled means pass, the weighted mean of the shrink among those
# colours, and the solid backdrop behind where they do not, the lit
# loop's picture from the same build agreeing at every level, and with
# level 0 alone built the mid pose's blocks taking the chain at their
# own level and agreeing too, fewer tiles built and read than with
# every level, the same poses under the room's own light within
# TheUser's bound, tiled against lit, and the near pose with the tile
# arena reset after the frame's first binds every frame, each pixel the
# tiled picture's or the lit loop's and none the poison a stale binding
# would read; the texel-centre rule, a white
# texture on that wall under lumels set as a checkerboard, each texel
# beside a node read from its tile at the light of its centre by the
# test's own bilinear; one level a block, the still copy's spawn view
# with every level built against the tiles held off, identical over the
# screen with the far floor's blocks past the tiles' levels, and drawn in
# packets of a few commands and spans, flushed many times, identical
# again; the flow's
# eye on the line two sectors share reaching the sector behind it, and
# a map where a hall's rectangle grows through a later path before the
# room beyond it can be reached; a map whose magic is wrong, which exits
# 6, and Render One's map cut short, which exits 7, each saying so on
# the UART.
use ../../../../sdk/nu/jab.nu
use ../nu/map.nu
use ../nu/png.nu
use ./pose.nu
use ./gauge.nu
use std/assert

const LOAD = "fps: {name} loaded in {ms} ms: {sectors} sectors, {walls} walls, {vertices} vertices, {portals} portals, {entities} entities, {lights} lights, {lumel_maps} lumel maps, {sprites} sprites, {materials} materials, {textures} textures, {missing} missing"
const FRAME = "fps: frame in {us} us: {sectors} sectors, {walls} walls, {pieces} pieces, {planes} planes, {openings} openings, {sprites} sprites, {uncovered} uncovered; clear, planes, walls, portals, sprites, raster us {clear}, {plane_us}, {wall_us}, {portal_us}, {sprite_us}, {raster_us}; spans {spans}, pixels {pixels}, lit spans {lit_spans}, lit pixels {lit_pixels}, light us {light_us}, rejected {rejected}, samples {samples}, tiles built {tiles_built}, tiled {tiled}, resets {resets}, commands {commands}, flushes {flushes}, invalidated {invalidated}"
const SHORT_BYTES = 2000
# The pixels a frame may leave unreached where two surfaces meet, the
# float steps of their edges disagreeing by a rounding
const CRACKS = 32
# The API's record, 64 bytes: the kind at 0, the camera's sector at 4,
# the eye at 8, the yaw, pitch, and roll in degrees at 20, the drawing's
# and the game's microseconds at 32 and 36, an event's own fields from
# 40: kind 2 a round (what it met: 0 nothing, 1 geometry, 2 an android;
# the actor; its health after), 3 an android's event (1 roused, 2
# fired, 3 struck, 4 destroyed, 5 fallen, 6 a waypoint reached; the
# actor; its row), 4 the frame struck (the damage; the health), 5 a
# pickup (the rounds), 6 a trace's answer (0 nothing, 1 a plane, 2 a
# piece, 3 an android, 4 the player; the distance and the point in
# millimetres); kinds 7, 8, 10, and 12 the frame before's clock, its
# drawing, its presentation, and its packets, sent at each frame's start,
# and 9 the end of a measurement, which gauge.nu reads (`gauge measure`)
# and `records` leaves out
const RECORD = 64
const CLOCK_KINDS = [7 8 9 10 12]
# A console record carries the command's byte where the state's sector
# sits; the P frame's
const CONSOLE_P = 80
# The clock over Render Zero's walk: the seed and the cadence sent before
# the first frame, the E closing the measurement half a second before
# the capture, and the records' schema; a frame's next start less its
# start less its critical path, wait, and await, the microseconds the
# conversions drop, at most CLOCK_RESIDUAL
const CLOCK_SEED = 7
const CLOCK_CADENCE = 0
const CLOCK_SEED_AT = 200ms
const CLOCK_END_AT = 13500ms
const CLOCK_SCHEMA = 3
const CLOCK_RESIDUAL = 4
# A synthetic capture's frames start this many microseconds apart
const FX_PERIOD = 20000
# The cadence fixtures (cadence-holds): the cadences, the period at the
# cap of 60 in microseconds, the S frame's command byte as a console
# record carries it, and a sustained stage's first frames set aside.
# CadenceSchedule on Render One: the standing stall and the consume's
# spin from 1.5 s, ten trigger reports, the frame whose flip is tried
# before its wait, the frame stalled once, the slow stage's standing
# stall, and the E. The once stall stands well past two periods: from the
# tick before it to its flip's end run two present calls, 0.3 to 4 ms
# each here, and the kernel sets the next tick from the grid when a flip
# lands within a period of its tick and from the flip when later, so a
# stall near two periods falls either side of that edge by chance; at 38
# ms every cadence's frames stand 5 ms or more clear of every edge they
# meet. Every timed action stands 300 ms or more from the
# next: a launch writes its actions on the turns of its loop, about 220
# ms apart here, so two reports nearer than that go in together and fire
# once in a frame, as two S frames would act on one. The wakes a frame
# stays under: a consume that takes nothing spins its 500 us again on
# every wake, twenty or more in a period's wait. MotionByTime on the
# still copy of Render Zero: the placement, north along the bay's east side clear of
# the pillars, the standing stall, the stick held forward, the E, the
# body's speed, and the clearance from every wall of a frame's sector its
# frames keep
const CADENCES = [0 1 2]
const CADENCE_PERIOD = (1000000 / 60)
const CONSOLE_S = 83
const CADENCE_SKIP = 5
const SCHEDULE_FAST = { at: 1500ms, stall: 4000, spin: 500 }
const SCHEDULE_TRIGGERS = [1800ms 2200ms 2600ms 3000ms 3400ms 3800ms 4200ms 4600ms 5000ms 5400ms]
const SCHEDULE_FORCED = 5900ms
const SCHEDULE_ONCE = { at: 6300ms, stall: 38000 }
const SCHEDULE_SLOW = { at: 7000ms, stall: 25000 }
const SCHEDULE_END = 9000ms
const SCHEDULE_WAKES = 8
const MOTION_POSE = { name: "motion", x: 28.0, y: 2.5, z: 1.6, yaw: 90, pitch: 0 }
const MOTION_AT = 1500ms
const MOTION_STALL = 25000
const MOTION_STICK = { from: 2000ms, to: 5000ms }
const MOTION_END = 5500ms
const MOTION_SPEED = 4.0
const MOTION_CLEAR = 1.0
const MET_GEOMETRY = 1
const MET_ANDROID = 2
const ROUSED = 1
const FIRED = 2
const DESTROYED = 4
const FALLEN = 5
const TRACE_PLANE = 1
const TRACE_PIECE = 2
# The load screen: the map's title in bold off-white at four times the
# console's cell, centred (main.S's TITLE_*), read while the program
# loads behind it, which here runs from before 0.1 s of a launch to
# about 0.65 s
const TITLE_AT = 300ms
const TITLE_INK = "ebe6dc"
const TITLE_CELL = 48
const TITLE_HEIGHT = 96
const TITLE_Y = 492
# The sprite launches, on copies of Render One the test compiles with
# its lights and its android dropped, so every texel reads as its
# texture holds it (sprite-tree): the halves sprite, the test's own
# texture whose left half is transparent and right half red, facing the
# camera and two-sided, its feet in the hall three metres in front of
# the `sprite` pose and two metres a side, so its halves fill the middle
# of the screen with the hall's west wall behind; the same copy without
# it draws that wall from the same pose
const SPRITE_MAP = "render_1_sprite"
const PLAIN_MAP = "render_1_plain"
const SPRITE_MATERIAL = "sprite/test"
const SPRITE_FLAGS = 5              # facing the camera, two-sided
const SPRITE = { at: [1.5, 4.0, 0.6], size: [2.0, 2.0] }
const SPRITE_POSE = { name: "sprite", x: 4.5, y: 4.0, z: 1.6, yaw: 180, pitch: 0 }
const RED = 0x[ff 00 00]
const SPRITE_LEFT = [760, 540]
const SPRITE_RIGHT = [1160, 540]
# The straddling sprite: a quad of the uniform alpha case over the pass,
# its colour as the unlit copy draws it, fixed and two-sided, along y
# through the door sector (x 3 to 5, y 8 to 9) with its feet in it and
# its ends past both of its portal walls; the pose in the hall's
# north-east sees it obliquely, so the quad's near end lies over the
# hall's solid north wall beside the doorway, outside the door's
# rectangle, where a clip to that rectangle would cut it; a point on
# that near end
const STRADDLE_MATERIAL = "sprite/test/opaque"
const STRADDLE_COLOUR = 0x[40 80 c0]
const STRADDLE_FLAGS = 4
const STRADDLE = { at: [3.3, 8.5, 0.6], size: [1.8, 1.0] }
const STRADDLE_POSE = { name: "straddle", x: 7.0, y: 7.0, z: 1.6, yaw: 170, pitch: 0 }
const STRADDLE_POINT = [3.3, 7.75, 1.2]
# The alpha cases, textures of the test's own laid in the sprite tree,
# every one a material of its map: the sprite's halves; a uniform alpha
# over the pass, which the engine leaves at one and names no line for;
# a uniform alpha under it; a checkerboard of opaque and transparent
# texels, whose coarser levels go uniform; an 8 by 8 texture with one
# opaque 2 by 2 block, whose coarsest level is one texel; and a 4 by 4
# whose every 2 by 2 holds three alphas at the pass and one a step
# under it, three quarters passing, whose means of 127 vanish at level
# 1 unless the search lifts them back over the pass. The engine's line
# for a material under full coverage, its share of texels at or above
# the pass at every level of its chain in 10000ths and every coarser
# level's scale in 65536ths; the slack each of the first three coarser
# levels of the fence and the grate as authored may sit from level 0,
# stated from the measured lines: the fence's levels read 606, 947, and
# 922 against 733, and the grate's 6093, 6093, and 5000 against 6093,
# its third a step the search cannot reach nearer; the deeper levels of
# a texture a few texels a side move in steps too coarse to hold, and
# the oracle holds them exactly instead
const ALPHA_CASES = [
    { name: "sprite/test", w: 64, h: 64, kind: "halves", alpha: 255 },
    { name: "sprite/test/opaque", w: 64, h: 64, kind: "uniform", alpha: 200 },
    { name: "sprite/test/faint", w: 64, h: 64, kind: "uniform", alpha: 100 },
    { name: "sprite/test/checker", w: 64, h: 64, kind: "checker", alpha: 255 },
    { name: "sprite/test/small", w: 8, h: 8, kind: "block", alpha: 255 },
    { name: "sprite/test/edge", w: 4, h: 4, kind: "edge", alpha: 128 },
]
const ALPHA_LINE = "fps: alpha {name}: coverage {coverage} of 10000, scale {scale} of 65536"
const MIPS_LINE = "fps: mips {chains} chains, {levels} levels, {texels} texels in {ms} ms"
const ALPHA_PASS = 128
const ALPHA_SLACKS = { "texture/fence": 300, "texture/grate": 1200 }
# The chain's levels at most and the scratch a level's alphas take at
# the search, past which a texture keeps a scale of one (render.inc's
# MIP_LEVELS and ALPHA_PLANE_BYTES)
const MIP_LEVELS = 10
const ALPHA_PLANE_BYTES = 262144
# The alpha policy rendered: Render One's grate wall given a texture
# of the test's own, 256 square at two repeats a metre so a lumel cell
# is one repeat, in patches of 64 texels of one kind each, a kind a 2
# by 2 of alphas and colours indexed by a texel's parity on each axis:
# opaque red; green at the pass less one; blue at the pass; yellow
# under alpha 255 and black under 0, whose weighted mean is yellow
# where a plain mean is not; transparent black; cyan at 255 and 145
# over black, whose mean of 100 stays under the pass; and red at 255
# with blue at 128 twice over black, whose weighted mean the shrink's
# rule gives as (127, 0, 128) where a plain mean gives (63, 0, 127) and
# an equal weighting of the opaque texels (85, 0, 170); the grid of
# kinds over the 4 by 4 patches counted so the search moves the
# threshold to 127 at level 1, where the means of 127 against level 0's
# halves and three quarters leave 128 short, and keeps 128 after; the
# alcove behind the wall a solid backdrop of one colour on every
# surface, so an absent patch reads it exactly; the samples the centre
# texel of every patch in two repeats over the wall, none under the
# crosshair; the poses head-on at distances where the wall's blocks
# read level 0, 1, and 2 by the block's rule over 512 texels a metre,
# each run again with the tiles held off for the lit loop's picture,
# identical at every level; the opening compared inset from its edges
const FIXTURE_MAP = "render_1_alpha"
const ALPHA_FIXTURE = { name: "texture/alphafix", w: 256, h: 256, patch: 64, scale: 2.0 }
const FIXTURE_BACKDROP = { name: "texture/alphaback", size: 16, colour: 0x[30 30 30] }
const FIXTURE_KINDS = {
    A: { colours: [0x[ff 00 00], 0x[ff 00 00], 0x[ff 00 00], 0x[ff 00 00]], alphas: [255, 255, 255, 255] },
    B: { colours: [0x[00 ff 00], 0x[00 ff 00], 0x[00 ff 00], 0x[00 ff 00]], alphas: [127, 127, 127, 127] },
    C: { colours: [0x[00 00 ff], 0x[00 00 ff], 0x[00 00 ff], 0x[00 00 ff]], alphas: [128, 128, 128, 128] },
    D: { colours: [0x[ff ff 00], 0x[ff ff 00], 0x[00 00 00], 0x[00 00 00]], alphas: [255, 255, 0, 0] },
    E: { colours: [0x[00 00 00], 0x[00 00 00], 0x[00 00 00], 0x[00 00 00]], alphas: [0, 0, 0, 0] },
    F: { colours: [0x[00 ff ff], 0x[00 ff ff], 0x[00 00 00], 0x[00 00 00]], alphas: [255, 145, 0, 0] },
    G: { colours: [0x[ff 00 00], 0x[00 00 ff], 0x[00 00 ff], 0x[00 00 00]], alphas: [255, 128, 128, 0] },
}
const FIXTURE_GRID = [[A, B, A, D], [C, A, E, D], [A, F, A, G], [D, E, C, F]]
const FIXTURE_REPEATS = [[1, 1], [2, 2]]
# The mid pose is run a third time with level 0 alone built (the L
# frame's byte 6), its blocks asking level 1: they take the chain at
# level 1, never a sharper tile, so its picture is the lit loop's
const FIXTURE_POSES = [
    { name: "near", distance: 2.0, level: 0, capped: false },
    { name: "mid", distance: 5.5, level: 1, capped: true },
    { name: "far", distance: 10.0, level: 2, capped: false },
]
const FIXTURE_INSET = 8
# The radius a sample must lie outside of about the screen's centre,
# the crosshair's five and a pixel of rounding
const FIXTURE_CROSSHAIR = 6
# TheUser's bound on the alpha poses under the room's own light, tiled
# against the lit loop over the opening: the largest difference in a
# channel, of 255, for these three poses alone
const REAL_LIGHT_BOUND = 10
# The texel-centre rule rendered: the fixture's wall given a white
# texture of the test's own, 16 square at two repeats a metre, so a
# lumel cell is 16 texels, one repeat, its nodes on the repeats' edges;
# the console's L frame byte 7 setting every lumel by its node's parity,
# a quarter where its column and row sum even and one where odd, so a
# cell's bilinear light runs steeply from each corner; head-on at 2 m,
# level 0, a texel some 15 pixels across; the four texels touching each
# node in the opening read at their centres against the bilinear light
# there times 255, within the slack of the build's two truncations,
# where a texel lit at its corner reads 63 or 85 beside a dark node and
# 255 or 232 beside a bright one; a tile's texel one colour over the
# pixels about its centre, where the lit loop lights each pixel at its
# own coordinate and the same pixels vary
const CENTRE_FIXTURE = { name: "texture/centrefix", size: 16, scale: 2.0 }
const CENTRE_LIGHTS = [0.25, 1.0]
const CENTRE_DISTANCE = 2.0
const CENTRE_SLACK = 2
const CENTRE_FOOTPRINT = 3
# The flow's growth: a map of the test's own (grow-source) where the
# hall S is reached from the camera's room C first through a narrow
# high window, two hops, and again through a side room T and its wide
# door, three hops, after S has been flowed once; a far room D opens
# off S in the line of sight through T's doors and outside the window's
# rectangle on screen, so D is reached only when S is flowed again with
# its grown rectangle; D's surfaces are the backdrop, read exactly on a
# point of its far wall through its doorway, the map unlit
const GROW_MAP = "rectgrow"
const GROW_POSE = { name: "grow", x: 3.7, y: 0.4, z: 1.6, yaw: 72, pitch: 0 }
const GROW_POINT = [8.1, 13.0, 1.6]
const GROW_FAR = "D"
# The light: Render One's pose under the hall's light, its eye the
# spawn's, facing west 45 degrees down, the floor under the light at the
# bottom of the screen and the far wall at the top, blocks of [x, y, w,
# h]; the bottom block's mean brightness over the top's at least
# LIT_RATIO, measured 1.79 lit and 1.12 with the lit flag never set,
# the floor's texture being the brighter
const LIGHT_POSE = { name: "light", x: 4.0, y: 4.0, z: 1.6, yaw: 180, pitch: -45 }
const LIGHT_BLOCKS = { near: [860, 980, 200, 100], far: [860, 0, 200, 100] }
const LIT_RATIO = 1.4
# The eye's height over the feet, and how far in the plan the spawn's
# eye may stand from the spawn, a body's radius, the push off a wall
# there, with a millimetre's slack
const EYE_HEIGHT = 1.6
const BODY_RADIUS = 0.351
# The sound: a recording's peak sample under this is silence, and a
# window with a peak at or over this and a mean an eighth of it is
# heard, out of 32767
const SOUND_SILENCE = 8
const SOUND_HEARD = 64
# Render Zero: the spawn view's bound here, a sanity bound loose since a
# host's first launch can read double the lane's 23 to 25 ms, the
# frame's ceiling being the gauge's to read; the pixel of the yard's
# capture read for the sky, near the top where the sky texture's solid
# top band lands at pitch 0, and that band's colour
const RENDER_0_START_BOUND = 100000
const SKY_PIXEL = [960, 100]
const SKY_TOP = 0x[3a 6f b0]
const CROSSHAIR = [960, 540]
# the functions whose loops run a pixel or a sample, the span loop with
# the helpers it calls, and the packet's render with the span it calls,
# each within one page of code (render.inc's CODE_PAGE) and trapping
# only where the mixer's two calls a frame are
const HOT_FUNCTIONS = [
    span_fill span_light tile_build mixer_update
    row_crossings span_bound row_range poly_fill span_record
    packet_render
]
const HOT_ECALLS = {
    span_fill: 0, span_light: 0, tile_build: 0, mixer_update: 2,
    row_crossings: 0, span_bound: 0, row_range: 0, poly_fill: 0, span_record: 0,
    packet_render: 0,
}
# the families, each together on one page: poly_fill's loop runs once a
# span and calls span_bound twice a span, and packet_render's loop calls
# span_fill once a span, so a member on another page costs every span a
# lookup, which each member within a page of its own does not catch
const HOT_FAMILIES = [
    { name: "the span loop's", members: [row_crossings span_bound row_range poly_fill span_record] }
    { name: "the packet's render", members: [packet_render span_fill] }
]
# The packet's bounds and the stale binding, through the console's K
# frame on a debug build. The still copy of Render Zero's spawn view,
# every level built, drawn in packets of at most PACKET_CAPS' commands and
# spans, so a frame flushes many times, each full packet rendered whole
# before preparation goes on: the capture the uncapped one's. The alpha
# fixture's near pose under the room's own light with the tile arena
# reset after the frame's first STALE_BINDS binds every frame and every
# surface after the reset rebuilt whole, the commands bound before it
# holding atlases the reset took back, which a debug build poisons with
# TILE_POISON: those commands take the chain at their own level, so every
# pixel is the tiled picture's or the lit loop's, some of each, and none
# the poison a stale read would show. Measured: a reset after the near
# pose's first three binds invalidates nothing on screen, every pixel the
# tiled picture's; after five, two commands on screen take the chain,
# 793,002 pixels the lit loop's and 514,469 the tiled picture's
const PACKET_CAPS = { commands: 7, spans: 500 }
const STALE_BINDS = 5
const TILE_POISON = 0x[01 fe 02]
# The program's lines: what only a debug build says, its reports, and
# what every build says, the exits and a load that fails, so a release
# build carries no debug text and prints nothing but an exit
const DEBUG_TEXT = [
    "fps: frame in "
    "fps: sectors "
    "fps: ambient "
    "fps: frames "
    "fps: frame "
    "fps: soundfont "
    "fps: soundfont refused "
    "fps: soundfont none, the chip voices play"
    "fps: lumel maps "
    "fps: sound "
    "fps: sounds "
    "fps: alpha "
    "fps: mips "
]
const EXIT_TEXT = [
    "fps: "
    "fps: material "
    "fps: a load failed on material "
    "fps: no display\n"
    "fps: no sound\n"
    "fps: no disk of serial fps\n"
    "fps: the disk has no /map/name\n"
]
# The engine's own images and sounds, every one in a tree of ours
const FRAMES_LINE = "fps: frames 69 loaded, 0 missing"
const SOUNDS_LINE = "fps: sounds 16 loaded, 0 missing"
# The fight: the eye placed on the bay's east patrol leg facing south
# down it at the first android, which walks north up the leg from its
# start at (28, 8), sees the eye, and stops to fight on the crosshair;
# four rounds from the console a third of a second apart from 3 s, the
# trigger pressed on the pad at 4.2 s, the stick held forward from 5.5
# s to 9 s south over the fallen frame and its magazine; the first
# android entity's actor is actor 0; the shots' window of the
# recording, the android's first round certain within a second of the
# pose and the player's from 3.2 s
const FIGHT_POSE = { name: "fight", x: 28.0, y: 17.0, z: 1.6, yaw: 270, pitch: 0 }
const FIGHT_ROUNDS = [3000ms, 3300ms, 3600ms, 3900ms]
const FIGHT_ACTOR = 0
const FIGHT_HEALTHS = [75, 50, 25, 0]
const FIGHT_SHOTS = { from: 3.2, to: 4.6, over: 8000 }
const MAGAZINE_ROUNDS = 30
# The traces from Render Zero's window and yard poses: the window's
# ray reaches the bay's floor, the yard's the street's far wall
const TRACE_SLACK = 50
# The light's view independence: six floor points of the bay under and
# between its lights, read from the spawn's eye at two yaws, and the
# levels of 256 the light alone may differ by across the yaws
const VIEW_POINTS = [[26.0, 6.0], [15.0, 6.0], [18.0, 4.0], [22.0, 8.0], [20.0, 12.0], [24.0, 16.0]]
const VIEW_EYE = { x: 29.0, y: 2.5, z: 1.6 }
const VIEW_YAWS = [170, 130]
const VIEW_SLACK = 4
# Render Zero's spawn view, the spawn's eye and yaw, for one level a
# block: the bay's floor runs to some twenty metres from it, where a
# block asks a level past the tiles' four
const SPAWN_POSE = { name: "spawn", x: 29.0, y: 2.5, z: 1.6, yaw: 150, pitch: 0 }

def main [--kernel: path, --image: path, --out: path, --set: string = "", --assets: path = ""] {
    assert (($assets | path exists)) "the sdk built the assets image"
    hot-functions $image
    release-strings $image
    gauge-rules ($out | path join "gauge_rules")
    print "fps: the gauge's rules hold on synthetic captures"
    let game = ($env.FILE_PWD | path join ".." | path expand)
    let trees = (jab program-shard $game "asset")
    let render_1_source = (open ($game | path join "content" "map" "render_1.nuon"))
    let render_1_tree = ($trees | path join "render_1")
    let render_1_index = {|name: string| $render_1_source.sectors | enumerate | where {|s| $s.item.name == $name } | get 0.index }

    # the load screen: Render One's title drawn there while the map loads
    # behind it, and with no title in its tree a map's name in its place,
    # the growth map's (grow-source)
    let grow_tree = (grow-tree $game ($out | path join "grow"))
    let titles = [
        { text: $render_1_source.title, ink: (title-holds $kernel $image $out $set "render_1" $render_1_tree $render_1_source.title) }
        { text: $GROW_MAP, ink: (title-holds $kernel $image $out $set "grow" $grow_tree $GROW_MAP) }
    ]

    # a sprite: a copy of Render One with its lights and its android
    # dropped and the halves sprite facing the camera in the hall, seen
    # from in front of it: its right half the texture's red and its
    # transparent left half the wall behind, as the same copy without the
    # sprite draws it from the same pose
    let sprite_tree = (sprite-tree $render_1_source $SPRITE_MAP ($out | path join "sprite_tree") $game --halves)
    let plain_tree = (sprite-tree $render_1_source $PLAIN_MAP ($out | path join "plain_tree") $game)
    let sprite_read = (map read ($sprite_tree | path join "map" $"($SPRITE_MAP).jabfps.map"))
    let material_index = {|name: string| $sprite_read.materials | enumerate | where {|m| $m.item.name == $name } | get 0.index }
    for c in $ALPHA_CASES {
        assert ($c.name in ($sprite_read.materials | get name)) $"the alpha case ($c.name) a material of the sprite tree"
    }
    let halves = ($sprite_read.entities | where material == (do $material_index $SPRITE_MATERIAL) | get 0)
    assert equal $halves.flags $SPRITE_FLAGS $"the halves sprite faces the camera, two-sided: ($halves)"
    assert equal $halves.sector (do $render_1_index "hall") $"the halves sprite stands in the hall: ($halves)"
    let straddler = ($sprite_read.entities | where material == (do $material_index $STRADDLE_MATERIAL) | get 0)
    assert equal $straddler.flags $STRADDLE_FLAGS $"the straddler fixed, two-sided: ($straddler)"
    assert equal $straddler.sector (do $render_1_index "door") $"the straddler's feet in the door sector: ($straddler)"
    let sprite_disk = (romfs $sprite_tree ($out | path join "sprite.romfs"))
    let sprite_sends = [{ at: 1500ms, bytes: (pose pose-frame $SPRITE_POSE) }]
    let plain_run = (jab launch --kernel $kernel --image $image --out ($out | path join "plain") --set $set --sound --api --disk (romfs $plain_tree ($out | path join "plain.romfs")) --serial "fps" --send $sprite_sends --capture 2500ms --seconds 5)
    assert equal (open --raw $plain_run.qemu_log) "" "QEMU has no complaint about the guest on the plain run"
    # the first frames drawn: a debug build poisons the producer's scratch
    # once a frame's packet is published (raster.S), so a render reading
    # it through a pointer faults here
    assert (not ($plain_run.serial | str contains "jab: program fault")) $"no program fault drawing the plain run's frames: ($plain_run.serial | lines | where {|l| $l starts-with 'jab: ' })"
    assert ($plain_run.screen != "") "a screen was taken on the plain run"
    let sprite_run = (jab launch --kernel $kernel --image $image --out ($out | path join "sprite") --set $set --sound --api --disk $sprite_disk --serial "fps" --send $sprite_sends --capture 2500ms --seconds 5)
    assert equal (open --raw $sprite_run.qemu_log) "" $"QEMU has no complaint about the guest on the sprite run"
    let sprite_lines = ($sprite_run.serial | lines)
    assert (($sprite_lines | where {|l| $l starts-with $"fps: ($SPRITE_MAP) loaded" } | length) == 1) $"the sprite tree loaded: ($sprite_run.serial)"
    let sprite_frames = ($sprite_lines | where {|l| $l starts-with "fps: frame in" })
    assert equal ($sprite_frames | length) 2 $"the first frame and the sprite pose's reported: ($sprite_run.serial)"
    let sprite_frame = ($sprite_frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
    assert ($sprite_frame.sprites >= 1) $"the sprite drawn from the sprite pose: ($sprite_frame)"
    assert ($sprite_frame.uncovered < $CRACKS) $"the sprite view has no pixel uncovered: ($sprite_frame)"
    assert ($sprite_run.screen != "") "a screen was taken on the sprite run"
    assert equal (pixel $sprite_run.screen $SPRITE_RIGHT) $RED $"the sprite's right half is the texture's red: ($sprite_run.screen)"
    assert equal (pixel $sprite_run.screen $SPRITE_LEFT) (pixel $plain_run.screen $SPRITE_LEFT) $"the sprite's transparent left half shows the wall behind, as the plain run drew it"
    # the alpha policy at load over the test's own textures, against the
    # same rule on the host: each level's share of texels at or above
    # the pass and the scale that holds it, a line a material under full
    # coverage and none for one at it
    let alpha_lines = ($sprite_lines | where {|l| $l starts-with "fps: alpha " })
    for c in $ALPHA_CASES {
        let alphas = (0..<$c.h | each {|y| 0..<$c.w | each {|x| (case-texel $c $x $y).alpha } } | flatten)
        let want = (alpha-levels $alphas $c.w $c.h)
        let line = ($alpha_lines | where {|l| $l starts-with $"fps: alpha ($c.name): " })
        if $want.line {
            assert equal ($line | length) 1 $"one alpha line for ($c.name): ($alpha_lines)"
            let got = (alpha-line ($line | get 0))
            assert equal $got.coverage $want.coverage $"($c.name)'s coverage at every level of its chain as the rule gives it: ($line | get 0)"
            assert equal $got.scale $want.scale $"($c.name)'s scales at every coarser level as the rule gives them: ($line | get 0)"
        } else {
            assert ($line | is-empty) $"no alpha line for ($c.name), full at the pass: ($line)"
        }
    }
    # the straddling sprite, seen obliquely from the hall: the door's
    # rectangle as the flow hands it on, the hall's portal wall into the
    # door sector, between its two ends' columns from the pose with the
    # flow's pixel of slack, and the quad's near end left of it over the
    # solid wall beside the doorway; there it reads the texture, the quad
    # drawn over the whole screen as one not proven within its sector,
    # where a clip to the sector's rectangle would cut it off
    let straddle_run = (jab launch --kernel $kernel --image $image --out ($out | path join "straddle") --set $set --sound --api --disk $sprite_disk --serial "fps" --send [{ at: 1500ms, bytes: (pose pose-frame $STRADDLE_POSE) }] --capture 2500ms --seconds 5)
    assert equal (open --raw $straddle_run.qemu_log) "" "QEMU has no complaint about the guest on the straddle run"
    let straddle_frames = ($straddle_run.serial | lines | where {|l| $l starts-with "fps: frame in" })
    assert equal ($straddle_frames | length) 2 $"the first frame and the straddle pose's reported: ($straddle_run.serial)"
    let straddle_frame = ($straddle_frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
    assert ($straddle_frame.sprites >= 1) $"the straddling sprite drawn: ($straddle_frame)"
    assert ($straddle_frame.uncovered < $CRACKS) $"the straddle view has no pixel uncovered: ($straddle_frame)"
    assert ($straddle_run.screen != "") "a screen was taken on the straddle run"
    let straddle_eye = { x: $STRADDLE_POSE.x, y: $STRADDLE_POSE.y, z: $STRADDLE_POSE.z }
    let straddle_at = (project $straddle_eye $STRADDLE_POSE.yaw $STRADDLE_POINT)
    assert ($straddle_at != null) $"the straddling quad's near end is on screen from ($STRADDLE_POSE)"
    let hall = (do $render_1_index "hall")
    let door = (do $render_1_index "door")
    let door_wall = ($sprite_read.walls | where {|w| $w.sector == $hall and $w.portal_count > 0 } | where {|w| ($sprite_read.portals | get $w.first_portal | get sector) == $door } | get 0)
    let door_columns = ([$door_wall.a $door_wall.b] | each {|v| let p = ($sprite_read.vertices | get $v); project-x $straddle_eye $STRADDLE_POSE.yaw [$p.x, $p.y] })
    assert ($door_columns | all {|c| $c != null }) $"the doorway in front of the straddle pose: ($door_columns)"
    let door_left = (($door_columns | math min) - 1)
    assert ($straddle_at.0 < $door_left) $"the straddling quad's near end at ($straddle_at) lies outside the door's rectangle, left of column ($door_left), so a clip to it would cut it"
    assert equal (pixel $straddle_run.screen $straddle_at) $STRADDLE_COLOUR $"the straddling quad's near end at ($straddle_at), beside the doorway, reads its texture: ($straddle_run.screen)"

    # Render One, the map the format and the engine are proven on: loaded
    # and held to its counts, the camera at the spawn with its eye over the
    # floor there facing the spawn's way, the sign drawn from the spawn,
    # the stairwell seen from the upper room through its window, the
    # alcove through the grate, the north room through the door, the ramp
    # posed with no pixel uncovered, the door tagged, a plan view a storey
    # at the storey's bounds, and last the hall's light, the floor under
    # it brighter than the far wall
    let render_1_expected = (open ($render_1_tree | path join "map.nuon"))
    let render_1_read = (map read ($render_1_tree | path join "map" "render_1.jabfps.map"))
    # the line pose stands with the eye on the line the hall and the door
    # sectors share, looking into the hall, which the flow reaches only by
    # its facing slack, the eye's distance from the wall's line being zero
    # there; the ramp's stands at its middle, midway between its planes,
    # facing up its slope 30 degrees down at it; the light's is the
    # capture's, last
    let ramp = ($render_1_read.sectors | get (do $render_1_index "ramp"))
    let ramp_x = (($ramp.bounds.min_x + $ramp.bounds.max_x) / 2)
    let ramp_y = (($ramp.bounds.min_y + $ramp.bounds.max_y) / 2)
    let ramp_z = (((map plane-z $ramp.floor $ramp_x $ramp_y) + (map plane-z $ramp.ceiling $ramp_x $ramp_y)) / 2)
    let render_1_poses = [
        { name: "window", sector: (do $render_1_index "upper_room"), x: 5.0, y: 4.0, z: 4.85, yaw: 0, pitch: -20, sees: (do $render_1_index "step1") },
        { name: "grate", sector: (do $render_1_index "north"), x: 9.0, y: 11.0, z: 1.6, yaw: 0, pitch: 0, sees: (do $render_1_index "alcove") },
        { name: "line", sector: (do $render_1_index "door"), x: 4.0, y: 8.0, z: 1.6, yaw: 270, pitch: 0, sees: (do $render_1_index "hall") },
        { name: "door", sector: (do $render_1_index "hall"), x: 4.0, y: 5.0, z: 1.6, yaw: 90, pitch: 0, sees: (do $render_1_index "north") },
        { name: "ramp", sector: (do $render_1_index "ramp"), x: $ramp_x, y: $ramp_y, z: $ramp_z, yaw: 90, pitch: -30, sees: (do $render_1_index "upper_hall") },
        ($LIGHT_POSE | insert sector (do $render_1_index "hall") | insert sees (do $render_1_index "hall")),
    ]
    # the rendered assets the tree carries: the hum a Standard MIDI File
    # of one track, the servo the recipe's seconds of 16-bit samples
    assert equal $render_1_expected.ambients 1 "render_1 names one ambient"
    let recipes = (glob ($game | path join "content" "sound" "*.nuon") | length)
    assert equal $render_1_expected.sounds $recipes $"render_1's tree carries every sound the content holds: ($render_1_expected.sounds) against ($recipes) recipes"
    let hum = (open --raw ($render_1_tree | path join "ambient" "hum.mid") | into binary)
    assert equal ($hum | bytes at 0..<4) ("MThd" | into binary) "the hum is a Standard MIDI File"
    assert equal ($hum | bytes at 8..<10 | into int --endian big) 0 "the hum is format 0"
    assert equal ($hum | bytes at 10..<12 | into int --endian big) 1 "the hum holds one track"
    let servo_recipe = (open ($game | path join "content" "sound" "servo.nuon"))
    let servo = (open --raw ($render_1_tree | path join "sound" "servo.pcm") | into binary)
    assert equal ($servo | bytes length) (((($servo_recipe.seconds | into float) * 48000) | math round | into int) * 2) "the servo is its seconds of 16-bit samples"
    let render_1_sends = ($render_1_poses | enumerate | each {|e| { at: (1500ms + ($e.index * 500ms)), bytes: (pose pose-frame $e.item) } })
    let render_1_disk = (romfs $render_1_tree ($out | path join "render_1.romfs"))
    let render_1_run = (jab launch --kernel $kernel --image $image --out ($out | path join "render_1") --set $set --sound --api --disk $render_1_disk --serial "fps" --send $render_1_sends --capture 5500ms --seconds 6)
    assert equal (open --raw $render_1_run.qemu_log) "" "QEMU has no complaint about the guest on render_1"
    let render_1_lines = ($render_1_run.serial | lines)
    let render_1_reports = ($render_1_lines | where {|l| $l starts-with "fps: render_1 loaded" })
    assert equal ($render_1_reports | length) 1 $"the load reported once on render_1: ($render_1_run.serial)"
    let render_1_load = ($render_1_reports | get 0 | parse $LOAD | get 0 | update cells {|c| if $c =~ '^\d+$' { $c | into int } else { $c } })
    for f in [sectors walls vertices portals entities lights sprites materials] {
        assert equal ($render_1_load | get $f) ($render_1_expected | get $f) $"render_1's ($f) as the tree has it: ($render_1_reports | get 0)"
    }
    assert equal $render_1_load.materials (open ($render_1_tree | path join "tile.nuon") | length) "render_1's materials as tile.nuon has them"
    assert equal $render_1_load.textures $render_1_expected.materials "render_1's materials all textures"
    assert equal $render_1_load.missing 0 "render_1's materials all in the tree"
    assert ($render_1_load.ms > 0 and $render_1_load.ms < 20000) $"render_1 loaded in a plausible time: ($render_1_load.ms) ms"
    assert ($FRAMES_LINE in $render_1_lines) $"the engine's images all in render_1's tree: ($render_1_lines | where {|l| $l starts-with 'fps: frame' })"
    assert ($SOUNDS_LINE in $render_1_lines) $"the engine's sounds all in render_1's tree: ($render_1_lines | where {|l| $l starts-with 'fps: sound' })"
    # the soundfont off the generic disk, and the hum playing once the
    # camera stands in the north room
    let fonts = ($render_1_lines | where {|l| $l starts-with "fps: soundfont " })
    assert equal ($fonts | length) 1 $"the soundfont reported once on render_1: ($render_1_run.serial)"
    let font = ($fonts | get 0 | parse "fps: soundfont {presets} presets, {instruments} instruments, {samples} samples")
    assert (not ($font | is-empty)) $"the soundfont loaded off the generic disk: ($fonts | get 0)"
    assert (($font | get 0.presets | into int) > 0) $"the soundfont holds presets: ($fonts | get 0)"
    assert ("fps: ambient 0 playing" in $render_1_lines) $"the hum plays in the north room: ($render_1_lines | where {|l| $l starts-with 'fps: ambient' })"
    # and is heard: the run's recording silent while the camera stands
    # in the hall, sounding once it stands in the north room and the
    # pad has swelled; the recording ends at the screen capture
    assert ($render_1_run.sound != "") "the render_1 run recorded its sound"
    let hall_level = (sound-level $render_1_run.sound 0.3 1.4)
    let room_level = (sound-level $render_1_run.sound 3.5 5.4)
    assert ($hall_level.peak < $SOUND_SILENCE) $"the hall is silent, having no ambient: ($hall_level)"
    assert ($room_level.peak >= $SOUND_HEARD and $room_level.mean >= ($SOUND_HEARD / 8)) $"the hum is heard in the north room: ($room_level) against silence ($hall_level)"
    let render_1_frames = ($render_1_lines | where {|l| $l starts-with "fps: frame in" } | each {|f| $f | parse $FRAME | get 0 | update cells {|c| $c | into int } })
    assert equal ($render_1_frames | length) (1 + ($render_1_poses | length)) $"the first frame and each pose's reported on render_1: ($render_1_run.serial)"
    for f in $render_1_frames {
        assert ($f.uncovered < $CRACKS) $"every pixel of the view reached by a surface on render_1: ($f)"
    }
    let render_1_start = ($render_1_frames | get 0)
    assert ($render_1_start.sectors > 0 and $render_1_start.walls > 0 and $render_1_start.pieces > 0 and $render_1_start.planes > 0) $"the first frame drew the world on render_1: ($render_1_start)"
    assert ($render_1_start.us < 1000000) $"the first frame within a bound here on render_1: ($render_1_start.us) us"
    assert ($render_1_start.sprites >= 1) $"the sign drawn from the spawn: ($render_1_start)"
    let door_frame = ($render_1_frames | get (1 + ($render_1_poses | enumerate | where {|p| $p.item.name == "door" } | get 0.index)))
    assert ($door_frame.sprites >= 2) $"the sign and the north room's android drawn from the door: ($door_frame)"
    let render_1_sectors = ($render_1_lines | where {|l| $l starts-with "fps: sectors " } | each {|l| $l | str substring 13.. | str trim | split row " " | each {|s| $s | into int } })
    assert equal ($render_1_sectors | length) ($render_1_frames | length) $"a sectors line a reported frame on render_1: ($render_1_sectors | length)"
    for e in ($render_1_poses | enumerate) {
        let drawn = ($render_1_sectors | get ($e.index + 1))
        assert ($e.item.sees in $drawn) $"the pose ($e.item.name) sees sector ($e.item.sees) through its opening: ($drawn)"
    }
    let render_1_records = (records $render_1_run.api)
    let render_1_states = ($render_1_records | where kind == 1)
    assert (($render_1_states | length) > 10) $"a state a frame on render_1: ($render_1_states | length)"
    # the camera at the spawn: in its sector, its eye a body's radius at
    # most from it in the plan, the eye's height over the floor there,
    # facing the spawn's way
    let spawned = ($render_1_states | get 0)
    let spawn = $render_1_expected.spawn
    assert equal $spawned.sector ($render_1_read.entities | where class == 0 | get 0.sector) "the camera in the spawn's sector on render_1"
    let shove = ((($spawned.x - $spawn.at.0) ** 2 + ($spawned.y - $spawn.at.1) ** 2) | math sqrt)
    assert ($shove <= $BODY_RADIUS) $"the eye stands at the spawn, or a body's radius off a wall there: ($spawned.x), ($spawned.y) against ($spawn.at), ($shove) off"
    let spawn_floor = (map plane-z ($render_1_read.sectors | get $spawned.sector | get floor) $spawned.x $spawned.y)
    assert ((($spawned.z - ($spawn_floor + $EYE_HEIGHT)) | math abs) < 0.01) $"the eye its height over the floor at the spawn: ($spawned.z) over a floor at ($spawn_floor)"
    assert ((($spawned.yaw - $spawn.yaw) | math abs) < 0.01 and (($spawned.pitch - $spawn.pitch) | math abs) < 0.01 and $spawned.roll == 0.0) $"the camera faces the spawn's way: ($spawned.yaw), ($spawned.pitch), ($spawned.roll) against ($spawn.yaw), ($spawn.pitch)"
    let render_1_consoles = ($render_1_records | enumerate | where {|r| $r.item.kind == 11 })
    assert equal ($render_1_consoles | length) ($render_1_poses | length) $"a console record a pose on render_1: ($render_1_consoles | length)"
    for e in ($render_1_consoles | enumerate) {
        let landed = ($render_1_records | slice ($e.item.index + 1).. | where kind == 1 | get -o 0)
        let pose_at = ($render_1_poses | get $e.index)
        assert ($landed != null) $"a state after the pose ($pose_at.name) on render_1"
        assert equal $landed.sector $pose_at.sector $"the camera in the pose ($pose_at.name)'s sector on render_1: ($landed.sector)"
    }
    assert equal ($render_1_read.sectors | get (do $render_1_index "door") | get tag) 1 "the door sector carries its tag"
    # the grate as authored: its coarser levels' share within the slack
    alpha-held $render_1_lines "texture/grate"
    let render_1_mips = (mips-built $render_1_lines)
    plan-views $render_1_tree $render_1_source $render_1_read
    # the hall's light, the capture's pose: the floor under the light
    # brighter than the far wall by LIT_RATIO at least
    assert ($render_1_run.screen != "") "a screen was taken on render_1"
    let lit_near = (mean-brightness $render_1_run.screen $LIGHT_BLOCKS.near)
    let lit_far = (mean-brightness $render_1_run.screen $LIGHT_BLOCKS.far)
    assert ($lit_near > ($lit_far * $LIT_RATIO)) $"the floor under the hall's light lit past the far wall: ($lit_near) against ($lit_far), ($lit_near / $lit_far)"

    # the stair: from Render One's spawn the left stick held forward up
    # the three steps onto the landing, a quarter turn to the north, then
    # up the ramp into the upper hall
    let stair_run = (jab launch --kernel $kernel --image $image --out ($out | path join "stair") --set $set --sound --api --pad ($env.FILE_PWD | path join "table_stair.nuon") --disk $render_1_disk --serial "fps" --capture 8000ms --seconds 9)
    assert equal (open --raw $stair_run.qemu_log) "" "QEMU has no complaint about the guest on the stair"
    let stair_states = (records $stair_run.api | where kind == 1)
    assert (($stair_states | length) > 100) $"states through the stair: ($stair_states | length)"
    let stair_first = ($stair_states | first)
    let stair_last = ($stair_states | last)
    assert equal $stair_first.sector (do $render_1_index "hall") "the stair walk starts in the hall"
    assert equal $stair_last.sector (do $render_1_index "upper_hall") $"the body ended in the upper hall: ($stair_last.x), ($stair_last.y), ($stair_last.z) in ($stair_last.sector)"
    let stair_floor = (map plane-z ($render_1_read.sectors | get $stair_last.sector | get floor) $stair_last.x $stair_last.y)
    assert ((($stair_last.z - ($stair_floor + $EYE_HEIGHT)) | math abs) < 0.05) $"the eye rides the upper floor: ($stair_last.z) over ($stair_floor)"
    let stair_sectors = ($stair_states | get sector | uniq)
    let stair_way = ([step1 step2 step3 landing ramp upper_hall] | each {|n| do $render_1_index $n })
    let stair_order = ($stair_way | each {|s| $stair_sectors | enumerate | where {|e| $e.item == $s } | get -o 0.index })
    assert ($stair_order | all {|i| $i != null }) $"the body crossed every step, the landing, and the ramp: ($stair_sectors) against ($stair_way)"
    assert (($stair_order | window 2 | all {|w| $w.0 < $w.1 })) $"in order: ($stair_sectors)"

    # Render Zero, the game's map: loaded and held to its counts with
    # every material and ambient in the tree, the bay's ambient playing
    # from the spawn, the spawn view lit within its bound; then the poses:
    # the office window down onto the bay, the garage toward its door,
    # down the down flight under its sloped ceiling, and the yard under
    # the sky, whose capture carries the sky texture's top band; each door
    # sector tagged, a plan view a storey
    let render_0_tree = ($trees | path join "render_0")
    let render_0_source = (open ($game | path join "content" "map" "render_0.nuon"))
    let render_0_expected = (open ($render_0_tree | path join "map.nuon"))
    let render_0_read = (map read ($render_0_tree | path join "map" "render_0.jabfps.map"))
    let render_0_index = {|name: string| $render_0_source.sectors | enumerate | where {|s| $s.item.name == $name } | get 0.index }
    let render_0_ambient = {|name: string| $render_0_read.ambients | enumerate | where {|a| $a.item.name == $"ambient/($name)" } | get 0.index }
    # the down flight's pose stands mid-flight on its third step with the
    # eye its height over the tread, facing down the flight, the ceiling
    # sloping down over it to the garage's opening
    let down3 = (do $render_0_index "down3")
    let down_z = ((map plane-z ($render_0_read.sectors | get $down3 | get floor) 1.5 7.0) + $EYE_HEIGHT)
    let render_0_poses = [
        { name: "window", sector: (do $render_0_index "office_hall"), x: 8.75, y: 17.0, z: 4.6, yaw: 0, pitch: -15, sees: (do $render_0_index "bay") },
        { name: "garage", sector: (do $render_0_index "garage"), x: 16.0, y: 14.0, z: -1.4, yaw: 0, pitch: 0, sees: (do $render_0_index "drive_low") },
        { name: "down", sector: $down3, x: 1.5, y: 7.0, z: $down_z, yaw: 90, pitch: 0, sees: (do $render_0_index "garage") },
        { name: "yard", sector: (do $render_0_index "yard"), x: 40.0, y: 6.0, z: 1.6, yaw: 90, pitch: 0, sees: (do $render_0_index "beyond") },
    ]
    assert equal $render_0_expected.unresolved 0 $"render_0 names nothing the content lacks: ($render_0_expected.missing)"
    assert equal $render_0_expected.ambients 5 "render_0 names five ambients"
    # a trace a quarter second after the window pose and after the yard's
    let render_0_sends = (($render_0_poses | enumerate | each {|e| { at: (1500ms + ($e.index * 500ms)), bytes: (pose pose-frame $e.item) } })
        | append [{ at: 1750ms, bytes: (pose command-frame "T") }, { at: 3250ms, bytes: (pose command-frame "T") }]
        | sort-by at)
    let render_0_disk = (romfs $render_0_tree ($out | path join "render_0.romfs"))
    let render_0_run = (jab launch --kernel $kernel --image $image --out ($out | path join "render_0") --set $set --sound --api --disk $render_0_disk --serial "fps" --send $render_0_sends --capture 4000ms --seconds 5)
    assert equal (open --raw $render_0_run.qemu_log) "" "QEMU has no complaint about the guest on render_0"
    let render_0_lines = ($render_0_run.serial | lines)
    let render_0_reports = ($render_0_lines | where {|l| $l starts-with "fps: render_0 loaded" })
    assert equal ($render_0_reports | length) 1 $"the load reported once on render_0: ($render_0_run.serial)"
    let render_0_load = ($render_0_reports | get 0 | parse $LOAD | get 0 | update cells {|c| if $c =~ '^\d+$' { $c | into int } else { $c } })
    for f in [sectors walls vertices portals entities lights sprites materials] {
        assert equal ($render_0_load | get $f) ($render_0_expected | get $f) $"render_0's ($f) as the tree has it: ($render_0_reports | get 0)"
    }
    assert equal $render_0_load.materials (open ($render_0_tree | path join "tile.nuon") | length) "render_0's materials as tile.nuon has them"
    assert equal $render_0_load.textures $render_0_expected.materials "render_0's materials all textures"
    assert equal $render_0_load.missing 0 "render_0's materials all in the tree"
    assert ($FRAMES_LINE in $render_0_lines) $"the engine's images all in render_0's tree: ($render_0_lines | where {|l| $l starts-with 'fps: frame' })"
    assert ($SOUNDS_LINE in $render_0_lines) $"the engine's sounds all in render_0's tree: ($render_0_lines | where {|l| $l starts-with 'fps: sound' })"
    assert (($render_0_lines | where {|l| $l starts-with "fps: ambient " and ($l | str contains " missing") } | is-empty)) $"every ambient of render_0 in the tree: ($render_0_lines | where {|l| $l starts-with 'fps: ambient' })"
    assert ($"fps: ambient (do $render_0_ambient 'floor') playing" in $render_0_lines) $"the bay's ambient plays from the spawn: ($render_0_lines | where {|l| $l starts-with 'fps: ambient' })"
    let render_0_frames = ($render_0_lines | where {|l| $l starts-with "fps: frame in" } | each {|f| $f | parse $FRAME | get 0 | update cells {|c| $c | into int } })
    assert equal ($render_0_frames | length) (1 + ($render_0_poses | length)) $"the first frame and each pose's reported on render_0: ($render_0_run.serial)"
    for f in $render_0_frames {
        assert ($f.uncovered < $CRACKS) $"every pixel of the view reached by a surface on render_0: ($f)"
    }
    let render_0_start = ($render_0_frames | get 0)
    assert ($render_0_start.sectors > 0 and $render_0_start.pieces > 0 and $render_0_start.planes > 0) $"the spawn view drew the bay: ($render_0_start)"
    assert ($render_0_start.us < $RENDER_0_START_BOUND) $"the spawn view within its bound on render_0: ($render_0_start)"
    let render_0_sectors = ($render_0_lines | where {|l| $l starts-with "fps: sectors " } | each {|l| $l | str substring 13.. | str trim | split row " " | each {|s| $s | into int } })
    assert equal ($render_0_sectors | length) ($render_0_frames | length) $"a sectors line a reported frame on render_0: ($render_0_sectors | length)"
    for e in ($render_0_poses | enumerate) {
        let drawn = ($render_0_sectors | get ($e.index + 1))
        assert ($e.item.sees in $drawn) $"the pose ($e.item.name) sees sector ($e.item.sees): ($drawn)"
    }
    let render_0_records = (records $render_0_run.api)
    let render_0_states = ($render_0_records | where kind == 1)
    assert (($render_0_states | length) > 10) $"a state a frame on render_0: ($render_0_states | length)"
    assert equal ($render_0_states | get 0.sector) (do $render_0_index "bay") "the camera in the bay at the spawn"
    let render_0_consoles = ($render_0_records | enumerate | where {|r| $r.item.kind == 11 and $r.item.sector == $CONSOLE_P })
    assert equal ($render_0_consoles | length) ($render_0_poses | length) $"a console record a pose on render_0: ($render_0_consoles | length)"
    for e in ($render_0_consoles | enumerate) {
        let landed = ($render_0_records | slice ($e.item.index + 1).. | where kind == 1 | get -o 0)
        let pose_at = ($render_0_poses | get $e.index)
        assert ($landed != null) $"a state after the pose ($pose_at.name) on render_0"
        assert equal $landed.sector $pose_at.sector $"the camera in the pose ($pose_at.name)'s sector on render_0: ($landed.sector)"
    }
    # the traces: the window's ray onto the bay's floor, the yard's to
    # the street's far wall at the world's edge
    let traces = ($render_0_records | where kind == 6)
    assert equal ($traces | length) 2 $"two traces answered on render_0: ($traces)"
    let window_trace = ($traces | get 0)
    assert equal $window_trace.fields.0 $TRACE_PLANE $"the window's ray met a plane: ($window_trace)"
    assert (($window_trace.fields.4 | math abs) < $TRACE_SLACK) $"the window's ray met the bay's floor: ($window_trace)"
    let yard_trace = ($traces | get 1)
    assert equal $yard_trace.fields.0 $TRACE_PIECE $"the yard's ray met a piece: ($yard_trace)"
    let street_north = ((($render_0_source.sectors | where name == "beyond" | get 0.loops.0 | each {|p| $p | get 1 } | math max) * 1000) | into int)
    assert ((($yard_trace.fields.3 - $street_north) | math abs) < $TRACE_SLACK) $"the yard's ray reached the street's far wall at ($street_north) mm: ($yard_trace)"
    assert ($render_0_run.screen != "") "a screen was taken on render_0"
    assert equal (pixel $render_0_run.screen $SKY_PIXEL) $SKY_TOP $"the sky's top band at ($SKY_PIXEL) from the yard: ($render_0_run.screen)"
    # the crosshair: the centre pixel blended half with white, so every
    # channel is at least half scale whatever lies under it
    let centre = (pixel $render_0_run.screen $CROSSHAIR)
    assert (([0 1 2] | all {|i| ($centre | bytes at $i..<($i + 1) | into int) >= 128 })) $"the crosshair at ($CROSSHAIR): ($centre | encode hex)"
    for tag in [1 2 3 4 5] {
        assert equal ($render_0_read.sectors | where tag == $tag | length) 1 $"one door sector carries tag ($tag)"
    }
    # the fence as authored: each coarser level's share at or above the
    # pass within the slack of the texture's
    alpha-held $render_0_lines "texture/fence"
    let render_0_mips = (mips-built $render_0_lines)
    plan-views $render_0_tree $render_0_source $render_0_read

    # Render Zero walked, one launch of three placed starts with the left
    # stick held forward after each: the up flight from the hall's foot
    # to the office corridor, the down flight to the garage, and the
    # driveway from the garage door up the ramp to the gate, the sectors
    # crossed in order, the eye riding the floor at each end, and each
    # area's ambient reported as the body enters it
    let render_0_starts = [
        { name: "up", at: 1500ms, x: 8.75, y: 3.0, z: 1.6, yaw: 90, pitch: 0, way: [stair_ground up1 up2 up3 up4 up5 up6 office_hall], ambient: "office" },
        { name: "down", at: 5500ms, x: 1.5, y: 3.0, z: 1.6, yaw: 90, pitch: 0, way: [stair_ground down1 down2 down3 down4 down5 down6 garage], ambient: "garage" },
        { name: "ramp", at: 9500ms, x: 34.0, y: 13.0, z: -1.4, yaw: 90, pitch: 0, way: [drive_low drive_ramp], ambient: "yard" },
    ]
    let walk_sends = ([{ at: $CLOCK_SEED_AT, bytes: (gauge seed-frame $CLOCK_SEED) }, { at: $CLOCK_SEED_AT, bytes: (gauge cadence-frame $CLOCK_CADENCE) }]
        | append ($render_0_starts | each {|s| { at: $s.at, bytes: (pose pose-frame $s) } })
        | append [{ at: $CLOCK_END_AT, bytes: (pose command-frame "E") }]
        | sort-by at)
    let render_0_walk = (jab launch --kernel $kernel --image $image --out ($out | path join "render_0_walk") --set $set --sound --api --pad ($env.FILE_PWD | path join "table_render_0.nuon") --disk $render_0_disk --serial "fps" --send $walk_sends --capture 14500ms --seconds 16)
    assert equal (open --raw $render_0_walk.qemu_log) "" "QEMU has no complaint about the guest on the render_0 walk"
    let walk_lines = ($render_0_walk.serial | lines)
    let render_0_walk_records = (records $render_0_walk.api)
    let walk_consoles = ($render_0_walk_records | enumerate | where {|r| $r.item.kind == 11 and $r.item.sector == $CONSOLE_P } | get index)
    assert equal ($walk_consoles | length) ($render_0_starts | length) $"a console record a start on the render_0 walk: ($walk_consoles | length)"
    mut render_0_walks = []
    for e in ($render_0_starts | enumerate) {
        let from = (($walk_consoles | get $e.index) + 1)
        let to = (if ($e.index + 1) < ($render_0_starts | length) { $walk_consoles | get ($e.index + 1) } else { $render_0_walk_records | length })
        let states = ($render_0_walk_records | slice $from..<$to | where kind == 1)
        assert (($states | length) > 50) $"states through the ($e.item.name) walk: ($states | length)"
        let way = ($e.item.way | each {|n| do $render_0_index $n })
        let crossed = ($states | get sector | uniq)
        let order = ($way | each {|s| $crossed | enumerate | where {|c| $c.item == $s } | get -o 0.index })
        assert ($order | all {|i| $i != null }) $"the ($e.item.name) walk crossed ($e.item.way): ($crossed)"
        assert (($order | window 2 | all {|w| $w.0 < $w.1 })) $"in order on the ($e.item.name) walk: ($crossed)"
        let last = ($states | last)
        assert equal $last.sector ($way | last) $"the ($e.item.name) walk ended in ($e.item.way | last): ($last)"
        let floor = (map plane-z ($render_0_read.sectors | get $last.sector | get floor) $last.x $last.y)
        assert ((($last.z - ($floor + $EYE_HEIGHT)) | math abs) < 0.05) $"the eye rides the floor at the end of the ($e.item.name) walk: ($last.z) over ($floor)"
        assert ($"fps: ambient (do $render_0_ambient $e.item.ambient) playing" in $walk_lines) $"the ($e.item.ambient) ambient plays on the ($e.item.name) walk: ($walk_lines | where {|l| $l starts-with 'fps: ambient' })"
        $render_0_walks = ($render_0_walks | append { name: $e.item.name, first: ($states | first), last: $last, crossed: $crossed, frames: ($states | length) })
    }
    let ramp_end = ($render_0_walks | last | get last)
    assert ($ramp_end.y > 27.0) $"the body reached the gate at the ramp's top: ($ramp_end)"

    # the frame's clock over the walk: the seed and the cadence answered
    # before the first frame, the E closing the measurement with the end
    # marker after its final frame's records, every frame from 0 to it
    # with a frame, a draw, a presentation, and a packet record in order
    # at the schema, each at cadence 0, awaiting after its flip: no wait
    # and no pacing, one flip attempt, a refusal only when it came early;
    # each frame's start, critical path, wait, and await adding up to its
    # next start, the next frame's start; each frame's phases within its
    # critical path and the drawing's parts, the raster among them, within
    # the drawing, the tiles' time within the planes' and the walls', the
    # tiled pixels within the lit, the arena's peak at or past what it
    # holds; each frame's drawing its preparation and its raster, the
    # bytes its packets held its commands' and span records', and its
    # packets prepared from its own simulation, the gauge's rules at
    # schema 3 which its validity holds; commands and spans in every
    # frame; and the game going on past the measurement
    let walk_clock = (gauge measure $render_0_walk.api [{ name: "walk", places: $render_0_starts, pad: [] }])
    assert $walk_clock.seeded "the walk's seed answered before its first frame"
    assert ($walk_clock.cadence_set and (not $walk_clock.late_cadence)) "the walk's cadence asked before its first frame, once"
    assert $walk_clock.complete $"the walk's measurement complete: ($walk_clock.problems)"
    assert equal $walk_clock.schema $CLOCK_SCHEMA $"the walk's clock records at schema ($CLOCK_SCHEMA)"
    let clock_rows = $walk_clock.rows
    assert ($clock_rows | all {|r| $r.cadence == $CLOCK_CADENCE }) $"every frame of the walk presented at cadence ($CLOCK_CADENCE): ($walk_clock.cadences)"
    let unbalanced = ($clock_rows | where {|r| $r.residual_us < 0 or $r.residual_us > $CLOCK_RESIDUAL })
    assert ($unbalanced | is-empty) $"every frame's start, critical path, wait, and await add up to its next start: ($unbalanced | select frame start_us critical_us wait_us await_us next_start_us residual_us | first 3)"
    let broken = ($clock_rows | window 2 | where {|w| $w.0.next_start_us != $w.1.start_us })
    assert ($broken | is-empty) $"each frame's next start is the next frame's start: ($broken | first 3)"
    let waited = ($clock_rows | where {|r| $r.wait_us != 0 or $r.pacing_us != 0 or $r.flip_attempts != 1 or $r.refusals != (if $r.flip_status == 1 { 1 } else { 0 }) })
    assert ($waited | is-empty) $"each frame awaits after one flip attempt, no wait or pacing before it: ($waited | first 3)"
    assert $walk_clock.valid $"the walk's measurement valid: ($walk_clock.invalid)"
    assert ($walk_clock.past_window > 0) $"the game went on past the measurement: ($walk_clock.past_window) frames"
    let outside = ($clock_rows | where {|r| $r.unattributed_us < 0 or $r.parts_unattributed_us < 0 })
    assert ($outside | is-empty) $"every phase within its frame and every part within its drawing: ($outside | first 3)"
    assert ($clock_rows | all {|r| $r.tiles_us <= ($r.planes_us + $r.walls_us) }) "the tiles' time within the planes' and the walls'"
    assert ($clock_rows | all {|r| $r.tiled_pixels <= $r.lit_pixels }) "the tiled pixels within the lit"
    assert ($clock_rows | all {|r| $r.tile_peak >= $r.tile_bytes }) "the tile arena's peak at or past what it holds"
    assert ($clock_rows | all {|r| $r.aligned }) "each frame record carries its state's drawing and game times"
    let unprepared = ($clock_rows | where {|r| $r.commands == null or $r.commands == 0 or $r.spans == 0 })
    assert ($unprepared | is-empty) $"each frame of the walk prepares commands and spans into its packets: ($unprepared | select frame commands spans | first 3)"
    print $"fps: the clock over the walk: ($walk_clock.frames) frames to frame ($walk_clock.final) at schema ($walk_clock.schema), the critical path's median ($walk_clock.whole.critical.median) us, unattributed at most ($walk_clock.whole.unattributed.max) us of a frame and ($walk_clock.whole.parts_unattributed.max) us of a drawing, residual at most ($clock_rows | get residual_us | math max) us, ($walk_clock.whole.refusals) flips early; the preparation's median ($walk_clock.whole.preparation.median) us and the raster's ($walk_clock.whole.raster.median) us, ($walk_clock.whole.commands.min) to ($walk_clock.whole.commands.max) commands a frame, ($walk_clock.whole.flushes) flushes, ($walk_clock.whole.invalidated) bindings invalidated, ($walk_clock.whole.packet_bytes_max) packet bytes at most"

    # the three cadences on a schedule of stalls and trigger reports and
    # on a timed walk (cadence-holds)
    cadence-holds $kernel $image $out $set $game

    # the fight: the first android, facing the spawn, rouses and fires;
    # from the placed eye four rounds from the console strike it down to
    # the fallen frame, the trigger's round meets the geometry past it,
    # the walk takes its magazine; the shots heard in the recording
    let fight_sends = ([{ at: 1500ms, bytes: (pose pose-frame $FIGHT_POSE) }] | append ($FIGHT_ROUNDS | each {|at| { at: $at, bytes: (pose command-frame "F") } }))
    let fight_run = (jab launch --kernel $kernel --image $image --out ($out | path join "fight") --set $set --sound --api --pad ($env.FILE_PWD | path join "table_fight.nuon") --disk $render_0_disk --serial "fps" --send $fight_sends --capture 9500ms --seconds 11)
    assert equal (open --raw $fight_run.qemu_log) "" "QEMU has no complaint about the guest on the fight"
    let fight_records = (records $fight_run.api)
    assert (($fight_records | where kind == 1 | length) > 100) $"states through the fight: ($fight_records | where kind == 1 | length)"
    let fight_events = ($fight_records | where kind == 3 | where {|e| $e.fields.1 == $FIGHT_ACTOR })
    let fight_event = {|which: int| $fight_events | where {|e| $e.fields.0 == $which } }
    assert ((do $fight_event $ROUSED | length) == 1) $"the android roused once: ($fight_events)"
    assert ((do $fight_event $FIRED | length) >= 1) $"the android fired: ($fight_events)"
    let fight_rounds = ($fight_records | where kind == 2)
    let struck = ($fight_rounds | where {|r| $r.fields.0 == $MET_ANDROID and $r.fields.1 == $FIGHT_ACTOR })
    assert equal ($struck | each {|r| $r.fields.2 }) $FIGHT_HEALTHS $"four rounds struck the android down: ($fight_rounds)"
    assert ((do $fight_event $DESTROYED | length) == 1) $"the android destroyed: ($fight_events)"
    assert ((do $fight_event $FALLEN | length) == 1) $"the android fallen: ($fight_events)"
    assert (($fight_rounds | where {|r| $r.fields.0 == $MET_GEOMETRY } | length) >= 1) $"the trigger's round met the geometry: ($fight_rounds)"
    let pickups = ($fight_records | where kind == 5)
    assert equal ($pickups | length) 1 $"the magazine taken once: ($pickups)"
    assert equal ($pickups | get 0.fields.0) $MAGAZINE_ROUNDS $"the magazine's rounds: ($pickups)"
    let fight_frames = ($fight_run.serial | lines | where {|l| $l starts-with "fps: frame in" } | each {|f| $f | parse $FRAME | get 0 | update cells {|c| $c | into int } })
    assert equal ($fight_frames | length) 2 $"the first frame and the pose's reported on the fight: ($fight_run.serial)"
    assert (($fight_frames | last | get sprites) >= 1) $"the android drawn from the fight's pose: ($fight_frames | last)"
    assert ($fight_run.sound != "") "the fight run recorded its sound"
    let shots = (sound-level $fight_run.sound $FIGHT_SHOTS.from $FIGHT_SHOTS.to)
    assert ($shots.peak >= $FIGHT_SHOTS.over) $"the shots are heard: ($shots)"

    # the light's view independence: six floor points of the bay read
    # from the spawn's eye at two yaws on a copy of Render Zero with its
    # androids dropped, so no sprite crosses a point, once as lit and
    # once with every lumel set full bright by the console's L frame,
    # both runs rebuilding their tiles from nothing under no budget at
    # the pose so the texture is sampled the same way in both; the lit
    # reading over the bright at a point, the light alone, holds within
    # a few levels across the yaws at every point in view at both
    let view_still = (variant-tree $render_0_source "render_0_still" [android] ($out | path join "still") $game)
    mut view_readings = []
    for yaw in $VIEW_YAWS {
        let view_pose = { name: $"view($yaw)", x: $VIEW_EYE.x, y: $VIEW_EYE.y, z: $VIEW_EYE.z, yaw: $yaw, pitch: 0 }
        mut captures = {}
        for v in [{ name: "still", bright: false }, { name: "bright", bright: true }] {
            let view_sends = [{ at: 1400ms, bytes: (level-frame $v.bright false 0) }, { at: 1500ms, bytes: (pose pose-frame $view_pose) }]
            let run = (jab launch --kernel $kernel --image $image --out ($out | path join $"view_($v.name)_($yaw)") --set $set --sound --api --disk (romfs $view_still ($out | path join $"($v.name).romfs")) --serial "fps" --send $view_sends --capture 3000ms --seconds 5)
            assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on the ($v.name) view at yaw ($yaw)"
            let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
            assert equal ($frames | length) 2 $"the first frame and the pose's reported on the ($v.name) view at yaw ($yaw): ($run.serial)"
            let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
            assert ($frame.uncovered < $CRACKS) $"the ($v.name) view at yaw ($yaw) has no pixel uncovered: ($frame)"
            assert ($run.screen != "") $"a screen was taken on the ($v.name) view at yaw ($yaw)"
            $captures = ($captures | insert $v.name { bytes: (open --raw $run.screen | into binary), frame: $frame })
        }
        assert ($captures.bright.frame.tiled > 0) $"the bright copy reads its tiles: ($captures.bright.frame)"
        assert ($captures.still.frame.tiled > 0) $"the lit copy reads its tiles: ($captures.still.frame)"
        for p in $VIEW_POINTS {
            let at = (project $VIEW_EYE $yaw [$p.0, $p.1, 0.0])
            if $at == null { continue }
            let lit = (block-sum $captures.still.bytes $at)
            let bright = (block-sum $captures.bright.bytes $at)
            assert ($bright > 0) $"the floor at ($p) reads on the bright copy at ($at)"
            $view_readings = ($view_readings | append { yaw: $yaw, point: ($p | str join ","), at: $at, lit: $lit, bright: $bright, light: (256 * $lit / $bright) })
        }
    }
    let view_seen = ($view_readings | group-by point)
    mut view_spread = []
    for key in ($view_seen | columns) {
        let rs = ($view_seen | get $key)
        if ($rs | length) < 2 { continue }
        let spread = (($rs | get light | math max) - ($rs | get light | math min))
        assert ($spread <= $VIEW_SLACK) $"the light at ($key) reads the same from every yaw within ($VIEW_SLACK) of 256: ($rs)"
        $view_spread = ($view_spread | append { point: $key, spread: $spread, light: ($rs | get light) })
    }
    assert (($view_spread | length) >= 3) $"floor points in view at both yaws: ($view_readings)"

    # one level a block: the still copy's spawn view under the bright
    # frame with every level of the tiles built against the tiles held
    # off, identical over the whole screen; the bay's far floor asks
    # levels past the tiles' four, which take the chain at their own
    # level whether the tiles are built or not, and every nearer block
    # reads its level from the tiles or the chain alike
    mut spawn_captures = {}
    for v in [{ name: "tiled", held: false }, { name: "held", held: true }] {
        let sends = [{ at: 1400ms, bytes: (level-frame true $v.held 0) }, { at: 1500ms, bytes: (pose pose-frame $SPAWN_POSE) }]
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $"spawn_($v.name)") --set $set --sound --api --disk ($out | path join "still.romfs") --serial "fps" --send $sends --capture 3000ms --seconds 5)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on the spawn view with the tiles ($v.name)"
        let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
        assert equal ($frames | length) 2 $"the first frame and the pose's reported on the spawn view with the tiles ($v.name): ($run.serial)"
        let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
        assert ($frame.uncovered < $CRACKS) $"the spawn view with the tiles ($v.name) has no pixel uncovered: ($frame)"
        assert ($run.screen != "") $"a screen was taken on the spawn view with the tiles ($v.name)"
        $spawn_captures = ($spawn_captures | insert $v.name { bytes: (open --raw $run.screen | into binary), frame: $frame })
    }
    assert ($spawn_captures.tiled.frame.tiled > 0) $"the spawn view read its tiles: ($spawn_captures.tiled.frame)"
    assert ($spawn_captures.held.frame.tiles_built == 0 and $spawn_captures.held.frame.tiled == 0) $"no tile built or read with the tiles held off: ($spawn_captures.held.frame)"
    let spawn_rows = (rows-differ $spawn_captures.tiled.bytes $spawn_captures.held.bytes [0 0 1920 1080])
    assert ($spawn_rows | is-empty) $"the spawn view the same whether its tiles are built or held off: rows ($spawn_rows | first 5) differ, ($spawn_rows | length) in all"

    # the packet bounded: the same view, every level built, drawn in
    # packets of a few commands and spans (PACKET_CAPS), each full packet
    # rendered whole before preparation goes on, the capture the uncapped
    # one's over the whole screen
    let capped_sends = [
        { at: 1300ms, bytes: (packet-frame $PACKET_CAPS.commands $PACKET_CAPS.spans 0) }
        { at: 1400ms, bytes: (level-frame true false 0) }
        { at: 1500ms, bytes: (pose pose-frame $SPAWN_POSE) }
    ]
    let capped_run = (jab launch --kernel $kernel --image $image --out ($out | path join "spawn_capped") --set $set --sound --api --disk ($out | path join "still.romfs") --serial "fps" --send $capped_sends --capture 3000ms --seconds 5)
    assert equal (open --raw $capped_run.qemu_log) "" "QEMU has no complaint about the guest on the spawn view in capped packets"
    let capped_frames = ($capped_run.serial | lines | where {|l| $l starts-with "fps: frame in" })
    assert equal ($capped_frames | length) 2 $"the first frame and the pose's reported on the spawn view in capped packets: ($capped_run.serial)"
    let capped_frame = ($capped_frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
    assert ($capped_frame.flushes > 0) $"the spawn view's packets flushed under the caps: ($capped_frame)"
    assert ($capped_run.screen != "") "a screen was taken on the spawn view in capped packets"
    let capped_rows = (rows-differ (open --raw $capped_run.screen | into binary) $spawn_captures.tiled.bytes [0 0 1920 1080])
    assert ($capped_rows | is-empty) $"the spawn view drawn in packets of ($PACKET_CAPS.commands) commands and ($PACKET_CAPS.spans) spans, ($capped_frame.flushes) flushed, the uncapped one's: rows ($capped_rows | first 5) differ, ($capped_rows | length) in all"

    # the alpha policy rendered: a copy of Render One with its grate
    # wall given the fixture texture and its alcove the solid backdrop,
    # every lumel full bright and the tiles rebuilt whole by the
    # console's L frame at each pose, so a pixel reads a tile's texel as
    # the shrink made it from the texture; each patch's centre projected
    # onto a pixel and read: its exact colour where the oracle's plane
    # for the pose's level passes, the backdrop exactly where it does
    # not, so at level 0 the 128 patches show and the 127 ones do not,
    # and at the coarser levels the scale the search chose lifts the 127
    # patches and the varied ones over the pass, the yellow surviving
    # the weighted mean over black and the red and blue mixing as the
    # shrink's rule says; each pose run again with the tiles held off
    # draws the lit loop's picture from the texture's chain at the same
    # level, read the same way and identical over the opening
    let fixture_alphas = (0..<$ALPHA_FIXTURE.h | each {|y| (fixture-row $y).alphas } | flatten)
    let fixture_levels = (alpha-levels $fixture_alphas $ALPHA_FIXTURE.w $ALPHA_FIXTURE.h)
    assert $fixture_levels.line "the fixture is under full coverage, so the engine names a line for it"
    assert equal ($fixture_levels.scale | get 0) ((8388608 + 126) // 127) $"the fixture's search moves to 127 at level 1, so the scale lifts the pass less one over it: ($fixture_levels.scale)"
    let fixture_tree = (alpha-tree $render_1_source $game ($out | path join "alpha"))
    let fixture_read = (map read ($fixture_tree | path join "map" $"($FIXTURE_MAP).jabfps.map"))
    let fixture_expected = (open ($fixture_tree | path join "map.nuon"))
    let fixture_material = ($fixture_read.materials | enumerate | where {|m| $m.item.name == $ALPHA_FIXTURE.name } | get 0.index)
    let fixture_wall = ($fixture_read.walls | where {|w| $w.surface.material == $fixture_material } | get 0)
    let wall_a = ($fixture_read.vertices | get $fixture_wall.a)
    let wall_b = ($fixture_read.vertices | get $fixture_wall.b)
    let wall_len = ((($wall_b.x - $wall_a.x) ** 2 + ($wall_b.y - $wall_a.y) ** 2) | math sqrt)
    let wall_e = [(($wall_b.x - $wall_a.x) / $wall_len), (($wall_b.y - $wall_a.y) / $wall_len)]
    let fixture_samples = (fixture-samples $fixture_wall $wall_a $wall_e $fixture_levels)
    let fixture_disk = (romfs $fixture_tree ($out | path join "alpha.romfs"))
    let fixture_texels = ($fixture_wall.surface.u_scale * $ALPHA_FIXTURE.w)
    mut fixture_runs = {}
    for fp in $FIXTURE_POSES {
        let step = ($fixture_texels * $fp.distance / 960)
        let level = (if $step < 2 { 0 } else if $step < 4 { 1 } else if $step < 8 { 2 } else { 3 })
        assert equal $level $fp.level $"the ($fp.name) pose reads level ($fp.level) by the block's rule at ($step) texels a pixel"
        let eye = { x: ($wall_a.x - $fp.distance), y: (($wall_a.y + $wall_b.y) / 2), z: $EYE_HEIGHT }
        let placed = { name: $"alpha_($fp.name)", x: $eye.x, y: $eye.y, z: $eye.z, yaw: 0, pitch: 0 }
        for mode in ([tiled lit] | append (if $fp.capped { [capped] } else { [] })) {
            let level_send = (level-frame true ($mode == "lit") (if $mode == "capped" { 1 } else { 0 }))
            let sends = [{ at: 1400ms, bytes: $level_send }, { at: 1500ms, bytes: (pose pose-frame $placed) }]
            let run = (jab launch --kernel $kernel --image $image --out ($out | path join $"alpha_($fp.name)_($mode)") --set $set --sound --api --disk $fixture_disk --serial "fps" --send $sends --capture 3500ms --seconds 5)
            let label = $"the ($fp.name) pose with the tiles ($mode)"
            assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($label)"
            let lines = ($run.serial | lines)
            let loads = ($lines | where {|l| $l starts-with $"fps: ($FIXTURE_MAP) loaded" })
            assert equal ($loads | length) 1 $"the fixture loaded once on ($label): ($run.serial)"
            let load = ($loads | get 0 | parse $LOAD | get 0 | update cells {|c| if $c =~ '^\d+$' { $c | into int } else { $c } })
            assert equal $load.missing 0 $"every material of the fixture in its tree on ($label): ($loads | get 0)"
            assert equal $load.textures $fixture_expected.materials $"the fixture's materials all textures on ($label): ($loads | get 0)"
            let alpha_line = ($lines | where {|l| $l starts-with $"fps: alpha ($ALPHA_FIXTURE.name): " })
            assert equal ($alpha_line | length) 1 $"one alpha line for the fixture on ($label): ($lines | where {|l| $l starts-with 'fps: alpha' })"
            let got = (alpha-line ($alpha_line | get 0))
            assert equal $got.coverage $fixture_levels.coverage $"the fixture's coverage at every level as the rule gives it: ($alpha_line | get 0)"
            assert equal $got.scale $fixture_levels.scale $"the fixture's scales at every coarser level as the rule gives them: ($alpha_line | get 0)"
            let frames = ($lines | where {|l| $l starts-with "fps: frame in" })
            assert equal ($frames | length) 2 $"the first frame and the pose's reported on ($label): ($run.serial)"
            let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
            assert ($frame.uncovered < $CRACKS) $"no pixel uncovered on ($label): ($frame)"
            assert equal $frame.resets 0 $"the arena holds on ($label): ($frame)"
            if $mode == "tiled" {
                assert ($frame.tiles_built > 0 and $frame.tiled > 0) $"the view built its tiles whole and read them on ($label): ($frame)"
            } else if $mode == "capped" {
                # the cap proven against the same pose built whole, the
                # frame after the reset and the pose in each: fewer tiles
                # built, and fewer pixels read from tiles, the blocks
                # asking a coarser level taking the chain
                let whole = ($fixture_runs | get $"($fp.name)_tiled" | get frame)
                assert ($frame.tiles_built > 0) $"the view built its level 0 tiles on ($label): ($frame)"
                assert ($frame.tiles_built < $whole.tiles_built) $"the cap held back the levels past 0 on ($label): ($frame.tiles_built) tiles built against ($whole.tiles_built) with every level"
                assert ($frame.tiled < $whole.tiled) $"the blocks asking level ($fp.level) read the chain, not tiles, on ($label): ($frame.tiled) pixels tiled against ($whole.tiled) with every level"
            } else {
                assert ($frame.tiles_built == 0 and $frame.tiled == 0) $"no tile built or read with the tiles held off on ($label): ($frame)"
            }
            assert ($run.screen != "") $"a screen was taken on ($label)"
            let bytes = (open --raw $run.screen | into binary)
            let read_level = $level
            let read = (fixture-read $bytes $eye $fixture_samples $read_level)
            for r in ($read | where {|r| $r.uniform or $read_level > 0 }) {
                if $r.shows {
                    assert equal $r.pixel $r.colour $"the ($r.kind) patch at ($r.at) shows its colour at level ($read_level) on ($label): ($r.pixel | encode hex)"
                } else {
                    assert equal $r.pixel $FIXTURE_BACKDROP.colour $"the ($r.kind) patch at ($r.at) is absent at level ($read_level) on ($label), the backdrop behind it: ($r.pixel | encode hex)"
                }
            }
            $fixture_runs = ($fixture_runs | insert $"($fp.name)_($mode)" { bytes: $bytes, eye: $eye, frame: $frame, read: $read, level: $read_level })
        }
    }
    # the lit loop's picture against the tiled one over the whole
    # opening at every level: the tiles are built from the texture by
    # the shrink's rule a level at a time and the loop reads the
    # texture's chain, built by the same rule, each at the level the
    # block's footprint asks for, so under the bright frame the two
    # agree texel for texel; the solid alcove behind reads one colour at
    # any level
    mut openings = []
    for fp in $FIXTURE_POSES {
        let tiled = ($fixture_runs | get $"($fp.name)_tiled")
        let lit = ($fixture_runs | get $"($fp.name)_lit")
        let opening = (fixture-opening $fixture_read $fixture_wall $tiled.eye)
        let differing = (rows-differ $tiled.bytes $lit.bytes $opening)
        assert ($differing | is-empty) $"the tiled and the lit pictures agree over the opening ($opening) at level ($fp.level): rows ($differing | first 5) differ, ($differing | length) in all"
        if $fp.capped {
            # level 0 alone built: a block asking level 1 takes the chain
            # at level 1, so the picture is the lit loop's
            let capped = ($fixture_runs | get $"($fp.name)_capped")
            let partial = (rows-differ $capped.bytes $lit.bytes $opening)
            assert ($partial | is-empty) $"with level 0 alone built the ($fp.name) pose's blocks take the chain at level ($fp.level), the lit picture over the opening ($opening): rows ($partial | first 5) differ, ($partial | length) in all"
        }
        $openings = ($openings | append [$opening])
    }
    let level_pairs = ($fixture_runs.near_tiled.read | zip $fixture_runs.mid_tiled.read | where {|p| $p.0.uniform })
    assert (($level_pairs | where {|p| $p.0.shows != $p.1.shows } | length) > 0) "a uniform patch's pass differs at level 1 from level 0, so the scale is exercised"
    # the same poses under the room's own light, the spotlight's
    # gradient across the wall, tiled against the lit loop over the
    # opening: a tile holds lit texels filtered where the loop lights a
    # filtered texel at the pixel's own coordinate, so the two differ by
    # their rounding and the light's change across a texel; reported, the
    # pixels that differ and the largest difference in a channel, held
    # within TheUser's bound, each run proven on its path
    mut light_report = []
    mut light_captures = {}
    for fp in $FIXTURE_POSES {
        let eye = ($fixture_runs | get $"($fp.name)_tiled" | get eye)
        let placed = { name: $"alpha_($fp.name)", x: $eye.x, y: $eye.y, z: $eye.z, yaw: 0, pitch: 0 }
        mut lit_captures = {}
        for mode in [tiled lit] {
            let sends = [{ at: 1400ms, bytes: (level-frame false ($mode == "lit") 0) }, { at: 1500ms, bytes: (pose pose-frame $placed) }]
            let run = (jab launch --kernel $kernel --image $image --out ($out | path join $"alpha_light_($fp.name)_($mode)") --set $set --sound --api --disk $fixture_disk --serial "fps" --send $sends --capture 3500ms --seconds 5)
            let label = $"the ($fp.name) pose under the room's light with the tiles ($mode)"
            assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($label)"
            let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
            assert equal ($frames | length) 2 $"the first frame and the pose's reported on ($label): ($run.serial)"
            let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
            assert ($frame.uncovered < $CRACKS) $"no pixel uncovered on ($label): ($frame)"
            if $mode == "tiled" {
                assert ($frame.tiles_built > 0 and $frame.tiled > 0) $"the view built its tiles whole and read them on ($label): ($frame)"
            } else {
                assert ($frame.tiles_built == 0 and $frame.tiled == 0) $"no tile built or read with the tiles held off on ($label): ($frame)"
            }
            assert ($run.screen != "") $"a screen was taken on ($label)"
            $lit_captures = ($lit_captures | insert $mode (open --raw $run.screen | into binary))
        }
        let opening = (fixture-opening $fixture_read $fixture_wall $eye)
        let delta = (region-delta $lit_captures.tiled $lit_captures.lit $opening)
        $light_report = ($light_report | append ($delta | insert pose $fp.name | insert level $fp.level))
        $light_captures = ($light_captures | insert $fp.name ($lit_captures | insert placed $placed))
    }
    print $"fps: the alpha poses under the room's light, tiled against lit over the opening: ($light_report | each {|r| $'($r.pose) at level ($r.level), ($r.differing) of ($r.pixels) pixels differ, by ($r.largest) at most' } | str join '; ')"
    for r in $light_report {
        assert ($r.largest <= $REAL_LIGHT_BOUND) $"the ($r.pose) pose under the room's light, tiled against lit over the opening, within ($REAL_LIGHT_BOUND) of 255 a channel: ($r.differing) of ($r.pixels) pixels differ, by ($r.largest) at most"
    }

    # a stale binding: the near pose under the room's light with the tile
    # arena reset after the frame's first STALE_BINDS binds every frame
    # (the K frame), every surface after the reset rebuilt whole under the
    # lifted budget; the commands bound before the reset take the chain at
    # their own level, so every pixel is the tiled picture's or the lit
    # loop's, some of each, none the poison of the arena they held
    let near = ($light_captures | get near)
    let stale_sends = [
        { at: 1300ms, bytes: (packet-frame 0 0 $STALE_BINDS) }
        { at: 1400ms, bytes: (level-frame false false 0) }
        { at: 1500ms, bytes: (pose pose-frame $near.placed) }
    ]
    let stale_run = (jab launch --kernel $kernel --image $image --out ($out | path join "alpha_light_near_stale") --set $set --sound --api --disk $fixture_disk --serial "fps" --send $stale_sends --capture 3500ms --seconds 5)
    assert equal (open --raw $stale_run.qemu_log) "" "QEMU has no complaint about the guest on the near pose with stale bindings"
    let stale_frames = ($stale_run.serial | lines | where {|l| $l starts-with "fps: frame in" })
    assert equal ($stale_frames | length) 2 $"the first frame and the pose's reported on the near pose with stale bindings: ($stale_run.serial)"
    let stale_frame = ($stale_frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
    assert ($stale_run.screen != "") "a screen was taken on the near pose with stale bindings"
    let stale = (pixels-from (open --raw $stale_run.screen | into binary) $near.tiled $near.lit [0 0 1920 1080])
    assert equal $stale.neither 0 $"every pixel of the near pose with stale bindings the tiled picture's or the lit loop's: ($stale.neither) neither, ($stale.poisoned) of them the poison"
    assert ($stale.second > 0) $"the commands bound before the reset on the chain, the lit loop's pixels: ($stale)"
    assert ($stale.first > 0) $"the commands bound after it on their tiles, the tiled picture's pixels: ($stale)"
    assert ($stale_frame.invalidated > 0 and $stale_frame.resets > 0) $"the reset counted and the bindings before it invalidated: ($stale_frame)"

    # the texel-centre rule (CENTRE_FIXTURE): the fixture's wall white
    # under lumels set by their nodes' parity, posed head-on at level 0
    # with the tiles built whole and again held off; every sampled texel
    # beside a node read on the tiled run at its centre against the
    # light of its centre, the four nodes of its cell bilinear there, and
    # one colour over the pixels about its centre, which a tile holds and
    # the lit loop, lighting each pixel at its own coordinate, does not:
    # the held-off run's same pixels vary, proving the tiled reading came
    # from the tiles; the samples' own arithmetic putting a texel lit at
    # its corner past the slack beside dark and bright nodes alike
    let centre_tree = (centre-tree $render_1_source $game ($out | path join "centre"))
    let centre_read = (map read ($centre_tree | path join "map" $"($FIXTURE_MAP).jabfps.map"))
    let centre_material = ($centre_read.materials | enumerate | where {|m| $m.item.name == $CENTRE_FIXTURE.name } | get 0.index)
    let centre_wall = ($centre_read.walls | where {|w| $w.surface.material == $centre_material } | get 0)
    let centre_a = ($centre_read.vertices | get $centre_wall.a)
    let centre_b = ($centre_read.vertices | get $centre_wall.b)
    let centre_eye = { x: ($centre_a.x - $CENTRE_DISTANCE), y: (($centre_a.y + $centre_b.y) / 2), z: $EYE_HEIGHT }
    let centre_step = ($CENTRE_FIXTURE.size * $centre_wall.surface.u_scale * $CENTRE_DISTANCE / 960)
    assert ($centre_step < 2) $"the centre pose reads level 0 by the block's rule at ($centre_step) texels a pixel"
    let centre_opening = (fixture-opening $centre_read $centre_wall $centre_eye)
    let centre_samples = (centre-samples $centre_read $centre_wall $centre_eye $centre_opening)
    let telling = ($centre_samples | where {|s| (($s.corner - $s.expected) | math abs) > (2 * $CENTRE_SLACK) })
    assert equal ($telling | get parity | uniq | sort) [0, 1] $"texels beside dark and bright nodes alike where the corner rule reads past twice the slack: ($telling | length) of ($centre_samples | length) samples"
    let centre_disk = (romfs $centre_tree ($out | path join "centre.romfs"))
    let centre_placed = { name: "centre", x: $centre_eye.x, y: $centre_eye.y, z: $centre_eye.z, yaw: 0, pitch: 0 }
    mut centre_runs = {}
    for mode in [tiled held] {
        let sends = [{ at: 1400ms, bytes: (level-frame false ($mode == "held") 0 --parity) }, { at: 1500ms, bytes: (pose pose-frame $centre_placed) }]
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $"centre_($mode)") --set $set --sound --api --disk $centre_disk --serial "fps" --send $sends --capture 3500ms --seconds 5)
        let label = $"the white wall under the parity lumels with the tiles ($mode)"
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($label)"
        let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
        assert equal ($frames | length) 2 $"the first frame and the pose's reported on ($label): ($run.serial)"
        let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
        assert ($frame.uncovered < $CRACKS) $"no pixel uncovered on ($label): ($frame)"
        if $mode == "tiled" {
            assert ($frame.tiles_built > 0 and $frame.tiled > 0) $"the view built its tiles whole and read them on ($label): ($frame)"
        } else {
            assert ($frame.tiles_built == 0 and $frame.tiled == 0) $"no tile built or read with the tiles held off on ($label): ($frame)"
        }
        assert ($run.screen != "") $"a screen was taken on ($label)"
        $centre_runs = ($centre_runs | insert $mode (open --raw $run.screen | into binary))
    }
    let centre_tiled = (centre-read $centre_runs.tiled $centre_samples)
    for r in $centre_tiled {
        assert ($r.off <= $CENTRE_SLACK) $"the texel ($r.texel) beside the node ($r.node) lit ($r.light) reads the light of its centre from its tile, ($r.expected | math round --precision 2) of 255 within ($CENTRE_SLACK), at ($r.at): ($r.pixel | encode hex), where lit at its corner it would read ($r.corner | math round --precision 2)"
        assert $r.uniform $"the texel ($r.texel) beside the node ($r.node) lit ($r.light) is one colour over the pixels about its centre at ($r.at), as a tile holds it"
    }
    let centre_held = (centre-read $centre_runs.held $centre_samples)
    let varied = ($centre_held | where {|r| not $r.uniform } | length)
    assert ($varied > (($centre_held | length) // 2)) $"the lit loop's picture varies over most sampled texels' pixels, so one colour there tells a tile: ($varied) of ($centre_held | length)"
    print $"fps: the texel-centre rule, ($centre_tiled | length) texels beside ($centre_samples | get node | uniq | length) nodes read from their tiles within ($centre_tiled | get off | math max | math round --precision 2) of their centres' light, ($telling | length) where the corner's lies past twice the slack; the lit loop's pixels varied over ($varied)"

    # the flow's growth on the growth map: the far room is reached only
    # once the hall's rectangle has grown through the side room's path
    # after the hall was flowed off the window's, and its far wall reads
    # the backdrop through its doorway
    let grow_far = ((grow-source).sectors | enumerate | where {|s| $s.item.name == $GROW_FAR } | get 0.index)
    let grow_run = (jab launch --kernel $kernel --image $image --out ($out | path join "grow_run") --set $set --sound --api --disk (romfs $grow_tree ($out | path join "grow.romfs")) --serial "fps" --send [{ at: 1500ms, bytes: (pose pose-frame $GROW_POSE) }] --capture 2500ms --seconds 5)
    assert equal (open --raw $grow_run.qemu_log) "" "QEMU has no complaint about the guest on the growth run"
    let grow_lines = ($grow_run.serial | lines)
    let grow_loads = ($grow_lines | where {|l| $l starts-with $"fps: ($GROW_MAP) loaded" })
    assert equal ($grow_loads | length) 1 $"the growth map loaded once: ($grow_run.serial)"
    let grow_load = ($grow_loads | get 0 | parse $LOAD | get 0 | update cells {|c| if $c =~ '^\d+$' { $c | into int } else { $c } })
    assert equal $grow_load.missing 0 $"every material of the growth map in its tree: ($grow_loads | get 0)"
    let grow_frames = ($grow_lines | where {|l| $l starts-with "fps: frame in" } | each {|f| $f | parse $FRAME | get 0 | update cells {|c| $c | into int } })
    assert equal ($grow_frames | length) 2 $"the first frame and the growth pose's reported: ($grow_run.serial)"
    let grow_frame = ($grow_frames | last)
    assert ($grow_frame.uncovered < $CRACKS) $"no pixel uncovered on the growth view: ($grow_frame)"
    let grow_sectors = ($grow_lines | where {|l| $l starts-with "fps: sectors " } | last | str substring 13.. | str trim | split row " " | each {|s| $s | into int })
    assert ($grow_far in $grow_sectors) $"the far room reached through the hall's grown rectangle: ($grow_sectors)"
    assert ($grow_run.screen != "") "a screen was taken on the growth run"
    let grow_at = (project { x: $GROW_POSE.x, y: $GROW_POSE.y, z: $GROW_POSE.z } $GROW_POSE.yaw $GROW_POINT)
    assert ($grow_at != null) "the far wall's point is on screen"
    assert equal (pixel $grow_run.screen $grow_at) $FIXTURE_BACKDROP.colour $"the far room's wall at ($grow_at), seen only through the grown rectangle, reads the backdrop: ($grow_run.screen)"

    # a map whose magic is wrong
    let bad = (broken ($out | path join "bad_tree") "bad" ([("XXXX" | into binary), (0..<60 | each {|i| 0x[00] } | bytes collect)] | bytes collect))
    let bad_run = (jab launch --kernel $kernel --image $image --out ($out | path join "bad") --set $set --sound --disk (romfs $bad ($out | path join "bad.romfs")) --serial "fps" --seconds 8)
    assert equal $bad_run.status 6 $"a wrong magic exits 6: ($bad_run.status), ($bad_run.serial)"
    assert ("fps: /map/bad.jabfps.map is not a Jab FPS map" in ($bad_run.serial | lines)) $"and says so: ($bad_run.serial)"

    # Render One's map cut short inside its sections
    let whole = (open --raw ($render_1_tree | path join "map" "render_1.jabfps.map") | into binary)
    assert (($whole | bytes length) > $SHORT_BYTES) $"Render One's map runs past ($SHORT_BYTES) bytes: ($whole | bytes length)"
    let short = (broken ($out | path join "short_tree") "short" ($whole | bytes at 0..<$SHORT_BYTES))
    let short_run = (jab launch --kernel $kernel --image $image --out ($out | path join "short") --set $set --sound --disk (romfs $short ($out | path join "short.romfs")) --serial "fps" --seconds 8)
    assert equal $short_run.status 7 $"a short file exits 7: ($short_run.status), ($short_run.serial)"
    assert ($"fps: /map/short.jabfps.map ends at ($SHORT_BYTES) bytes before its structures do" in ($short_run.serial | lines)) $"and says so: ($short_run.serial)"

    print $"fps: the load screen: ($titles | each {|t| $'($t.text) inked ($t.ink.left) to ($t.ink.right) on rows ($t.ink.top) to ($t.ink.bottom)' } | str join '; ')"
    print $"fps: the sprite drawn in ($sprite_frame.us) us, ($sprite_frame.sprites) sprites in ($sprite_frame.sprite_us) us, ($sprite_frame.uncovered) uncovered, red at ($SPRITE_RIGHT) and the wall at ($SPRITE_LEFT); the straddling sprite's near end at ($straddle_at) its texture, left of the doorway's column ($door_left), ($straddle_frame.sprites) sprites in ($straddle_frame.us) us"
    print $"fps: the growth map drew ($grow_sectors) in ($grow_frame.us) us with ($grow_frame.uncovered) uncovered, the far wall at ($grow_at) the backdrop"
    print $"fps: render_1 loaded in ($render_1_load.ms) ms; the spawn view in ($render_1_start.us) us with ($render_1_start.sprites) sprites, the eye ($shove | math round --precision 3) off the spawn; the poses ($render_1_poses | get name | str join ', ') in ($render_1_frames | slice 1.. | each {|p| $p.us } | str join ', ') us with ($render_1_frames | slice 1.. | each {|p| $p.uncovered } | str join ', ') uncovered, drawing ($render_1_sectors | slice 1.. | each {|s| $s | length } | str join ', ') sectors; the light's floor ($lit_near | math round --precision 1) against the far wall's ($lit_far | math round --precision 1); ($render_1_mips.chains) chains of ($render_1_mips.levels) levels, ($render_1_mips.texels) texels in ($render_1_mips.ms) ms"
    print $"fps: the stair from ($stair_first.x), ($stair_first.y), ($stair_first.z) in ($stair_first.sector) to ($stair_last.x), ($stair_last.y), ($stair_last.z) in ($stair_last.sector) through ($stair_sectors) over ($stair_states | length) frames"
    print $"fps: render_0 loaded in ($render_0_load.ms) ms; the spawn view in ($render_0_start.us) us over ($render_0_start.sectors) sectors, ($render_0_start.walls) walls, ($render_0_start.pieces) pieces, ($render_0_start.planes) planes \(clear ($render_0_start.clear), planes ($render_0_start.plane_us), walls ($render_0_start.wall_us), portals ($render_0_start.portal_us) us\); the poses ($render_0_poses | get name | str join ', ') in ($render_0_frames | slice 1.. | each {|p| $p.us } | str join ', ') us with ($render_0_frames | slice 1.. | each {|p| $p.uncovered } | str join ', ') uncovered, drawing ($render_0_sectors | slice 1.. | each {|s| $s | length } | str join ', ') sectors; ($render_0_mips.chains) chains of ($render_0_mips.levels) levels, ($render_0_mips.texels) texels in ($render_0_mips.ms) ms"
    for w in $render_0_walks {
        print $"fps: the ($w.name) walk from ($w.first.x), ($w.first.y), ($w.first.z) in ($w.first.sector) to ($w.last.x), ($w.last.y), ($w.last.z) in ($w.last.sector) through ($w.crossed) over ($w.frames) frames"
    }
    print $"fps: the fight: the android fired ($fight_events | where {|e| $e.fields.0 == $FIRED } | length) rounds, the frame struck ($fight_records | where kind == 4 | length) times; struck down through ($struck | each {|r| $r.fields.2 } | str join ', '), ($fight_rounds | length) rounds in all, the magazine taken with ($pickups | get 0.fields.0) rounds; the shots' window peaking at ($shots.peak); the pose's frame in ($fight_frames | last | get us) us with ($fight_frames | last | get sprites) sprites"
    print $"fps: the light from the spawn at yaws ($VIEW_YAWS): ($view_spread | each {|s| $'($s.point) ($s.light | each {|l| $l | math round --precision 1 } | str join ' and ') of 256, ($s.spread | math round --precision 1) apart' } | str join '; ')"
    print $"fps: the alpha fixture: coverage ($fixture_levels.coverage) of 10000 and scales ($fixture_levels.scale) of 65536 by level; ($fixture_runs | transpose name run | each {|r| $'($r.name) at level ($r.run.level) in ($r.run.frame.us) us, ($r.run.frame.tiles_built) tiles built, ($r.run.read | where shows | length) of ($r.run.read | length) patches shown' } | str join '; '); the openings ($openings) identical between the tiles and the lit loop at levels 0, 1, and 2"
    print $"fps: the wrong magic out with ($bad_run.status), the short file with ($short_run.status)"
    print "fps: ok"
}

# A copy of a map source with the entities of the given classes dropped,
# compiled under out with the game's content; the tree's path.
def variant-tree [source: record, name: string, dropped: list<string>, out: path, game: path]: nothing -> string {
    jab retire $out
    mkdir $out
    let copy = ($source | update name $name | update entities ($source.entities | where {|e| $e.class not-in $dropped }))
    let src = ($out | path join $"($name).nuon")
    $copy | to nuon | save --raw -f $src
    let compiled = (^nu ($game | path join "nu" "map.nu") compile $src $out --content ($game | path join "content") | complete)
    if $compiled.exit_code != 0 { error make { msg: $"compiling ($name): ($compiled.stderr)" } }
    $out | path join $name
}

# A world point's pixel from an eye at a yaw with no pitch or roll: the
# point's right and up over its depth times the focal length from the
# screen's centre; null behind the near plane or off the screen by a
# block's margin.
def project [eye: record, yaw: int, point: list<float>]: nothing -> oneof<list<int>, nothing> {
    let rad = ($yaw * 3.141592653589793 / 180)
    let fx = ($rad | math cos)
    let fy = ($rad | math sin)
    let v = [($point.0 - $eye.x), ($point.1 - $eye.y), ($point.2 - $eye.z)]
    let depth = ($v.0 * $fx + $v.1 * $fy)
    if $depth <= 0.0625 { return null }
    let right = ($v.0 * $fy - $v.1 * $fx)
    let x = ((960 + $right / $depth * 960) | math round | into int)
    let y = ((540 - $v.2 / $depth * 960) | math round | into int)
    if $x < 1 or $x >= 1919 or $y < 1 or $y >= 1079 { return null }
    [$x, $y]
}

# A point of the plan's screen column from an eye at a yaw, as `project`
# finds it, on the screen or off it; null behind the near plane.
def project-x [eye: record, yaw: int, point: list<float>]: nothing -> oneof<int, nothing> {
    let rad = ($yaw * 3.141592653589793 / 180)
    let fx = ($rad | math cos)
    let fy = ($rad | math sin)
    let v = [($point.0 - $eye.x), ($point.1 - $eye.y)]
    let depth = ($v.0 * $fx + $v.1 * $fy)
    if $depth <= 0.0625 { return null }
    let right = ($v.0 * $fy - $v.1 * $fx)
    (960 + $right / $depth * 960) | math round | into int
}

# The sum of every channel over the 3 by 3 block of pixels about a point
# of a capture, the capture's bytes whole.
def block-sum [bytes: binary, at: list<int>]: nothing -> int {
    let newlines = ($bytes | bytes index-of --all 0x[0a] | take 3)
    let head_len = ($newlines.2 + 1)
    [-1, 0, 1] | each {|dy|
        let o = ($head_len + (($at.1 + $dy) * 1920 + $at.0 - 1) * 3)
        $bytes | bytes at $o..<($o + 9) | encode hex | split chars | chunks 2 | each {|h| $h | str join "" | into int --radix 16 } | math sum
    } | math sum
}

# Each hot function within one page of code and trapping no more than
# its table says, and the span loop's family together on one page,
# through the SDK's `jab hot` over the ELF beside the image: QEMU's
# translator ends a block at a page boundary and chains blocks within a
# page only, so a loop straddling one runs seven times slower, a call
# across one costs a lookup, and a trap in a per-pixel loop would cost
# more. `jab hot` gives an end exclusive, so a page is an end less one's.
def hot-functions [image: path]: nothing -> nothing {
    let elf = ($image | path dirname | path join "fps.elf")
    let hot = (jab hot $elf $HOT_FUNCTIONS)
    for h in $hot {
        assert $h.paged $"($h.name) within one page of code: ($h.start) to ($h.end)"
        assert equal $h.ecalls ($HOT_ECALLS | get $h.name) $"($h.name) traps inside its page"
    }
    for f in $HOT_FAMILIES {
        let family = ($hot | where {|h| $h.name in $f.members })
        assert equal ($family | length) ($f.members | length) $"every member of ($f.name) family among the hot functions"
        let lowest = ($family | get start | math min)
        let highest = (($family | get end | math max) - 1)
        assert equal ($lowest // 4096) ($highest // 4096) $"($f.name) family within one page of code together: ($lowest) to ($highest)"
    }
}

# A release build carries none of the program's debug text, every
# `fps: ` string in it an exit's, and the debug build carries all of it,
# so the scan is proved where it must find things before it is trusted
# where it must find nothing; the release image is built here through
# the tool, since the test's build is a debug one.
def release-strings [image: path]: nothing -> nothing {
    let here = ($env.FILE_PWD | path join ".." | path expand)
    let tool = ($here | path join ".." ".." ".." "sdk" "nu" "jab.nu" | path expand)
    let built = (^nu $tool build $here | complete)
    assert equal $built.exit_code 0 $"the release image built: ($built.stderr)"
    let release = (jab program-out $here "release" | path join "fps.jab")
    assert ($release | path exists) $"the release image at ($release)"
    let debug_found = (jab strings $image "fps: ")
    for text in $DEBUG_TEXT {
        assert ($debug_found | any {|s| $s | str starts-with $text }) $"the debug build carries '($text)'"
    }
    for text in $EXIT_TEXT {
        assert ($text in $debug_found) $"the debug build carries the exit text '($text)'"
    }
    let release_found = (jab strings $release "fps: ")
    for text in $DEBUG_TEXT {
        assert (not ($release_found | any {|s| $s | str starts-with $text })) $"the release build carries no '($text)'"
    }
    assert equal ($release_found | sort) ($EXIT_TEXT | sort) $"every fps: string in the release build is an exit's: ($release_found)"
}

# The records of an API capture, the clock's kinds left to gauge.nu: the
# kind, the sector, the eye, the angles in degrees, the times, and an
# event's five fields.
def records [api: binary]: nothing -> table<kind: int, sector: int, x: float, y: float, z: float, yaw: float, pitch: float, roll: float, frame_us: int, game_us: int, fields: list<int>> {
    0..<(($api | bytes length) // $RECORD) | each {|i|
        let r = ($api | bytes at ($i * $RECORD)..<(($i + 1) * $RECORD))
        let kind = ($r | bytes at 0..<1 | into int)
        if $kind in $CLOCK_KINDS { null } else {
            {
                kind: $kind,
                sector: ($r | bytes at 4..<8 | into int --endian little --signed),
                x: (map float-at $r 8), y: (map float-at $r 12), z: (map float-at $r 16),
                yaw: (map float-at $r 20), pitch: (map float-at $r 24), roll: (map float-at $r 28),
                frame_us: ($r | bytes at 32..<36 | into int --endian little),
                game_us: ($r | bytes at 36..<40 | into int --endian little),
                fields: (0..<5 | each {|f| $r | bytes at (40 + $f * 4)..<(44 + $f * 4) | into int --endian little --signed }),
            }
        }
    } | compact
}

# A tree's load screen, captured at TITLE_AT while the map loads behind
# it: the text in the title's ink, bold at four times the console's cell
# and centred, its ink within the text's cells, wider than all of them
# but one, and on the title's rows, so a shorter text drawn in its place
# fails by its width and nothing drawn by its count; the ink's box.
def title-holds [kernel: path, image: path, out: path, set: string, name: string, tree: path, text: string]: nothing -> record<count: int, left: int, top: int, right: int, bottom: int> {
    let run = (jab launch --kernel $kernel --image $image --out ($out | path join $"title_($name)") --set $set --sound --disk (romfs $tree ($out | path join $"title_($name).romfs")) --serial "fps" --capture $TITLE_AT --seconds 5)
    assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($name)'s load screen"
    assert ($run.screen != "") $"a screen was taken on ($name)'s load screen"
    let ink = (jab ink (jab screen $run.screen) $TITLE_INK)
    let cells = ($text | str length)
    let half = ($cells * $TITLE_CELL // 2)
    let width = ($ink.right - $ink.left + 1)
    assert ($ink.count > 0) $"($name)'s load screen draws ($text): ($ink)"
    assert ($ink.left >= (960 - $half) and $ink.right < (960 + $half)) $"($text) centred within its ($cells) cells on ($name)'s load screen: ($ink)"
    assert ($width > (($cells - 1) * $TITLE_CELL)) $"the ink as wide as ($text)'s ($cells) cells on ($name)'s load screen, not a shorter text's: ($width) px, ($ink)"
    assert ($ink.top >= $TITLE_Y and $ink.bottom < ($TITLE_Y + $TITLE_HEIGHT)) $"($text) on the title's rows on ($name)'s load screen: ($ink)"
    $ink
}

# A romfs image of the tree, as the SDK builds one, with the program's
# volume name; the image's path.
def romfs [tree: path, image: path]: nothing -> string {
    let made = (^genromfs -d $tree -f $image -V "fps" | complete)
    if $made.exit_code != 0 { error make { msg: $"genromfs on ($tree): ($made.stderr)" } }
    $image
}

# A copy of a map source compiled with its lights and its android
# dropped, so every texel reads as its texture holds it, and an alpha
# case a sprite, two-sided: the straddler, a fixed quad along y; with
# --halves the halves sprite facing the camera; and every other case a
# small fixed quad standing in the upper storey, out of the lower's
# sight, so it is a material of the map; each case's texture written
# into the tree after the compile, which names it unresolved; the
# tree's path.
def sprite-tree [source: record, name: string, out: path, game: path, --halves]: nothing -> string {
    let cases = ($ALPHA_CASES | where {|c| $halves or $c.name != $SPRITE_MATERIAL })
    let sprites = ($cases | enumerate | each {|e|
        let placed = (if $e.item.name == $SPRITE_MATERIAL {
            { at: $SPRITE.at, size: $SPRITE.size, facing: "camera" }
        } else if $e.item.name == $STRADDLE_MATERIAL {
            { at: $STRADDLE.at, size: $STRADDLE.size, facing: "fixed" }
        } else {
            { at: [(1.0 + $e.index), 1.0, 3.5], size: [0.5, 0.5], facing: "fixed" }
        })
        { name: $"alpha_($e.index)", class: "sprite", at: $placed.at, yaw: 0.0, pitch: 0.0, size: $placed.size, material: ($e.item.name | str substring 7..), colour: [1.0, 1.0, 1.0], radius: 0.0, spread: 0.0, facing: $placed.facing, two_sided: true, solid: false, tag: 0, target: "" }
    })
    let tree = (variant-tree ($source | update entities ($source.entities | append $sprites)) $name [light android] $out $game)
    for c in $cases {
        let file = ($tree | path join (map tile-path $c.name | str substring 1..))
        mkdir ($file | path dirname)
        let pixels = (0..<$c.h | each {|y| 0..<$c.w | each {|x| (case-texel $c $x $y).bytes } | bytes collect } | bytes collect)
        png write-rgba $file $c.w $c.h $pixels
    }
    $tree
}

# A texel of an alpha case: its four bytes as the PNG carries them, red,
# green, blue, alpha, and its alpha. The halves: the left transparent, the
# right opaque red. Uniform: one colour at the case's alpha. The checker:
# opaque red and transparent texels alternating on both axes. The block:
# transparent but for an opaque white 2 by 2 at the top left. The edge:
# one colour at the case's alpha, the pass, but a step under it where
# both coordinates are odd, one texel of every 2 by 2.
def case-texel [c: record, x: int, y: int]: nothing -> record<bytes: binary, alpha: int> {
    let clear = { bytes: 0x[00 00 00 00], alpha: 0 }
    let red = { bytes: 0x[ff 00 00 ff], alpha: 255 }
    let white = { bytes: 0x[ff ff ff ff], alpha: 255 }
    let tinted = {|alpha: int| { bytes: ([0x[40 80 c0], ($alpha | into binary | bytes at 0..<1)] | bytes collect), alpha: $alpha } }
    match $c.kind {
        "halves" => (if $x < ($c.w // 2) { $clear } else { $red }),
        "uniform" => (do $tinted $c.alpha),
        "checker" => (if (($x + $y) mod 2) == 0 { $red } else { $clear }),
        "block" => (if $x < 2 and $y < 2 { $white } else { $clear }),
        "edge" => (if ($x mod 2) == 1 and ($y mod 2) == 1 { do $tinted ($c.alpha - 1) } else { do $tinted $c.alpha }),
        _ => (error make { msg: $"no alpha case of kind ($c.kind)" }),
    }
}

# A material's alpha line among a run's, its first three coarser levels'
# shares of texels at or above the pass each within the material's slack
# of level 0's.
def alpha-held [lines: list<string>, name: string]: nothing -> nothing {
    let line = ($lines | where {|l| $l starts-with $"fps: alpha ($name): " })
    assert equal ($line | length) 1 $"one alpha line for ($name): ($lines | where {|l| $l starts-with 'fps: alpha' })"
    let got = (alpha-line ($line | get 0))
    let slack = ($ALPHA_SLACKS | get $name)
    let c0 = ($got.coverage | get 0)
    for c in ($got.coverage | slice 1..3) {
        assert ((($c - $c0) | math abs) <= $slack) $"($name)'s coverage holds by level within ($slack) of 10000: ($line | get 0)"
    }
}

# An alpha line read: its material, its share of texels at or above the
# pass at every level of the chain in 10000ths, and every coarser
# level's scale in 65536ths.
def alpha-line [line: string]: nothing -> record<name: string, coverage: list<int>, scale: list<int>> {
    let got = ($line | parse $ALPHA_LINE | get 0)
    {
        name: $got.name,
        coverage: ($got.coverage | split row " " | each {|v| $v | into int }),
        scale: ($got.scale | split row " " | each {|v| $v | into int }),
    }
}

# The levels a texture's mip chain has, as the engine builds it: one,
# and one more for every halving while both sides are two texels or
# more, MIP_LEVELS at most, so a side can end at one texel.
def chain-levels [w: int, h: int]: nothing -> int {
    mut levels = 1
    mut pw = $w
    mut ph = $h
    while $levels < $MIP_LEVELS and $pw >= 2 and $ph >= 2 {
        $pw = $pw // 2
        $ph = $ph // 2
        $levels += 1
    }
    $levels
}

# The console's L frame: every tile forgotten, every lumel set full
# bright first when `bright`, the build budget held at zero when `held`
# so every span takes the lit loop, else lifted, and on a debug build the
# levels a surface builds capped at `cap`, 0 for every level, and every
# lumel set by its node's parity after the bright with `--parity`.
def level-frame [bright: bool, held: bool, cap: int, --parity]: nothing -> binary {
    let flag = {|on: bool| if $on { 0x[01] } else { 0x[00] } }
    [("L" | into binary), 0x[00 00 00], (do $flag $bright), (do $flag $held), ($cap | into binary | bytes at 0..<1), (do $flag $parity), (0..<56 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# The console's K frame, a debug build's: the commands and the spans a
# packet holds, 0 for the engine's own bounds, and the binds each frame
# before the tile arena is reset, 0 for none, each a word from byte 4.
def packet-frame [commands: int, spans: int, reset: int]: nothing -> binary {
    let word = {|v: int| $v | into binary | bytes at 0..<4 }
    [("K" | into binary), 0x[00 00 00], (do $word $commands), (do $word $spans), (do $word $reset), (0..<48 | each {|i| 0x[00] } | bytes collect)] | bytes collect
}

# Where a capture's pixels come from over a rectangle, [x0, y0, x1, y1]
# with the pixel past the last, given two pictures of the same view: the
# pixels, those equal to the first's alone where the two differ, to the
# second's alone, to neither, and among those the poison's.
def pixels-from [c: binary, a: binary, b: binary, rect: list<int>]: nothing -> record<pixels: int, first: int, second: int, neither: int, poisoned: int> {
    let hc = (ppm-head $c)
    let ha = (ppm-head $a)
    let hb = (ppm-head $b)
    let rows = ($rect.1..<$rect.3 | each {|y|
        let from = ((($y * 1920) + $rect.0) * 3)
        let to = ((($y * 1920) + $rect.2) * 3)
        let rc = ($c | bytes at ($hc + $from)..<($hc + $to))
        let ra = ($a | bytes at ($ha + $from)..<($ha + $to))
        let rb = ($b | bytes at ($hb + $from)..<($hb + $to))
        if $rc == $ra and $rc == $rb { { first: 0, second: 0, neither: 0, poisoned: 0 } } else {
            let px = ($rc | chunks 3 | zip ($ra | chunks 3) | zip ($rb | chunks 3) | each {|t| { c: $t.0.0, a: $t.0.1, b: $t.1 } } | where {|t| $t.a != $t.b or $t.c != $t.a })
            let neither = ($px | where {|t| $t.c != $t.a and $t.c != $t.b })
            {
                first: ($px | where {|t| $t.c == $t.a and $t.c != $t.b } | length),
                second: ($px | where {|t| $t.c == $t.b and $t.c != $t.a } | length),
                neither: ($neither | length),
                poisoned: ($neither | where {|t| $t.c == $TILE_POISON } | length),
            }
        }
    })
    {
        pixels: (($rect.2 - $rect.0) * ($rect.3 - $rect.1)),
        first: ($rows | get first | math sum), second: ($rows | get second | math sum),
        neither: ($rows | get neither | math sum), poisoned: ($rows | get poisoned | math sum),
    }
}

# How two captures differ over a rectangle, [x0, y0, x1, y1] with the
# pixel past the last: its pixels, the pixels whose colours differ, and
# the largest difference in any channel, of 255.
def region-delta [p: binary, q: binary, rect: list<int>]: nothing -> record<pixels: int, differing: int, largest: int> {
    let hp = (ppm-head $p)
    let hq = (ppm-head $q)
    let y0 = $rect.1
    let y1 = $rect.3
    let rows = ($y0..<$y1 | each {|y|
        let from = ((($y * 1920) + $rect.0) * 3)
        let to = ((($y * 1920) + $rect.2) * 3)
        let a = ($p | bytes at ($hp + $from)..<($hp + $to))
        let b = ($q | bytes at ($hq + $from)..<($hq + $to))
        if $a == $b { { differing: 0, largest: 0 } } else {
            let deltas = ($a | chunks 3 | zip ($b | chunks 3) | where {|c| $c.0 != $c.1 } | each {|c|
                let u = ($c.0 | into int --endian little)
                let v = ($c.1 | into int --endian little)
                [((($u bit-and 255) - ($v bit-and 255)) | math abs) (((($u bit-shr 8) bit-and 255) - (($v bit-shr 8) bit-and 255)) | math abs) ((($u bit-shr 16) - ($v bit-shr 16)) | math abs)] | math max
            })
            { differing: ($deltas | length), largest: (if ($deltas | is-empty) { 0 } else { $deltas | math max }) }
        }
    })
    let pixels = (($rect.2 - $rect.0) * ($rect.3 - $rect.1))
    if ($rows | is-empty) { return { pixels: $pixels, differing: 0, largest: 0 } }
    { pixels: $pixels, differing: ($rows | get differing | math sum), largest: ($rows | get largest | math max) }
}

# The chains' line among a run's: the materials with a level past 0, the
# levels built, the texels, and the time; a tree with textures builds
# chains, at least a level a chain.
def mips-built [lines: list<string>]: nothing -> record<chains: int, levels: int, texels: int, ms: int> {
    let line = ($lines | where {|l| $l starts-with "fps: mips " })
    assert equal ($line | length) 1 $"one mips line: ($line)"
    let got = ($line | get 0 | parse $MIPS_LINE | get 0 | update cells {|v| $v | into int })
    assert ($got.chains >= 1) $"chains built: ($line | get 0)"
    assert ($got.levels >= $got.chains) $"a level a chain at least: ($line | get 0)"
    assert ($got.texels > 0) $"texels built: ($line | get 0)"
    $got
}

# The alpha policy as the engine applies it at load, over a texture's
# alphas in row order: the share of texels at or above the pass at level
# 0 in 10000ths, the target; then each coarser level of the chain, its
# alphas as the integer means of the two by two under them in the level
# before, the threshold whose share at or above it lies nearest the
# target (the least error, a tie to the lower share, equal shares to the
# threshold nearest the pass), the level's scale ceil(2^23 / T), and the
# level scaled by it and capped at 255 for the level after; whether the
# engine names a line for the texture, which it does under full coverage
# at level 0 for a chain with a level past 0 whose level 1 fits the
# search's scratch; and the planes by level, level 0 the alphas given and
# each coarser level's scaled alphas in row order at half the width,
# which the tiles and the chain hold.
export def alpha-levels [alphas: list<int>, w: int, h: int]: nothing -> record<line: bool, coverage: list<int>, scale: list<int>, planes: list<list<int>>> {
    let n0 = ($w * $h)
    let levels = (chain-levels $w $h)
    let c0 = ($alphas | where {|a| $a >= $ALPHA_PASS } | length)
    if $levels <= 1 or ($n0 // 4) > $ALPHA_PLANE_BYTES or $c0 == $n0 { return { line: false, coverage: [], scale: [], planes: [] } }
    mut coverage = [(($c0 * 10000) // $n0)]
    mut scale = []
    mut planes = [$alphas]
    mut plane = $alphas
    mut pw = $w
    mut ph = $h
    for level in 1..<$levels {
        let sw = $pw
        let lw = ($pw // 2)
        let lh = ($ph // 2)
        let src = $plane
        let means = (0..<$lh | each {|y| 0..<$lw | each {|x|
            let i = (2 * $y * $sw + 2 * $x)
            (($src | get $i) + ($src | get ($i + 1)) + ($src | get ($i + $sw)) + ($src | get ($i + $sw + 1))) // 4
        } } | flatten)
        let nl = ($lw * $lh)
        if $c0 == 0 {
            $coverage = ($coverage | append 0)
            $scale = ($scale | append 65536)
            $plane = $means
            $planes = ($planes | append [$means])
            $pw = $lw
            $ph = $lh
            continue
        }
        let hist = ($means | reduce --fold (0..255 | each {|i| 0 }) {|v, acc| $acc | update $v {|n| $n + 1 } })
        mut best: any = null
        mut cov = 0
        for t in 256..1 {
            if $t <= 255 { $cov = ($cov + ($hist | get $t)) }
            let err = ((($cov * $n0) - ($c0 * $nl)) | math abs)
            let dist = (($t - $ALPHA_PASS) | math abs)
            let take = (if $best == null { true } else if $err < $best.err { true } else if $err == $best.err and $cov == $best.cov and $dist < $best.dist { true } else { false })
            if $take { $best = { err: $err, t: $t, cov: $cov, dist: $dist } }
        }
        let s = ((8388608 + $best.t - 1) // $best.t)
        $plane = ($means | each {|v| [(($v * $s) bit-shr 16), 255] | math min })
        $planes = ($planes | append [$plane])
        $pw = $lw
        $ph = $lh
        $coverage = ($coverage | append (($best.cov * 10000) // $nl))
        $scale = ($scale | append $s)
    }
    { line: true, coverage: $coverage, scale: $scale, planes: $planes }
}

# A row of the alpha fixture: its pixels as the PNG carries them, each
# texel the colour and the alpha its patch's kind gives its parity on
# each axis in the kind's 2 by 2, and the row's alphas alone.
export def fixture-row [y: int]: nothing -> record<bytes: binary, alphas: list<int>> {
    let kinds = ($FIXTURE_GRID | get ($y // $ALPHA_FIXTURE.patch))
    let parity = (($y mod 2) * 2)
    let half = ($ALPHA_FIXTURE.patch // 2)
    let cells = ($kinds | each {|kind|
        let k = ($FIXTURE_KINDS | get $kind)
        let even = ($k.alphas | get $parity)
        let odd = ($k.alphas | get ($parity + 1))
        let pair = ([($k.colours | get $parity), ($even | into binary | bytes at 0..<1), ($k.colours | get ($parity + 1)), ($odd | into binary | bytes at 0..<1)] | bytes collect)
        { bytes: (0..<$half | each {|i| $pair } | bytes collect), alphas: (0..<$half | each {|i| [$even, $odd] } | flatten) }
    })
    { bytes: ($cells | get bytes | bytes collect), alphas: ($cells | get alphas | flatten) }
}

# A copy of Render One compiled with its grate wall given a material
# of the test's own at a scale, the alcove's floor, ceiling, and walls
# given the backdrop's, its android dropped, and the backdrop laid in the
# tree after the compile, which names it unresolved; the tree's path.
def fixture-tree [source: record, game: path, out: path, material: string, scale: float]: nothing -> string {
    let north = ($source.sectors | enumerate | where {|s| $s.item.name == "north" } | get 0.index)
    let sector = ($source.sectors | get $north)
    let grate = ($sector.walls | enumerate | where {|w| $w.item.material == "grate" } | get 0.index)
    let stem = ($material | path basename)
    let walls = ($sector.walls | update $grate {|w| $w | update material $stem | update scale [$scale, $scale] | update offset [0.0, 0.0] })
    let alcove = ($source.sectors | enumerate | where {|s| $s.item.name == "alcove" } | get 0.index)
    let back = ($FIXTURE_BACKDROP.name | path basename)
    let solid = ($source.sectors | get $alcove | update floor.material $back | update ceiling.material $back | update wall.material $back)
    let fixed = ($source | update sectors ($source.sectors | update $north ($sector | update walls $walls) | update $alcove $solid))
    let tree = (variant-tree $fixed $FIXTURE_MAP [android] $out $game)
    let backdrop = ($tree | path join (map tile-path $FIXTURE_BACKDROP.name | str substring 1..))
    mkdir ($backdrop | path dirname)
    let texel = ([$FIXTURE_BACKDROP.colour, 0x[ff]] | bytes collect)
    png write-rgba $backdrop $FIXTURE_BACKDROP.size $FIXTURE_BACKDROP.size (0..<($FIXTURE_BACKDROP.size * $FIXTURE_BACKDROP.size) | each {|i| $texel } | bytes collect)
    $tree
}

# The alpha fixture's tree: the grate wall given the fixture's texture
# at its scale, the texture laid in; the tree's path.
def alpha-tree [source: record, game: path, out: path]: nothing -> string {
    let tree = (fixture-tree $source $game $out $ALPHA_FIXTURE.name $ALPHA_FIXTURE.scale)
    let file = ($tree | path join (map tile-path $ALPHA_FIXTURE.name | str substring 1..))
    mkdir ($file | path dirname)
    let pixels = (0..<$ALPHA_FIXTURE.h | each {|y| (fixture-row $y).bytes } | bytes collect)
    png write-rgba $file $ALPHA_FIXTURE.w $ALPHA_FIXTURE.h $pixels
    $tree
}

# The texel-centre fixture's tree: the grate wall given an opaque white
# texture of CENTRE_FIXTURE's size at its scale, laid in; the tree's
# path.
def centre-tree [source: record, game: path, out: path]: nothing -> string {
    let tree = (fixture-tree $source $game $out $CENTRE_FIXTURE.name $CENTRE_FIXTURE.scale)
    let file = ($tree | path join (map tile-path $CENTRE_FIXTURE.name | str substring 1..))
    mkdir ($file | path dirname)
    png write-rgba $file $CENTRE_FIXTURE.size $CENTRE_FIXTURE.size (0..<($CENTRE_FIXTURE.size * $CENTRE_FIXTURE.size) | each {|i| 0x[ff ff ff ff] } | bytes collect)
    $tree
}

# The growth map's source: eight rectangular sectors, the camera's room
# C with a narrow high window W into the hall S and a door E into the
# side room T, T's wide door G into S, and S's door H into the far room
# D, every surface the panel but D's, which are the backdrop; a spawn in
# C and no lights, so every texel reads exactly.
def grow-source []: nothing -> record {
    let room = {|name: string, loop: list<list<float>>, floor: float, ceiling: float, material: string|
        {
            name: $name, storey: "lower", tag: 0, ambient: "",
            floor: { height: $floor, slope: [0.0, 0.0], material: $material, scale: [0.5, 0.5], offset: [0.0, 0.0], sky: false },
            ceiling: { height: $ceiling, slope: [0.0, 0.0], material: $material, scale: [0.5, 0.5], offset: [0.0, 0.0], sky: false },
            wall: { material: $material, scale: [0.5, 0.5], offset: [0.0, 0.0], anchor: "top", solid: false, masked: false, sky: false, tag: 0 },
            loops: [$loop], walls: [],
        }
    }
    let back = ($FIXTURE_BACKDROP.name | path basename)
    {
        name: $GROW_MAP,
        sectors: [
            (do $room "C" [[0.0, 0.0], [4.0, 0.0], [4.0, 1.0], [4.0, 3.0], [4.0, 4.0], [2.5, 4.0], [1.5, 4.0], [0.0, 4.0]] 0.0 3.0 "panel"),
            (do $room "W" [[1.5, 4.0], [2.5, 4.0], [2.5, 4.5], [1.5, 4.5]] 1.2 2.2 "panel"),
            (do $room "E" [[4.0, 1.0], [4.5, 1.0], [4.5, 3.0], [4.0, 3.0]] 0.0 2.5 "panel"),
            (do $room "T" [[4.5, 0.0], [8.5, 0.0], [8.5, 4.0], [8.0, 4.0], [4.75, 4.0], [4.5, 4.0], [4.5, 3.0], [4.5, 1.0]] 0.0 3.0 "panel"),
            (do $room "G" [[4.75, 4.0], [8.0, 4.0], [8.0, 4.5], [4.75, 4.5]] 0.0 2.5 "panel"),
            (do $room "S" [[0.0, 4.5], [1.5, 4.5], [2.5, 4.5], [4.75, 4.5], [8.0, 4.5], [8.0, 8.5], [7.5, 8.5], [5.5, 8.5], [0.0, 8.5]] 0.0 3.0 "panel"),
            (do $room "H" [[5.5, 8.5], [7.5, 8.5], [7.5, 9.0], [5.5, 9.0]] 0.0 2.5 "panel"),
            (do $room $GROW_FAR [[5.0, 9.0], [5.5, 9.0], [7.5, 9.0], [9.0, 9.0], [9.0, 13.0], [5.0, 13.0]] 0.0 3.0 $back),
        ],
        entities: [
            { name: "spawn", class: "spawn", at: [2.0, 2.0, 0.0], yaw: 0.0, pitch: 0.0, size: [0.0, 0.0], material: "", colour: [0.0, 0.0, 0.0], radius: 0.0, spread: 0.0, facing: "fixed", two_sided: false, solid: false, tag: 0, target: "" },
        ],
    }
}

# The growth map compiled under out with the game's content and the
# backdrop texture laid in after the compile, which names it
# unresolved; the tree's path.
def grow-tree [game: path, out: path]: nothing -> string {
    let tree = (variant-tree (grow-source) $GROW_MAP [] $out $game)
    let backdrop = ($tree | path join (map tile-path $FIXTURE_BACKDROP.name | str substring 1..))
    mkdir ($backdrop | path dirname)
    let texel = ([$FIXTURE_BACKDROP.colour, 0x[ff]] | bytes collect)
    png write-rgba $backdrop $FIXTURE_BACKDROP.size $FIXTURE_BACKDROP.size (0..<($FIXTURE_BACKDROP.size * $FIXTURE_BACKDROP.size) | each {|i| $texel } | bytes collect)
    $tree
}

# The colour the tile shrink gives a coarser texel from the four under
# it, as the engine computes it: alike alphas take the plain mean of
# each channel; otherwise each channel's sum weighted by the alphas,
# times the truncated reciprocal of their sum in 8.24, a half added and
# the product shifted down, so a transparent texel's colour counts for
# nothing and an exact mean survives.
export def shrink-colour [texels: list<record<colour: binary, alpha: int>>]: nothing -> binary {
    let alphas = ($texels | get alpha)
    let channels = (0..<3 | each {|c| $texels | each {|t| $t.colour | bytes at $c..<($c + 1) | into int } })
    let means = (if ($alphas | uniq | length) == 1 {
        $channels | each {|vs| ($vs | math sum) // 4 }
    } else {
        let recip = (16777216 // ($alphas | math sum))
        $channels | each {|vs|
            let weighted = ($vs | zip $alphas | each {|p| $p.0 * $p.1 } | math sum)
            (($weighted * $recip) + 8388608) // 16777216
        }
    })
    $means | each {|v| $v | into binary | bytes at 0..<1 } | bytes collect
}

# The fixture's samples: the centre texel of every patch in each repeat
# of the texture over the wall, the world point it maps to along the
# wall from its first vertex and down from its anchor by the surface's
# scales and offsets, its colour by level, the texel's own at level 0
# and the shrink's at every coarser one, which the alike path then
# carries unchanged, and whether its patch passes at each level by the
# oracle's plane for the level; a kind is uniform when its 2 by 2 holds
# one alpha and one colour, so its level 0 reading does not hang on
# which texel a pixel lands on.
def fixture-samples [wall: record, a: record, e: list<float>, levels: record]: nothing -> table<kind: string, colours: list<binary>, uniform: bool, point: list<float>, pass: list<bool>> {
    let patch = $ALPHA_FIXTURE.patch
    $FIXTURE_REPEATS | each {|rep|
        0..<($ALPHA_FIXTURE.h // $patch) | each {|j|
            0..<($ALPHA_FIXTURE.w // $patch) | each {|i|
                let kind = ($FIXTURE_GRID | get $j | get $i)
                let k = ($FIXTURE_KINDS | get $kind)
                let coarse = (shrink-colour (0..<4 | each {|t| { colour: ($k.colours | get $t), alpha: ($k.alphas | get $t) } }))
                let u = (($i * $patch) + ($patch // 2))
                let v = (($j * $patch) + ($patch // 2))
                let along = ((((($rep.0 * $ALPHA_FIXTURE.w) + $u) + 0.5) / $ALPHA_FIXTURE.w - $wall.surface.u_offset) / $wall.surface.u_scale)
                let down = ((((($rep.1 * $ALPHA_FIXTURE.h) + $v) + 0.5) / $ALPHA_FIXTURE.h - $wall.surface.v_offset) / $wall.surface.v_scale)
                {
                    kind: $kind, colours: [($k.colours | get 0), $coarse, $coarse, $coarse],
                    uniform: ((($k.alphas | uniq | length) == 1) and (($k.colours | each {|c| $c | encode hex } | uniq | length) == 1)),
                    point: [($a.x + $e.0 * $along), ($a.y + $e.1 * $along), ($wall.anchor - $down)],
                    pass: (0..3 | each {|l| ($levels.planes | get $l | get ((($v bit-shr $l) * ($ALPHA_FIXTURE.w bit-shr $l)) + ($u bit-shr $l))) >= $ALPHA_PASS }),
                }
            }
        } | flatten
    } | flatten
}

# The fixture's samples read from a capture: each one's pixel from the
# eye at yaw 0, clear of the crosshair, its colour at the level, and
# whether its patch shows there.
def fixture-read [bytes: binary, eye: record, samples: table<kind: string, colours: list<binary>, uniform: bool, point: list<float>, pass: list<bool>>, level: int]: nothing -> table<kind: string, colour: binary, uniform: bool, at: list<int>, pixel: binary, shows: bool> {
    let head = (ppm-head $bytes)
    $samples | each {|s|
        let at = (project $eye 0 $s.point)
        assert ($at != null) $"the ($s.kind) patch at ($s.point) is on screen from ($eye)"
        assert (((($at.0 - 960) ** 2) + (($at.1 - 540) ** 2)) > ($FIXTURE_CROSSHAIR * $FIXTURE_CROSSHAIR)) $"the ($s.kind) patch at ($at) lies clear of the crosshair's disc"
        { kind: $s.kind, colour: ($s.colours | get $level), uniform: $s.uniform, at: $at, pixel: (pixel-at $bytes $head $at), shows: ($s.pass | get $level) }
    }
}

# The screen rectangle of the fixture wall's opening from an eye facing
# it at yaw 0, [x0, y0, x1, y1] with the pixel past the last, inset by
# FIXTURE_INSET and clamped to the screen: the wall's two vertices at
# the ceiling and the floor of the sector across its portal, projected.
def fixture-opening [m: record, wall: record, eye: record]: nothing -> list<int> {
    let across = ($m.sectors | get ($m.portals | get $wall.first_portal | get sector))
    let corners = ([($m.vertices | get $wall.a), ($m.vertices | get $wall.b)] | each {|p|
        [(map plane-z $across.ceiling $p.x $p.y), (map plane-z $across.floor $p.x $p.y)] | each {|z|
            let depth = ($p.x - $eye.x)
            { x: (960 + (($eye.y - $p.y) / $depth) * 960), y: (540 - (($z - $eye.z) / $depth) * 960) }
        }
    } | flatten)
    let x0 = ((($corners | get x | math min) | math ceil | into int) + $FIXTURE_INSET)
    let x1 = ((($corners | get x | math max) | math floor | into int) - $FIXTURE_INSET)
    let top = ((($corners | get y | math min) | math ceil | into int) + $FIXTURE_INSET)
    let bottom = ((($corners | get y | math max) | math floor | into int) - $FIXTURE_INSET)
    let y0 = ([$top, 0] | math max)
    let y1 = ([$bottom, 1080] | math min)
    [$x0, $y0, $x1, $y1]
}

# The rows of a rectangle over which two captures differ, each row's
# bytes within the rectangle compared whole.
def rows-differ [p: binary, q: binary, rect: list<int>]: nothing -> list<int> {
    let hp = (ppm-head $p)
    let hq = (ppm-head $q)
    let y0 = $rect.1
    let y1 = $rect.3
    $y0..<$y1 | each {|y|
        let from = ((($y * 1920) + $rect.0) * 3)
        let to = ((($y * 1920) + $rect.2) * 3)
        if ($p | bytes at ($hp + $from)..<($hp + $to)) == ($q | bytes at ($hq + $from)..<($hq + $to)) { null } else { $y }
    } | compact
}

# The texel-centre fixture's samples: the four texels touching each node
# of the wall's lumel map whose centres, with the pixels about them,
# project inside the opening and clear of the crosshair, the map laid as
# lumap_frame lays it, its origin a whole repeat at least a texel before
# the wall's least u and its sector's top's v, a node a cell apart; each
# texel with the node's parity, its light the cell's four nodes bilinear
# at the texel's centre by the console's parity rule times 255, the
# colour a white texel lit there takes, and the same at its corner, the
# reading of the rule the centre replaced.
def centre-samples [m: record, wall: record, eye: record, opening: list<int>]: nothing -> table<node: list<int>, parity: int, texel: list<int>, at: list<int>, expected: float, corner: float> {
    let size = $CENTRE_FIXTURE.size
    let s = $wall.surface
    assert equal ($size * $s.u_scale / 2) ($size * 1.0) $"a lumel cell is one repeat: ($size * $s.u_scale / 2) texels in half a metre against ($size)"
    let a = ($m.vertices | get $wall.a)
    let b = ($m.vertices | get $wall.b)
    let len = ((($b.x - $a.x) ** 2 + ($b.y - $a.y) ** 2) | math sqrt)
    let e = [(($b.x - $a.x) / $len), (($b.y - $a.y) / $len)]
    let sector = ($m.sectors | get $wall.sector)
    let top = ([(map plane-z $sector.ceiling $a.x $a.y), (map plane-z $sector.ceiling $b.x $b.y)] | math max)
    let bottom = ([(map plane-z $sector.floor $a.x $a.y), (map plane-z $sector.floor $b.x $b.y)] | math min)
    let us = [($s.u_offset * $size), ((($s.u_scale * $len) + $s.u_offset) * $size)]
    let vs = [(((($wall.anchor - $top) * $s.v_scale) + $s.v_offset) * $size), (((($wall.anchor - $bottom) * $s.v_scale) + $s.v_offset) * $size)]
    let u0 = (((($us | math min | math floor | into int) - 1) // $size) * $size)
    let v0 = (((($vs | math min | math floor | into int) - 1) // $size) * $size)
    let cols = (((($us | math max | math ceil | into int) - $u0) // $size) + 2)
    let rows = (((($vs | math max | math ceil | into int) - $v0) // $size) + 2)
    assert ($cols >= 3 and $rows >= 3) $"the wall's map has a node inside it: ($cols) columns, ($rows) rows"
    let light = {|c: int, r: int| $CENTRE_LIGHTS | get (($c + $r) mod 2) }
    let lit = {|c: int, r: int, fx: float, fy: float|
        let upper = (((do $light $c $r) * (1.0 - $fx)) + ((do $light ($c + 1) $r) * $fx))
        let lower = (((do $light $c ($r + 1)) * (1.0 - $fx)) + ((do $light ($c + 1) ($r + 1)) * $fx))
        ($upper * (1.0 - $fy)) + ($lower * $fy)
    }
    let f = $CENTRE_FOOTPRINT
    let clear = ($FIXTURE_CROSSHAIR + (2 * $f))
    1..<($cols - 1) | each {|c|
        1..<($rows - 1) | each {|r|
            [[-1, -1], [0, -1], [-1, 0], [0, 0]] | each {|d|
                let tu = ($u0 + ($c * $size) + $d.0)
                let tv = ($v0 + ($r * $size) + $d.1)
                let along = (((($tu + 0.5) / $size) - $s.u_offset) / $s.u_scale)
                let down = (((($tv + 0.5) / $size) - $s.v_offset) / $s.v_scale)
                let at = (project $eye 0 [($a.x + ($e.0 * $along)), ($a.y + ($e.1 * $along)), ($wall.anchor - $down)])
                let inside = ($at != null and ($at.0 - $f) >= $opening.0 and ($at.0 + $f) < $opening.2 and ($at.1 - $f) >= $opening.1 and ($at.1 + $f) < $opening.3)
                if not $inside or (((($at.0 - 960) ** 2) + (($at.1 - 540) ** 2)) <= ($clear * $clear)) { null } else {
                    let cc = (($tu - $u0) // $size)
                    let cr = (($tv - $v0) // $size)
                    let iu = (($tu - $u0) mod $size)
                    let iv = (($tv - $v0) mod $size)
                    {
                        node: [$c, $r], parity: (($c + $r) mod 2), texel: [$tu, $tv], at: $at,
                        expected: (255.0 * (do $lit $cc $cr (($iu + 0.5) / $size) (($iv + 0.5) / $size))),
                        corner: (255.0 * (do $lit $cc $cr ($iu / $size) ($iv / $size))),
                    }
                }
            }
        } | flatten
    } | flatten | compact
}

# The texel-centre samples read from a capture: each one's pixel at its
# centre, the most any of its channels lies from the colour expected, and
# whether the pixels CENTRE_FOOTPRINT about its centre each way are all
# that one colour.
def centre-read [bytes: binary, samples: table<node: list<int>, parity: int, texel: list<int>, at: list<int>, expected: float, corner: float>]: nothing -> table<node: list<int>, light: float, texel: list<int>, at: list<int>, expected: float, corner: float, pixel: binary, off: float, uniform: bool> {
    let head = (ppm-head $bytes)
    let f = $CENTRE_FOOTPRINT
    let width = ((2 * $f) + 1)
    $samples | each {|s|
        let pixel = (pixel-at $bytes $head $s.at)
        let off = (0..<3 | each {|c| (($pixel | bytes at $c..<($c + 1) | into int) - $s.expected) | math abs } | math max)
        let run = (0..<$width | each {|i| $pixel } | bytes collect)
        let uniform = ((-1 * $f)..$f | each {|dy|
            let o = ($head + (((($s.at.1 + $dy) * 1920) + ($s.at.0 - $f)) * 3))
            ($bytes | bytes at $o..<($o + ($width * 3))) == $run
        } | all {|same| $same })
        { node: $s.node, light: ($CENTRE_LIGHTS | get $s.parity), texel: $s.texel, at: $s.at, expected: $s.expected, corner: $s.corner, pixel: $pixel, off: $off, uniform: $uniform }
    }
}

# The level of a run's recording between two seconds: the peak and the
# mean of the left channel's samples' magnitudes, every 97th frame.
def sound-level [wav: path, from: float, to: float]: nothing -> record<from: float, to: float, peak: int, mean: float> {
    let w = (jab wave $wav)
    let frame_bytes = ($w.channels * ($w.bits // 8))
    let a = (($from * $w.rate) | math round | into int)
    let b = ([(($to * $w.rate) | math round | into int), $w.frames] | math min)
    assert ($b > ($a + 97)) $"the recording reaches ($to) s: ($w.frames) frames at ($w.rate)"
    let picks = (seq $a 97 ($b - 1) | each {|f|
        $w.samples | bytes at ($f * $frame_bytes)..<($f * $frame_bytes + 2) | into int --endian little --signed | math abs
    })
    { from: $from, to: $to, peak: ($picks | math max), mean: ($picks | math avg) }
}

# The mean of the channels over a block of a capture, [x, y, w, h],
# every fourth pixel of every fourth row.
def mean-brightness [ppm: path, block: list<int>]: nothing -> float {
    let bytes = (open --raw $ppm | into binary)
    let newlines = ($bytes | bytes index-of --all 0x[0a] | take 3)
    let head_len = ($newlines.2 + 1)
    let sums = (0..<($block.3 // 4) | each {|r|
        let y = ($block.1 + $r * 4)
        let row = ($bytes | bytes at ($head_len + ($y * 1920 + $block.0) * 3)..<($head_len + ($y * 1920 + $block.0 + $block.2) * 3))
        0..<($block.2 // 4) | each {|c| $row | bytes at ($c * 12)..<($c * 12 + 3) | encode hex | split chars | chunks 2 | each {|h| $h | str join "" | into int --radix 16 } | math sum } | math sum
    } | math sum)
    $sums / (($block.2 // 4) * ($block.3 // 4) * 3)
}

# A pixel of a capture as its three bytes.
def pixel [ppm: path, at: list<int>]: nothing -> binary {
    let bytes = (open --raw $ppm | into binary)
    pixel-at $bytes (ppm-head $bytes) $at
}

# The bytes of a capture's header, the three lines before its pixels.
def ppm-head [bytes: binary]: nothing -> int {
    let newlines = ($bytes | bytes index-of --all 0x[0a] | take 3)
    $newlines.2 + 1
}

# A pixel of a capture held whole, as its three bytes.
def pixel-at [bytes: binary, head: int, at: list<int>]: nothing -> binary {
    let o = ($head + (($at.1 * 1920) + $at.0) * 3)
    $bytes | bytes at $o..<($o + 3)
}

# The plan views of a compiled tree held to the source: an SVG a
# storey, each at the storey's bounds with the compiler's margin and
# scale.
def plan-views [tree: path, source: record, read: record]: nothing -> nothing {
    for storey in ($source.sectors | get storey | uniq) {
        let svg = ($tree | path join "plan" $"($storey).svg")
        assert ($svg | path exists) $"a plan view of the ($storey) storey"
        let members = ($source.sectors | enumerate | where {|s| $s.item.storey == $storey } | each {|s| $read.sectors | get $s.index | get bounds })
        let width = ((($members | get max_x | math max) - ($members | get min_x | math min) + 2.0) * 24)
        let height = ((($members | get max_y | math max) - ($members | get min_y | math min) + 2.0) * 24)
        let head = (open --raw $svg | decode | lines | get 0 | parse --regex 'width="(?P<w>[0-9.]+)" height="(?P<h>[0-9.]+)"' | get 0)
        assert (((($head.w | into float) - $width) | math abs) < 0.001 and ((($head.h | into float) - $height) | math abs) < 0.001) $"the ($storey) plan view at the storey's bounds: ($head) against ($width) by ($height)"
    }
}

# A tree holding a map of the given bytes under the given name; its
# path.
def broken [tree: path, name: string, bytes: binary]: nothing -> string {
    jab retire $tree
    mkdir ($tree | path join "map")
    $name | save --raw -f ($tree | path join "map" "name")
    $bytes | save --raw -f ($tree | path join "map" $"($name).jabfps.map")
    $tree
}

# The gauge's rules over synthetic captures (gauge.nu's stream, measure,
# legs-for, and compare), each built as the program sends one and then
# broken the way a wrong reading would accept: a frame record sent after
# the end marker fills no gap before it; a second marker past the window
# changes nothing; a marker at another schema refuses the window; a flip
# never shown, a phase or a part past its whole, and a clock disagreeing
# with its state each make a complete window invalid, while a flip
# refused as early does not; a frame at the ceiling fails a valid window;
# a seed answered after the first state is late; a frame record, a draw
# record, or a marker alone among the states makes a capture clocked and
# incomplete, where states alone are clockless; a route the identity did
# not record is refused, kept or given, and a capture with no route is
# one leg, play; a comparison refuses a run measured incomplete, invalid,
# or unchecked, naming its file, its run, and the reasons, and admits it
# marked under --diagnostic; it refuses under --diagnostic too an empty
# run, whatever frame count its measurement records, an unclassified one,
# and an unusable one, a field whose values are null though its name is
# the states', and a clock field on a clockless run; it names every run
# it refuses; it refuses a clockless run as unpaired and admits it marked
# under --diagnostic; and it refuses a run missing a leg another run
# holds, one batch of a build or a whole build, naming the run and its
# missing legs, and under --diagnostic keeps that build's row for the leg
# with the batches missing it and no value, the build's other legs valued
# as before. At schema 2: a frame without its presentation record and a
# capture of mixed schemas are incomplete; under cadence 1 a wait apart
# from the critical path balances and a critical path holding it does
# not; a flip refused as early is valid under cadence 0 and invalid under
# 1; under cadence 0 a wait and a second attempt are invalid; attempts
# past the refusals and the final one, a cadence outside 0 to 2, and a
# next start apart from the next frame's start are invalid; a one-frame
# capture closes through its next start alone, and one whose next start
# does not close is invalid; a simulation before its frame's start, one
# past its flip's end, and a flip's end past its next start are each out
# of order and invalid for that alone. A comparison refuses as unpaired a
# run whose seed or cadence went unanswered, came late, or came early and
# again late, whose identity asks a cadence outside 0 to 2 or none, with
# a frame at another cadence than asked, or below schema 2 whose identity
# asks a cadence other than 0, each named with its reason and admitted
# marked under --diagnostic; it refuses two cadences under one name and
# one build under two names, keeps one image's two cadences apart as two
# builds, and takes one image's schema 1 captures asking none and 0 as
# one build at cadence 0, each comparison it must make wrapped and held
# to no refusal. At schema 3: the packet record read at its offsets; a
# frame without it, or one at another schema, leaves the window
# incomplete; packet records alone among the states are clocked and
# incomplete; a drawing a microsecond past its preparation and raster is
# valid, and two past, or less than they, invalid; a raster past what the
# drawing's other parts leave, packet bytes other than the commands' and
# span records', and packets prepared from another frame's simulation are
# each invalid for that alone; and one image's captures at cadences 0 and
# 1 compare as two builds. The drawing's moved parts: schema 1 against
# schema 3 refused on planes_us with or without --diagnostic and compared
# on draw_us, critical_us, and parts_unattributed_us; an unlisted schema
# 2 run, dirty or without its program's source, refused on planes_us and
# compared on draw_us; f59f7a7's commit on an unlisted image refused; its
# listed image under another clean commit, dirty, and with no commit
# compared with schema 3 on planes_us, its remainder refused; two runs of
# one class compared. A run on a diagnostic machine is refused as
# diagnostic and admitted marked under --diagnostic; runs on two machines
# refuse the comparison, and under --diagnostic each build's row names its
# machine; one name's runs on two machines are two builds; a run whose
# identity carries QEMU words of its launch's own is refused as
# diagnostic, its machine the one the launch marked or the one asked
# for, the reason naming the words and no hart count; and a bench
# pools the specification's machine's run alone, keeps the diagnostic
# machine's apart, and names every step's machine in its report.
export def gauge-rules [dir: path]: nothing -> nothing {
    let legs = [{ name: "walk", places: [], pad: [] }]
    let measure = {|items: list<any>| gauge measure (fx-bytes $items) $legs }
    let good = (fx-items 3)
    let m = (do $measure $good)
    assert ($m.complete and $m.valid and $m.passes and $m.seeded) $"a well-formed capture: ($m.problems) ($m.invalid)"
    assert equal [$m.final $m.frames $m.past_window] [2 3 2] "the marker names frame 2: three frames in the window, two past it"

    let sent_late = ($good | where {|i| not ($i.kind == "frame" and $i.frame == 1) } | append (fx-frame 1))
    assert (not (do $measure $sent_late).complete) "a frame record sent after the marker fills no gap before it"
    let twice = ($good | append { kind: "end", frame: 4, schema: 1 })
    let mt = (do $measure $twice)
    assert ($mt.complete and $mt.valid and $mt.final == 2) $"a second marker past the window changes nothing: ($mt.problems)"
    let schema = ($good | each {|i| if $i.kind == "end" { $i | update schema 2 } else { $i } })
    assert (not (do $measure $schema).complete) "a marker at another schema refuses the window"

    for s in [[0 true] [1 true] [2 false] [3 false] [7 false]] {
        let flipped = ($good | each {|i| if $i.kind == "frame" and $i.frame == 1 { $i | update status $s.0 } else { $i } })
        let mf = (do $measure $flipped)
        assert ($mf.complete and $mf.valid == $s.1) $"a flip at status ($s.0), valid ($s.1): ($mf.invalid)"
        assert ($s.1 or ($mf.invalid | any {|r| $r =~ "never shown" })) $"a flip at status ($s.0) named: ($mf.invalid)"
    }
    let short = ($good | each {|i| if $i.kind == "frame" and $i.frame == 0 { $i | update critical 1000 } else { $i } })
    let ms = (do $measure $short)
    assert ((not $ms.valid) and ($ms.invalid | any {|r| $r =~ "past their whole" })) $"phases past the critical path: ($ms.invalid)"
    let parts = ($good | each {|i|
        if $i.kind == "frame" and $i.frame == 0 { $i | update draw 900 } else if $i.kind == "state" and ($i.frame? == 0) { $i | insert draw 900 } else { $i }
    })
    let mp = (do $measure $parts)
    assert ((not $mp.valid) and ($mp.invalid | any {|r| $r =~ "past their whole" }) and (not ($mp.invalid | any {|r| $r =~ "differs" }))) $"parts past the drawing: ($mp.invalid)"
    let misaligned = ($good | each {|i| if $i.kind == "state" and ($i.frame? == 2) { $i | insert draw 999 } else { $i } })
    let mm = (do $measure $misaligned)
    assert ((not $mm.valid) and ($mm.invalid | any {|r| $r =~ "differs" })) $"a clock disagreeing with its state: ($mm.invalid)"
    let over = ($good | each {|i| if $i.kind == "frame" and $i.frame == 2 { $i | update critical 15000 } else { $i } })
    let mo = (do $measure $over)
    assert ($mo.valid and (not $mo.passes)) "a frame at 15 ms leaves the window valid and failing"
    let late = ($good | skip 1 | insert 1 { kind: "ack" })
    let ml = (do $measure $late)
    assert ((not $ml.seeded) and $ml.late_seed) "a seed answered after the first state is late"
    let states = ($good | where {|i| $i.kind in ["ack" "state"] })
    assert (not (do $measure $states).clocked) "states alone are a build older than the clock records"
    for k in ["frame" "draw" "end"] {
        let mk = (do $measure ($good | where {|i| $i.kind in ["ack" "state" $k] }))
        let says = $"states with ($k) records alone are clocked and incomplete: ($mk.problems)"
        assert ($mk.clocked and (not $mk.complete)) $says
    }

    mkdir $dir
    let played = "{ legs: [{ name: \"played\", places: [], pad: [] }] }"
    let other = "{ legs: [{ name: \"other\", places: [], pad: [] }] }"
    let kept = ($dir | path join "route.nuon")
    let id = { route: { file: $kept, sha256: ($played | hash sha256) } }
    $played | save --raw -f $kept
    assert equal ((gauge legs-for $dir $id "").legs | get 0.name) "played" "the kept route the identity recorded"
    $other | save --raw -f $kept
    assert (try { gauge legs-for $dir $id ""; false } catch { true }) "a kept route the identity did not record is refused"
    let given = ($dir | path join "given.nuon")
    $other | save --raw -f $given
    assert (try { gauge legs-for $dir $id $given; false } catch { true }) "a route given that the identity did not record is refused"
    assert equal ((gauge legs-for ($dir | path join "bare") { route: null } "").legs | get 0.name) "play" "a capture with no route is one leg, play"

    let rows_of = {|clocked: bool|
        0..<3 | each {|n|
            let critical = (if $clocked { 1800 } else { null })
            { run: 1, frame: $n, leg: "walk", entry: ($n == 0), x: 1.0, y: 1.0, draw_us: 1000, critical_us: $critical }
        }
    }
    let clocked_rows = (do $rows_of true)
    let clockless_rows = (do $rows_of false)
    let checked = { clocked: true, complete: true, problems: [], valid: true, invalid: [], seeded: true, late_seed: false }
    let stateless = { clocked: false, complete: false, problems: [], valid: false, invalid: [] }
    let never_shown = ["1 flips at status 2, never shown"]
    let never_closed = ["no end marker: the measurement never closed"]
    let invalid = ($checked | update valid false | update invalid $never_shown)
    let incomplete = ($checked | update complete false | update valid false | update problems $never_closed)
    let fixtures = [
        { name: "valid", measured: $checked, rows: $clocked_rows }
        { name: "invalid", measured: $invalid, rows: $clocked_rows }
        { name: "incomplete", measured: $incomplete, rows: $clocked_rows }
        { name: "unchecked", measured: ($checked | reject valid invalid), rows: $clocked_rows }
        { name: "clockless", measured: $stateless, rows: $clockless_rows }
        { name: "empty", measured: ($stateless | insert frames 3), rows: [] }
        { name: "unclassified", measured: ($checked | reject clocked), rows: $clocked_rows }
        { name: "bare", measured: null, rows: $clocked_rows }
        { name: "nulled", measured: $stateless, rows: ($clockless_rows | update draw_us null) }
    ]
    let files = ($fixtures | each {|x|
        let file = ($dir | path join $"compare_($x.name).nuon")
        let doc = { label: $x.name, identity: { build: { image_sha256: $x.name } } }
        $doc | insert runs [{ run: 1, measured: $x.measured }] | insert rows $x.rows | to nuon | save --raw -f $file
        { name: $x.name, file: ($file | path expand) }
    })
    let file_of = {|name: string| $files | where name == $name | get 0.file }
    let valid_file = (do $file_of "valid")
    for name in ["invalid" "incomplete" "unchecked"] {
        let file = (do $file_of $name)
        let pair = [$valid_file $file]
        let refused = (try { gauge compare $pair "draw_us" 50; "" } catch {|e| $e.msg })
        let says = $"a comparison refuses a run measured ($name), naming its file and run: ($refused)"
        assert ($refused | str contains $"($file) run 1, ($name): ") $says
        let admitted = (gauge compare $pair "draw_us" 50 --diagnostic)
        assert equal ($admitted.runs | where build == $name | get 0.standing) $name $"--diagnostic admits a run measured ($name), marked"
        assert (not ($admitted.runs | where build == $name | get 0.reasons | is-empty)) $"the ($name) run keeps its reasons"
        assert equal ($admitted.table | where build == $name | get 0.standings) [$name] $"the ($name) build's row names its standing"
    }
    let clockless_file = (do $file_of "clockless")
    let clockless = (try { gauge compare [$valid_file $clockless_file] "draw_us" 50; "" } catch {|e| $e.msg })
    assert ($clockless | str contains $"($clockless_file) run 1, unpaired: clockless") $"a clockless run is refused unpaired: ($clockless)"
    let compared = (gauge compare [$valid_file $clockless_file] "draw_us" 50 --diagnostic)
    assert equal ($compared.table | where build == "clockless" | get 0.standings) ["unpaired"] "--diagnostic admits a clockless run marked unpaired"
    assert equal ($compared.table | where build == "valid" | get 0.standings) ["valid"] "a valid run stands valid"
    let stopped = [
        { fixture: "empty", field: "draw_us", standing: "empty" }
        { fixture: "unclassified", field: "draw_us", standing: "unclassified" }
        { fixture: "bare", field: "draw_us", standing: "unclassified" }
        { fixture: "nulled", field: "draw_us", standing: "unusable" }
        { fixture: "clockless", field: "critical_us", standing: "unusable" }
    ]
    for s in $stopped {
        let file = (do $file_of $s.fixture)
        for admit in [false true] {
            let msg = (try {
                gauge compare [$valid_file $file] $s.field 50 --diagnostic=$admit; ""
            } catch {|e| $e.msg })
            let says = $"the ($s.fixture) run on ($s.field) refused as ($s.standing), --diagnostic ($admit): ($msg)"
            assert ($msg | str contains $"($file) run 1, ($s.standing): ") $says
        }
    }
    let invalid_file = (do $file_of "invalid")
    let empty_file = (do $file_of "empty")
    let every = (try { gauge compare [$valid_file $invalid_file $empty_file] "draw_us" 50; "" } catch {|e| $e.msg })
    let names_invalid = ($every | str contains $"($invalid_file) run 1, invalid: ")
    let names_empty = ($every | str contains $"($empty_file) run 1, empty: ")
    assert ($names_invalid and $names_empty) $"every run refused is named, none left out: ($every)"

    # coverage: a run's expected legs are every leg any compared run
    # holds; a build of two batches, the second missing the ramp, and a
    # build of one batch missing it
    let legged = {|legs: list<string>|
        $legs | enumerate | each {|l|
            0..<3 | each {|n| { run: 1, frame: ($l.index * 3 + $n), leg: $l.item, entry: ($n == 0), x: 1.0, y: 1.0, draw_us: (1000 + $l.index * 100), critical_us: 1800 } }
        } | flatten
    }
    let covers = [
        { name: "whole", label: "whole", legs: [walk ramp] }
        { name: "partial_1", label: "partial_1", legs: [walk ramp] }
        { name: "partial_2", label: "partial_2", legs: [walk] }
        { name: "short", label: "short", legs: [walk] }
    ]
    let cover_files = ($covers | each {|x|
        let file = ($dir | path join $"cover_($x.name).nuon")
        let image = ($x.label | str replace --regex '_\d+$' '')
        let doc = { label: $x.label, identity: { build: { image_sha256: $image } }, runs: [{ run: 1, measured: $checked }], rows: (do $legged $x.legs) }
        $doc | to nuon | save --raw -f $file
        { name: $x.name, file: ($file | path expand) }
    })
    let cover_of = {|name: string| $cover_files | where name == $name | get 0.file }
    let whole_file = (do $cover_of "whole")
    let partial_files = [(do $cover_of "partial_1") (do $cover_of "partial_2")]
    let batch_short = (try { gauge compare ([$whole_file] | append $partial_files) "draw_us" 50; "" } catch {|e| $e.msg })
    assert ($batch_short | str contains $"($partial_files.1) run 1, partial: missing the legs ramp") $"a batch missing a leg is refused, named with the leg: ($batch_short)"
    assert (not ($batch_short | str contains $"($partial_files.0) run")) $"the batch holding every leg is not named: ($batch_short)"
    let short_file = (do $cover_of "short")
    let build_short = (try { gauge compare [$whole_file $short_file] "draw_us" 50; "" } catch {|e| $e.msg })
    assert ($build_short | str contains $"($short_file) run 1, partial: missing the legs ramp") $"a build missing a leg is refused, named with the leg: ($build_short)"
    let full = (gauge compare [$whole_file (do $cover_of "partial_1")] "draw_us" 50)
    assert ($full.table | all {|t| $t.missing == 0 and $t.value_us != null }) $"full coverage compares with every row valued: ($full.table)"
    let batch_admitted = (gauge compare ([$whole_file] | append $partial_files) "draw_us" 50 --diagnostic)
    let partial_ramp = ($batch_admitted.table | where build == "partial" and leg == "ramp" | get 0)
    assert ($partial_ramp.value_us == null and $partial_ramp.missing == 1 and $partial_ramp.batches == 2) $"under --diagnostic the build's ramp is missing in one of two batches, no value: ($partial_ramp)"
    let partial_walk = ($batch_admitted.table | where build == "partial" and leg == "walk" | get 0)
    assert ($partial_walk.value_us != null and $partial_walk.missing == 0) $"the build's walk, in both batches, is valued: ($partial_walk)"
    let missing_leg = ($batch_admitted.runs | where label == "partial_2" | get 0.legs | where leg == "ramp" | get 0)
    assert ($missing_leg.kind == "missing" and $missing_leg.value == null) $"the batch's own missing leg is explicit: ($missing_leg)"
    let build_admitted = (gauge compare [$whole_file $short_file] "draw_us" 50 --diagnostic)
    let short_ramp = ($build_admitted.table | where build == "short" and leg == "ramp")
    assert (($short_ramp | length) == 1 and ($short_ramp | get 0.value_us) == null and ($short_ramp | get 0.missing) == 1) $"under --diagnostic a build missing a leg keeps the leg's row, missing: ($build_admitted.table)"

    # schema 2: every frame's presentation, one schema a capture
    let good2 = (fx-items 3 --schema 2)
    let m2 = (do $measure $good2)
    assert ($m2.complete and $m2.valid and $m2.passes and $m2.seeded and $m2.cadence_set) $"a well-formed capture at schema 2: ($m2.problems) ($m2.invalid)"
    assert equal [$m2.schema $m2.cadences $m2.final $m2.frames] [2 [0] 2 3] "schema 2, cadence 0, frames 0 to 2"
    let unpresented = (do $measure ($good2 | where {|i| not ($i.kind == "present" and $i.frame == 1) }))
    let without_record = $"a frame without its presentation record leaves the window incomplete: ($unpresented.problems)"
    assert ((not $unpresented.complete) and ($unpresented.problems | any {|p| $p =~ "presentation records" })) $without_record
    let mixed = (do $measure (fx-set $good2 "draw" 1 { schema: 1 }))
    let mixed_says = $"a capture of mixed schemas is incomplete: ($mixed.problems)"
    assert ((not $mixed.complete) and ($mixed.problems | any {|p| $p =~ "at schemas 1 in a capture at schema 2" })) $mixed_says

    # cadence 1 waits before its flip: a wait apart from the critical path
    # balances, a critical path holding it does not
    let early = (fx-items 3 --schema 2 --cadence 1)
    let waited = (fx-set (fx-set $early "present" 1 { wait: 500 }) "frame" 1 { await: ($FX_PERIOD - 1800 - 500) })
    let apart = (do $measure $waited)
    assert ($apart.complete and $apart.valid) $"a wait apart from the critical path balances under cadence 1: ($apart.invalid)"
    let holding = (do $measure (fx-set $waited "frame" 1 { critical: 2300 }))
    let holding_says = $"a critical path holding the wait breaks the frame's sum: ($holding.invalid)"
    assert ((not $holding.valid) and ($holding.invalid | any {|r| $r =~ "not their critical path, wait, and await" })) $holding_says

    # a flip refused as early: valid under cadence 0, which awaits after
    # it, invalid under 1, which flips again until it presents
    let refused_after = (do $measure (fx-set (fx-set $good2 "frame" 1 { status: 1 }) "present" 1 { refusals: 1 }))
    assert ($refused_after.complete and $refused_after.valid) $"a flip refused as early is valid under cadence 0: ($refused_after.invalid)"
    let refused_early = (do $measure (fx-set (fx-set $early "frame" 1 { status: 1 }) "present" 1 { refusals: 1 }))
    let refused_says = $"a final flip refused as early is invalid under cadence 1: ($refused_early.invalid)"
    assert ((not $refused_early.valid) and ($refused_early.invalid | any {|r| $r =~ "final flip was not presented" })) $refused_says

    # cadence 0 waits nothing before its flip and flips once; attempts are
    # the refusals and the final one; a cadence is 0 to 2
    let waited_after = (do $measure (fx-set (fx-set $good2 "present" 1 { wait: 500 }) "frame" 1 { await: ($FX_PERIOD - 1800 - 500) }))
    let waited_says = $"a wait under cadence 0 is invalid: ($waited_after.invalid)"
    assert ((not $waited_after.valid) and ($waited_after.invalid | any {|r| $r =~ "under cadence 0 with a wait or a pacing" })) $waited_says
    let twice_after = (do $measure (fx-set $good2 "present" 1 { attempts: 2, refusals: 1 }))
    let twice_says = $"a second flip attempt under cadence 0 is invalid: ($twice_after.invalid)"
    assert ((not $twice_after.valid) and ($twice_after.invalid | any {|r| $r =~ "attempted other than once" })) $twice_says
    let miscounted = (do $measure (fx-set $early "present" 1 { attempts: 3, refusals: 1 }))
    let miscounted_says = $"attempts past the refusals and the final one are invalid: ($miscounted.invalid)"
    assert ((not $miscounted.valid) and ($miscounted.invalid | any {|r| $r =~ "not their refusals and their final attempt" })) $miscounted_says
    let outside = (do $measure (fx-set $good2 "present" 1 { cadence: 5 }))
    let outside_says = $"a cadence outside 0 to 2 is invalid: ($outside.invalid)"
    assert ((not $outside.valid) and ($outside.invalid | any {|r| $r =~ "cadence outside 0 to 2" })) $outside_says

    # a frame's next start is the next frame's start, its own sum balanced
    # or not; a one-frame capture closes through its next start alone
    let moved = (do $measure (fx-set (fx-set $good2 "present" 0 { next: ($FX_PERIOD + 100) }) "frame" 0 { await: ($FX_PERIOD + 100 - 1800) }))
    let moved_apart = ($moved.invalid | any {|r| $r =~ "not the next frame's start" })
    let moved_balanced = (not ($moved.invalid | any {|r| $r =~ "critical path, wait, and await" }))
    assert ((not $moved.valid) and $moved_apart and $moved_balanced) $"a next start apart from the next frame's start is invalid, its sum balanced: ($moved.invalid)"
    let one = (fx-items 1 --schema 2)
    let closed = (do $measure $one)
    assert ($closed.complete and $closed.valid and $closed.frames == 1) $"a one-frame capture closes through its next start: ($closed.problems) ($closed.invalid)"
    let unclosed = (do $measure (fx-set $one "present" 0 { next: ($FX_PERIOD + 5000) }))
    let unclosed_says = $"a one-frame capture whose next start does not close is invalid: ($unclosed.invalid)"
    assert ((not $unclosed.valid) and ($unclosed.invalid | any {|r| $r =~ "critical path, wait, and await" })) $unclosed_says

    # a frame's start, simulation, flip end, and next start come in that
    # order: frame 1's start is 20,000, its flip's end 21,700, its next
    # start 40,000; each case moves one field of it and is out of order
    # alone, the sum and the continuity reading none of them
    let disorder = "1 frames whose start, simulation, flip end, and next start are out of order"
    let orders = [
        { name: "the simulation before the start", items: (fx-set $good2 "present" 1 { simulation: ($FX_PERIOD - 1) }) }
        { name: "the simulation past the flip's end", items: (fx-set $good2 "present" 1 { simulation: ($FX_PERIOD + 1701) }) }
        { name: "the flip's end past the next start", items: (fx-set $good2 "frame" 1 { flip_done: (2 * $FX_PERIOD + 1) }) }
    ]
    for o in $orders {
        let ordered = (do $measure $o.items)
        assert ($ordered.complete and $ordered.invalid == [$disorder]) $"($o.name) is out of order and nothing else: ($ordered.problems) ($ordered.invalid)"
    }

    # pairing: a seed or a cadence unanswered, answered late, or answered
    # early and again late, an identity asking a cadence outside 0 to 2 or
    # none, a frame at another cadence than asked, and below schema 2 an
    # identity asking a cadence other than 0 each leave a run unpaired,
    # refused unless --diagnostic admits it marked
    let paired = (fx-gauge $dir "paired" "paired" "paired" 0 $good2)
    let without = {|kind: string| $good2 | where {|i| $i.kind != $kind } }
    let unpaired = [
        { name: "seed_unanswered", items: (do $without "ack"), cadence: 0, reason: "unseeded: no seed answered" }
        { name: "seed_late", items: (fx-late (do $without "ack") { kind: "ack" }), cadence: 0, reason: "a seed answered after the first frame" }
        { name: "seed_again", items: (fx-late $good2 { kind: "ack" }), cadence: 0, reason: "a seed answered after the first frame" }
        { name: "cadence_unanswered", items: (do $without "cack"), cadence: 0, reason: "no cadence asked before the first frame" }
        { name: "cadence_late", items: (fx-late (do $without "cack") { kind: "cack" }), cadence: 0, reason: "a cadence asked after the first frame" }
        { name: "cadence_again", items: (fx-late $good2 { kind: "cack" }), cadence: 0, reason: "a cadence asked after the first frame" }
        { name: "asked_outside", items: $good2, cadence: 3, reason: "asks cadence 3, outside 0 to 2" }
        { name: "asked_none", items: $good2, cadence: null, reason: "the identity asks no cadence" }
        { name: "asked_other", items: $good2, cadence: 1, reason: "frames at cadence 0 where the identity asked 1" }
        { name: "legacy_asked", items: $good, cadence: 1, reason: "the identity asks cadence 1, which a capture below schema 2 cannot play" }
    ]
    for u in $unpaired {
        let file = (fx-gauge $dir $u.name $u.name $u.name $u.cadence $u.items)
        let refused = (try { gauge compare [$paired $file] "draw_us" 50; "" } catch {|e| $e.msg })
        assert ($refused | str contains $"($file) run 1, unpaired: ") $"the ($u.name) run is refused unpaired: ($refused)"
        assert ($refused | str contains $u.reason) $"the ($u.name) run's reason, ($u.reason): ($refused)"
        assert (not ($refused | str contains $"($paired) run")) $"the paired run is not named beside ($u.name): ($refused)"
        let admitted = (try { gauge compare [$paired $file] "draw_us" 50 --diagnostic } catch {|e| { refusal: $e.msg } })
        assert (($admitted | get -o refusal) == null) $"--diagnostic admits the ($u.name) run, the comparison standing: ($admitted | get -o refusal)"
        assert equal ($admitted.table | where build == $u.name | get 0.standings) ["unpaired"] $"--diagnostic admits the ($u.name) run marked unpaired"
    }

    # grouping: a build is an image at a cadence, one name a build and one
    # build a name
    let split = (try {
        gauge compare [(fx-gauge $dir "split_0" "split_1" "one_image" 0 $good2) (fx-gauge $dir "split_1" "split_2" "one_image" 1 $early)] "draw_us" 50
        ""
    } catch {|e| $e.msg })
    assert ($split | str contains "come from 2 builds") $"two cadences under one name refuse the comparison: ($split)"
    let kept_apart = (try {
        gauge compare [(fx-gauge $dir "apart_0" "after" "one_image" 0 $good2) (fx-gauge $dir "apart_1" "early" "one_image" 1 $early)] "draw_us" 50
    } catch {|e| { refusal: $e.msg } })
    let apart_says = $"one image's two cadences compare without a refusal: ($kept_apart | get -o refusal)"
    assert (($kept_apart | get -o refusal) == null) $apart_says
    assert equal ($kept_apart.table | get build | uniq | sort) [after early] $"one image's two cadences are two builds: ($kept_apart.table)"
    let renamed = (try {
        gauge compare [(fx-gauge $dir "named_0" "one" "same_image" 0 $good2) (fx-gauge $dir "named_1" "two" "same_image" 0 $good2)] "draw_us" 50
        ""
    } catch {|e| $e.msg })
    assert ($renamed | str contains "a build has one name") $"one build under two names refuses the comparison: ($renamed)"

    # below schema 2 a capture plays cadence 0 whatever its identity asks:
    # one image's schema 1 captures, one asking none and one 0, are one
    # build at cadence 0, each run keeping what it asked
    let legacy = (try {
        gauge compare [(fx-gauge $dir "legacy_1" "legacy_1" "legacy_image" null $good) (fx-gauge $dir "legacy_2" "legacy_2" "legacy_image" 0 $good)] "draw_us" 50
    } catch {|e| { refusal: $e.msg } })
    let legacy_says = $"schema 1 captures asking none and 0 compare as one build without a refusal: ($legacy | get -o refusal)"
    assert (($legacy | get -o refusal) == null) $legacy_says
    assert equal ($legacy.table | get build | uniq) [legacy] $"one image's schema 1 captures are the one build legacy: ($legacy.table)"
    assert equal ($legacy.runs | get standing) [valid valid] $"both schema 1 captures stand valid: ($legacy.runs | get reasons)"
    assert equal ($legacy.runs | get effective_cadence) [0 0] $"both played cadence 0: ($legacy.runs | get effective_cadence)"
    assert equal ($legacy.runs | get requested_cadence) [null 0] $"each keeps the cadence it asked: ($legacy.runs | get requested_cadence)"

    # schema 3: every frame's packets, read at their offsets, a capture's
    # records at one schema, the packet records clock evidence; the drawing
    # its preparation and its raster to within the microsecond the
    # conversions drop, the raster a part of the drawing, the bytes the
    # packets held their commands' and span records', the packets prepared
    # from the frame's own simulation, each case moving one field of frame
    # 1 and invalid for that alone
    let good3 = (fx-items 3 --schema 3)
    let m3 = (do $measure $good3)
    assert ($m3.complete and $m3.valid and $m3.passes and $m3.seeded and $m3.cadence_set) $"a well-formed capture at schema 3: ($m3.problems) ($m3.invalid)"
    assert equal [$m3.schema $m3.cadences $m3.final $m3.frames] [3 [0] 2 3] "schema 3, cadence 0, frames 0 to 2"
    let read3 = ($m3.rows | get 2 | select preparation_us raster_us commands flushes invalidated packet_bytes snapshot packet_residual_us)
    let read3_holds = { preparation_us: 960, raster_us: 40, commands: 3, flushes: 1, invalidated: 2, packet_bytes: 1016, snapshot: 2, packet_residual_us: 0 }
    assert equal $read3 $read3_holds $"frame 2's packet record read at its offsets: ($read3)"
    let unpacked = (do $measure ($good3 | where {|i| not ($i.kind == "packet" and $i.frame == 1) }))
    let unpacked_says = $"a frame without its packet record leaves the window incomplete: ($unpacked.problems)"
    assert ((not $unpacked.complete) and ($unpacked.problems | any {|p| $p =~ "packet records" })) $unpacked_says
    let mixed3 = (do $measure (fx-set $good3 "packet" 1 { schema: 2 }))
    let mixed3_says = $"a packet record at another schema leaves the window incomplete: ($mixed3.problems)"
    assert ((not $mixed3.complete) and ($mixed3.problems | any {|p| $p =~ "at schemas 2 in a capture at schema 3" })) $mixed3_says
    let packets_alone = (do $measure ($good3 | where {|i| $i.kind in ["ack" "cack" "state" "packet"] }))
    assert ($packets_alone.clocked and (not $packets_alone.complete)) $"states with packet records alone are clocked and incomplete: ($packets_alone.problems)"
    let rounded = (do $measure (fx-set $good3 "packet" 1 { preparation: 959 }))
    assert ($rounded.complete and $rounded.valid) $"a drawing a microsecond past its preparation and raster, the conversions' drop, is valid: ($rounded.invalid)"
    let unsplit = "1 frames whose drawing is not their preparation and their raster"
    let packet_cases = [
        { name: "a drawing two microseconds past its preparation and raster", items: (fx-set $good3 "packet" 1 { preparation: 958 }), says: $unsplit }
        { name: "a preparation and raster past the drawing", items: (fx-set $good3 "packet" 1 { preparation: 961 }), says: $unsplit }
        { name: "a raster past what the drawing's other parts leave", items: (fx-set $good3 "packet" 1 { preparation: 940, raster: 60 }), says: "1 frames whose phases or parts sum past their whole" }
        { name: "packet bytes other than the commands' and span records'", items: (fx-set $good3 "packet" 1 { bytes: 1015 }), says: "1 frames whose packets' bytes are not their commands' and their span records'" }
        { name: "packets prepared from the frame before's simulation", items: (fx-set $good3 "packet" 1 { snapshot: 0 }), says: "1 frames whose packets were prepared from another frame's simulation" }
    ]
    for c in $packet_cases {
        let mc = (do $measure $c.items)
        assert ($mc.complete and $mc.invalid == [$c.says]) $"($c.name) is invalid for that alone: ($mc.problems) ($mc.invalid)"
    }

    # from schema 2 a capture plays the cadence it asks: one image's
    # schema 3 captures at cadences 0 and 1 are two builds, the comparison
    # wrapped and held to no refusal
    let early3 = (fx-items 3 --schema 3 --cadence 1)
    let at3 = (try {
        gauge compare [(fx-gauge $dir "three_0" "three_after" "three_image" 0 $good3) (fx-gauge $dir "three_1" "three_early" "three_image" 1 $early3)] "draw_us" 50
    } catch {|e| { refusal: $e.msg } })
    let at3_says = $"schema 3 captures at cadences 0 and 1 compare without a refusal: ($at3 | get -o refusal)"
    assert (($at3 | get -o refusal) == null) $at3_says
    assert equal ($at3.runs | get effective_cadence) [0 1] $"each schema 3 capture plays the cadence it asked: ($at3.runs | get effective_cadence)"

    # the drawing's parts whose meaning moved with the packets: the phases
    # with rendering at schema 1 and preparation alone at 3, the remainder
    # holding no rendering at both and the raster in f59f7a7's listed
    # schema 2 images, a listed image classified by its SHA-256 whatever
    # its identity's commit or dirty flag says and any other schema 2 run
    # unknown; a comparison on a phase or the remainder refused,
    # --diagnostic or not, when its runs' classes differ or one is unknown,
    # every other field comparing across schemas
    let compared = {|files: list<string>, field: string, diagnostic: bool|
        try { gauge compare $files $field 50 --diagnostic=$diagnostic; "" } catch {|e| $e.msg }
    }
    let one_a = (fx-gauge $dir "parts_one_a" "parts_one_a" "parts_one_a" null $good)
    let one_b = (fx-gauge $dir "parts_one_b" "parts_one_b" "parts_one_b" null $good)
    let three_a = (fx-gauge $dir "parts_three_a" "parts_three_a" "parts_three_a" 0 $good3)
    let three_b = (fx-gauge $dir "parts_three_b" "parts_three_b" "parts_three_b" 0 $good3)
    let across = (do $compared [$one_a $three_a] "planes_us" false)
    let across_says = $"schema 1 against schema 3 refused on planes_us, each run's class named: ($across)"
    assert (($across | str contains "planes_us refuses") and ($across | str contains $"($one_a) run 1, schema 1") and ($across | str contains "with rendering") and ($across | str contains "preparation alone")) $across_says
    let across_admitted = (do $compared [$one_a $three_a] "planes_us" true)
    assert ($across_admitted | str contains "planes_us refuses") $"--diagnostic admits no comparison of phases measuring different things: ($across_admitted)"
    for field in [draw_us critical_us parts_unattributed_us] {
        let kept = (do $compared [$one_a $three_a] $field false)
        assert ($kept == "") $"schema 1 against schema 3 compares on ($field): ($kept)"
    }
    let unlisted = [
        { name: "dirty", file: (fx-gauge $dir "parts_dirty" "parts_dirty" "parts_dirty" 0 $good2 --program { dir: "", commit: "d876d94", dirty: true, from: "git" }) }
        { name: "unsourced", file: (fx-gauge $dir "parts_unsourced" "parts_unsourced" "parts_unsourced" 0 $good2) }
    ]
    for u in $unlisted {
        let refused = (do $compared [$u.file $one_a] "planes_us" false)
        let refused_says = $"an unlisted schema 2 run, ($u.name), is unknown and refused on planes_us: ($refused)"
        assert (($refused | str contains "planes_us refuses") and ($refused | str contains $"($u.file) run 1, schema 2, image parts_($u.name): unknown")) $refused_says
        let drawn = (do $compared [$u.file $one_a] "draw_us" false)
        assert ($drawn == "") $"the unlisted ($u.name) run compares on draw_us: ($drawn)"
    }
    let stale = (fx-gauge $dir "parts_stale" "parts_stale" "parts_stale" 0 $good2 --program { dir: "", commit: "f59f7a740873f9dfad4c3bcab8126271fe475fd4", dirty: false, from: "git" })
    let stale_refused = (do $compared [$stale $three_a] "planes_us" false)
    let stale_says = $"f59f7a7's commit, clean, on an unlisted image is unknown and refused: ($stale_refused)"
    assert (($stale_refused | str contains "planes_us refuses") and ($stale_refused | str contains $"($stale) run 1, schema 2, image parts_stale: unknown")) $stale_says
    let listed = (gauge phase-images | columns | first)
    let listings = [
        { name: "under another clean commit", label: "parts_listed_clean", program: { dir: "", commit: "64f518a", dirty: false, from: "git" } }
        { name: "dirty", label: "parts_listed_dirty", program: { dir: "", commit: "64f518a", dirty: true, from: "git" } }
        { name: "with no commit", label: "parts_listed_bare", program: { dir: "", commit: null, dirty: null, from: null } }
    ]
    for l in $listings {
        let file = (fx-gauge $dir $l.label $l.label $listed 0 $good2 --program $l.program)
        let kept = (do $compared [$file $three_a] "planes_us" false)
        assert ($kept == "") $"f59f7a7's listed image ($l.name) compares with schema 3 on planes_us: ($kept)"
    }
    let listed_clean = ($dir | path join "pair_parts_listed_clean.nuon" | path expand)
    let remainder = (do $compared [$listed_clean $three_a] "parts_unattributed_us" false)
    let remainder_says = $"the listed image's remainder, holding the raster, refused against schema 3's: ($remainder)"
    assert (($remainder | str contains "parts_unattributed_us refuses") and ($remainder | str contains "holding the raster") and ($remainder | str contains "holding no rendering")) $remainder_says
    for pair in [[$one_a $one_b] [$three_a $three_b]] {
        let alike = (do $compared $pair "planes_us" false)
        assert ($alike == "") $"two runs of one class compare on planes_us: ($alike)"
    }

    # machines: the specification's four harts, two harts diagnostic, and
    # four harts on another -machine, the PLIC's line before the AIA
    let four = (jab machine-of 4)
    let two = (jab machine-of 2)
    let plic = ($four | update machine "virt")
    let on_four = (fx-gauge $dir "machine_four" "four" "four" 0 $good2 --machine $four)
    let on_two = (fx-gauge $dir "machine_two" "two" "two" 0 $good2 --machine $two)
    let on_plic = (fx-gauge $dir "machine_plic" "plic" "plic" 0 $good2 --machine $plic)
    let diag_refused = (try { gauge compare [$on_four $on_two] "draw_us" 50; "" } catch {|e| $e.msg })
    let diag_says = $"a run on a diagnostic machine is refused as diagnostic: ($diag_refused)"
    assert ($diag_refused | str contains $"($on_two) run 1, diagnostic: a diagnostic machine of 2 harts") $diag_says
    let diag_admitted = (gauge compare [$on_four $on_two] "draw_us" 50 --diagnostic)
    assert equal ($diag_admitted.table | where build == "two" | get 0.standings) ["diagnostic"] "--diagnostic admits it marked"
    let across = (try { gauge compare [$on_four $on_plic] "draw_us" 50; "" } catch {|e| $e.msg })
    assert ($across | str contains "the runs ran on 2 machines") $"runs on two machines refuse the comparison: ($across)"
    let across_admitted = (gauge compare [$on_four $on_plic] "draw_us" 50 --diagnostic)
    let rows = ($across_admitted.table | each {|t| [$t.build $t.machine.machine] })
    assert equal $rows [[four $four.machine] [plic virt]] $"each build's row names its machine: ($rows)"
    let one_name = (try {
        gauge compare [(fx-gauge $dir "mixed_1" "mixed_1" "mixed" 0 $good2 --machine $four) (fx-gauge $dir "mixed_2" "mixed_2" "mixed" 0 $good2 --machine $plic)] "draw_us" 50 --diagnostic
        ""
    } catch {|e| $e.msg })
    assert ($one_name | str contains "come from 2 builds") $"one name's runs on two machines are two builds: ($one_name)"

    # QEMU words of the launch's own: the machine the launch returns, the
    # specification's four marked diagnostic, and the one asked for before
    # it, unmarked, each with the words beside it; both stand diagnostic,
    # the reason naming the words and no hart count
    let words = ["-global" "virtio-rng-device.period=6000"]
    let worded = [
        { name: "words_launched", machine: (jab machine-of 4 --overrides $words) }
        { name: "words_asked", machine: $four }
    ]
    for w in $worded {
        let file = (fx-gauge $dir $w.name $w.name $w.name 0 $good2 --machine $w.machine --overrides $words)
        let refused = (try { gauge compare [$on_four $file] "draw_us" 50; "" } catch {|e| $e.msg })
        let refused_says = $"the ($w.name) run is refused as diagnostic, the words named: ($refused)"
        assert ($refused | str contains $"($file) run 1, diagnostic: QEMU words of its launch's own: ($words | str join ' ')") $refused_says
        assert (not ($refused | str contains "harts")) $"the ($w.name) run's reason names no hart count: ($refused)"
        let admitted = (gauge compare [$on_four $file] "draw_us" 50 --diagnostic)
        assert equal ($admitted.table | where build == $w.name | get 0.standings) ["diagnostic"] $"--diagnostic admits the ($w.name) run marked"
    }

    # a bench of two route steps at cadence 0, one on each machine
    let bench = ($dir | path join "bench")
    for step in [[four $on_four] [two $on_two]] {
        mkdir ($bench | path join $step.0)
        cp $step.1 ($bench | path join $step.0 "gauge.nuon")
    }
    let doc = (gauge bench-doc $bench)
    let pool = ($doc.groups | where kind == "route" | get 0.cadences.0)
    assert equal [$pool.runs $pool.valid] [2 1] $"the bench pools the specification's machine's run alone: ($pool.standings)"
    assert equal ($pool.apart | get standing) ["diagnostic"] $"the diagnostic machine's run kept apart: ($pool.apart)"
    assert equal ($doc.steps | get machine.harts) [4 2] $"every step names its machine: ($doc.steps)"
    let text = (gauge bench-text $doc | lines)
    let line = $"machine: 2 harts, diagnostic, -machine ($two.machine), -cpu ($two.cpu), -accel ($two.accel); QEMU unrecorded: two"
    assert ($line in $text) $"the report names the step's machine, ($line): ($text)"
}

# The program's three cadences on its own clock records, one
# launch a cadence of each fixture, the debug build's S frames standing
# stalls in place of the drawing, each window held complete and valid at
# the program's schema before anything is read from it. CadenceSchedule,
# on Render One: R and C at 200 ms; from 1.5 s a 4 ms standing stall and a
# 500 us spin inside every consume; ten trigger reports from 1.8 s, 400
# ms apart, each pressed and released in one report; at 5.9 s a frame
# whose flip is tried before its wait; at 6.3 s a frame stalled 30 ms;
# from 7 s a 25 ms standing stall; the E at 9 s. A sustained stage sets
# its first five frames aside; a one-off is read at the frame its S
# answer names, the first state after it, and the frames after it as they
# come. The fast
# stage presents every period under every cadence, soon after its
# simulation under 0 and a period after it under 1 and 2, which wait for
# the tick, every frame with wakes holding the consume's spin in its
# pacing and its critical path, never its wait; the forced frame under 1
# and 2 is refused once and presents on the tick; the stalled frame's
# intervals are each cadence's catch-up; the slow stage presents a period
# past each late flip under 0, as soon as ready with no wait under 1, and
# every second period on the tick grid under 2; ten rounds under every
# cadence, presses taken in waits under 1 and 2, and few wakes a frame.
# MotionByTime, on the still copy of Render Zero: placed on the bay's east side
# facing north, a 25 ms standing stall, the stick held forward from 2 to
# 5 s; over the frames the body moved in a metre or more from every wall
# of their sector, the distance from the first to the last over the
# difference of their simulation times is 4 m/s within 2 percent under
# every cadence.
export def cadence-holds [kernel: path, image: path, out: path, set: string, game: path]: nothing -> nothing {
    let dir = ($out | path join "cadence")
    mkdir $dir
    let render_1_disk = (romfs (jab program-shard $game "asset" | path join "render_1") ($dir | path join "render_1.romfs"))
    let still_tree = (variant-tree (open ($game | path join "content" "map" "render_0.nuon")) "render_0_still" [android] ($dir | path join "still") $game)
    let still_disk = (romfs $still_tree ($dir | path join "still.romfs"))
    let still_read = (map read ($still_tree | path join "map" "render_0_still.jabfps.map"))
    let triggers = ($dir | path join "triggers.nuon")
    $SCHEDULE_TRIGGERS | each {|at| [{ at: $at, type: 1, code: 313, value: 1 } { at: $at, type: 1, code: 313, value: 0 }] } | flatten | to nuon | save --raw -f $triggers
    let stick = ($dir | path join "stick.nuon")
    [{ at: $MOTION_STICK.from, type: 3, code: 1, value: 0 } { at: $MOTION_STICK.to, type: 3, code: 1, value: 127 }] | to nuon | save --raw -f $stick
    let p = $CADENCE_PERIOD
    for cadence in $CADENCES {
        let says = $"on the schedule at cadence ($cadence)"
        let sends = ([
            { at: $CLOCK_SEED_AT, bytes: (gauge seed-frame $CLOCK_SEED) }
            { at: $CLOCK_SEED_AT, bytes: (gauge cadence-frame $cadence) }
            { at: $SCHEDULE_FAST.at, bytes: (stall-frame true $SCHEDULE_FAST.stall 0 false $SCHEDULE_FAST.spin) }
            { at: $SCHEDULE_FORCED, bytes: (stall-frame true $SCHEDULE_FAST.stall 0 true $SCHEDULE_FAST.spin) }
            { at: $SCHEDULE_ONCE.at, bytes: (stall-frame true $SCHEDULE_FAST.stall $SCHEDULE_ONCE.stall false $SCHEDULE_FAST.spin) }
            { at: $SCHEDULE_SLOW.at, bytes: (stall-frame true $SCHEDULE_SLOW.stall 0 false $SCHEDULE_FAST.spin) }
            { at: $SCHEDULE_END, bytes: (pose command-frame "E") }
        ] | sort-by at)
        let run = (jab launch --kernel $kernel --image $image --out ($dir | path join $"schedule_($cadence)") --set $set --sound --api --pad $triggers --disk $render_1_disk --serial "fps" --send $sends --capture ($SCHEDULE_END + 1sec) --seconds 11)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest ($says)"
        let m = (gauge measure $run.api [{ name: "schedule", places: [], pad: [] }])
        assert ($m.complete and $m.valid and $m.schema == $CLOCK_SCHEMA) $"the window complete and valid at schema ($CLOCK_SCHEMA) ($says): ($m.problems) ($m.invalid)"
        assert equal $m.cadences [$cadence] $"every frame presented at cadence ($cadence) ($says)"
        let s = (answered-frames $run.api $CONSOLE_S)
        assert equal ($s | length) 4 $"the four S frames answered in the window ($says): ($s)"
        let rows = (submitted $m.rows)
        let row = {|f: int| $rows | where frame == $f | get 0 }
        let fast = ($rows | where {|r| $r.frame >= ($s.0 + $CADENCE_SKIP) and $r.frame < $s.1 })
        let slow = ($rows | where {|r| $r.frame >= ($s.3 + $CADENCE_SKIP) })

        # the fast stage
        let interval = ($fast | get submit_interval_us | compact | math median)
        assert ((($interval - $p) | math abs) <= 500) $"the fast stage presents every period ($says): ($interval) us"
        let age = ($fast | get submission_age_us | compact | math median)
        if $cadence == 0 {
            assert ($age < 8000) $"the fast stage's submission age its own work under cadence 0: ($age) us"
        } else {
            assert ($age > 14000) $"the fast stage's submission age near a period ($says): ($age) us"
            let wait = ($fast | get wait_us | math median)
            assert ($wait > 9000) $"the fast stage waits for the tick ($says): ($wait) us"
        }
        let woken = ($fast | where {|r| $r.wakes > 0 })
        let spilled = ($woken | where {|r| $r.pacing_us < ($r.wakes * $SCHEDULE_FAST.spin) or $r.unattributed_us < 0 or $r.unattributed_us > 1000 })
        let spilled_says = $"every frame with wakes holds the consume's spin in its pacing and its critical path ($says): ($spilled | select frame wakes pacing_us wait_us unattributed_us | first 3)"
        assert ($spilled | is-empty) $spilled_says

        # the frame whose flip is tried before its wait
        let forced = (do $row $s.1)
        let others = ($rows | where {|r| $r.frame != $s.1 and $r.flip_attempts != 1 })
        assert ($others | is-empty) $"every other frame tries its flip once ($says): ($others | select frame flip_attempts refusals | first 3)"
        if $cadence == 0 {
            assert equal $forced.flip_attempts 1 $"the forced frame tries once under cadence 0, which awaits after its flip: ($forced.flip_attempts)"
        } else {
            let tried = ($forced.flip_attempts == 2 and $forced.refusals == 1 and $forced.flip_status == 0)
            assert $tried $"the forced frame tried before its wait, refused once, then presented ($says): ($forced | select frame flip_attempts refusals flip_status)"
            assert ((($forced.submit_interval_us - $p) | math abs) <= 1000) $"the forced frame presents on the tick ($says): ($forced.submit_interval_us) us"
        }

        # the frame stalled once and the two after it: under 0 its flip a
        # period past the frame before's tick and its stall, the next a
        # period past its flip and that frame's work; under 1 presented
        # once ready, the next held to the tick a period past its flip, then
        # the period; under 2 held to the third tick, then the period
        let once = $SCHEDULE_ONCE.stall
        let stalled = (do $row $s.2)
        assert ($stalled.draw_us >= $once and $stalled.draw_us <= ($once + 1000)) $"the stalled frame's drawing its ($once / 1000) ms stall ($says): ($stalled.draw_us) us"
        let after = (0..2 | each {|k| (do $row ($s.2 + $k)).submit_interval_us })
        let recovered = (match $cadence {
            0 => ($after.0 >= ($once + 9000) and $after.0 <= ($once + 17000) and $after.1 >= 19000 and $after.1 <= 27000)
            1 => ($after.0 >= $once and $after.0 <= ($once + 7000) and $after.1 >= ($p - 500) and $after.1 <= ($p + 6000) and ((($after.2 - $p) | math abs) <= 1000))
            _ => (((($after.0 - 3 * $p) | math abs) <= 1000) and ((($after.1 - $p) | math abs) <= 1000))
        })
        assert $recovered $"the stall's intervals ($says): ($after) us"

        # the slow stage
        let slow_interval = ($slow | get submit_interval_us | compact | math median)
        if $cadence == 0 {
            assert ($slow_interval > 40000) $"the slow stage a period past each late flip under cadence 0: ($slow_interval) us"
        } else if $cadence == 1 {
            assert ($slow_interval < 28000) $"the slow stage presents as soon as ready under cadence 1: ($slow_interval) us"
            let waited = ($slow | where {|r| $r.wait_us > 0 })
            assert ($waited | is-empty) $"no frame of the slow stage waits under cadence 1: ($waited | select frame wait_us | first 3)"
        } else {
            assert ((($slow_interval - 2 * $p) | math abs) <= 500) $"the slow stage every second period under cadence 2: ($slow_interval) us"
            let intervals = ($slow | get submit_interval_us | compact)
            let gridded = ($intervals | where {|i| (($i - (($i / $p) | math round) * $p) | math abs) <= 1000 } | length)
            assert (($gridded * 10) >= (($intervals | length) * 9)) $"nine in ten of the slow stage's intervals on the tick grid under cadence 2: ($gridded) of ($intervals | length)"
        }

        # the rounds, the presses taken in waits, and the wakes a frame
        let rounds = (records $run.api | where kind == 2 | length)
        assert equal $rounds 10 $"ten rounds from ten trigger reports ($says)"
        if $cadence != 0 {
            let presses = ($rows | get wait_presses | math sum)
            assert ($presses >= 1) $"presses taken in waits ($says): ($presses)"
            let wakes = ($rows | get wakes | math max)
            assert ($wakes < $SCHEDULE_WAKES) $"under ($SCHEDULE_WAKES) wakes in any frame ($says): ($wakes)"
        }
        print $"fps: the schedule at cadence ($cadence): ($m.frames) frames; the fast stage's interval ($interval) us and age ($age) us; the stall's intervals ($after) us; the slow stage's ($slow_interval) us"
    }
    for cadence in $CADENCES {
        let says = $"walking at cadence ($cadence)"
        let sends = ([
            { at: $CLOCK_SEED_AT, bytes: (gauge seed-frame $CLOCK_SEED) }
            { at: $CLOCK_SEED_AT, bytes: (gauge cadence-frame $cadence) }
            { at: $MOTION_AT, bytes: (pose pose-frame $MOTION_POSE) }
            { at: $MOTION_AT, bytes: (stall-frame true $MOTION_STALL 0 false 0) }
            { at: $MOTION_END, bytes: (pose command-frame "E") }
        ] | sort-by at)
        let run = (jab launch --kernel $kernel --image $image --out ($dir | path join $"motion_($cadence)") --set $set --sound --api --pad $stick --disk $still_disk --serial "fps" --send $sends --capture ($MOTION_END + 1sec) --seconds 7)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest ($says)"
        let m = (gauge measure $run.api [{ name: "motion", places: [$MOTION_POSE], pad: [] }])
        assert ($m.complete and $m.valid and $m.schema == $CLOCK_SCHEMA) $"the window complete and valid at schema ($CLOCK_SCHEMA) ($says): ($m.problems) ($m.invalid)"
        let moved = ($m.rows | window 2 | where {|w|
            let step = (((($w.1.x - $w.0.x) ** 2) + (($w.1.y - $w.0.y) ** 2)) | math sqrt)
            $step > 0.001 and $step < 0.5
        } | each {|w| $w.1 })
        let clear = ($moved | where {|r| $r.sector >= 0 and (wall-clearance $still_read $r.sector $r.x $r.y) >= $MOTION_CLEAR })
        assert (($clear | length) >= 2) $"frames that moved clear of the walls ($says): ($clear | length) of ($moved | length)"
        let first = ($clear | first)
        let last = ($clear | last)
        let seconds = (($last.simulation_us - $first.simulation_us) / 1000000)
        assert ($seconds >= 2.0) $"the walk measured over at least 2 s ($says): ($seconds) s"
        let metres = (((($last.x - $first.x) ** 2) + (($last.y - $first.y) ** 2)) | math sqrt)
        let speed = ($metres / $seconds)
        assert ((($speed - $MOTION_SPEED) | math abs) <= ($MOTION_SPEED * 0.02)) $"the body walks 4 m/s by the clock ($says): ($speed) m/s over ($seconds) s"
        print $"fps: the walk at cadence ($cadence): ($speed) m/s over ($seconds) s, ($clear | length) frames, the interval's median ($m.rows | get flip_interval_us | compact | math median) us"
    }
}

# A capture's rows each with the interval from the presented flip before
# its own to its own, both read at the call's start, the flip's end less
# its calls: the call that presents takes 0.5 to 2 ms here as the device
# answers, so intervals between flip ends carry that spread, where a call
# starts on the display's tick. Null for a frame whose flip did not
# present and for the first that did.
def submitted [rows: list<any>]: nothing -> list<any> {
    mut previous: any = null
    mut out = []
    for r in $rows {
        let start = (if $r.flip_status == 0 { $r.flip_done_us - $r.flip_us } else { null })
        let interval = (if $start == null or $previous == null { null } else { $start - $previous })
        if $start != null { $previous = $start }
        $out = ($out | append ($r | insert submit_interval_us $interval))
    }
    $out
}

# The console's S frame, a debug build's alone: byte 4 the standing stall
# on, byte 5 the reading frame's flip tried before its wait, then the
# standing stall, the reading frame's own stall, and the spin inside
# every consume, words in microseconds from byte 8.
def stall-frame [on: bool, standing: int, once: int, forced: bool, spin: int]: nothing -> binary {
    [
        ("S" | into binary) 0x[00 00 00]
        (if $on { 0x[01] } else { 0x[00] }) (if $forced { 0x[01] } else { 0x[00] }) 0x[00 00]
        (fx-u32 $standing) (fx-u32 $once) (fx-u32 $spin) (fx-zeros 44)
    ] | bytes collect
}

# The frames that read a console command, each the count of state records
# before its answer, so the frame's own state is the next one.
def answered-frames [api: binary, command: int]: nothing -> list<int> {
    mut states = 0
    mut frames = []
    for r in ($api | chunks $RECORD | where {|c| ($c | bytes length) == $RECORD }) {
        let kind = ($r | bytes at 0..<1 | into int)
        if $kind == 1 { $states += 1 }
        if $kind == 11 and ($r | bytes at 4..<5 | into int) == $command { $frames = ($frames | append $states) }
    }
    $frames
}

# A point's distance in the plan from the nearest wall of a sector's
# loops.
def wall-clearance [m: record, sector: int, x: float, y: float]: nothing -> float {
    let sec = ($m.sectors | get $sector)
    $sec.first_loop..<($sec.first_loop + $sec.loop_count) | each {|li|
        let lp = ($m.loops | get $li)
        $lp.first_wall..<($lp.first_wall + $lp.wall_count) | each {|wi|
            let w = ($m.walls | get $wi)
            let a = ($m.vertices | get $w.a)
            let b = ($m.vertices | get $w.b)
            let dx = ($b.x - $a.x)
            let dy = ($b.y - $a.y)
            let along = (((($x - $a.x) * $dx) + (($y - $a.y) * $dy)) / (($dx * $dx) + ($dy * $dy)))
            let t = ([0.0 ([1.0 $along] | math min)] | math max)
            ((($x - ($a.x + $t * $dx)) ** 2) + (($y - ($a.y + $t * $dy)) ** 2)) | math sqrt
        }
    } | flatten | math min
}

# A synthetic capture's records as the program sends them over `frames`
# frames: the seed's answer and from schema 2 the cadence's, frame 0's
# state, then at each frame's top the frame before's clock, drawing, from
# schema 2 presentation, and at schema 3 packets, the end marker after
# the final frame's, and the frame's state, two frames' states past the
# window.
def fx-items [frames: int, --schema: int = 1, --cadence: int = 0]: nothing -> list<any> {
    let tops = (1..$frames | each {|n|
        [(fx-frame ($n - 1) $schema) { kind: "draw", frame: ($n - 1), schema: $schema }]
        | append (if $schema >= 2 { [(fx-present ($n - 1) $cadence $schema)] } else { [] })
        | append (if $schema >= 3 { [(fx-packet ($n - 1))] } else { [] })
        | append (if $n == $frames { [{ kind: "end", frame: ($n - 1), schema: $schema }] } else { [] })
        | append [{ kind: "state", frame: $n }]
    } | flatten)
    let answers = (if $schema >= 2 { [{ kind: "ack" } { kind: "cack" }] } else { [{ kind: "ack" }] })
    $answers | append [{ kind: "state", frame: 0 }] | append $tops | append [{ kind: "state", frame: ($frames + 1) }]
}

# A frame record's fields for a synthetic capture: its phases 1.72 ms of
# a critical path of 1.8, the drawing 1 ms, presented, frames FX_PERIOD
# apart; from schema 2 the await the rest of the period, so the frame's
# start, critical path, wait, and await add up to the next frame's start.
def fx-frame [frame: int, schema: int = 1]: nothing -> record {
    let await = (if $schema >= 2 { $FX_PERIOD - 1800 } else { 16000 })
    { kind: "frame", frame: $frame, critical: 1800, game: 100, draw: 1000, status: 0, schema: $schema, await: $await }
}

# A presentation record's fields for a synthetic capture: the simulation
# 50 us into the frame, the next start the next frame's, no wait, pacing,
# wakes, or presses, one attempt, presented.
def fx-present [frame: int, cadence: int, schema: int = 2]: nothing -> record {
    {
        kind: "present", frame: $frame, simulation: ($frame * $FX_PERIOD + 50), next: (($frame + 1) * $FX_PERIOD),
        wait: 0, pacing: 0, wakes: 0, presses: 0, attempts: 1, refusals: 0, cadence: $cadence, schema: $schema,
    }
}

# A packet record's fields for a synthetic capture: the drawing's 1 ms
# its preparation's 0.96 and its raster's 0.04, the drawing's other parts
# taking 0.95 of it; three commands, a flush, two bindings invalidated;
# the bytes three commands' and the draw record's five span records'; and
# the frame's own simulation.
def fx-packet [frame: int]: nothing -> record {
    {
        kind: "packet", frame: $frame, preparation: 960, raster: 40, commands: 3, flushes: 1, invalidated: 2,
        bytes: (3 * 312 + 5 * 16), snapshot: $frame, schema: 3,
    }
}

# A synthetic capture with the item of a kind and frame changed.
def fx-set [items: list<any>, kind: string, frame: int, changes: record]: nothing -> list<any> {
    $items | each {|i| if $i.kind == $kind and ($i.frame? == $frame) { $i | merge $changes } else { $i } }
}

# A synthetic capture with an item put right after its first state.
def fx-late [items: list<any>, item: record]: nothing -> list<any> {
    let first = ($items | enumerate | where {|e| $e.item.kind == "state" } | get 0.index)
    $items | insert ($first + 1) $item
}

# A gauge.nuon for a comparison, as `run` writes one, from a synthetic
# capture measured: its label, an identity of the image, the cadence
# asked, none when null, the machine when given, the program's source as
# the identity records it when given, and the launch's QEMU words when
# given, the run's measurement, and its rows.
def fx-gauge [dir: path, name: string, label: string, image: string, cadence: any, items: list<any>, --machine: record, --program: record, --overrides: list<string> = []]: nothing -> string {
    let m = (gauge measure (fx-bytes $items) [{ name: "walk", places: [], pad: [] }])
    let mode = (if $cadence == null { {} } else { { cadence: $cadence } })
    let file = ($dir | path join $"pair_($name).nuon")
    let id = { build: { image_sha256: $image }, mode: $mode }
    let machined = (if $machine == null { $id } else { $id | insert machine $machine })
    let sourced = (if $program == null { $machined } else { $machined | insert program $program })
    {
        label: $label,
        identity: (if ($overrides | is-empty) { $sourced } else { $sourced | insert overrides $overrides }),
        runs: [{ run: 1, measured: ($m | reject rows) }],
        rows: ($m.rows | each {|r| $r | insert run 1 }),
    } | to nuon | save --raw -f $file
    $file | path expand
}

# A synthetic capture's records as bytes, 64 each in render.inc's
# layouts: the console's answers to R and to C; a state, its drawing and
# game microseconds at 32 and 36, 1000 and 100 unless given; a frame's
# clock, the crosshair and the mix 10 us each, the flip 500, the
# reporting 100, its await, its flip's end 1.7 ms past its start unless
# given; a drawing whose parts take 0.95 ms, its tiles 0.1, its spans 5;
# a presentation; a packet record; and the end marker's frame and schema.
def fx-bytes [items: list<any>]: nothing -> binary {
    $items | each {|i|
        match $i.kind {
            "ack" => (fx-pad ([0x[0b 00 00 00] 0x[52]] | bytes collect)),
            "cack" => (fx-pad ([0x[0b 00 00 00] 0x[43]] | bytes collect)),
            "state" => (fx-pad ([0x[01 00 00 00] (fx-zeros 28) (fx-u32 ($i.draw? | default 1000)) (fx-u32 ($i.game? | default 100))] | bytes collect)),
            "frame" => ([
                0x[07 00 00 00] (fx-u32 $i.frame) (fx-u64 ($i.frame * $FX_PERIOD)) (fx-u32 $i.critical) (fx-u32 $i.game) (fx-u32 $i.draw)
                (fx-u32 10) (fx-u32 10) (fx-u32 500) (fx-u32 100) (fx-u32 ($i.await? | default 16000))
                (fx-u64 ($i.flip_done? | default ($i.frame * $FX_PERIOD + 1700)))
                (fx-u32 $i.status) (fx-u32 $i.schema)
            ] | bytes collect),
            "draw" => ([
                0x[08 00 00 00] (fx-u32 $i.frame) (fx-u32 100) (fx-u32 100) (fx-u32 300) (fx-u32 400) (fx-u32 50) (fx-u32 100)
                (fx-u32 2) (fx-u32 0) (fx-u32 10) (fx-u32 20) (fx-u32 50) (fx-u32 100) (fx-u32 5) (fx-u32 $i.schema)
            ] | bytes collect),
            "present" => ([
                0x[0a 00 00 00] (fx-u32 $i.frame) (fx-u64 $i.simulation) (fx-u64 $i.next) (fx-u32 $i.wait) (fx-u32 $i.pacing)
                (fx-u32 $i.wakes) (fx-u32 $i.presses) (fx-u32 $i.attempts) (fx-u32 $i.refusals) (fx-u32 $i.cadence) (fx-zeros 8)
                (fx-u32 $i.schema)
            ] | bytes collect),
            "packet" => ([
                0x[0c 00 00 00] (fx-u32 $i.frame) (fx-u32 $i.preparation) (fx-u32 $i.raster) (fx-u32 $i.commands)
                (fx-u32 $i.flushes) (fx-u32 $i.invalidated) (fx-u32 $i.bytes) (fx-u32 $i.snapshot) (fx-zeros 24)
                (fx-u32 $i.schema)
            ] | bytes collect),
            "end" => ([0x[09 00 00 00] (fx-u32 $i.frame) (fx-zeros 52) (fx-u32 $i.schema)] | bytes collect),
        }
    } | bytes collect
}

# A little-endian word, a double word, a run of zero bytes, and a record
# filled with zeros to its 64 bytes.
def fx-u32 [v: int]: nothing -> binary { $v | into binary --endian little | bytes at 0..<4 }
def fx-u64 [v: int]: nothing -> binary { $v | into binary --endian little | bytes at 0..<8 }
def fx-zeros [n: int]: nothing -> binary { if $n <= 0 { 0x[] } else { 1..$n | each { 0x[00] } | bytes collect } }
def fx-pad [b: binary]: nothing -> binary { [$b (fx-zeros ($RECORD - ($b | bytes length)))] | bytes collect }
