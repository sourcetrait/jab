use (path self ../../../../../../nu/mod/launch)
use (path self ../../console)
use (path self ../../frame)
use (path self ../../map)
use (path self ../../picture)
use (path self ../../pose)
use (path self ../../tree)
use std/assert
use (path self ../../console) [CLOCK_CADENCE CLOCK_SEED CLOCK_SEED_AT CONSOLE_P]
use (path self ../../frame) [CRACKS FRAME FRAMES_LINE LOAD SOUNDS_LINE]
use (path self ../../tree) [EYE_HEIGHT]

# When the walk's E closes its measurement, a second before the capture
const CLOCK_END_AT = 13500ms

# What a round met when it struck geometry, its record's first field
const MET_GEOMETRY = 1

# What a round met when it struck an android, its record's first field
const MET_ANDROID = 2

# An android's roused event, its record's first field
const ROUSED = 1

# An android's fired event, its record's first field
export const FIRED = 2

# An android's destroyed event, its record's first field
const DESTROYED = 4

# An android's fallen event, its record's first field
const FALLEN = 5

# A trace's answer for a ray that met a plane
const TRACE_PLANE = 1

# A trace's answer for a ray that met a piece
const TRACE_PIECE = 2

# Render Zero's spawn view's loose sanity bound, in microseconds
const RENDER_0_START_BOUND = 100000

# The yard capture's pixel read for the sky's top band
const SKY_PIXEL = [960, 100]

# The sky texture's top band colour
const SKY_TOP = 0x[3a 6f b0]

# The screen's centre pixel, where the crosshair is read
const CROSSHAIR = [960, 540]

# The fight's pose on the bay's east patrol leg, facing south
const FIGHT_POSE = { name: "fight", x: 28.0, y: 17.0, z: 1.6, yaw: 270, pitch: 0 }

# When the console's four rounds go in
const FIGHT_ROUNDS = [3000ms, 3300ms, 3600ms, 3900ms]

# The fought android's actor, the first android entity's
const FIGHT_ACTOR = 0

# The android's health after each of the four rounds
const FIGHT_HEALTHS = [75, 50, 25, 0]

# The shots' window in seconds and the peak it must reach
const FIGHT_SHOTS = { from: 3.2, to: 4.6, over: 8000 }

# The rounds the taken magazine holds
const MAGAZINE_ROUNDS = 30

# The millimetres a trace may land from its expected point
const TRACE_SLACK = 50

# Render Zero's tree read: nothing unresolved, five ambients, four views set
export def poses [context: record, records: record]: nothing -> record {
    let trees = $context.trees
    let game = $context.game
    let render_0_tree = ($trees | path join "render_0")
    let render_0_source = (open ($game | path join "content" "map" "render_0.nuon"))
    let render_0_expected = (open ($render_0_tree | path join "map.nuon"))
    let render_0_read = (map read ($render_0_tree | path join "map" "render_0.jabfps.map"))
    let down3 = (tree sector-index $render_0_source "down3")
    let down_z = ((map plane-z ($render_0_read.sectors | get $down3 | get floor) 1.5 7.0) + $EYE_HEIGHT)
    let render_0_poses = [
        { name: "window", sector: (tree sector-index $render_0_source "office_hall"), x: 8.75, y: 17.0, z: 4.6, yaw: 0, pitch: -15, sees: (tree sector-index $render_0_source "bay") },
        { name: "garage", sector: (tree sector-index $render_0_source "garage"), x: 16.0, y: 14.0, z: -1.4, yaw: 0, pitch: 0, sees: (tree sector-index $render_0_source "drive_low") },
        { name: "down", sector: $down3, x: 1.5, y: 7.0, z: $down_z, yaw: 90, pitch: 0, sees: (tree sector-index $render_0_source "garage") },
        { name: "yard", sector: (tree sector-index $render_0_source "yard"), x: 40.0, y: 6.0, z: 1.6, yaw: 90, pitch: 0, sees: (tree sector-index $render_0_source "beyond") },
    ]
    assert equal $render_0_expected.unresolved 0 $"render_0 names nothing the content lacks: ($render_0_expected.missing)"
    assert equal $render_0_expected.ambients 5 "render_0 names five ambients"
    let rooted = (open ($render_0_tree | path join "tile.nuon") | where {|t| $t.source | str starts-with "/" })
    assert ($rooted | is-empty) $"render_0's tile.nuon names each source under the content, never by a path of this machine: ($rooted | get source)"
    let game_bytes = ($game | path expand | into binary)
    let leaked = (glob ($render_0_tree | path join "**" "*") --no-dir | where {|f| (open --raw $f | into binary | bytes index-of $game_bytes) != -1 })
    assert ($leaked | is-empty) $"render_0's tree holds no path of the checkout that compiled it: ($leaked)"
    {
        render_0_tree: $render_0_tree,
        render_0_source: $render_0_source,
        render_0_expected: $render_0_expected,
        render_0_read: $render_0_read,
        render_0_poses: $render_0_poses,
    }
}

