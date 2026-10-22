use (path self ../../../../../../nu/mod/launch)
use (path self ../../console)
use (path self ../../frame)
use (path self ../../map)
use (path self ../../padtable)
use (path self ../../picture)
use (path self ../../pose)
use (path self ../../tree)
use std/assert
use (path self ../../console) [CONSOLE_P RECEIPT_NONCE]
use (path self ../../frame) [CRACKS FRAME FRAMES_LINE LOAD SOUNDS_LINE]
use (path self ../../tree) [ALPHA_CASES EYE_HEIGHT SPRITE_MATERIAL STRADDLE_MATERIAL]

# The sprite copy's map name, the halves sprite in its hall
const SPRITE_MAP = "render_1_sprite"

# The plain copy's map name, the same copy without the halves sprite
const PLAIN_MAP = "render_1_plain"

# The halves sprite's flags: facing the camera, two-sided
const SPRITE_FLAGS = 5

# The pose in the hall the halves sprite is seen from
const SPRITE_POSE = { name: "sprite", x: 4.5, y: 4.0, z: 1.6, yaw: 180, pitch: 0 }

# The halves sprite's red as a pixel's bytes
const RED = 0x[ff 00 00]

# A pixel on the halves sprite's transparent left half
export const SPRITE_LEFT = [760, 540]

# A pixel on the halves sprite's red right half
export const SPRITE_RIGHT = [1160, 540]

# The straddling quad's colour as the unlit copy draws it
const STRADDLE_COLOUR = 0x[40 80 c0]

# The straddling quad's flags: fixed, two-sided
const STRADDLE_FLAGS = 4

# The pose in the hall's north-east that sees the quad obliquely
const STRADDLE_POSE = { name: "straddle", x: 7.0, y: 7.0, z: 1.6, yaw: 170, pitch: 0 }

# A point on the straddling quad's near end, over the solid wall
const STRADDLE_POINT = [3.3, 7.75, 1.2]

# Render One's pose under the hall's light, facing west 45 degrees down
const LIGHT_POSE = { name: "light", x: 4.0, y: 4.0, z: 1.6, yaw: 180, pitch: -45 }

# The near floor and far wall blocks read for brightness, [x, y, w, h]
const LIGHT_BLOCKS = { near: [860, 980, 200, 100], far: [860, 0, 200, 100] }

# The least the lit floor's brightness may stand over the far wall's
const LIT_RATIO = 1.4

# A body's radius with a millimetre's slack, the spawn eye's most offset
const BODY_RADIUS = 0.351

# Render One's sprite and plain copies: sprites placed, the plain run launched
export def plain [context: record, records: record]: nothing -> record {
    let render_1_source = $context.render_1.source
    let out = $context.out
    let game = $context.game
    let kernel = $context.kernel
    let image = $context.image
    let set = $context.set
    let sprite_tree = (tree sprite-tree $render_1_source $SPRITE_MAP ($out | path join "sprite_tree") $game --halves)
    let plain_tree = (tree sprite-tree $render_1_source $PLAIN_MAP ($out | path join "plain_tree") $game)
    let sprite_read = (map read ($sprite_tree | path join "map" $"($SPRITE_MAP).jabfps.map"))
    for c in $ALPHA_CASES {
        assert ($c.name in ($sprite_read.materials | get name)) $"the alpha case ($c.name) a material of the sprite tree"
    }
    let halves = ($sprite_read.entities | where material == (tree material-index $sprite_read $SPRITE_MATERIAL) | get 0)
    assert equal $halves.flags $SPRITE_FLAGS $"the halves sprite faces the camera, two-sided: ($halves)"
    assert equal $halves.sector (tree sector-index $render_1_source "hall") $"the halves sprite stands in the hall: ($halves)"
    let straddler = ($sprite_read.entities | where material == (tree material-index $sprite_read $STRADDLE_MATERIAL) | get 0)
    assert equal $straddler.flags $STRADDLE_FLAGS $"the straddler fixed, two-sided: ($straddler)"
    assert equal $straddler.sector (tree sector-index $render_1_source "door") $"the straddler's feet in the door sector: ($straddler)"
    let sprite_disk = (tree romfs $sprite_tree ($out | path join "sprite.romfs"))
    let sprite_sends = [{ at: 1500ms, bytes: (pose pose-frame $SPRITE_POSE) }]
    let plain_run = (launch --kernel $kernel --image $image --out ($out | path join "plain") --set $set --sound --api --disk (tree romfs $plain_tree ($out | path join "plain.romfs")) --serial "fps" --send $sprite_sends --capture 2500ms --seconds 5)
    assert equal (open --raw $plain_run.qemu_log) "" "QEMU has no complaint about the guest on the plain run"
    {
        sprite_read: $sprite_read,
        sprite_disk: $sprite_disk,
        sprite_sends: $sprite_sends,
        plain_run: $plain_run,
    }
}

