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
# walk, the shots heard; a map whose magic is wrong, which exits 6,
# and one cut short, which exits 7, each saying so on the UART.
use ../../../../../jab/sdk/nu/jab.nu
use ../../../nu/map.nu
use ../../../nu/png.nu
use ./pose.nu
use std/assert

const LOAD = "fps: {name} loaded in {ms} ms: {sectors} sectors, {walls} walls, {vertices} vertices, {portals} portals, {entities} entities, {lights} lights, {sprites} sprites, {materials} materials, {textures} textures, {missing} missing"
const FRAME = "fps: frame in {us} us: {sectors} sectors, {walls} walls, {pieces} pieces, {planes} planes, {openings} openings, {sprites} sprites, {uncovered} uncovered; clear, planes, walls, portals, sprites us {clear}, {plane_us}, {wall_us}, {portal_us}, {sprite_us}; spans {spans}, pixels {pixels}, lit spans {lit_spans}, lit pixels {lit_pixels}, light us {light_us}"
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
# millimetres)
const RECORD = 64
# A console record carries the command's byte where the state's sector
# sits; the P frame's
const CONSOLE_P = 80
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
# at the bottom of the screen and the far wall at the top
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
# the functions whose loops run a pixel or a sample, each within one
# page of code (render.inc's CODE_PAGE) and trapping only where the
# mixer's two calls a frame are
const HOT_FUNCTIONS = [span_fill poly_shows span_light mixer_update]
const HOT_ECALLS = { span_fill: 0, poly_shows: 0, span_light: 0, mixer_update: 2 }
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