# Render Zero run with views and traces: its load, ambients, frames, sectors
export def launched [context: record, records: record]: nothing -> record {
    let render_0_poses = $records."render_zero poses".render_0_poses
    let render_0_tree = $records."render_zero poses".render_0_tree
    let out = $context.out
    let kernel = $context.kernel
    let image = $context.image
    let set = $context.set
    let render_0_expected = $records."render_zero poses".render_0_expected
    let render_0_read = $records."render_zero poses".render_0_read
    let render_0_source = $records."render_zero poses".render_0_source
    let render_0_sends = (($render_0_poses | enumerate | each {|e| { at: (1500ms + ($e.index * 500ms)), bytes: (pose pose-frame $e.item) } })
        | append [{ at: 1750ms, bytes: (pose command-frame "T") }, { at: 3250ms, bytes: (pose command-frame "T") }]
        | sort-by at)
    let render_0_disk = (tree romfs $render_0_tree ($out | path join "render_0.romfs"))
    let render_0_run = (launch --kernel $kernel --image $image --out ($out | path join "render_0") --set $set --sound --api --disk $render_0_disk --serial "fps" --send $render_0_sends --capture 4000ms --seconds 5)
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
    assert ($"fps: ambient (tree ambient-index $render_0_read 'floor') playing" in $render_0_lines) $"the bay's ambient plays from the spawn: ($render_0_lines | where {|l| $l starts-with 'fps: ambient' })"
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
    let render_0_records = (picture records $render_0_run.api)
    let render_0_states = ($render_0_records | where kind == 1)
    assert (($render_0_states | length) > 10) $"a state a frame on render_0: ($render_0_states | length)"
    assert equal ($render_0_states | get 0.sector) (tree sector-index $render_0_source "bay") "the camera in the bay at the spawn"
    let render_0_consoles = ($render_0_records | enumerate | where {|r| $r.item.kind == 11 and $r.item.sector == $CONSOLE_P })
    assert equal ($render_0_consoles | length) ($render_0_poses | length) $"a console record a pose on render_0: ($render_0_consoles | length)"
    for e in ($render_0_consoles | enumerate) {
        let landed = ($render_0_records | slice ($e.item.index + 1).. | where kind == 1 | get -o 0)
        let pose_at = ($render_0_poses | get $e.index)
        assert ($landed != null) $"a state after the pose ($pose_at.name) on render_0"
        assert equal $landed.sector $pose_at.sector $"the camera in the pose ($pose_at.name)'s sector on render_0: ($landed.sector)"
    }
    {
        render_0_disk: $render_0_disk,
        render_0_run: $render_0_run,
        render_0_lines: $render_0_lines,
        render_0_load: $render_0_load,
        render_0_frames: $render_0_frames,
        render_0_start: $render_0_start,
        render_0_sectors: $render_0_sectors,
        render_0_records: $render_0_records,
    }
}

