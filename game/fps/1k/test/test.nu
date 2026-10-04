# fps's integration test: the loader and the renderer over both test
# maps, then two broken maps. Each map's tree goes on the machine as a
# romfs image built here, the manifest's image being the factory's:
# the UART reports the load with its counts, which must be the tree's
# from map.nuon and tile.nuon; then the first frame with its phases and
# counts, every pixel of the start view reached by a surface but a
# rounding's worth, and the same for the frames drawn from camera poses
# the console places over the sloped sectors; the API's state records
# carry the camera at the spawn, its eye over the floor there, facing
# the spawn's way, then in each pose's sector after its console record;
# the screen is drawn; QEMU has nothing to say. Then a sprite of the
# test's own texture, a walk on the pad, the proof map of our own
# content with its window, grate, door, and plan views and its android
# drawn, the stair on it walked to the upper storey, the factory, the
# game's map, from its spawn and three poses with the sky read off the
# yard's capture and two traces answered, its flights and driveway
# walked from placed starts with the ambient following, the fight: an
# android roused and firing, struck down by four rounds from the
# console and one from the trigger, fallen, its magazine taken on a
# walk, the shots heard; the light's view independence, floor points
# of the bay read from the spawn at two yaws on a still copy of the
# factory and a lightless one, the light alone the same from both; the
# alpha policy rendered, a texture of the test's own on the proof map's
# grate wall read from poses at three levels, each patch present in its
# exact colour where the oracle's scaled means pass, the weighted mean
# of the shrink among those colours, and the solid backdrop behind
# where they do not, the lit loop's picture from the same build
# agreeing at every level, and with level 0 alone built the mid pose's
# blocks taking the chain at their own level and agreeing too, fewer
# tiles built and read than with every level, the same poses under the
# room's own light within TheUser's bound, tiled against lit; the
# texel-centre rule, a white texture on that wall under lumels set as a
# checkerboard, each texel beside a node read from its tile at the
# light of its centre by the test's own bilinear; one
# level a block, the still factory's spawn view with every level built
# against the tiles held off, identical over the screen with the far
# floor's blocks past the tiles' levels; the flow's three fixtures, a sprite straddling a
# doorway drawn whole beside it, the eye on the line two sectors share
# reaching the sector behind it, and a map where a hall's rectangle
# grows through a later path before the room beyond it can be reached;
# a map whose magic is wrong, which exits 6, and one cut short, which
# exits 7, each saying so on the UART.
use ../../../../sdk/nu/jab.nu
use ../nu/map.nu
use ../nu/png.nu
use ./pose.nu
use ./gauge.nu
use std/assert