def main [--kernel: path, --image: path, --out: path, --set: string = "", --assets: path = ""] {
    assert (($assets | path exists)) "the sdk built the assets image"
    hot-functions $image
    let game = ($env.FILE_PWD | path join ".." ".." ".." | path expand)
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
    let proof_poses = [
        { name: "window", sector: (do $proof_index "upper_room"), x: 5.0, y: 4.0, z: 4.85, yaw: 0, pitch: -20, sees: (do $proof_index "step1") },
        { name: "grate", sector: (do $proof_index "north"), x: 9.0, y: 11.0, z: 1.6, yaw: 0, pitch: 0, sees: (do $proof_index "alcove") },
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
    let walk_sends = ($factory_starts | each {|s| { at: $s.at, bytes: (pose pose-frame $s) } })
    let factory_walk = (jab launch --kernel $kernel --image $image --out ($out | path join "factory_walk") --set $set --sound --api --pad ($env.FILE_PWD | path join "table_factory.nuon") --disk $factory_disk --serial "fps" --send $walk_sends --capture 14500ms --seconds 16)
    assert equal (open --raw $factory_walk.qemu_log) "" "QEMU has no complaint about the guest on the factory walk"
    let walk_lines = ($factory_walk.serial | lines)
    let factory_walk_records = (records $factory_walk.api)
    let walk_consoles = ($factory_walk_records | enumerate | where {|r| $r.item.kind == 11 } | get index)
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
    print $"fps: the sprite drawn in ($sprite_frame.us) us, ($sprite_frame.sprites) sprites in ($sprite_frame.sprite_us) us, ($sprite_frame.uncovered) uncovered, red at ($SPRITE_RIGHT) and the wall at ($SPRITE_LEFT)"
    print $"fps: the walk from ($walk_first.x), ($walk_first.y), ($walk_first.z) in ($walk_first.sector) to ($walk_last.x), ($walk_last.y), ($walk_last.z) in ($walk_last.sector) through ($walk_sectors) over ($walk_states | length) frames, the eye ($walk_last.z) over the floor at ($floor)"
    print $"fps: proof loaded in ($proof_load.ms) ms; the spawn view in ($proof_frames | get 0 | get us) us with ($proof_frames | get 0 | get sprites) sprites, the poses in ($proof_frames | slice 1.. | each {|p| $p.us } | str join ', ') us with ($proof_frames | slice 1.. | each {|p| $p.uncovered } | str join ', ') uncovered, drawing ($proof_sectors | slice 1.. | each {|s| $s | length } | str join ' and ') sectors"
    print $"fps: the stair from ($stair_first.x), ($stair_first.y), ($stair_first.z) in ($stair_first.sector) to ($stair_last.x), ($stair_last.y), ($stair_last.z) in ($stair_last.sector) through ($stair_sectors) over ($stair_states | length) frames"
    print $"fps: factory loaded in ($factory_load.ms) ms; the spawn view in ($factory_start.us) us over ($factory_start.sectors) sectors, ($factory_start.walls) walls, ($factory_start.pieces) pieces, ($factory_start.planes) planes \(clear ($factory_start.clear), planes ($factory_start.plane_us), walls ($factory_start.wall_us), portals ($factory_start.portal_us) us\); the poses in ($factory_frames | slice 1.. | each {|p| $p.us } | str join ', ') us with ($factory_frames | slice 1.. | each {|p| $p.uncovered } | str join ', ') uncovered, drawing ($factory_sectors | slice 1.. | each {|s| $s | length } | str join ', ') sectors"
    for w in $factory_walks {
        print $"fps: the ($w.name) walk from ($w.first.x), ($w.first.y), ($w.first.z) in ($w.first.sector) to ($w.last.x), ($w.last.y), ($w.last.z) in ($w.last.sector) through ($w.crossed) over ($w.frames) frames"
    }
    print $"fps: the fight: the android fired ($fight_events | where {|e| $e.fields.0 == $FIRED } | length) rounds, the frame struck ($fight_records | where kind == 4 | length) times; struck down through ($struck | each {|r| $r.fields.2 } | str join ', '), ($fight_rounds | length) rounds in all, the magazine taken with ($pickups | get 0.fields.0) rounds; the shots' window peaking at ($shots.peak); the pose's frame in ($fight_frames | last | get us) us with ($fight_frames | last | get sprites) sprites"
    print $"fps: the wrong magic out with ($bad_run.status), the short file with ($short_run.status)"
    print "fps: ok"
}

# Each hot function within one page of code and trapping no more than
# its table says, through the SDK's `jab hot` over the ELF beside the
# image: QEMU's translator ends a block at a page boundary and chains
# blocks within a page only, so a loop straddling one runs seven times
# slower, and a trap in a per-pixel loop would cost more.
def hot-functions [image: path]: nothing -> nothing {
    let elf = ($image | path dirname | path join "fps.elf")
    for h in (jab hot $elf $HOT_FUNCTIONS) {
        assert $h.paged $"($h.name) within one page of code: ($h.start) to ($h.end)"
        assert equal $h.ecalls ($HOT_ECALLS | get $h.name) $"($h.name) traps inside its page"
    }
}

# The records of an API capture: the kind, the sector, the eye, the
# angles in degrees, the times, and an event's five fields.
def records [api: binary]: nothing -> table<kind: int, sector: int, x: float, y: float, z: float, yaw: float, pitch: float, roll: float, frame_us: int, game_us: int, fields: list<int>> {
    0..<(($api | bytes length) // $RECORD) | each {|i|
        let r = ($api | bytes at ($i * $RECORD)..<(($i + 1) * $RECORD))
        {
            kind: ($r | bytes at 0..<1 | into int),
            sector: ($r | bytes at 4..<8 | into int --endian little --signed),
            x: (map float-at $r 8), y: (map float-at $r 12), z: (map float-at $r 16),
            yaw: (map float-at $r 20), pitch: (map float-at $r 24), roll: (map float-at $r 28),
            frame_us: ($r | bytes at 32..<36 | into int --endian little),
            game_us: ($r | bytes at 36..<40 | into int --endian little),
            fields: (0..<5 | each {|f| $r | bytes at (40 + $f * 4)..<(44 + $f * 4) | into int --endian little --signed }),
        }
    }
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
# two-sided; the map read, changed, and written back through the
# reader and writer, and the texture written, 64 by 64, its left half
# transparent and its right half red; the copy's path.
def sprite-tree [tree: path, out: path]: nothing -> string {
    if ($out | path exists) { rm -r $out }
    cp -r $tree $out
    let map_path = ($out | path join "map" "doortest.jabfps.map")
    let m = (map read $map_path)
    let index = ($m.materials | length)
    let entity = ($m.entities | get $CONTENT.sprite.entity)
    assert equal $entity.class 2 $"the fixture names a sprite entity: ($entity)"
    let patched = ($m
        | update materials ($m.materials | append { name: $SPRITE_MATERIAL, flags: 0 })
        | update entities ($m.entities | update $CONTENT.sprite.entity {|e| $e | update material $index | update flags $SPRITE_FLAGS }))
    map write $patched | save --raw -f $map_path
    let file = ($out | path join (map tile-path $SPRITE_MATERIAL | str substring 1..))
    mkdir ($file | path dirname)
    let row = ([(0..<32 | each {|i| 0x[00 00 00 00] } | bytes collect), (0..<32 | each {|i| 0x[ff 00 00 ff] } | bytes collect)] | bytes collect)
    png write-rgba $file 64 64 (0..<64 | each {|r| $row } | bytes collect)
    $out
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
    let newlines = ($bytes | bytes index-of --all 0x[0a] | take 3)
    let head_len = ($newlines.2 + 1)
    $bytes | bytes at ($head_len + ($at.1 * 1920 + $at.0) * 3)..<($head_len + ($at.1 * 1920 + $at.0) * 3 + 3)
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