# Traces: the window's ray onto the bay floor, the yard's to the far wall
export def traces [context: record, records: record]: nothing -> record {
    let render_0_records = $records."render_zero launched".render_0_records
    let render_0_source = $records."render_zero poses".render_0_source
    let render_0_run = $records."render_zero launched".render_0_run
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
    assert equal (picture pixel $render_0_run.screen $SKY_PIXEL) $SKY_TOP $"the sky's top band at ($SKY_PIXEL) from the yard: ($render_0_run.screen)"
    {}
}

# The crosshair: the centre pixel at least half scale in every channel
export def crosshair [context: record, records: record]: nothing -> record {
    let render_0_run = $records."render_zero launched".render_0_run
    let render_0_read = $records."render_zero poses".render_0_read
    let centre = (picture pixel $render_0_run.screen $CROSSHAIR)
    assert (([0 1 2] | all {|i| ($centre | bytes at $i..<($i + 1) | into int) >= 128 })) $"the crosshair at ($CROSSHAIR): ($centre | encode hex)"
    for tag in [1 2 3 4 5] {
        assert equal ($render_0_read.sectors | where tag == $tag | length) 1 $"one door sector carries tag ($tag)"
    }
    {}
}

# Render Zero's mip chains built, and its plan views at the storeys' bounds
export def mips [context: record, records: record]: nothing -> record {
    let render_0_lines = $records."render_zero launched".render_0_lines
    let render_0_tree = $records."render_zero poses".render_0_tree
    let render_0_source = $records."render_zero poses".render_0_source
    let render_0_read = $records."render_zero poses".render_0_read
    let render_0_mips = (frame mips-built $render_0_lines)
    tree plan-views $render_0_tree $render_0_source $render_0_read
    {render_0_mips: $render_0_mips}
}