const LOAD = "fps: {name} loaded in {ms} ms: {sectors} sectors, {walls} walls, {vertices} vertices, {portals} portals, {entities} entities, {lights} lights, {lumel_maps} lumel maps, {sprites} sprites, {materials} materials, {textures} textures, {missing} missing"
const FRAME = "fps: frame in {us} us: {sectors} sectors, {walls} walls, {pieces} pieces, {planes} planes, {openings} openings, {sprites} sprites, {uncovered} uncovered; clear, planes, walls, portals, sprites us {clear}, {plane_us}, {wall_us}, {portal_us}, {sprite_us}; spans {spans}, pixels {pixels}, lit spans {lit_spans}, lit pixels {lit_pixels}, light us {light_us}, rejected {rejected}, samples {samples}, tiles built {tiles_built}, tiled {tiled}, resets {resets}"
const PIXELS = (1920 * 1080)
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
# millimetres); kinds 7 and 8 the frame before's clock and its drawing,
# sent at each frame's start, and 9 the end of a measurement, which
# gauge.nu reads (`gauge measure`) and `records` leaves out
const RECORD = 64
const CLOCK_KINDS = [7 8 9]
# A console record carries the command's byte where the state's sector
# sits; the P frame's
const CONSOLE_P = 80
# The clock over the factory walk: the seed sent before the first frame
# and the E closing the measurement half a second before the capture
const CLOCK_SEED = 7
const CLOCK_SEED_AT = 200ms
const CLOCK_END_AT = 13500ms
const MET_GEOMETRY = 1
const MET_ANDROID = 2
const ROUSED = 1
const FIRED = 2
const DESTROYED = 4
const FALLEN = 5
const TRACE_PLANE = 1
const TRACE_PIECE = 2
# Fixtures for the current test content, the two sample maps: the sector
# holding each map's spawn as the host-side read has it; camera poses
# the console places after the load, the eye in metres with z up, each
# over a sloped sector looking at its slope, with the sector the camera
# lands in, cage2's third a unit under the lightbulb at (2.5, -5, 2) in
# the start's hall, looking 60 degrees down, and doortest's third three
# units north of its first sprite in the room south of the start; that
# sprite's entity index, for the sprite launch; the blocks of cage2's
# bulb pose read for the light, [x, y, w, h], the floor under the bulb
# at the bottom of the screen and the far wall at the top; the
# straddling sprite, a fixed two-sided quad of the opaque alpha case's
# texture with its feet in the quarter-metre door sector north of the
# sprite room and its quad along y through both of that sector's
# portal walls, the pose in the room seeing it obliquely so the quad's
# near end lies over the solid wall beside the doorway, outside the
# sector's rectangle, and a point on that near end
const CONTENT = {
    start_sector: { cage2: 1, doortest: 2 },
    poses: {
        cage2: [
            { name: "ramp", sector: 29, x: 22.0625, y: 0.5, z: 2.15625, yaw: 180, pitch: -30 },
            { name: "ceiling", sector: 3, x: 11.875, y: -10.5, z: -0.734375, yaw: -90, pitch: 30 },
            { name: "bulb", sector: 1, x: 2.5, y: -5.0, z: 1.0, yaw: 0, pitch: -60 },
        ],
        doortest: [
            { name: "valley", sector: 24, x: 9.0625, y: -6.03125, z: 5.296875, yaw: 0, pitch: -30 },
            { name: "pit", sector: 29, x: 4.645833, y: -19.104166, z: 8.483105, yaw: 45, pitch: -30 },
            { name: "sprite", sector: 0, x: 0.0, y: -6.0, z: -0.25, yaw: -90, pitch: 0 },
        ],
    },
    sprite: { entity: 1 },
    lit: { near: [860, 980, 200, 100], far: [860, 0, 200, 100] },
    straddle: {
        entity: { x: -1.7, y: -4.9, z: -2.0, yaw: 0.0, width: 1.5, height: 1.0, sector: 17 },
        pose: { name: "straddle", x: 1.5, y: -6.5, z: -0.4, yaw: 165, pitch: 0 },
        point: [-1.7, -5.5, -1.5],
    },
}
# The sprite launch: doortest's tree with its first sprite given a
# material of the test's own, a texture whose left half is transparent
# and right half red, and made to face the camera; seen from the
# `sprite` pose the sprite fills the middle of the screen, its right
# half red and its left half the wall behind
const SPRITE_MATERIAL = "sprite/test"
const SPRITE_FLAGS = 5              # facing the camera, two-sided
const RED = 0x[ff 00 00]
const SPRITE_LEFT = [760, 540]
const SPRITE_RIGHT = [1160, 540]
# The straddling sprite's texture, the uniform alpha case over the pass,
# its colour as the unlit map draws it, and its flags: fixed, two-sided
const STRADDLE_MATERIAL = "test/opaque"
const STRADDLE_COLOUR = 0x[40 80 c0]
const STRADDLE_FLAGS = 4
# The alpha cases, textures of the test's own laid in the sprite tree as
# materials beside the sprite's: the sprite's halves; a uniform alpha
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
    { name: "test/opaque", w: 64, h: 64, kind: "uniform", alpha: 200 },
    { name: "test/faint", w: 64, h: 64, kind: "uniform", alpha: 100 },
    { name: "test/checker", w: 64, h: 64, kind: "checker", alpha: 255 },
    { name: "test/small", w: 8, h: 8, kind: "block", alpha: 255 },
    { name: "test/edge", w: 4, h: 4, kind: "edge", alpha: 128 },
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
# The alpha policy rendered: the proof map's grate wall given a texture
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
const FIXTURE_MAP = "proof_alpha"
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
# The light: the bottom block's mean brightness over the top's, at
# least; the top block is a metre and a half further from the bulb and
# at a lower cosine, while the hall's other bulbs light both
const LIT_RATIO = 1.1
# The walk: from doortest's spawn south through the rooms until the
# stick is released; the eye's height over the feet
const EYE_HEIGHT = 1.6
const BODY_RADIUS = 0.351
# The sound: a recording's peak sample under this is silence, and a
# window with a peak at or over this and a mean an eighth of it is
# heard, out of 32767
const SOUND_SILENCE = 8
const SOUND_HEARD = 64
# The factory: the spawn view's bound here, loose since a host's first
# launch can read double the lane's 23 to 25 ms, the budget of 33 ms
# being read by hand from the printed line; the pixel of the yard's
# capture read for the sky, near the top where the sky texture's solid
# top band lands at pitch 0, and that band's colour
const FACTORY_START_BOUND = 100000
const SKY_PIXEL = [960, 100]
const SKY_TOP = 0x[3a 6f b0]
const CROSSHAIR = [960, 540]
# the functions whose loops run a pixel or a sample, and the span loop
# with the helpers it calls, each within one page of code (render.inc's
# CODE_PAGE) and trapping only where the mixer's two calls a frame are
const HOT_FUNCTIONS = [
    span_fill span_light tile_build mixer_update
    row_crossings span_bound row_range poly_fill span_record
]
const HOT_ECALLS = {
    span_fill: 0, span_light: 0, tile_build: 0, mixer_update: 2,
    row_crossings: 0, span_bound: 0, row_range: 0, poly_fill: 0, span_record: 0,
}
# the span loop's family, together on one page: poly_fill's loop runs
# once a span and calls span_bound twice a span, so a member on another
# page costs every span a lookup, which each member within a page of its
# own does not catch
const HOT_FAMILY = [row_crossings span_bound row_range poly_fill span_record]
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
# The traces from the factory's window and yard poses: the window's
# ray reaches the bay's floor, the yard's the street's far wall
const TRACE_SLACK = 50
# The light's view independence: six floor points of the bay under and
# between its lights, read from the spawn's eye at two yaws, and the
# levels of 256 the light alone may differ by across the yaws
const VIEW_POINTS = [[26.0, 6.0], [15.0, 6.0], [18.0, 4.0], [22.0, 8.0], [20.0, 12.0], [24.0, 16.0]]
const VIEW_EYE = { x: 29.0, y: 2.5, z: 1.6 }
const VIEW_YAWS = [170, 130]
const VIEW_SLACK = 4
# The factory's spawn view, the spawn's eye and yaw, for one level a
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
    let trees = ($game | path join ".target" "asset")
    mut runs = []
    for map in [doortest cage2] {
        let tree = ($trees | path join $map)
        assert (($tree | path join "map.nuon") | path exists) $"a test tree for ($map)"
        let expected = (open ($tree | path join "map.nuon"))
        let tiles = (open ($tree | path join "tile.nuon"))
        let disk = (romfs $tree ($out | path join $"($map).romfs"))
        let poses = ($CONTENT.poses | get $map)
        let sends = ($poses | enumerate | each {|e| { at: (1500ms + ($e.index * 500ms)), bytes: (pose pose-frame $e.item) } })
        let run = (jab launch --kernel $kernel --image $image --out ($out | path join $map) --set $set --sound --api --disk $disk --serial "fps" --send $sends --capture 3000ms --seconds 8)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($map)"
        let lines = ($run.serial | lines)

        # the load
        let reports = ($lines | where {|l| $l starts-with $"fps: ($map) loaded" })
        assert equal ($reports | length) 1 $"the load reported once on ($map): ($run.serial)"
        let parsed = ($reports | get 0 | parse $LOAD)
        assert (not ($parsed | is-empty)) $"the load line's shape on ($map): ($reports | get 0)"
        let load = ($parsed | get 0 | update cells {|c| if $c =~ '^\d+$' { $c | into int } else { $c } })
        for f in [sectors walls vertices portals entities lights sprites materials] {
            assert equal ($load | get $f) ($expected | get $f) $"($map)'s ($f) as the tree has it: ($reports | get 0)"
        }
        assert equal $load.materials ($tiles | length) $"($map)'s materials as tile.nuon has them"
        assert equal $load.textures ($expected.materials - $expected.unresolved) $"($map)'s textures, the materials the tree carries"
        assert equal $load.missing $expected.unresolved $"($map)'s materials the tree lacks"
        assert ($load.ms > 0 and $load.ms < 20000) $"($map) loaded in a plausible time: ($load.ms) ms"
        let named = ($lines | where {|l| $l starts-with "fps: material " })
        assert equal ($named | length) $expected.unresolved $"($map)'s missing materials named on the UART: ($named)"
        let map_read = (map read ($tree | path join "map" $"($map).jabfps.map"))

        # the first frame, then one a pose
        let frames = ($lines | where {|l| $l starts-with "fps: frame in" })
        assert equal ($frames | length) (1 + ($poses | length)) $"the first frame and each pose's reported on ($map): ($run.serial)"
        let parsed = ($frames | each {|f| $f | parse $FRAME })
        assert ($parsed | all {|f| not ($f | is-empty) }) $"the frame lines' shape on ($map): ($frames)"
        let parsed = ($parsed | each {|f| $f | get 0 | update cells {|c| $c | into int } })
        let frame = ($parsed | get 0)
        assert ($frame.sectors > 0 and $frame.walls > 0 and $frame.pieces > 0 and $frame.planes > 0) $"the frame drew the world on ($map): ($frame)"
        assert ($frame.us < 1000000) $"the frame within a bound here on ($map): ($frame.us) us"
        for f in $parsed {
            assert ($f.uncovered < $CRACKS) $"every pixel of the view reached by a surface but a rounding's worth on ($map): ($f)"
        }

        # the camera over the API: at the spawn, the eye over the floor
        # there, facing the spawn's way
        let records = (records $run.api)
        let states = ($records | where kind == 1)
        assert (($states | length) > 10) $"a state a frame over the API on ($map): ($states | length) records"
        let first = ($states | get 0)
        assert equal $first.sector ($CONTENT.start_sector | get $map) $"the camera in the spawn's sector on ($map): ($first.sector)"
        let spawn = $expected.spawn
        let shove = ((($first.x - $spawn.at.0) ** 2 + ($first.y - $spawn.at.1) ** 2) | math sqrt)
        assert ($shove <= $BODY_RADIUS) $"the eye stands at the spawn, or a body's radius off a wall there, on ($map): ($first.x), ($first.y) against ($spawn.at), ($shove) off"
        let floor = (map plane-z ($map_read.sectors | get $first.sector | get floor) $first.x $first.y)
        assert ((($first.z - ($floor + $EYE_HEIGHT)) | math abs) < 0.01) $"the eye its height over the floor on ($map): ($first.z) over a floor at ($floor)"
        assert ((($first.yaw - $spawn.yaw) | math abs) < 0.01 and (($first.pitch - $spawn.pitch) | math abs) < 0.01 and $first.roll == 0.0) $"the camera faces the spawn's way on ($map): ($first.yaw), ($first.pitch), ($first.roll) against ($spawn.yaw), ($spawn.pitch)"
        # each pose's console record, then the camera in the pose's sector
        let consoles = ($records | enumerate | where {|r| $r.item.kind == 11 })
        assert equal ($consoles | length) ($poses | length) $"a console record a pose on ($map): ($consoles | length)"
        for e in ($consoles | enumerate) {
            let landed = ($records | slice ($e.item.index + 1).. | where kind == 1 | get -o 0)
            let pose_at = ($poses | get $e.index)
            assert ($landed != null) $"a state after the pose ($pose_at.name) on ($map)"
            assert equal $landed.sector $pose_at.sector $"the camera in the pose ($pose_at.name)'s sector on ($map): ($landed.sector)"
        }

        # the screen, drawn; cage2's lit, the floor under the bulb
        # brighter than the far wall
        assert ($run.screen != "") $"a screen was taken on ($map)"
        assert (not (black-screen $run.screen)) $"the screen is drawn on ($map)"
        if $map == "cage2" {
            let near = (mean-brightness $run.screen $CONTENT.lit.near)
            let far = (mean-brightness $run.screen $CONTENT.lit.far)
            assert ($near > ($far * $LIT_RATIO)) $"the floor under the bulb is lit against the far wall: ($near) against ($far)"
        }
        $runs = ($runs | append { map: $map, load_ms: $load.ms, frame: $frame, poses: ($parsed | slice 1..), states: ($states | length), cpu: $run.cpu_seconds, screen: $run.screen })
    }

    # a sprite: doortest's tree with its first sprite given the test
    # texture and made to face the camera, seen from the sprite pose
    let plain = ($runs | where map == "doortest" | get 0.screen)
    let sprite_tree = (sprite-tree ($trees | path join "doortest") ($out | path join "sprite_tree"))
    let sprite_pose = ($CONTENT.poses.doortest | last)
    let sprite_run = (jab launch --kernel $kernel --image $image --out ($out | path join "sprite") --set $set --sound --api --disk (romfs $sprite_tree ($out | path join "sprite.romfs")) --serial "fps" --send [{ at: 1500ms, bytes: (pose pose-frame $sprite_pose) }] --capture 2500ms --seconds 5)
    assert equal (open --raw $sprite_run.qemu_log) "" $"QEMU has no complaint about the guest on the sprite run"
    let sprite_lines = ($sprite_run.serial | lines)
    assert (($sprite_lines | where {|l| $l starts-with "fps: doortest loaded" } | length) == 1) $"the sprite tree loaded: ($sprite_run.serial)"
    let sprite_frames = ($sprite_lines | where {|l| $l starts-with "fps: frame in" })
    assert equal ($sprite_frames | length) 2 $"the first frame and the sprite pose's reported: ($sprite_run.serial)"
    let sprite_frame = ($sprite_frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
    assert ($sprite_frame.sprites >= 1) $"the sprite drawn from the sprite pose: ($sprite_frame)"
    assert ($sprite_frame.uncovered < $CRACKS) $"the sprite view has no pixel uncovered: ($sprite_frame)"
    assert ($sprite_run.screen != "") "a screen was taken on the sprite run"
    assert equal (pixel $sprite_run.screen $SPRITE_RIGHT) $RED $"the sprite's right half is the texture's red: ($sprite_run.screen)"
    assert equal (pixel $sprite_run.screen $SPRITE_LEFT) (pixel $plain $SPRITE_LEFT) $"the sprite's transparent left half shows the wall behind, as the plain run drew it"
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
    # the straddling sprite, seen obliquely from the room: its quad's
    # near end over the solid wall beside the doorway reads the texture,
    # the quad drawn over the whole screen as one not proven within its
    # sector, where a clip to the sector's rectangle would cut it off
    let straddle_pose = $CONTENT.straddle.pose
    let straddle_run = (jab launch --kernel $kernel --image $image --out ($out | path join "straddle") --set $set --sound --api --disk ($out | path join "sprite.romfs") --serial "fps" --send [{ at: 1500ms, bytes: (pose pose-frame $straddle_pose) }] --capture 2500ms --seconds 5)
    assert equal (open --raw $straddle_run.qemu_log) "" "QEMU has no complaint about the guest on the straddle run"
    let straddle_frames = ($straddle_run.serial | lines | where {|l| $l starts-with "fps: frame in" })
    assert equal ($straddle_frames | length) 2 $"the first frame and the straddle pose's reported: ($straddle_run.serial)"
    let straddle_frame = ($straddle_frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
    assert ($straddle_frame.sprites >= 1) $"the straddling sprite drawn: ($straddle_frame)"
    assert ($straddle_frame.uncovered < $CRACKS) $"the straddle view has no pixel uncovered: ($straddle_frame)"
    assert ($straddle_run.screen != "") "a screen was taken on the straddle run"
    let straddle_at = (project { x: $straddle_pose.x, y: $straddle_pose.y, z: $straddle_pose.z } $straddle_pose.yaw $CONTENT.straddle.point)
    assert ($straddle_at != null) $"the straddling quad's near end is on screen from ($straddle_pose)"
    assert equal (pixel $straddle_run.screen $straddle_at) $STRADDLE_COLOUR $"the straddling quad's near end at ($straddle_at), beside the doorway, reads its texture: ($straddle_run.screen)"

    # the walk: the left stick held forward from doortest's spawn, the
    # body south through the doorway and the hall into the room beyond
    # until its wall, the eye riding the floor
    let walk_run = (jab launch --kernel $kernel --image $image --out ($out | path join "walk") --set $set --sound --api --pad ($env.FILE_PWD | path join "table_walk.nuon") --disk ($out | path join "doortest.romfs") --serial "fps" --capture 6000ms --seconds 7)
    assert equal (open --raw $walk_run.qemu_log) "" "QEMU has no complaint about the guest on the walk"
    let walk_states = (records $walk_run.api | where kind == 1)
    assert (($walk_states | length) > 100) $"states through the walk: ($walk_states | length)"
    let walk_first = ($walk_states | first)
    let walk_last = ($walk_states | last)
    assert equal $walk_first.sector $CONTENT.start_sector.doortest "the walk starts in the spawn's sector"
    assert ($walk_last.y < ($walk_first.y - 8.0)) $"the body walked south: from ($walk_first.y) to ($walk_last.y)"
    let walk_map = (map read ($trees | path join "doortest" "map" "doortest.jabfps.map"))
    let end_sector = (map sector-holding $walk_map $walk_last.x $walk_last.y ($walk_last.z - $EYE_HEIGHT))
    assert equal $walk_last.sector $end_sector $"the body ended in the sector holding its feet, as the host reads the map: ($walk_last.x), ($walk_last.y) in ($walk_last.sector), the host's ($end_sector)"
    let floor = (map plane-z ($walk_map.sectors | get $walk_last.sector | get floor) $walk_last.x $walk_last.y)
    assert ((($walk_last.z - ($floor + $EYE_HEIGHT)) | math abs) < 0.05) $"the eye rides the floor: ($walk_last.z) over a floor at ($floor)"
    let before_last = ($walk_states | get (($walk_states | length) - 2))
    assert ((($walk_last.y - $before_last.y) | math abs) < 0.01) $"the body stands once the stick is released: ($before_last.y) then ($walk_last.y)"
    let walk_sectors = ($walk_states | get sector | uniq)
    assert (($walk_sectors | length) >= 3) $"the walk crossed sectors: ($walk_sectors)"
    let walk_x_off = ($walk_states | each {|s| ($s.x - $walk_first.x) | math abs } | math max)
    assert ($walk_x_off < 0.5) $"the walk held its line: ($walk_x_off) off in x"

    # the proof map, our own content: loaded and held to its counts, the
    # sign drawn from the spawn, the stairwell seen from the upper room
    # through its window and the alcove through the grate, the door
    # tagged, and a plan view a storey at the storey's bounds
    let proof_tree = ($trees | path join "proof")
    let proof_source = (open ($game | path join "content" "map" "proof.nuon"))
    let proof_expected = (open ($proof_tree | path join "map.nuon"))
    let proof_read = (map read ($proof_tree | path join "map" "proof.jabfps.map"))
    let proof_index = {|name: string| $proof_source.sectors | enumerate | where {|s| $s.item.name == $name } | get 0.index }
    # the line pose stands with the eye on the line the hall and the
    # door sectors share, looking into the hall, which the flow reaches
    # only by its facing slack, the eye's distance from the wall's line
    # being zero there
    let proof_poses = [
        { name: "window", sector: (do $proof_index "upper_room"), x: 5.0, y: 4.0, z: 4.85, yaw: 0, pitch: -20, sees: (do $proof_index "step1") },
        { name: "grate", sector: (do $proof_index "north"), x: 9.0, y: 11.0, z: 1.6, yaw: 0, pitch: 0, sees: (do $proof_index "alcove") },
        { name: "line", sector: (do $proof_index "door"), x: 4.0, y: 8.0, z: 1.6, yaw: 270, pitch: 0, sees: (do $proof_index "hall") },
        { name: "door", sector: (do $proof_index "hall"), x: 4.0, y: 5.0, z: 1.6, yaw: 90, pitch: 0, sees: (do $proof_index "north") },
    ]
    # the rendered assets the tree carries: the hum a Standard MIDI File
    # of one track, the servo the recipe's seconds of 16-bit samples
    assert equal $proof_expected.ambients 1 "proof names one ambient"
    let recipes = (glob ($game | path join "content" "sound" "*.nuon") | length)
    assert equal $proof_expected.sounds $recipes $"proof's tree carries every sound the content holds: ($proof_expected.sounds) against ($recipes) recipes"
    let hum = (open --raw ($proof_tree | path join "ambient" "hum.mid") | into binary)
    assert equal ($hum | bytes at 0..<4) ("MThd" | into binary) "the hum is a Standard MIDI File"
    assert equal ($hum | bytes at 8..<10 | into int --endian big) 0 "the hum is format 0"
    assert equal ($hum | bytes at 10..<12 | into int --endian big) 1 "the hum holds one track"
    let servo_recipe = (open ($game | path join "content" "sound" "servo.nuon"))
    let servo = (open --raw ($proof_tree | path join "sound" "servo.pcm") | into binary)
    assert equal ($servo | bytes length) (((($servo_recipe.seconds | into float) * 48000) | math round | into int) * 2) "the servo is its seconds of 16-bit samples"
    let proof_sends = ($proof_poses | enumerate | each {|e| { at: (1500ms + ($e.index * 500ms)), bytes: (pose pose-frame $e.item) } })
    let proof_disk = (romfs $proof_tree ($out | path join "proof.romfs"))
    let proof_run = (jab launch --kernel $kernel --image $image --out ($out | path join "proof") --set $set --sound --api --disk $proof_disk --serial "fps" --send $proof_sends --capture 5500ms --seconds 6)
    assert equal (open --raw $proof_run.qemu_log) "" "QEMU has no complaint about the guest on proof"
    let proof_lines = ($proof_run.serial | lines)
    let proof_reports = ($proof_lines | where {|l| $l starts-with "fps: proof loaded" })
    assert equal ($proof_reports | length) 1 $"the load reported once on proof: ($proof_run.serial)"
    let proof_load = ($proof_reports | get 0 | parse $LOAD | get 0 | update cells {|c| if $c =~ '^\d+$' { $c | into int } else { $c } })
    for f in [sectors walls vertices portals entities lights sprites materials] {
        assert equal ($proof_load | get $f) ($proof_expected | get $f) $"proof's ($f) as the tree has it: ($proof_reports | get 0)"
    }
    assert equal $proof_load.textures $proof_expected.materials "proof's materials all textures"
    assert equal $proof_load.missing 0 "proof's materials all in the tree"
    assert ($FRAMES_LINE in $proof_lines) $"the engine's images all in proof's tree: ($proof_lines | where {|l| $l starts-with 'fps: frame' })"
    assert ($SOUNDS_LINE in $proof_lines) $"the engine's sounds all in proof's tree: ($proof_lines | where {|l| $l starts-with 'fps: sound' })"
    # the soundfont off the generic disk, and the hum playing once the
    # camera stands in the north room
    let fonts = ($proof_lines | where {|l| $l starts-with "fps: soundfont " })
    assert equal ($fonts | length) 1 $"the soundfont reported once on proof: ($proof_run.serial)"
    let font = ($fonts | get 0 | parse "fps: soundfont {presets} presets, {instruments} instruments, {samples} samples")
    assert (not ($font | is-empty)) $"the soundfont loaded off the generic disk: ($fonts | get 0)"
    assert (($font | get 0.presets | into int) > 0) $"the soundfont holds presets: ($fonts | get 0)"
    assert ("fps: ambient 0 playing" in $proof_lines) $"the hum plays in the north room: ($proof_lines | where {|l| $l starts-with 'fps: ambient' })"
    # and is heard: the run's recording silent while the camera stands
    # in the hall, sounding once it stands in the north room and the
    # pad has swelled; the recording ends at the screen capture
    assert ($proof_run.sound != "") "the proof run recorded its sound"
    let hall_level = (sound-level $proof_run.sound 0.3 1.4)
    let room_level = (sound-level $proof_run.sound 3.5 5.4)
    assert ($hall_level.peak < $SOUND_SILENCE) $"the hall is silent, having no ambient: ($hall_level)"
    assert ($room_level.peak >= $SOUND_HEARD and $room_level.mean >= ($SOUND_HEARD / 8)) $"the hum is heard in the north room: ($room_level) against silence ($hall_level)"
    let proof_frames = ($proof_lines | where {|l| $l starts-with "fps: frame in" } | each {|f| $f | parse $FRAME | get 0 | update cells {|c| $c | into int } })
    assert equal ($proof_frames | length) (1 + ($proof_poses | length)) $"the first frame and each pose's reported on proof: ($proof_run.serial)"
    for f in $proof_frames {
        assert ($f.uncovered < $CRACKS) $"every pixel of the view reached by a surface on proof: ($f)"
    }
    assert (($proof_frames | get 0 | get sprites) >= 1) $"the sign drawn from the spawn: ($proof_frames | get 0)"
    assert (($proof_frames | last | get sprites) >= 2) $"the sign and the north room's android drawn from the door: ($proof_frames | last)"
    let proof_sectors = ($proof_lines | where {|l| $l starts-with "fps: sectors " } | each {|l| $l | str substring 13.. | str trim | split row " " | each {|s| $s | into int } })
    assert equal ($proof_sectors | length) ($proof_frames | length) $"a sectors line a reported frame on proof: ($proof_sectors | length)"
    for e in ($proof_poses | enumerate) {
        let drawn = ($proof_sectors | get ($e.index + 1))
        assert ($e.item.sees in $drawn) $"the pose ($e.item.name) sees sector ($e.item.sees) through its opening: ($drawn)"
    }
    let proof_records = (records $proof_run.api)
    let proof_states = ($proof_records | where kind == 1)
    assert (($proof_states | length) > 10) $"a state a frame on proof: ($proof_states | length)"
    assert equal ($proof_states | get 0.sector) ($proof_read.entities | where class == 0 | get 0.sector) "the camera in the spawn's sector on proof"
    let proof_consoles = ($proof_records | enumerate | where {|r| $r.item.kind == 11 })
    assert equal ($proof_consoles | length) ($proof_poses | length) $"a console record a pose on proof: ($proof_consoles | length)"
    for e in ($proof_consoles | enumerate) {
        let landed = ($proof_records | slice ($e.item.index + 1).. | where kind == 1 | get -o 0)
        let pose_at = ($proof_poses | get $e.index)
        assert ($landed != null) $"a state after the pose ($pose_at.name) on proof"
        assert equal $landed.sector $pose_at.sector $"the camera in the pose ($pose_at.name)'s sector on proof: ($landed.sector)"
    }
    assert equal ($proof_read.sectors | get (do $proof_index "door") | get tag) 1 "the door sector carries its tag"
    # the grate as authored: its coarser levels' share within the slack
    alpha-held $proof_lines "texture/grate"
    let proof_mips = (mips-built $proof_lines)
    plan-views $proof_tree $proof_source $proof_read

    # the stair: from the proof map's spawn the left stick held forward
    # up the three steps onto the landing, a quarter turn to the north,
    # then up the ramp into the upper hall
    let stair_run = (jab launch --kernel $kernel --image $image --out ($out | path join "stair") --set $set --sound --api --pad ($env.FILE_PWD | path join "table_stair.nuon") --disk $proof_disk --serial "fps" --capture 8000ms --seconds 9)
    assert equal (open --raw $stair_run.qemu_log) "" "QEMU has no complaint about the guest on the stair"
    let stair_states = (records $stair_run.api | where kind == 1)
    assert (($stair_states | length) > 100) $"states through the stair: ($stair_states | length)"
    let stair_first = ($stair_states | first)
    let stair_last = ($stair_states | last)
    assert equal $stair_first.sector (do $proof_index "hall") "the stair walk starts in the hall"
    assert equal $stair_last.sector (do $proof_index "upper_hall") $"the body ended in the upper hall: ($stair_last.x), ($stair_last.y), ($stair_last.z) in ($stair_last.sector)"
    let stair_floor = (map plane-z ($proof_read.sectors | get $stair_last.sector | get floor) $stair_last.x $stair_last.y)
    assert ((($stair_last.z - ($stair_floor + $EYE_HEIGHT)) | math abs) < 0.05) $"the eye rides the upper floor: ($stair_last.z) over ($stair_floor)"
    let stair_sectors = ($stair_states | get sector | uniq)
    let stair_way = ([step1 step2 step3 landing ramp upper_hall] | each {|n| do $proof_index $n })
    let stair_order = ($stair_way | each {|s| $stair_sectors | enumerate | where {|e| $e.item == $s } | get -o 0.index })
    assert ($stair_order | all {|i| $i != null }) $"the body crossed every step, the landing, and the ramp: ($stair_sectors) against ($stair_way)"
    assert (($stair_order | window 2 | all {|w| $w.0 < $w.1 })) $"in order: ($stair_sectors)"

    # the factory, the game's map: loaded and held to its counts with
    # every material and ambient in the tree, the bay's ambient playing
    # from the spawn, the spawn view lit within its bound; then the
    # poses: the office window down onto the bay, the garage toward its
    # door, and the yard under the sky, whose capture carries the sky
    # texture's top band; each door sector tagged, a plan view a storey
    let factory_tree = ($trees | path join "factory")
    let factory_source = (open ($game | path join "content" "map" "factory.nuon"))
    let factory_expected = (open ($factory_tree | path join "map.nuon"))
    let factory_read = (map read ($factory_tree | path join "map" "factory.jabfps.map"))
    let factory_index = {|name: string| $factory_source.sectors | enumerate | where {|s| $s.item.name == $name } | get 0.index }
    let factory_ambient = {|name: string| $factory_read.ambients | enumerate | where {|a| $a.item.name == $"ambient/($name)" } | get 0.index }
    let factory_poses = [
        { name: "window", sector: (do $factory_index "office_hall"), x: 8.75, y: 17.0, z: 4.6, yaw: 0, pitch: -15, sees: (do $factory_index "bay") },
        { name: "garage", sector: (do $factory_index "garage"), x: 16.0, y: 14.0, z: -1.4, yaw: 0, pitch: 0, sees: (do $factory_index "drive_low") },
        { name: "yard", sector: (do $factory_index "yard"), x: 40.0, y: 6.0, z: 1.6, yaw: 90, pitch: 0, sees: (do $factory_index "beyond") },
    ]
    assert equal $factory_expected.unresolved 0 $"the factory names nothing the content lacks: ($factory_expected.missing)"
    assert equal $factory_expected.ambients 5 "the factory names five ambients"
    # a trace a quarter second after the window pose and after the yard's
    let factory_sends = (($factory_poses | enumerate | each {|e| { at: (1500ms + ($e.index * 500ms)), bytes: (pose pose-frame $e.item) } })
        | append [{ at: 1750ms, bytes: (pose command-frame "T") }, { at: 2750ms, bytes: (pose command-frame "T") }]
        | sort-by at)
    let factory_disk = (romfs $factory_tree ($out | path join "factory.romfs"))
    let factory_run = (jab launch --kernel $kernel --image $image --out ($out | path join "factory") --set $set --sound --api --disk $factory_disk --serial "fps" --send $factory_sends --capture 3500ms --seconds 5)
    assert equal (open --raw $factory_run.qemu_log) "" "QEMU has no complaint about the guest on the factory"
    let factory_lines = ($factory_run.serial | lines)
    let factory_reports = ($factory_lines | where {|l| $l starts-with "fps: factory loaded" })
    assert equal ($factory_reports | length) 1 $"the load reported once on the factory: ($factory_run.serial)"
    let factory_load = ($factory_reports | get 0 | parse $LOAD | get 0 | update cells {|c| if $c =~ '^\d+$' { $c | into int } else { $c } })
    for f in [sectors walls vertices portals entities lights sprites materials] {
        assert equal ($factory_load | get $f) ($factory_expected | get $f) $"the factory's ($f) as the tree has it: ($factory_reports | get 0)"
    }
    assert equal $factory_load.textures $factory_expected.materials "the factory's materials all textures"
    assert equal $factory_load.missing 0 "the factory's materials all in the tree"
    assert ($FRAMES_LINE in $factory_lines) $"the engine's images all in the factory's tree: ($factory_lines | where {|l| $l starts-with 'fps: frame' })"
    assert ($SOUNDS_LINE in $factory_lines) $"the engine's sounds all in the factory's tree: ($factory_lines | where {|l| $l starts-with 'fps: sound' })"
    assert (($factory_lines | where {|l| $l starts-with "fps: ambient " and ($l | str contains " missing") } | is-empty)) $"every ambient of the factory in the tree: ($factory_lines | where {|l| $l starts-with 'fps: ambient' })"
    assert ($"fps: ambient (do $factory_ambient 'floor') playing" in $factory_lines) $"the bay's ambient plays from the spawn: ($factory_lines | where {|l| $l starts-with 'fps: ambient' })"
    let factory_frames = ($factory_lines | where {|l| $l starts-with "fps: frame in" } | each {|f| $f | parse $FRAME | get 0 | update cells {|c| $c | into int } })
    assert equal ($factory_frames | length) (1 + ($factory_poses | length)) $"the first frame and each pose's reported on the factory: ($factory_run.serial)"
    for f in $factory_frames {
        assert ($f.uncovered < $CRACKS) $"every pixel of the view reached by a surface on the factory: ($f)"
    }
    let factory_start = ($factory_frames | get 0)
    assert ($factory_start.sectors > 0 and $factory_start.pieces > 0 and $factory_start.planes > 0) $"the spawn view drew the bay: ($factory_start)"
    assert ($factory_start.us < $FACTORY_START_BOUND) $"the spawn view within its bound on the factory: ($factory_start)"
    let factory_sectors = ($factory_lines | where {|l| $l starts-with "fps: sectors " } | each {|l| $l | str substring 13.. | str trim | split row " " | each {|s| $s | into int } })
    assert equal ($factory_sectors | length) ($factory_frames | length) $"a sectors line a reported frame on the factory: ($factory_sectors | length)"
    for e in ($factory_poses | enumerate) {
        let drawn = ($factory_sectors | get ($e.index + 1))
        assert ($e.item.sees in $drawn) $"the pose ($e.item.name) sees sector ($e.item.sees): ($drawn)"
    }
    let factory_records = (records $factory_run.api)
    let factory_states = ($factory_records | where kind == 1)
    assert (($factory_states | length) > 10) $"a state a frame on the factory: ($factory_states | length)"
    assert equal ($factory_states | get 0.sector) (do $factory_index "bay") "the camera in the bay at the spawn"
    let factory_consoles = ($factory_records | enumerate | where {|r| $r.item.kind == 11 and $r.item.sector == $CONSOLE_P })
    assert equal ($factory_consoles | length) ($factory_poses | length) $"a console record a pose on the factory: ($factory_consoles | length)"
    for e in ($factory_consoles | enumerate) {
        let landed = ($factory_records | slice ($e.item.index + 1).. | where kind == 1 | get -o 0)
        let pose_at = ($factory_poses | get $e.index)
        assert ($landed != null) $"a state after the pose ($pose_at.name) on the factory"
        assert equal $landed.sector $pose_at.sector $"the camera in the pose ($pose_at.name)'s sector on the factory: ($landed.sector)"
    }
    # the traces: the window's ray onto the bay's floor, the yard's to
    # the street's far wall at the world's edge
    let traces = ($factory_records | where kind == 6)
    assert equal ($traces | length) 2 $"two traces answered on the factory: ($traces)"
    let window_trace = ($traces | get 0)
    assert equal $window_trace.fields.0 $TRACE_PLANE $"the window's ray met a plane: ($window_trace)"
    assert (($window_trace.fields.4 | math abs) < $TRACE_SLACK) $"the window's ray met the bay's floor: ($window_trace)"
    let yard_trace = ($traces | get 1)
    assert equal $yard_trace.fields.0 $TRACE_PIECE $"the yard's ray met a piece: ($yard_trace)"
    let street_north = ((($factory_source.sectors | where name == "beyond" | get 0.loops.0 | each {|p| $p | get 1 } | math max) * 1000) | into int)
    assert ((($yard_trace.fields.3 - $street_north) | math abs) < $TRACE_SLACK) $"the yard's ray reached the street's far wall at ($street_north) mm: ($yard_trace)"
    assert ($factory_run.screen != "") "a screen was taken on the factory"
    assert equal (pixel $factory_run.screen $SKY_PIXEL) $SKY_TOP $"the sky's top band at ($SKY_PIXEL) from the yard: ($factory_run.screen)"
    # the crosshair: the centre pixel blended half with white, so every
    # channel is at least half scale whatever lies under it
    let centre = (pixel $factory_run.screen $CROSSHAIR)
    assert (([0 1 2] | all {|i| ($centre | bytes at $i..<($i + 1) | into int) >= 128 })) $"the crosshair at ($CROSSHAIR): ($centre | encode hex)"
    for tag in [1 2 3 4 5] {
        assert equal ($factory_read.sectors | where tag == $tag | length) 1 $"one door sector carries tag ($tag)"
    }
    # the fence as authored: each coarser level's share at or above the
    # pass within the slack of the texture's
    alpha-held $factory_lines "texture/fence"
    let factory_mips = (mips-built $factory_lines)
    plan-views $factory_tree $factory_source $factory_read

    # the factory walked, one launch of three placed starts with the
    # left stick held forward after each: the up flight from the hall's
    # foot to the office corridor, the down flight to the garage, and the
    # driveway from the garage door up the ramp to the gate, the sectors
    # crossed in order, the eye riding the floor at each end, and each
    # area's ambient reported as the body enters it
    let factory_starts = [
        { name: "up", at: 1500ms, x: 8.75, y: 3.0, z: 1.6, yaw: 90, pitch: 0, way: [stair_ground up1 up2 up3 up4 up5 up6 office_hall], ambient: "office" },
        { name: "down", at: 5500ms, x: 1.5, y: 3.0, z: 1.6, yaw: 90, pitch: 0, way: [stair_ground down1 down2 down3 down4 down5 down6 garage], ambient: "garage" },
        { name: "ramp", at: 9500ms, x: 34.0, y: 13.0, z: -1.4, yaw: 90, pitch: 0, way: [drive_low drive_ramp], ambient: "yard" },
    ]
    let walk_sends = ([{ at: $CLOCK_SEED_AT, bytes: (gauge seed-frame $CLOCK_SEED) }]
        | append ($factory_starts | each {|s| { at: $s.at, bytes: (pose pose-frame $s) } })
        | append [{ at: $CLOCK_END_AT, bytes: (pose command-frame "E") }]
        | sort-by at)
    let factory_walk = (jab launch --kernel $kernel --image $image --out ($out | path join "factory_walk") --set $set --sound --api --pad ($env.FILE_PWD | path join "table_factory.nuon") --disk $factory_disk --serial "fps" --send $walk_sends --capture 14500ms --seconds 16)
    assert equal (open --raw $factory_walk.qemu_log) "" "QEMU has no complaint about the guest on the factory walk"
    let walk_lines = ($factory_walk.serial | lines)
    let factory_walk_records = (records $factory_walk.api)
    let walk_consoles = ($factory_walk_records | enumerate | where {|r| $r.item.kind == 11 and $r.item.sector == $CONSOLE_P } | get index)
    assert equal ($walk_consoles | length) ($factory_starts | length) $"a console record a start on the factory walk: ($walk_consoles | length)"
    mut factory_walks = []
    for e in ($factory_starts | enumerate) {
        let from = (($walk_consoles | get $e.index) + 1)
        let to = (if ($e.index + 1) < ($factory_starts | length) { $walk_consoles | get ($e.index + 1) } else { $factory_walk_records | length })
        let states = ($factory_walk_records | slice $from..<$to | where kind == 1)
        assert (($states | length) > 50) $"states through the ($e.item.name) walk: ($states | length)"
        let way = ($e.item.way | each {|n| do $factory_index $n })
        let crossed = ($states | get sector | uniq)
        let order = ($way | each {|s| $crossed | enumerate | where {|c| $c.item == $s } | get -o 0.index })
        assert ($order | all {|i| $i != null }) $"the ($e.item.name) walk crossed ($e.item.way): ($crossed)"
        assert (($order | window 2 | all {|w| $w.0 < $w.1 })) $"in order on the ($e.item.name) walk: ($crossed)"
        let last = ($states | last)
        assert equal $last.sector ($way | last) $"the ($e.item.name) walk ended in ($e.item.way | last): ($last)"
        let floor = (map plane-z ($factory_read.sectors | get $last.sector | get floor) $last.x $last.y)
        assert ((($last.z - ($floor + $EYE_HEIGHT)) | math abs) < 0.05) $"the eye rides the floor at the end of the ($e.item.name) walk: ($last.z) over ($floor)"
        assert ($"fps: ambient (do $factory_ambient $e.item.ambient) playing" in $walk_lines) $"the ($e.item.ambient) ambient plays on the ($e.item.name) walk: ($walk_lines | where {|l| $l starts-with 'fps: ambient' })"
        $factory_walks = ($factory_walks | append { name: $e.item.name, first: ($states | first), last: $last, crossed: $crossed, frames: ($states | length) })
    }
    let ramp_end = ($factory_walks | last | get last)
    assert ($ramp_end.y > 27.0) $"the body reached the gate at the ramp's top: ($ramp_end)"

    # the frame's clock over the walk: the seed answered before the first
    # frame, the E closing the measurement with the end marker after its
    # final frame's records, every frame from 0 to it with a frame and a
    # draw record in order at the schema, each frame's phases within its
    # critical path and the drawing's parts within the drawing, the tiles'
    # time within the planes' and the walls', the tiled pixels within the
    # lit, the arena's peak at or past what it holds, and the game going
    # on past the measurement
    let walk_clock = (gauge measure $factory_walk.api [{ name: "walk", places: $factory_starts, pad: [] }])
    assert $walk_clock.seeded "the walk's seed answered before its first frame"
    assert $walk_clock.complete $"the walk's measurement complete: ($walk_clock.problems)"
    assert $walk_clock.valid $"the walk's measurement valid: ($walk_clock.invalid)"
    assert ($walk_clock.past_window > 0) $"the game went on past the measurement: ($walk_clock.past_window) frames"
    let clock_rows = $walk_clock.rows
    let outside = ($clock_rows | where {|r| $r.unattributed_us < 0 or $r.parts_unattributed_us < 0 })
    assert ($outside | is-empty) $"every phase within its frame and every part within its drawing: ($outside | first 3)"
    assert ($clock_rows | all {|r| $r.tiles_us <= ($r.planes_us + $r.walls_us) }) "the tiles' time within the planes' and the walls'"
    assert ($clock_rows | all {|r| $r.tiled_pixels <= $r.lit_pixels }) "the tiled pixels within the lit"
    assert ($clock_rows | all {|r| $r.tile_peak >= $r.tile_bytes }) "the tile arena's peak at or past what it holds"
    assert ($clock_rows | all {|r| $r.aligned }) "each frame record carries its state's drawing and game times"
    print $"fps: the clock over the walk: ($walk_clock.frames) frames to frame ($walk_clock.final), the critical path's median ($walk_clock.whole.critical.median) us, unattributed at most ($walk_clock.whole.unattributed.max) us of a frame and ($walk_clock.whole.parts_unattributed.max) us of a drawing"

    # the fight: the first android, facing the spawn, rouses and fires;
    # from the placed eye four rounds from the console strike it down to
    # the fallen frame, the trigger's round meets the geometry past it,
    # the walk takes its magazine; the shots heard in the recording
    let fight_sends = ([{ at: 1500ms, bytes: (pose pose-frame $FIGHT_POSE) }] | append ($FIGHT_ROUNDS | each {|at| { at: $at, bytes: (pose command-frame "F") } }))
    let fight_run = (jab launch --kernel $kernel --image $image --out ($out | path join "fight") --set $set --sound --api --pad ($env.FILE_PWD | path join "table_fight.nuon") --disk $factory_disk --serial "fps" --send $fight_sends --capture 9500ms --seconds 11)
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
    # from the spawn's eye at two yaws on a copy of the factory with its
    # androids dropped, so no sprite crosses a point, once as lit and
    # once with every lumel set full bright by the console's L frame,
    # both runs rebuilding their tiles from nothing under no budget at
    # the pose so the texture is sampled the same way in both; the lit
    # reading over the bright at a point, the light alone, holds within
    # a few levels across the yaws at every point in view at both
    let view_still = (variant-tree $factory_source "factory_still" [android] ($out | path join "still") $game)
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

    # one level a block: the still factory's spawn view under the bright
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

    # the alpha policy rendered: a copy of the proof map with its grate
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
    let fixture_tree = (alpha-tree $proof_source $game ($out | path join "alpha"))
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
    }
    print $"fps: the alpha poses under the room's light, tiled against lit over the opening: ($light_report | each {|r| $'($r.pose) at level ($r.level), ($r.differing) of ($r.pixels) pixels differ, by ($r.largest) at most' } | str join '; ')"
    for r in $light_report {
        assert ($r.largest <= $REAL_LIGHT_BOUND) $"the ($r.pose) pose under the room's light, tiled against lit over the opening, within ($REAL_LIGHT_BOUND) of 255 a channel: ($r.differing) of ($r.pixels) pixels differ, by ($r.largest) at most"
    }

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
    let centre_tree = (centre-tree $proof_source $game ($out | path join "centre"))
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
    let grow_tree = (grow-tree $game ($out | path join "grow"))
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

    # a map cut short inside its sections
    let cage = (open --raw ($trees | path join "cage2" "map" "cage2.jabfps.map") | into binary)
    let short = (broken ($out | path join "short_tree") "short" ($cage | bytes at 0..<$SHORT_BYTES))
    let short_run = (jab launch --kernel $kernel --image $image --out ($out | path join "short") --set $set --sound --disk (romfs $short ($out | path join "short.romfs")) --serial "fps" --seconds 8)
    assert equal $short_run.status 7 $"a short file exits 7: ($short_run.status), ($short_run.serial)"
    assert ($"fps: /map/short.jabfps.map ends at ($SHORT_BYTES) bytes before its structures do" in ($short_run.serial | lines)) $"and says so: ($short_run.serial)"

    for r in $runs {
        print $"fps: ($r.map) loaded in ($r.load_ms) ms; the first frame in ($r.frame.us) us over ($r.frame.sectors) sectors, ($r.frame.walls) walls, ($r.frame.pieces) pieces, ($r.frame.planes) planes, ($r.frame.openings) openings, ($r.frame.sprites) sprites, ($r.frame.uncovered) uncovered \(clear ($r.frame.clear), planes ($r.frame.plane_us), walls ($r.frame.wall_us), portals ($r.frame.portal_us), sprites ($r.frame.sprite_us) us\); the poses' frames in ($r.poses | each {|p| $p.us } | str join ', ') us with ($r.poses | each {|p| $p.uncovered } | str join ', ') uncovered; ($r.states) frames; QEMU ($r.cpu) CPU seconds"
    }
    print $"fps: the sprite drawn in ($sprite_frame.us) us, ($sprite_frame.sprites) sprites in ($sprite_frame.sprite_us) us, ($sprite_frame.uncovered) uncovered, red at ($SPRITE_RIGHT) and the wall at ($SPRITE_LEFT); the straddling sprite's near end at ($straddle_at) its texture, ($straddle_frame.sprites) sprites in ($straddle_frame.us) us"
    print $"fps: the growth map drew ($grow_sectors) in ($grow_frame.us) us with ($grow_frame.uncovered) uncovered, the far wall at ($grow_at) the backdrop"
    print $"fps: the walk from ($walk_first.x), ($walk_first.y), ($walk_first.z) in ($walk_first.sector) to ($walk_last.x), ($walk_last.y), ($walk_last.z) in ($walk_last.sector) through ($walk_sectors) over ($walk_states | length) frames, the eye ($walk_last.z) over the floor at ($floor)"
    print $"fps: proof loaded in ($proof_load.ms) ms; the spawn view in ($proof_frames | get 0 | get us) us with ($proof_frames | get 0 | get sprites) sprites, the poses in ($proof_frames | slice 1.. | each {|p| $p.us } | str join ', ') us with ($proof_frames | slice 1.. | each {|p| $p.uncovered } | str join ', ') uncovered, drawing ($proof_sectors | slice 1.. | each {|s| $s | length } | str join ' and ') sectors; ($proof_mips.chains) chains of ($proof_mips.levels) levels, ($proof_mips.texels) texels in ($proof_mips.ms) ms"
    print $"fps: the stair from ($stair_first.x), ($stair_first.y), ($stair_first.z) in ($stair_first.sector) to ($stair_last.x), ($stair_last.y), ($stair_last.z) in ($stair_last.sector) through ($stair_sectors) over ($stair_states | length) frames"
    print $"fps: factory loaded in ($factory_load.ms) ms; the spawn view in ($factory_start.us) us over ($factory_start.sectors) sectors, ($factory_start.walls) walls, ($factory_start.pieces) pieces, ($factory_start.planes) planes \(clear ($factory_start.clear), planes ($factory_start.plane_us), walls ($factory_start.wall_us), portals ($factory_start.portal_us) us\); the poses in ($factory_frames | slice 1.. | each {|p| $p.us } | str join ', ') us with ($factory_frames | slice 1.. | each {|p| $p.uncovered } | str join ', ') uncovered, drawing ($factory_sectors | slice 1.. | each {|s| $s | length } | str join ', ') sectors; ($factory_mips.chains) chains of ($factory_mips.levels) levels, ($factory_mips.texels) texels in ($factory_mips.ms) ms"
    for w in $factory_walks {
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
    if ($out | path exists) { rm -r $out }
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
    let family = ($hot | where {|h| $h.name in $HOT_FAMILY })
    assert equal ($family | length) ($HOT_FAMILY | length) "every member of the span loop's family among the hot functions"
    let lowest = ($family | get start | math min)
    let highest = (($family | get end | math max) - 1)
    assert equal ($lowest // 4096) ($highest // 4096) $"the span loop's family within one page of code together: ($lowest) to ($highest)"
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
    let release = ($here | path join ".target" "release" "fps" "fps.jab")
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

# Whether the capture is a screen of the display's size with every
# pixel black: its pixels the same bytes as that many zeros. Read here
# rather than through `jab screen`, whose `open --raw` comes back as a
# string for a file of ASCII and zeros, which an all-black PPM is.
def black-screen [ppm: path]: nothing -> bool {
    let bytes = (open --raw $ppm | into binary)
    let newlines = ($bytes | bytes index-of --all 0x[0a] | take 3)
    let header = ($bytes | bytes at 0..<($newlines.2) | decode | lines)
    if ($header | get 0) != "P6" or ($header | get 1) != "1920 1080" { return false }
    let pixels = ($bytes | bytes at ($newlines.2 + 1)..)
    let zeros = (^head -c ($PIXELS * 3) /dev/zero | hash sha256)
    (($pixels | bytes length) == ($PIXELS * 3)) and (($pixels | hash sha256) == $zeros)
}

# A romfs image of the tree, as the SDK builds one, with the program's
# volume name; the image's path.
def romfs [tree: path, image: path]: nothing -> string {
    let made = (^genromfs -d $tree -f $image -V "fps" | complete)
    if $made.exit_code != 0 { error make { msg: $"genromfs on ($tree): ($made.stderr)" } }
    $image
}

# A copy of a doortest tree with its first sprite given the test
# texture, a material of the test's own, and made to face the camera,
# two-sided, and the alpha cases' textures laid in as materials beside
# it; the map read, changed, and written back through the reader and
# writer, and each texture written from its case; the copy's path.
def sprite-tree [tree: path, out: path]: nothing -> string {
    if ($out | path exists) { rm -r $out }
    cp -r $tree $out
    let map_path = ($out | path join "map" "doortest.jabfps.map")
    let m = (map read $map_path)
    let index = ($m.materials | length)
    let entity = ($m.entities | get $CONTENT.sprite.entity)
    assert equal $entity.class 2 $"the fixture names a sprite entity: ($entity)"
    assert equal ($ALPHA_CASES | get 0.name) $SPRITE_MATERIAL "the sprite's texture is the first alpha case"
    let opaque = ($ALPHA_CASES | enumerate | where {|c| $c.item.name == $STRADDLE_MATERIAL } | get 0.index)
    let s = $CONTENT.straddle.entity
    let straddler = { class: 2, x: $s.x, y: $s.y, z: $s.z, yaw: $s.yaw, pitch: 0.0, width: $s.width, height: $s.height, material: ($index + $opaque), r: 1.0, g: 1.0, b: 1.0, radius: 0.0, spread: 0.0, flags: $STRADDLE_FLAGS, tag: 0, target: -1, sector: $s.sector }
    let patched = ($m
        | update materials ($m.materials | append ($ALPHA_CASES | each {|c| { name: $c.name, flags: 0 } }))
        | update entities ($m.entities | update $CONTENT.sprite.entity {|e| $e | update material $index | update flags $SPRITE_FLAGS } | append $straddler))
    map write $patched | save --raw -f $map_path
    for c in $ALPHA_CASES {
        let file = ($out | path join (map tile-path $c.name | str substring 1..))
        mkdir ($file | path dirname)
        let pixels = (0..<$c.h | each {|y| 0..<$c.w | each {|x| (case-texel $c $x $y).bytes } | bytes collect } | bytes collect)
        png write-rgba $file $c.w $c.h $pixels
    }
    $out
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

# A copy of the proof map compiled with its grate wall given a material
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
    if ($tree | path exists) { rm -r $tree }
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
# it refuses; it admits a clockless run marked; and it refuses a run
# missing a leg another run holds, one batch of a build or a whole
# build, naming the run and its missing legs, and under --diagnostic
# keeps that build's row for the leg with the batches missing it and no
# value, the build's other legs valued as before.
def gauge-rules [dir: path]: nothing -> nothing {
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
    let checked = { clocked: true, complete: true, problems: [], valid: true, invalid: [] }
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
    let compared = (gauge compare [$valid_file (do $file_of "clockless")] "draw_us" 50)
    let clockless_standings = ($compared.table | where build == "clockless" | get 0.standings)
    assert equal $clockless_standings ["clockless"] "a clockless run is admitted and marked"
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
}

# A synthetic capture's records as the program sends them over `frames`
# frames: the seed's answer, frame 0's state, then at each frame's top
# the frame before's clock and drawing, the end marker after the final
# frame's, and the frame's state, two frames' states past the window.
def fx-items [frames: int]: nothing -> list<any> {
    let tops = (1..$frames | each {|n|
        [(fx-frame ($n - 1)) { kind: "draw", frame: ($n - 1), schema: 1 }]
        | append (if $n == $frames { [{ kind: "end", frame: ($n - 1), schema: 1 }] } else { [] })
        | append [{ kind: "state", frame: $n }]
    } | flatten)
    [{ kind: "ack" } { kind: "state", frame: 0 }] | append $tops | append [{ kind: "state", frame: ($frames + 1) }]
}

# A frame record's fields for a synthetic capture: its phases 1.72 ms of
# a critical path of 1.8, the drawing 1 ms, presented.
def fx-frame [frame: int]: nothing -> record {
    { kind: "frame", frame: $frame, critical: 1800, game: 100, draw: 1000, status: 0, schema: 1 }
}

# A synthetic capture's records as bytes, 64 each in render.inc's
# layouts: the console's answer to R; a state, its drawing and game
# microseconds at 32 and 36, 1000 and 100 unless given; a frame's clock,
# the crosshair and the mix 10 us each, the flip 500, the reporting 100,
# the await 16 ms; a drawing whose parts take 0.95 ms, its tiles 0.1;
# and the end marker's frame and schema.
def fx-bytes [items: list<any>]: nothing -> binary {
    $items | each {|i|
        match $i.kind {
            "ack" => (fx-pad ([0x[0b 00 00 00] 0x[52]] | bytes collect)),
            "state" => (fx-pad ([0x[01 00 00 00] (fx-zeros 28) (fx-u32 ($i.draw? | default 1000)) (fx-u32 ($i.game? | default 100))] | bytes collect)),
            "frame" => ([
                0x[07 00 00 00] (fx-u32 $i.frame) (fx-u64 ($i.frame * 20000)) (fx-u32 $i.critical) (fx-u32 $i.game) (fx-u32 $i.draw)
                (fx-u32 10) (fx-u32 10) (fx-u32 500) (fx-u32 100) (fx-u32 16000) (fx-u64 ($i.frame * 20000 + 1700)) (fx-u32 $i.status) (fx-u32 $i.schema)
            ] | bytes collect),
            "draw" => ([
                0x[08 00 00 00] (fx-u32 $i.frame) (fx-u32 100) (fx-u32 100) (fx-u32 300) (fx-u32 400) (fx-u32 50) (fx-u32 100)
                (fx-u32 2) (fx-u32 0) (fx-u32 10) (fx-u32 20) (fx-u32 50) (fx-u32 100) (fx-u32 5) (fx-u32 $i.schema)
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