# The halves sprite: its right half red, its left the wall the plain run shows
export def sprite [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let sprite_disk = $records."render_one plain".sprite_disk
    let sprite_sends = $records."render_one plain".sprite_sends
    let plain_run = $records."render_one plain".plain_run
    let sprite_run = (launch --kernel $kernel --image $image --out ($out | path join "sprite") --set $set --sound --api --disk $sprite_disk --serial "fps" --send $sprite_sends --capture 2500ms --seconds 5)
    assert equal (open --raw $sprite_run.qemu_log) "" $"QEMU has no complaint about the guest on the sprite run"
    let sprite_lines = ($sprite_run.serial | lines)
    assert (($sprite_lines | where {|l| $l starts-with $"fps: ($SPRITE_MAP) loaded" } | length) == 1) $"the sprite tree loaded: ($sprite_run.serial)"
    let sprite_frames = ($sprite_lines | where {|l| $l starts-with "fps: frame in" })
    assert equal ($sprite_frames | length) 2 $"the first frame and the sprite pose's reported: ($sprite_run.serial)"
    let sprite_frame = ($sprite_frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
    assert ($sprite_frame.sprites >= 1) $"the sprite drawn from the sprite pose: ($sprite_frame)"
    assert ($sprite_frame.uncovered < $CRACKS) $"the sprite view has no pixel uncovered: ($sprite_frame)"
    assert ($sprite_run.screen != "") "a screen was taken on the sprite run"
    assert equal (picture pixel $sprite_run.screen $SPRITE_RIGHT) $RED $"the sprite's right half is the texture's red: ($sprite_run.screen)"
    assert equal (picture pixel $sprite_run.screen $SPRITE_LEFT) (picture pixel $plain_run.screen $SPRITE_LEFT) $"the sprite's transparent left half shows the wall behind, as the plain run drew it"
    {sprite_lines: $sprite_lines, sprite_frame: $sprite_frame}
}

# The straddling quad drawn whole beside the doorway, outside its rectangle
export def straddle [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let sprite_disk = $records."render_one plain".sprite_disk
    let render_1_source = $context.render_1.source
    let sprite_read = $records."render_one plain".sprite_read
    let straddle_run = (launch --kernel $kernel --image $image --out ($out | path join "straddle") --set $set --sound --api --disk $sprite_disk --serial "fps" --send [{ at: 1500ms, bytes: (pose pose-frame $STRADDLE_POSE) }] --capture 2500ms --seconds 5)
    assert equal (open --raw $straddle_run.qemu_log) "" "QEMU has no complaint about the guest on the straddle run"
    let straddle_frames = ($straddle_run.serial | lines | where {|l| $l starts-with "fps: frame in" })
    assert equal ($straddle_frames | length) 2 $"the first frame and the straddle pose's reported: ($straddle_run.serial)"
    let straddle_frame = ($straddle_frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
    assert ($straddle_frame.sprites >= 1) $"the straddling sprite drawn: ($straddle_frame)"
    assert ($straddle_frame.uncovered < $CRACKS) $"the straddle view has no pixel uncovered: ($straddle_frame)"
    assert ($straddle_run.screen != "") "a screen was taken on the straddle run"
    let straddle_eye = { x: $STRADDLE_POSE.x, y: $STRADDLE_POSE.y, z: $STRADDLE_POSE.z }
    let straddle_at = (picture project $straddle_eye $STRADDLE_POSE.yaw $STRADDLE_POINT)
    assert ($straddle_at != null) $"the straddling quad's near end is on screen from ($STRADDLE_POSE)"
    let hall = (tree sector-index $render_1_source "hall")
    let door = (tree sector-index $render_1_source "door")
    let door_wall = ($sprite_read.walls | where {|w| $w.sector == $hall and $w.portal_count > 0 } | where {|w| ($sprite_read.portals | get $w.first_portal | get sector) == $door } | get 0)
    let door_columns = ([$door_wall.a $door_wall.b] | each {|v| let p = ($sprite_read.vertices | get $v); picture project-x $straddle_eye $STRADDLE_POSE.yaw [$p.x, $p.y] })
    assert ($door_columns | all {|c| $c != null }) $"the doorway in front of the straddle pose: ($door_columns)"
    let door_left = (($door_columns | math min) - 1)
    assert ($straddle_at.0 < $door_left) $"the straddling quad's near end at ($straddle_at) lies outside the door's rectangle, left of column ($door_left), so a clip to it would cut it"
    assert equal (picture pixel $straddle_run.screen $straddle_at) $STRADDLE_COLOUR $"the straddling quad's near end at ($straddle_at), beside the doorway, reads its texture: ($straddle_run.screen)"
    {
        straddle_frame: $straddle_frame,
        straddle_at: $straddle_at,
        door_left: $door_left,
    }
}

# Render One's tree read and its six views set: window to ramp, the light last
export def poses [context: record, records: record]: nothing -> record {
    let render_1_tree = $context.render_1.tree
    let render_1_source = $context.render_1.source
    let render_1_expected = (open ($render_1_tree | path join "map.nuon"))
    let render_1_read = (map read ($render_1_tree | path join "map" "render_1.jabfps.map"))
    let ramp = ($render_1_read.sectors | get (tree sector-index $render_1_source "ramp"))
    let ramp_x = (($ramp.bounds.min_x + $ramp.bounds.max_x) / 2)
    let ramp_y = (($ramp.bounds.min_y + $ramp.bounds.max_y) / 2)
    let ramp_z = (((map plane-z $ramp.floor $ramp_x $ramp_y) + (map plane-z $ramp.ceiling $ramp_x $ramp_y)) / 2)
    let render_1_poses = [
        { name: "window", sector: (tree sector-index $render_1_source "upper_room"), x: 5.0, y: 4.0, z: 4.85, yaw: 0, pitch: -20, sees: (tree sector-index $render_1_source "step1") },
        { name: "grate", sector: (tree sector-index $render_1_source "north"), x: 9.0, y: 11.0, z: 1.6, yaw: 0, pitch: 0, sees: (tree sector-index $render_1_source "alcove") },
        { name: "line", sector: (tree sector-index $render_1_source "door"), x: 4.0, y: 8.0, z: 1.6, yaw: 270, pitch: 0, sees: (tree sector-index $render_1_source "hall") },
        { name: "door", sector: (tree sector-index $render_1_source "hall"), x: 4.0, y: 5.0, z: 1.6, yaw: 90, pitch: 0, sees: (tree sector-index $render_1_source "north") },
        { name: "ramp", sector: (tree sector-index $render_1_source "ramp"), x: $ramp_x, y: $ramp_y, z: $ramp_z, yaw: 90, pitch: -30, sees: (tree sector-index $render_1_source "upper_hall") },
        ($LIGHT_POSE | insert sector (tree sector-index $render_1_source "hall") | insert sees (tree sector-index $render_1_source "hall")),
    ]
    {
        render_1_expected: $render_1_expected,
        render_1_read: $render_1_read,
        render_1_poses: $render_1_poses,
    }
}

# Render One run with the I's nonce and its views half a second apart
export def launched [context: record, records: record]: nothing -> record {
    let render_1_poses = $records."render_one poses".render_1_poses
    let render_1_tree = $context.render_1.tree
    let out = $context.out
    let kernel = $context.kernel
    let image = $context.image
    let set = $context.set
    let render_1_sends = ([{ at: 200ms, bytes: (console nonce $RECEIPT_NONCE) }] | append ($render_1_poses | enumerate | each {|e| { at: (1500ms + ($e.index * 500ms)), bytes: (pose pose-frame $e.item) } }))
    let render_1_disk = (tree romfs $render_1_tree ($out | path join "render_1.romfs"))
    let render_1_run = (launch --kernel $kernel --image $image --out ($out | path join "render_1") --set $set --sound --api --disk $render_1_disk --serial "fps" --send $render_1_sends --capture 5500ms --seconds 6)
    assert equal (open --raw $render_1_run.qemu_log) "" "QEMU has no complaint about the guest on render_1"
    {render_1_disk: $render_1_disk, render_1_run: $render_1_run}
}

# Render One's load line once with the tree's counts, all images and sounds
export def loaded [context: record, records: record]: nothing -> record {
    let render_1_run = $records."render_one launched".render_1_run
    let render_1_expected = $records."render_one poses".render_1_expected
    let render_1_tree = $context.render_1.tree
    assert (not ($render_1_run.serial | str contains "fps: tile pool changed in flight")) $"the tile pool held unchanged through every frame's renders on render_1: ($render_1_run.serial | lines | last 2)"
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
    {render_1_lines: $render_1_lines, render_1_load: $render_1_load}
}

# Render One's frame lines: each view drawn whole, its sector seen, sprites
export def frames [context: record, records: record]: nothing -> record {
    let render_1_lines = $records."render_one loaded".render_1_lines
    let render_1_poses = $records."render_one poses".render_1_poses
    let render_1_run = $records."render_one launched".render_1_run
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
    let render_1_records = (picture records $render_1_run.api)
    let render_1_states = ($render_1_records | where kind == 1)
    assert (($render_1_states | length) > 10) $"a state a frame on render_1: ($render_1_states | length)"
    {
        render_1_frames: $render_1_frames,
        render_1_start: $render_1_start,
        render_1_sectors: $render_1_sectors,
        render_1_records: $render_1_records,
        render_1_states: $render_1_states,
    }
}

# The camera at the spawn: in its sector, within a body's radius, at eye height
export def spawn [context: record, records: record]: nothing -> record {
    let render_1_states = $records."render_one frames".render_1_states
    let render_1_expected = $records."render_one poses".render_1_expected
    let render_1_read = $records."render_one poses".render_1_read
    let render_1_records = $records."render_one frames".render_1_records
    let render_1_poses = $records."render_one poses".render_1_poses
    let render_1_source = $context.render_1.source
    let spawned = ($render_1_states | get 0)
    let spawn = $render_1_expected.spawn
    assert equal $spawned.sector ($render_1_read.entities | where class == 0 | get 0.sector) "the camera in the spawn's sector on render_1"
    let shove = ((($spawned.x - $spawn.at.0) ** 2 + ($spawned.y - $spawn.at.1) ** 2) | math sqrt)
    assert ($shove <= $BODY_RADIUS) $"the eye stands at the spawn, or a body's radius off a wall there: ($spawned.x), ($spawned.y) against ($spawn.at), ($shove) off"
    let spawn_floor = (map plane-z ($render_1_read.sectors | get $spawned.sector | get floor) $spawned.x $spawned.y)
    assert ((($spawned.z - ($spawn_floor + $EYE_HEIGHT)) | math abs) < 0.01) $"the eye its height over the floor at the spawn: ($spawned.z) over a floor at ($spawn_floor)"
    assert ((($spawned.yaw - $spawn.yaw) | math abs) < 0.01 and (($spawned.pitch - $spawn.pitch) | math abs) < 0.01 and $spawned.roll == 0.0) $"the camera faces the spawn's way: ($spawned.yaw), ($spawned.pitch), ($spawned.roll) against ($spawn.yaw), ($spawn.pitch)"
    let render_1_consoles = ($render_1_records | enumerate | where {|r| $r.item.kind == 11 and $r.item.sector == $CONSOLE_P })
    assert equal ($render_1_consoles | length) ($render_1_poses | length) $"a console record a pose on render_1: ($render_1_consoles | length)"
    for e in ($render_1_consoles | enumerate) {
        let landed = ($render_1_records | slice ($e.item.index + 1).. | where kind == 1 | get -o 0)
        let pose_at = ($render_1_poses | get $e.index)
        assert ($landed != null) $"a state after the pose ($pose_at.name) on render_1"
        assert equal $landed.sector $pose_at.sector $"the camera in the pose ($pose_at.name)'s sector on render_1: ($landed.sector)"
    }
    assert equal ($render_1_read.sectors | get (tree sector-index $render_1_source "door") | get tag) 1 "the door sector carries its tag"
    {shove: $shove}
}

# Render One's mip chains built, and its plan views at the storeys' bounds
export def mips [context: record, records: record]: nothing -> record {
    let render_1_lines = $records."render_one loaded".render_1_lines
    let render_1_tree = $context.render_1.tree
    let render_1_source = $context.render_1.source
    let render_1_read = $records."render_one poses".render_1_read
    let render_1_mips = (frame mips-built $render_1_lines)
    tree plan-views $render_1_tree $render_1_source $render_1_read
    {render_1_mips: $render_1_mips}
}

# The hall's light: the lit floor at least LIT_RATIO over the far wall
export def light [context: record, records: record]: nothing -> record {
    let render_1_run = $records."render_one launched".render_1_run
    assert ($render_1_run.screen != "") "a screen was taken on render_1"
    let lit_near = (picture mean-brightness $render_1_run.screen $LIGHT_BLOCKS.near)
    let lit_far = (picture mean-brightness $render_1_run.screen $LIGHT_BLOCKS.far)
    assert ($lit_near > ($lit_far * $LIT_RATIO)) $"the floor under the hall's light lit past the far wall: ($lit_near) against ($lit_far), ($lit_near / $lit_far)"
    {lit_near: $lit_near, lit_far: $lit_far}
}

# The stair walked from the spawn up the steps and the ramp to the upper hall
export def stair [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let game = $context.game
    let render_1_disk = $records."render_one launched".render_1_disk
    let render_1_source = $context.render_1.source
    let render_1_read = $records."render_one poses".render_1_read
    let stair_run = (launch --kernel $kernel --image $image --out ($out | path join "stair") --set $set --sound --api --pad (padtable held ($game | path join "nu" "nuon" "table" "table_stair.nuon")) --disk $render_1_disk --serial "fps" --capture 8000ms --seconds 9)
    assert equal (open --raw $stair_run.qemu_log) "" "QEMU has no complaint about the guest on the stair"
    let stair_states = (picture records $stair_run.api | where kind == 1)
    assert (($stair_states | length) > 100) $"states through the stair: ($stair_states | length)"
    let stair_first = ($stair_states | first)
    let stair_last = ($stair_states | last)
    assert equal $stair_first.sector (tree sector-index $render_1_source "hall") "the stair walk starts in the hall"
    assert equal $stair_last.sector (tree sector-index $render_1_source "upper_hall") $"the body ended in the upper hall: ($stair_last.x), ($stair_last.y), ($stair_last.z) in ($stair_last.sector)"
    let stair_floor = (map plane-z ($render_1_read.sectors | get $stair_last.sector | get floor) $stair_last.x $stair_last.y)
    assert ((($stair_last.z - ($stair_floor + $EYE_HEIGHT)) | math abs) < 0.05) $"the eye rides the upper floor: ($stair_last.z) over ($stair_floor)"
    let stair_sectors = ($stair_states | get sector | uniq)
    let stair_way = ([step1 step2 step3 landing ramp upper_hall] | each {|n| tree sector-index $render_1_source $n })
    let stair_order = ($stair_way | each {|s| $stair_sectors | enumerate | where {|e| $e.item == $s } | get -o 0.index })
    assert ($stair_order | all {|i| $i != null }) $"the body crossed every step, the landing, and the ramp: ($stair_sectors) against ($stair_way)"
    assert (($stair_order | window 2 | all {|w| $w.0 < $w.1 })) $"in order: ($stair_sectors)"
    {
        stair_states: $stair_states,
        stair_first: $stair_first,
        stair_last: $stair_last,
        stair_sectors: $stair_sectors,
    }
}