# Render Zero walked from three starts: sectors in order, floor, ambients
export def walk [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let game = $context.game
    let render_0_disk = $records."render_zero launched".render_0_disk
    let render_0_source = $records."render_zero poses".render_0_source
    let render_0_read = $records."render_zero poses".render_0_read
    let render_0_starts = [
        { name: "up", at: 1500ms, x: 8.75, y: 3.0, z: 1.6, yaw: 90, pitch: 0, way: [stair_ground up1 up2 up3 up4 up5 up6 office_hall], ambient: "office" },
        { name: "down", at: 5500ms, x: 1.5, y: 3.0, z: 1.6, yaw: 90, pitch: 0, way: [stair_ground down1 down2 down3 down4 down5 down6 garage], ambient: "garage" },
        { name: "ramp", at: 9500ms, x: 34.0, y: 13.0, z: -1.4, yaw: 90, pitch: 0, way: [drive_low drive_ramp], ambient: "yard" },
    ]
    let walk_sends = ([{ at: $CLOCK_SEED_AT, bytes: (console seed $CLOCK_SEED) }, { at: $CLOCK_SEED_AT, bytes: (console cadence $CLOCK_CADENCE) }]
        | append ($render_0_starts | each {|s| { at: $s.at, bytes: (pose pose-frame $s) } })
        | append [{ at: $CLOCK_END_AT, bytes: (pose command-frame "E") }]
        | sort-by at)
    let render_0_walk = (launch --kernel $kernel --image $image --out ($out | path join "render_0_walk") --set $set --sound --api --pad ($game | path join "nu" "nuon" "table" "table_render_0.nuon") --disk $render_0_disk --serial "fps" --send $walk_sends --capture 14500ms --seconds 16)
    assert equal (open --raw $render_0_walk.qemu_log) "" "QEMU has no complaint about the guest on the render_0 walk"
    let walk_lines = ($render_0_walk.serial | lines)
    let render_0_walk_records = (picture records $render_0_walk.api)
    let walk_consoles = ($render_0_walk_records | enumerate | where {|r| $r.item.kind == 11 and $r.item.sector == $CONSOLE_P } | get index)
    assert equal ($walk_consoles | length) ($render_0_starts | length) $"a console record a start on the render_0 walk: ($walk_consoles | length)"
    mut render_0_walks = []
    for e in ($render_0_starts | enumerate) {
        let from = (($walk_consoles | get $e.index) + 1)
        let to = (if ($e.index + 1) < ($render_0_starts | length) { $walk_consoles | get ($e.index + 1) } else { $render_0_walk_records | length })
        let states = ($render_0_walk_records | slice $from..<$to | where kind == 1)
        assert (($states | length) > 50) $"states through the ($e.item.name) walk: ($states | length)"
        let way = ($e.item.way | each {|n| tree sector-index $render_0_source $n })
        let crossed = ($states | get sector | uniq)
        let order = ($way | each {|s| $crossed | enumerate | where {|c| $c.item == $s } | get -o 0.index })
        assert ($order | all {|i| $i != null }) $"the ($e.item.name) walk crossed ($e.item.way): ($crossed)"
        assert (($order | window 2 | all {|w| $w.0 < $w.1 })) $"in order on the ($e.item.name) walk: ($crossed)"
        let last = ($states | last)
        assert equal $last.sector ($way | last) $"the ($e.item.name) walk ended in ($e.item.way | last): ($last)"
        let floor = (map plane-z ($render_0_read.sectors | get $last.sector | get floor) $last.x $last.y)
        assert ((($last.z - ($floor + $EYE_HEIGHT)) | math abs) < 0.05) $"the eye rides the floor at the end of the ($e.item.name) walk: ($last.z) over ($floor)"
        assert ($"fps: ambient (tree ambient-index $render_0_read $e.item.ambient) playing" in $walk_lines) $"the ($e.item.ambient) ambient plays on the ($e.item.name) walk: ($walk_lines | where {|l| $l starts-with 'fps: ambient' })"
        $render_0_walks = ($render_0_walks | append { name: $e.item.name, first: ($states | first), last: $last, crossed: $crossed, frames: ($states | length) })
    }
    let ramp_end = ($render_0_walks | last | get last)
    assert ($ramp_end.y > 27.0) $"the body reached the gate at the ramp's top: ($ramp_end)"
    {
        render_0_starts: $render_0_starts,
        render_0_walk: $render_0_walk,
        render_0_walks: $render_0_walks,
    }
}

# The fight: an android roused, struck down by four rounds, its magazine taken
export def fight [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let game = $context.game
    let render_0_disk = $records."render_zero launched".render_0_disk
    let fight_sends = ([{ at: 1500ms, bytes: (pose pose-frame $FIGHT_POSE) }] | append ($FIGHT_ROUNDS | each {|at| { at: $at, bytes: (pose command-frame "F") } }))
    let fight_run = (launch --kernel $kernel --image $image --out ($out | path join "fight") --set $set --sound --api --pad ($game | path join "nu" "nuon" "table" "table_fight.nuon") --disk $render_0_disk --serial "fps" --send $fight_sends --capture 9500ms --seconds 11)
    assert equal (open --raw $fight_run.qemu_log) "" "QEMU has no complaint about the guest on the fight"
    let fight_records = (picture records $fight_run.api)
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
    let shots = (picture sound-level $fight_run.sound $FIGHT_SHOTS.from $FIGHT_SHOTS.to)
    assert ($shots.peak >= $FIGHT_SHOTS.over) $"the shots are heard: ($shots)"
    {
        fight_records: $fight_records,
        fight_events: $fight_events,
        fight_rounds: $fight_rounds,
        struck: $struck,
        pickups: $pickups,
        fight_frames: $fight_frames,
        shots: $shots,
    }
}
