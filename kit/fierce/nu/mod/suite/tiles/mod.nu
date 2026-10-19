use (path self ../../../../../../nu/mod/launch)
use (path self ../../console)
use (path self ../../../map.nu)
use (path self ../../gauge/measure)
use (path self ../../picture)
use (path self ../../../../test/pose.nu)
use (path self ../../gauge/stream)
use (path self ../../tree)
use std/assert
use (path self ../../console) [PLACE_AT SETTLE_AT SPAWN_POSE]
use (path self ../../frame) [CRACKS FRAME]
use (path self ../../gauge/stream) [CLOCK_SCHEMA]
use (path self ../../picture) [FIXTURE_CROSSHAIR FIXTURE_INSET STAMP_BITS STAMP_CELL]
use (path self ../../tree) [BUILDER_FIXTURE EYE_HEIGHT FIXTURE_MAP HANDOFF_FIXTURE]

# When the builder's first lighting goes in
const BUILDER_AT = 1400ms

# The time between the builder's lighting, build, and dump frames
const BUILDER_STEP = 300ms

# The lumel lightings the builder runs under in turn
const BUILDER_LIGHTINGS = [bright gradient parity]

# The builder oracle's rounding slack, in a lane's 256ths
const BUILDER_TRUNCATIONS = 8

# render.inc's LUMAP_PLANES: a wall's surface is its index past these
const LUMAP_PLANES = 2048

# A tile's side as a power of two, 64 texels of its level
const TILE_SHIFT = 6

# Per-level limits on tiled against lit, levels 0 to k, under each light
const HANDOFF_BOUNDS = { gradient: [2, 3, 4, 7, 13], parity: [28, 29, 43, 73, 97] }

# The head-on handoff pose's distance from the wall, in metres
const HANDOFF_DISTANCE = 4.5

# The lumel lightings the handoff runs under
const HANDOFF_LIGHTINGS = [gradient parity]

# The slots a head-on partial residency run builds once
const HANDOFF_PARTIAL_SLOTS = 1

# How long after the first placement the O frame goes in
const HANDOFF_ONCE_AFTER = 300ms

# When a handoff run's screen is taken
const HANDOFF_SCREEN_AT = 3500ms

# When a handoff run's E goes in
const HANDOFF_END_AT = 3800ms

# A handoff run's bound, in seconds
const HANDOFF_SECONDS = 5

# How long before the screen the live fixture's placement is due
const HANDOFF_EARLY = 50ms

# The oblique pose: metres along the wall and off it, degrees turned
const HANDOFF_OBLIQUE = { along: 1.98, off: 2.5, turn: 45 }

# The slots an oblique partial residency run builds once
const HANDOFF_OBLIQUE_SLOTS = 3

# The oblique pose's levels, from 0 to this less one
const HANDOFF_OBLIQUE_LEVELS = 3

# A COUNT build's count line form, the reported frame's own counts
const COUNT_LINE = "fps: count {divides} divides, {avoided} avoided; blocks {shifted} shifted, {short} short; negative steps off sixteen {nu} in u, {nv} in v; flat spans {flat}; mismatches {mismatches}; re-entries {two} in two blocks, {four} in four, {cut} cut short"

# The saturations FOOTPRINT adds after a count line
const COUNT_SATURATED = "; saturated {saturated}"

# The packet caps the K frame sets: commands and spans
const PACKET_CAPS = { commands: 7, spans: 500 }

# The O frame's lifted mode bit: quota, allowance, merge share lifted
const POOL_LIFTED = 1

# The O frame's stale mode bit: an eviction leaving its entries
const POOL_STALE = 4

# The O frame's once mode bit: tiles built at one boundary alone
const POOL_ONCE = 8

# When the pool fixtures place the view and make their cold start
const POOL_PLACE_AT = 1500ms

# When the pool fixtures' E closes the measurement
const POOL_END_AT = 4500ms

# The rotation's admission: tier, ring, merge share, workers, grain
const POOL_ROTATION = { guarantee: 1, ring: 4, merge_us: 1, workers: 2, grain: 16 }

# The contexts a tier admits in: hart 0's and each secondary slot's
const TILE_CONTEXTS = 8

# The stale fixture's slot cap, under the 272 tiles the view asks
const POOL_STALE_SLOTS = 64

# When the pool fixtures' capture ends the run, past the E
const POOL_CAPTURE_AT = 5000ms

# Where a handoff run's window breaks its kind's rule, frame by frame
def handoff-unsettled [rows: list<any>, kind: string, slots: int]: nothing -> list<string> {
    let tiled = ($rows | get -o 0.tiled_pixels)
    $rows | each {|r|
        let broken = (match $kind {
            "tiled" => ([missed_blocks building admitted dropped filtered tiles_built] | where {|f| ($r | get $f) != 0 })
            "held" => ([tiled_pixels tiles_built building] | where {|f| ($r | get $f) != 0 })
            _ => ([
                (if $r.tiles_built != 0 { "tiles_built" })
                (if $r.building != 0 { "building" })
                (if $r.slots_used != $slots { "slots_used" })
                (if $r.evicted != 0 { "evicted" })
                (if $r.tiled_pixels != $tiled { "tiled_pixels" })
                (if $r.admitted == 0 { "admitted" })
                (if $r.filtered == 0 { "filtered" })
            ] | compact)
        })
        if ($broken | is-empty) { null } else { $"frame ($r.frame): ($broken | each {|f| $'($f) ($r | get $f)' } | str join ', ')" }
    }
}

# The pool's traced passes by frame: surfaces requesting, merged, built
def pool-trace [serial: string]: nothing -> table<frame: int, requesting: list<int>, merged: list<record<surface: int, keys: int>>, built: list<int>> {
    let parsed = ($serial | lines | where {|l| $l starts-with "fps: tile pass " } | parse "fps: tile pass {frame} {kind}:{items}" | update frame {|r| $r.frame | into int })
    $parsed | group-by frame | items {|frame, rows|
        let of = {|kind: string| $rows | where kind == $kind | get items | each {|i| $i | str trim | split row " " | where {|w| $w != "" } } | flatten }
        {
            frame: ($frame | into int),
            requesting: (do $of "requesting" | each {|w| $w | into int }),
            merged: (do $of "merged" | each {|w| let p = ($w | split row ":"); { surface: ($p.0 | into int), keys: ($p.1 | into int) } }),
            built: (do $of "built" | each {|w| $w | into int }),
        }
    } | sort-by frame
}

# Pool fixtures from cold starts: rotation, first sight, rings, stale entries
def pool-holds [kernel: path, image: path, out: path, set: string, disk: path, lit: binary]: nothing -> record<rotation_surfaces: int, rotation_wait: int, sight_frames: int, sight_slots: int, rings_merged: int, stale_evicted: int> {
    let launch = {|name: string, sends: list<any>|
        let all = ($sends | append [{ at: $POOL_PLACE_AT, bytes: (pose pose-frame $SPAWN_POSE) }, { at: $POOL_END_AT, bytes: (pose command-frame "E") }] | sort-by at)
        let run = (launch --kernel $kernel --image $image --out ($out | path join $"pool_($name)") --set $set --sound --api --disk $disk --serial "fps" --send $all --capture $POOL_CAPTURE_AT --seconds 7)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on the pool's ($name)"
        let m = (measure $run.api [{ name: "start", places: [], pad: [] }, { name: "sight", places: [$SPAWN_POSE], pad: [] }])
        assert ($m.complete and $m.valid and $m.schema == $CLOCK_SCHEMA) $"the pool's ($name) complete and valid at schema ($CLOCK_SCHEMA): ($m.problems | str join '; ') ($m.invalid | str join '; ')"
        assert ($m.rows | any {|r| $r.leg == "sight" }) $"the pool's ($name) placed its view"
        let cold = ((stream $run.api).configs | last | get from)
        assert ($cold > 0) $"the pool's ($name) cold start a configuration of its own: from ($cold)"
        { run: $run, rows: ($m.rows | where {|r| $r.frame >= $cold }), cold: $cold }
    }
    let settled = {|r| $r.missed_blocks == 0 and $r.building == 0 and $r.admitted == 0 and $r.dropped == 0 and $r.filtered == 0 and $r.tiles_built == 0 }

    let rotation = (do $launch "rotation" [
        { at: 1300ms, bytes: (console workers $POOL_ROTATION.workers $POOL_ROTATION.grain) }
        { at: 1300ms, bytes: (console packet $PACKET_CAPS.commands $PACKET_CAPS.spans) }
        { at: $POOL_PLACE_AT, bytes: (console pool --trace --cold --guarantee $POOL_ROTATION.guarantee --ring $POOL_ROTATION.ring --merge-us $POOL_ROTATION.merge_us) }
    ])
    let passes = (pool-trace $rotation.run.serial | where {|p| $p.frame > $rotation.cold })
    assert (($passes | length) > 0) $"the pool's trace printed the rotation's passes: ($rotation.run.serial | lines | last 3)"
    let most = ($passes | each {|p| $p.requesting | length } | math max)
    let last_pass = ($passes | last | get frame)
    let waits = ($passes | get requesting | flatten | uniq | each {|s|
        let asked = ($passes | where {|p| $s in $p.requesting } | get 0.frame)
        let built = ($passes | where {|p| $p.frame >= $asked and $s in $p.built } | get -o 0.frame)
        { surface: $s, asked: $asked, built: $built }
    } | where {|w| $w.asked + $most < $last_pass })
    let late = ($waits | where {|w| $w.built == null or ($w.built - $w.asked) > $most })
    assert ($late | is-empty) $"every surface requesting under the rotation built within ($most) frames of its first request, the most one pass found: ($late | first 5)"
    let starts = ($passes | where {|p| ($p.merged | length) > 0 })
    let repeated = ($starts | window 2 | where {|w|
        let left = ($w.0.requesting | where {|s| $s not-in ($w.0.merged | get surface) })
        ($w.1.requesting | length) >= 2 and $w.0.merged.0.surface == $w.1.merged.0.surface and ($left | is-not-empty)
    })
    assert ($repeated | is-empty) $"the merge's start moved on at every pass after one that left a requesting surface unmerged: ($repeated | first 2 | each {|w| $w.1.frame })"
    let over = ($passes | each {|p| $p.merged | where {|m| $m.keys > ($POOL_ROTATION.guarantee * $TILE_CONTEXTS) } | each {|m| { frame: $p.frame, merged: $m } } } | flatten)
    assert ($over | is-empty) $"no surface merged past its tier of ($POOL_ROTATION.guarantee) in every context across the bands and the flushes: ($over | first 3)"
    let rotated = ($rotation.rows | where {|r| $r.frame > $rotation.cold })
    assert ($rotated | any {|r| $r.dropped > 0 }) "the rotation's open ring of four overflowed"
    assert ($rotated | any {|r| $r.unprocessed > 0 }) "the rotation's merge stopped short at its share"

    let sight = (do $launch "sight" [{ at: $POOL_PLACE_AT, bytes: (console pool --cold) }])
    let first = ($sight.rows | first)
    assert ($first.missed_blocks > 0 and $first.admitted > 0 and $first.tiles_built == 0 and $first.slots_used == 0) $"first sight drew blocks without their tiles from an empty pool and asked for them: ($first | select frame missed_blocks admitted tiles_built slots_used)"
    let settled_at = ($sight.rows | where {|r| do $settled $r } | get -o 0.frame)
    assert ($settled_at != null) $"first sight settled under the ordinary budget: ($sight.rows | last | select frame missed_blocks admitted building tiles_built)"
    let unsettled = ($sight.rows | where {|r| $r.frame >= $settled_at and not (do $settled $r) })
    assert ($unsettled | is-empty) $"the view settled from frame ($settled_at) on: ($unsettled | first 3 | select frame missed_blocks admitted tiles_built)"
    let holds = ($sight.rows | where frame == $settled_at | get 0.slots_used)
    let built = ($sight.rows | where {|r| $r.frame <= $settled_at } | get tiles_built | math sum)
    assert ($built == $holds and ($sight.rows | all {|r| $r.evicted == 0 })) $"the ($built) tiles built to settling the ($holds) slots the view holds, none evicted"

    let rings = (do $launch "rings" [{ at: $POOL_PLACE_AT, bytes: (console pool --modes $POOL_LIFTED --cold --guarantee 1) }])
    let cold = ($rings.rows | get 0)
    let warming = ($rings.rows | get 1)
    let after = ($rings.rows | get 2)
    assert ($cold.missed_blocks > 0 and $cold.admitted > 0) $"the rings' cold start asked for the view's tiles: ($cold | select frame missed_blocks admitted)"
    assert ($warming.batch_admitted == $cold.admitted and $warming.unprocessed == 0 and $warming.tiles_built == $warming.merged and $warming.merged > 0) $"the warming frame merged every request the frame before made and built every key merged: ($warming | select frame batch_admitted merged unprocessed tiles_built)"
    assert ($warming.merged > ($warming.requesting * $TILE_CONTEXTS)) $"the warming frame merged past what tiers of one request hold, the open rings merged: ($warming.merged) keys for ($warming.requesting) surfaces"
    assert ($warming.admitted == 0 and $warming.missed_blocks == 0) $"the warming frame drew every block from its tile and asked for none: ($warming | select frame admitted missed_blocks)"
    assert (do $settled $after) $"the view settled at the frame after the warming frame: ($after | select frame missed_blocks admitted building tiles_built)"

    let stale = (do $launch "stale" [
        { at: 1400ms, bytes: (console level true false) }
        { at: $POOL_PLACE_AT, bytes: (console pool --modes ($POOL_LIFTED + $POOL_STALE) --cold --slots $POOL_STALE_SLOTS) }
    ])
    let held = ($stale.rows | where {|r| $r.frame > $stale.cold })
    assert ($held | all {|r| $r.config_flags == ($POOL_LIFTED + $POOL_STALE) and $r.slots_effective == $POOL_STALE_SLOTS }) $"the stale entries' run under the lift and the stale mode on ($POOL_STALE_SLOTS) slots: ($held | first | select config_flags slots_effective)"
    let evicted = ($held | get evicted | math sum)
    assert ($evicted > 0) $"the stale entries' run evicted under its cap: ($held | first 3 | select frame tiles_built evicted slots_used)"
    assert ($stale.run.screen != "") "a screen was taken on the stale entries' run"
    let stale_rows = (picture rows-differ (open --raw $stale.run.screen | into binary) $lit [0 0 1920 1080])
    assert ($stale_rows | is-empty) $"the stale entries read no tile: the bright spawn view on ($POOL_STALE_SLOTS) slots, ($evicted) tiles evicted with their entries left, the lit loop's picture: rows ($stale_rows | first 5) differ, ($stale_rows | length) in all"
    {
        rotation_surfaces: $most, rotation_wait: ($waits | each {|w| $w.built - $w.asked } | math max),
        sight_frames: ($settled_at - $sight.cold), sight_slots: $holds, rings_merged: $warming.merged,
        stale_evicted: $evicted,
    }
}

# The builder wall built and dumped under three lightings, read by the oracle
export def builder-holds [kernel: path, image: path, out: path, set: string, source: record, game: path]: nothing -> record<tiles: int, levels: int, k: int, w: int, h: int, by_level: list<any>> {
    let tree = (tree builder-tree $source $game ($out | path join "builder"))
    let m = (map read ($tree | path join "map" $"($FIXTURE_MAP).jabfps.map"))
    let material = ($m.materials | enumerate | where {|e| $e.item.name == $BUILDER_FIXTURE.name } | get 0.index)
    let found = ($m.walls | enumerate | where {|e| $e.item.surface.material == $material })
    assert equal ($found | length) 1 $"one wall carries the builder fixture: ($found | length)"
    let wall = ($found | get 0.item)
    let surface = ($LUMAP_PLANES + ($found | get 0.index))
    let size = $BUILDER_FIXTURE.size
    let frame = (tree wall-lumap $m $wall $size $size)
    let levels = (tree chain-levels $size $size)
    assert ($frame.k > 0 and $frame.k < ($levels - 1)) $"the fixture's k, ($frame.k), leaves levels below, at, and above it in its chain of ($levels)"
    let grid = (0..<$levels | each {|l|
        let span = (1 bit-shl ($l + $TILE_SHIFT))
        let across = ((($frame.w bit-shl $frame.k) + $span - 1) // $span)
        let down = ((($frame.h bit-shl $frame.k) + $span - 1) // $span)
        0..<$down | each {|ty| 0..<$across | each {|tx| { level: $l, tx: $tx, ty: $ty } } } | flatten
    } | flatten | sort-by level ty tx)
    let sends = ($BUILDER_LIGHTINGS | enumerate | each {|e|
        let at = ($BUILDER_AT + ($BUILDER_STEP * (3 * $e.index)))
        let light = (match $e.item {
            "bright" => (console level true false),
            "gradient" => (console level false false --gradient),
            _ => (console level false false --parity),
        })
        [{ at: $at, bytes: $light }, { at: ($at + $BUILDER_STEP), bytes: (console build $surface) }, { at: ($at + (2 * $BUILDER_STEP)), bytes: (console dump $surface) }]
    } | flatten)
    let end = ($BUILDER_AT + ($BUILDER_STEP * (3 * ($BUILDER_LIGHTINGS | length) + 1)))
    let run_out = ($out | path join "builder_run")
    let run = (launch --kernel $kernel --image $image --out $run_out --set $set --sound --api --disk (tree romfs $tree ($out | path join "builder.romfs")) --serial "fps" --send $sends --capture $end --seconds 9)
    assert equal (open --raw $run.qemu_log) "" "QEMU has no complaint about the guest on the builder's run"
    let spec = ({ size: $size, lightings: $BUILDER_LIGHTINGS, k: $frame.k, w: $frame.w, h: $frame.h, truncations: $BUILDER_TRUNCATIONS } | to nuon)
    let read_out = ($out | path join "builder.nuon")
    let oracle = (^nu ($game | path join "test" "tiles.nu") builder ($run_out | path join "api.out") $spec $read_out | complete)
    assert equal $oracle.exit_code 0 $"the builder's oracle read the run's dumps: ($oracle.stderr)"
    let read = (open $read_out)
    assert ($read.problems | is-empty) $"every dump whole, every record in its place: ($read.problems | first 3)"
    assert equal $read.dumps ($BUILDER_LIGHTINGS | length) $"a dump under each light: ($read.dumps) of ($BUILDER_LIGHTINGS | length)"
    mut dumped = []
    for e in $read.results {
        let keys = ($e.tiles | each {|t| { level: $t.level, tx: $t.tx, ty: $t.ty } } | sort-by level ty tx)
        assert equal $keys $grid $"every tile of the wall at every level dumped once under the ($e.lighting) lumels: ($keys | length) of ($grid | length)"
        let foreign = ($e.tiles | where {|t| $t.surface != $surface or $t.k != $frame.k or $t.w != $frame.w or $t.h != $frame.h })
        assert ($foreign | is-empty) $"every dumped tile the wall's, its map's k, W, and H ($frame.k), ($frame.w), and ($frame.h) as lumap_frame's rule gives them: ($foreign | first 2)"
        $dumped = ($dumped | append ($e.tiles | each {|t| $t | insert lighting $e.lighting }))
    }
    let held = $dumped
    let alpha = ($held | where {|r| $r.alpha > 0 })
    assert ($alpha | is-empty) $"every texel's alpha the chain's: ($alpha | first 3)"
    let bright = ($held | where {|r| $r.lighting == "bright" and $r.unlike > 0 })
    assert ($bright | is-empty) $"under the bright lumels every texel the chain's at its level: ($bright | first 3)"
    let past = ($held | where {|r| $r.past > 0 })
    assert ($past | is-empty) $"every texel within the build's rounding of its centre's light: ($past | first 3)"
    let by_level = (0..<$levels | each {|l|
        let these = ($held | where level == $l)
        let lit = ($these | where {|r| $r.lighting != "bright" })
        {
            level: $l, tiles: ($these | where lighting == "bright" | length),
            clamped: ($these | where lighting == "bright" | get clamped | math sum),
            telling: ($lit | get telling | math sum),
            gradient: ($these | where lighting == "gradient" | get most | math max),
            parity: ($these | where lighting == "parity" | get most | math max),
        }
    })
    let unclamped = ($by_level | where clamped == 0)
    assert ($unclamped | is-empty) $"texels past the last node at every level: none at levels ($unclamped | get level)"
    let untold = ($by_level | where telling == 0)
    assert ($untold | is-empty) $"texels where a light at the corner reads past twice the rounding at every level: none at levels ($untold | get level)"
    { tiles: ($grid | length), levels: $levels, k: $frame.k, w: $frame.w, h: $frame.h, by_level: $by_level }
}

# A count line's counts, saturations included where present, else refused
def count-of [line: string]: nothing -> record {
    let parsed = (if ($line | str contains "; saturated ") { $line | parse ($COUNT_LINE + $COUNT_SATURATED) } else { $line | parse $COUNT_LINE })
    assert equal ($parsed | length) 1 $"a count line of COUNT_LINE's form, FOOTPRINT's saturations after it or not: ($line)"
    $parsed | get 0 | update cells {|c| $c | into int }
}

# The handoff measured: tiled against lit by level and light, partial runs
export def handoff-holds [kernel: path, image: path, out: path, set: string, source: record, game: path]: nothing -> record<comparisons: list<any>, windows: list<any>, early: record, reentries: list<any>> {
    assert ("COUNT" in ($set | split row ",")) $"the handoff runs on a handoff,count build, its re-entries counted: ($set)"
    let names = {|order: list<any>| $order | each {|a| if $a.kind == "screen" { "screen" } else { [P E] | get $a.index } } }
    let late = (do $names (launch due-order [{ kind: "send", index: 0, at: $SETTLE_AT }, { kind: "send", index: 1, at: $HANDOFF_END_AT }] $HANDOFF_SCREEN_AT ($HANDOFF_END_AT + 100ms)))
    assert equal $late [P screen E] $"a late poll takes the overdue placement, the screen, then the E: ($late)"
    let tied = (do $names (launch due-order [{ kind: "send", index: 0, at: $HANDOFF_SCREEN_AT }, { kind: "send", index: 1, at: $HANDOFF_SCREEN_AT }] $HANDOFF_SCREEN_AT $HANDOFF_SCREEN_AT))
    assert equal $tied [screen P E] $"a placement, the screen, and the E due at one time take the screen first: ($tied)"
    let tree = (tree handoff-tree $source $game ($out | path join "handoff"))
    let m = (map read ($tree | path join "map" $"($FIXTURE_MAP).jabfps.map"))
    let material = ($m.materials | enumerate | where {|e| $e.item.name == $HANDOFF_FIXTURE.name } | get 0.index)
    let found = ($m.walls | where {|w| $w.surface.material == $material })
    assert equal ($found | length) 1 $"one wall carries the handoff fixture: ($found | length)"
    let wall = ($found | get 0)
    let s = $wall.surface
    let size = $HANDOFF_FIXTURE.size
    let frame = (tree wall-lumap $m $wall $size $size)
    let levels = (tree chain-levels $size $size)
    assert ($frame.k > 0 and $frame.k < ($levels - 2)) $"the fixture's k, ($frame.k), leaves levels below it, at it, and two above it in its chain of ($levels)"
    assert ($HANDOFF_BOUNDS | values | all {|b| ($b | length) == ($frame.k + 1) }) $"the fixture's bounds a level each from 0 to k, ($frame.k): ($HANDOFF_BOUNDS)"
    let a = ($m.vertices | get $wall.a)
    let b = ($m.vertices | get $wall.b)
    let len = ((($b.x - $a.x) ** 2 + ($b.y - $a.y) ** 2) | math sqrt)
    let e = [(($b.x - $a.x) / $len), (($b.y - $a.y) / $len)]
    assert ((($e.0 + 1.0) | math abs) < 0.000001 and ($e.1 | math abs) < 0.000001) $"the fixture's wall runs along -x with the room on its -y side, so yaw 90 faces it: ($e)"
    let d = $HANDOFF_DISTANCE
    let eye = { x: (($a.x + $b.x) / 2), y: ($a.y - $d), z: $EYE_HEIGHT }
    let step = ($size * $s.u_scale * $d / 960)
    assert ($step < 2) $"the handoff pose reads level 0 by the block's rule at ($step) texels a pixel"
    let sector = ($m.sectors | get $wall.sector)
    let top = ([(map plane-z $sector.ceiling $a.x $a.y), (map plane-z $sector.ceiling $b.x $b.y)] | math max)
    let bottom = ([(map plane-z $sector.floor $a.x $a.y), (map plane-z $sector.floor $b.x $b.y)] | math min)
    let u_at = {|x: number|
        let along = ((($eye.x + (((($x + 0.5) - 960) / 960) * $d)) - $a.x) * $e.0)
        ((($along * $s.u_scale) + $s.u_offset) * $size) - $frame.u0
    }
    let v_at = {|y: number|
        let z = ($eye.z - (((($y + 0.5) - 540) / 960) * $d))
        (((($wall.anchor - $z) * $s.v_scale) + $s.v_offset) * $size) - $frame.v0
    }
    let ends = ([$a.x, $b.x] | each {|x| 960 + ((($x - $eye.x) / $d) * 960) })
    let rect = [
        ([((($ends | math min) | math ceil | into int) + $FIXTURE_INSET), $FIXTURE_INSET] | math max)
        ([(((540 - ((($top - $eye.z) / $d) * 960)) | math ceil | into int) + $FIXTURE_INSET), $FIXTURE_INSET] | math max)
        ([((($ends | math max) | math floor | into int) - $FIXTURE_INSET), (1920 - $FIXTURE_INSET)] | math min)
        ([(((540 + ((($eye.z - $bottom) / $d) * 960)) | math floor | into int) - $FIXTURE_INSET), (1080 - $FIXTURE_INSET)] | math min)
    ]
    let seen = [(do $u_at $rect.0), (do $u_at ($rect.2 - 1))]
    let crossing = (0..<$levels | each {|l|
        let side = (1 bit-shl ($l + $TILE_SHIFT))
        if ((($seen | math min) / $side) | math floor) != ((($seen | math max) / $side) | math floor) { $l } else { null }
    } | compact)
    assert (0 in $crossing) $"the wall's spans cross tiles of level 0 on the screen: ($seen) texels from the map's first node"
    let place = { name: "handoff", x: $eye.x, y: $eye.y, z: $eye.z, yaw: 90, pitch: 0 }
    let disk = (tree romfs $tree ($out | path join "handoff.romfs"))
    let placed = (pose pose-frame $place)
    let ended = (pose command-frame "E")
    let legs = [{ name: "start", places: [], pad: [] }, { name: "first", places: [$place], pad: [] }, { name: "second", places: [$place], pad: [] }]
    let timing = { placed: $placed, second: $SETTLE_AT, screen: $HANDOFF_SCREEN_AT, end: $HANDOFF_END_AT }
    let launch = {|name: string, sends: list<any>, times: record|
        let all = ($sends | append [{ at: $PLACE_AT, bytes: $times.placed }, { at: $times.second, bytes: $times.placed }, { at: $times.end, bytes: $ended }] | sort-by at)
        let run = (launch --kernel $kernel --image $image --out ($out | path join $"handoff_($name)") --set $set --sound --api --disk $disk --serial "fps" --send $all --screen $times.screen --seconds $HANDOFF_SECONDS)
        let label = $"the handoff's ($name)"
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($label)"
        let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
        assert equal ($frames | length) 3 $"the first frame and the pose's two placements reported on ($label): ($run.serial)"
        let line = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
        assert ($line.uncovered < $CRACKS) $"no pixel uncovered on ($label): ($line)"
        assert ($run.screen != "") $"a screen taken whole on ($label), asked at ($run.screen_started) s"
        let m = (measure $run.api $legs)
        assert ($m.complete and $m.valid and $m.schema == $CLOCK_SCHEMA) $"($label) complete and valid at schema ($CLOCK_SCHEMA): ($m.problems | str join '; ') ($m.invalid | str join '; ')"
        let window = ($m.rows | where leg == "second")
        let stamp = (picture stamp (open --raw $run.screen | into binary))
        let written = {|at: duration, bytes: binary| $run.send_seconds | get ($all | enumerate | where {|x| $x.item.at == $at and $x.item.bytes == $bytes } | get 0.index) }
        let counted = ($run.serial | lines | where {|l| $l starts-with "fps: count " })
        assert (($counted | length) > 0) $"a count line on ($label), a COUNT build's"
        {
            name: $name, label: $label, screen: $run.screen, frame: $line, api: $run.api, final: $m.final, window: $window,
            stamp: $stamp, shown: ($stamp != null and ($window | any {|r| ($r.frame mod (1 bit-shl $STAMP_BITS)) == $stamp and $r.frame < $m.final })),
            started: $run.screen_started, completed: $run.screen_completed,
            placed: (do $written $times.second $times.placed), ended: (do $written $times.end $ended),
            counts: (count-of ($counted | last)),
        }
    }
    let holds = {|r: record, kind: string, slots: int|
        let unsettled = (handoff-unsettled $r.window $kind $slots)
        assert ($unsettled | is-empty) $"($r.label) held as a ($kind) run from its second placement's frame through the marker's: ($unsettled | first 3 | str join '; ')"
        assert $r.shown $"the screen of ($r.label) shows a frame of its window before the marker's: the stamp ($r.stamp), the window frames ($r.window | get -o 0.frame) to ($r.final)"
        assert ($r.ended != null and $r.ended > $r.completed) $"the E of ($r.label) written after its screen completed: at ($r.ended) s, the screen at ($r.completed) s"
        { name: $r.name, from: ($r.window | get 0.frame), stamp: $r.stamp, final: $r.final }
    }
    mut runs = []
    mut windows = []
    for lighting in $HANDOFF_LIGHTINGS {
        let light = {|held: bool| if $lighting == "gradient" { console level false $held --gradient } else { console level false $held --parity } }
        for l in 0..<$levels {
            let label = $"at level ($l) under the ($lighting) lumels"
            let lit = (do $launch $"($lighting)_($l)_held" [{ at: 1400ms, bytes: (do $light true) }, { at: 1400ms, bytes: (console raise $l --stamp) }] $timing)
            assert ($lit.frame.tiles_built == 0 and $lit.frame.tiled == 0) $"no tile built or read with the tiles held off ($label): ($lit.frame)"
            $windows = ($windows | append (do $holds $lit "held" $HANDOFF_PARTIAL_SLOTS))
            let tiled = (do $launch $"($lighting)_($l)_tiled" [{ at: 1400ms, bytes: (do $light false) }, { at: 1400ms, bytes: (console raise $l --stamp) }] $timing)
            if $l <= $frame.k {
                assert ($tiled.frame.tiles_built == 0 and $tiled.frame.tiled > 0) $"the wall settled on its tiles ($label): ($tiled.frame)"
            } else {
                assert ($tiled.frame.tiles_built == 0 and $tiled.frame.tiled == 0) $"the wall above k, ($frame.k), drawn by the lit loop, no tile read ($label): ($tiled.frame)"
            }
            $windows = ($windows | append (do $holds $tiled "tiled" $HANDOFF_PARTIAL_SLOTS))
            $runs = ($runs | append { name: $"($lighting)_($l)_tiled", pose: "head-on", lighting: $lighting, kind: "tiled", level: $l, a: $tiled.screen, b: $lit.screen, t: "" })
            if $l in $crossing {
                let partial = (do $launch $"($lighting)_($l)_partial" [
                    { at: 1300ms, bytes: (console workers 0 0) }
                    { at: 1400ms, bytes: (do $light false) }
                    { at: 1400ms, bytes: (console raise $l --stamp) }
                    { at: ($PLACE_AT + $HANDOFF_ONCE_AFTER), bytes: (console pool --modes ($POOL_LIFTED + $POOL_ONCE) --cold --slots $HANDOFF_PARTIAL_SLOTS) }
                ] $timing)
                let f = $partial.frame
                assert ($f.tiles_built == 0 and $f.slots == $HANDOFF_PARTIAL_SLOTS and $f.tiled > 0 and $f.tiled < $tiled.frame.tiled) $"the wall drawn under partial residency ($label), ($HANDOFF_PARTIAL_SLOTS) slots built once and some of its blocks read from them, fewer than settled: ($f | select tiles_built slots tiled) against ($tiled.frame.tiled)"
                $windows = ($windows | append (do $holds $partial "partial" $HANDOFF_PARTIAL_SLOTS))
                $runs = ($runs | append { name: $"($lighting)_($l)_partial", pose: "head-on", lighting: $lighting, kind: "partial", level: $l, a: $partial.screen, b: $lit.screen, t: $tiled.screen })
            }
        }
    }
    let oblique = { name: "oblique", x: ($a.x + ($e.0 * $HANDOFF_OBLIQUE.along)), y: ($a.y - $HANDOFF_OBLIQUE.off), z: $EYE_HEIGHT, yaw: (90 + $HANDOFF_OBLIQUE.turn), pitch: 0 }
    let oblique_timing = ($timing | merge { placed: (pose pose-frame $oblique) })
    let whole = [0, 0, 1920, 1080]
    mut reentries = []
    for lighting in $HANDOFF_LIGHTINGS {
        let light = {|held: bool| if $lighting == "gradient" { console level false $held --gradient } else { console level false $held --parity } }
        for l in 0..<$HANDOFF_OBLIQUE_LEVELS {
            let label = $"at level ($l) under the ($lighting) lumels, the wall oblique"
            let lit = (do $launch $"oblique_($lighting)_($l)_held" [{ at: 1400ms, bytes: (do $light true) }, { at: 1400ms, bytes: (console raise $l --stamp) }] $oblique_timing)
            assert ($lit.frame.tiles_built == 0 and $lit.frame.tiled == 0) $"no tile built or read with the tiles held off ($label): ($lit.frame)"
            $windows = ($windows | append (do $holds $lit "held" $HANDOFF_OBLIQUE_SLOTS))
            let tiled = (do $launch $"oblique_($lighting)_($l)_tiled" [{ at: 1400ms, bytes: (do $light false) }, { at: 1400ms, bytes: (console raise $l --stamp) }] $oblique_timing)
            assert ($tiled.frame.tiles_built == 0 and $tiled.frame.tiled > 0) $"the wall settled on its tiles ($label): ($tiled.frame)"
            $windows = ($windows | append (do $holds $tiled "tiled" $HANDOFF_OBLIQUE_SLOTS))
            let partial = (do $launch $"oblique_($lighting)_($l)_partial" [
                { at: 1300ms, bytes: (console workers 0 0) }
                { at: 1400ms, bytes: (do $light false) }
                { at: 1400ms, bytes: (console raise $l --stamp) }
                { at: ($PLACE_AT + $HANDOFF_ONCE_AFTER), bytes: (console pool --modes ($POOL_LIFTED + $POOL_ONCE) --cold --slots $HANDOFF_OBLIQUE_SLOTS) }
            ] $oblique_timing)
            let f = $partial.frame
            assert ($f.tiles_built == 0 and $f.slots == $HANDOFF_OBLIQUE_SLOTS and $f.tiled > 0 and $f.tiled < $tiled.frame.tiled) $"the wall drawn under partial residency ($label), ($HANDOFF_OBLIQUE_SLOTS) slots built once and some of its blocks read from them, fewer than settled: ($f | select tiles_built slots tiled) against ($tiled.frame.tiled)"
            $windows = ($windows | append (do $holds $partial "partial" $HANDOFF_OBLIQUE_SLOTS))
            $reentries = ($reentries | append { lighting: $lighting, level: $l, two: $partial.counts.two, four: $partial.counts.four, cut: $partial.counts.cut })
            $runs = ($runs | append [
                { name: $"oblique_($lighting)_($l)_tiled", pose: "oblique", lighting: $lighting, kind: "tiled", level: $l, a: $tiled.screen, b: $lit.screen, t: "", whole: true, rect: $whole }
                { name: $"oblique_($lighting)_($l)_partial", pose: "oblique", lighting: $lighting, kind: "partial", level: $l, a: $partial.screen, b: $lit.screen, t: $tiled.screen, whole: true, rect: $whole }
            ])
        }
    }
    let fixture = [{ at: 1400ms, bytes: (console level false false --gradient) }, { at: 1400ms, bytes: (console raise 0 --stamp) }]
    let early = (do $launch "early" $fixture ($timing | merge { second: ($HANDOFF_SCREEN_AT - $HANDOFF_EARLY) }))
    assert ($early.placed != null and $early.placed < $early.started) $"the early fixture's placement written before its screen was asked: the placement at ($early.placed) s, the screen asked at ($early.started) s"
    assert ($early.stamp != null) $"the early fixture's stamp read from its screen"
    let together = (do $launch "together" $fixture ($timing | merge { end: $HANDOFF_SCREEN_AT }))
    $windows = ($windows | append (do $holds $together "tiled" $HANDOFF_PARTIAL_SLOTS))
    let pairs = $runs
    let spec = {
        rect: $rect, crosshair: $FIXTURE_CROSSHAIR, stamp: [0, 0, ($STAMP_BITS * $STAMP_CELL), $STAMP_CELL], k: $frame.k, w: $frame.w, h: $frame.h,
        u: [(do $u_at 0), ((do $u_at 1) - (do $u_at 0))], v: [(do $v_at 0), ((do $v_at 1) - (do $v_at 0))],
        pairs: $pairs,
    }
    let spec_file = ($out | path join "handoff_spec.nuon")
    $spec | to nuon | save -f $spec_file
    let tiles = ($game | path join "test" "tiles.nu")
    let stats = ($pairs | enumerate | par-each --keep-order {|e|
        let file = ($out | path join $"handoff_stats_($e.index).nuon")
        let r = (^nu $tiles handoff $spec_file $e.index $file | complete)
        { name: $e.item.name, exit: $r.exit_code, stderr: $r.stderr, file: $file }
    })
    mut compared = []
    for s in $stats {
        assert equal $s.exit 0 $"the handoff's statistics read the ($s.name) captures: ($s.stderr)"
        $compared = ($compared | append (open $s.file))
    }
    let read = $compared
    assert equal ($read | get name) ($pairs | get name) $"every comparison read: ($read | get name)"
    let unmixed = ($read | where {|r| $r.kind == "partial" and $r.mixed_rows == 0 })
    assert ($unmixed | is-empty) $"under partial residency rows of the wall take the tiled picture's pixels and the lit one's both, its spans alternating hits and misses: none at ($unmixed | get name)"
    let residual = ($read | where {|r| $r.kind == "partial" and $r.residual.most != 0 })
    assert ($residual | is-empty) $"under partial residency every pixel the tiled picture's or the lit one's: ($residual | each {|r| $'($r.name) by ($r.residual.most) at most, ($r.residual.differing) pixels' } | str join '; ')"
    for r in ($read | where {|r| $r.pose == "head-on" and $r.kind == "tiled" }) {
        if $r.level <= $frame.k {
            let bound = ($HANDOFF_BOUNDS | get $r.lighting | get $r.level)
            assert ($r.inner.most <= $bound and $r.clamped.most <= $bound) $"the handoff at level ($r.level) under the ($r.lighting) lumels within ($bound) of 255: ($r.inner.most), past the last node ($r.clamped.most)"
        } else {
            assert ($r.inner.differing == 0 and $r.clamped.differing == 0) $"above k, ($frame.k), the tiled picture the lit one at level ($r.level) under the ($r.lighting) lumels: ($r.inner.differing) and ($r.clamped.differing) pixels differ"
        }
    }
    for lighting in $HANDOFF_LIGHTINGS {
        let counted = ($reentries | where lighting == $lighting)
        for case in [two four cut] {
            assert (($counted | get $case | math max) > 0) $"a re-entry into an interval ($case) on the oblique pose's reported frame under the ($lighting) lumels: ($counted | each {|r| $'level ($r.level) ($r.two), ($r.four), ($r.cut)' } | str join '; ')"
        }
    }
    {
        comparisons: $read, windows: $windows,
        early: { stamp: $early.stamp, from: ($early.window | get -o 0.frame), final: $early.final, accepted: $early.shown, placed: $early.placed, started: $early.started },
        reentries: $reentries,
    }
}

# A HANDOFF build's tiled-to-lit measurement run alone, its figures printed
export def handoff [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
        let game = $context.game
        let held = (handoff-holds $kernel $image $out $set (open ($game | path join "content" "map" "render_1.nuon")) $game)
        for r in $held.comparisons {
            let i = $r.inner
            let partial = (if $r.kind == "partial" { $", from the nearer of the tiled and the lit ($r.residual.most) at most, ($r.residual.p99) at the 99th, ($r.mixed_rows) rows taking both" } else { "" })
            print $"fps: the handoff ($r.pose), ($r.kind) against lit at level ($r.level) under the ($r.lighting) lumels: ($i.differing) of ($i.pixels) pixels differ, by ($i.most) at most, ($i.p99) at the 99th, ($i.mean | math round --precision 3) on average; past the last node ($r.clamped.pixels) pixels, by ($r.clamped.most) at most; ($r.left_out) left out($partial)"
        }
        for lighting in ($held.reentries | get lighting | uniq) {
            let counted = ($held.reentries | where lighting == $lighting | each {|c| $"level ($c.level) ($c.two) in two blocks, ($c.four) in four, ($c.cut) cut short" } | str join "; ")
            print $"fps: the handoff oblique under the ($lighting) lumels, re-entries on the reported frame: ($counted)"
        }
        let past = ($held.windows | each {|w| $w.stamp - $w.from })
        let e = $held.early
        let lead = ((($e.started - $e.placed) * 1000) | math round --precision 1)
        print $"fps: the handoff's screens: each of ($held.windows | length) runs shows a frame of its settled window, ($past | math min) to ($past | math max) frames past its second placement's, its E after it; the placement due ($HANDOFF_EARLY) before the screen written ($lead) ms before it was asked, its screen (if $e.accepted { 'accepted' } else { 'refused' }) by its stamp, frame ($e.stamp) against the window from ($e.from) to ($e.final)"
    {}
}

# One level a block: the tiled spawn view identical to the tiles held off
export def block [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let still_disk = $records."light independence".still_disk
    mut spawn_captures = {}
    for v in [{ name: "tiled", held: false }, { name: "held", held: true }] {
        let sends = ([{ at: 1400ms, bytes: (console level true $v.held) }] | append (console settled $SPAWN_POSE))
        let run = (launch --kernel $kernel --image $image --out ($out | path join $"spawn_($v.name)") --set $set --sound --api --disk $still_disk --serial "fps" --send $sends --capture 3000ms --seconds 5)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on the spawn view with the tiles ($v.name)"
        let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
        assert equal ($frames | length) 3 $"the first frame and the pose's two placements reported on the spawn view with the tiles ($v.name): ($run.serial)"
        let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
        assert ($frame.uncovered < $CRACKS) $"the spawn view with the tiles ($v.name) has no pixel uncovered: ($frame)"
        assert ($run.screen != "") $"a screen was taken on the spawn view with the tiles ($v.name)"
        $spawn_captures = ($spawn_captures | insert $v.name { bytes: (open --raw $run.screen | into binary), frame: $frame })
    }
    assert ($spawn_captures.tiled.frame.tiled > 0) $"the spawn view read its tiles: ($spawn_captures.tiled.frame)"
    assert ($spawn_captures.held.frame.tiles_built == 0 and $spawn_captures.held.frame.tiled == 0) $"no tile built or read with the tiles held off: ($spawn_captures.held.frame)"
    let spawn_rows = (picture rows-differ $spawn_captures.tiled.bytes $spawn_captures.held.bytes [0 0 1920 1080])
    assert ($spawn_rows | is-empty) $"the spawn view the same whether its tiles are built or held off: rows ($spawn_rows | first 5) differ, ($spawn_rows | length) in all"
    {spawn_captures: $spawn_captures}
}

# Packets capped to a few commands and spans, the picture the uncapped one's
export def packet [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let still_disk = $records."light independence".still_disk
    let spawn_captures = $records."tiles block".spawn_captures
    let capped_sends = ([
        { at: 1300ms, bytes: (console packet $PACKET_CAPS.commands $PACKET_CAPS.spans) }
        { at: 1400ms, bytes: (console level true false) }
    ] | append (console settled $SPAWN_POSE))
    let capped_run = (launch --kernel $kernel --image $image --out ($out | path join "spawn_capped") --set $set --sound --api --disk $still_disk --serial "fps" --send $capped_sends --capture 3000ms --seconds 5)
    assert equal (open --raw $capped_run.qemu_log) "" "QEMU has no complaint about the guest on the spawn view in capped packets"
    let capped_frames = ($capped_run.serial | lines | where {|l| $l starts-with "fps: frame in" })
    assert equal ($capped_frames | length) 3 $"the first frame and the pose's two placements reported on the spawn view in capped packets: ($capped_run.serial)"
    let capped_frame = ($capped_frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
    assert ($capped_frame.flushes > 0) $"the spawn view's packets flushed under the caps: ($capped_frame)"
    assert ($capped_run.screen != "") "a screen was taken on the spawn view in capped packets"
    let capped_rows = (picture rows-differ (open --raw $capped_run.screen | into binary) $spawn_captures.tiled.bytes [0 0 1920 1080])
    assert ($capped_rows | is-empty) $"the spawn view drawn in packets of ($PACKET_CAPS.commands) commands and ($PACKET_CAPS.spans) spans, ($capped_frame.flushes) flushed, the uncapped one's: rows ($capped_rows | first 5) differ, ($capped_rows | length) in all"
    assert equal $capped_frame.rounds ($capped_frame.flushes + 1) $"every render of the capped frame a round of the workers: ($capped_frame)"
    {capped_run: $capped_run}
}

# The pool unchanged across flushes in frames whose boundary built tiles
export def frozen [context: record, records: record]: nothing -> record {
    let capped_run = $records."tiles packet".capped_run
    let capped_stream = (stream $capped_run.api)
    let capped_built = ($capped_stream.draws | where {|d| $d.tiles_built > 0 } | get frame)
    let capped_flushed = ($capped_stream.packets | where {|k| $k.flushes > 0 and $k.frame in $capped_built })
    assert (($capped_flushed | length) > 0) $"frames whose boundary built tiles drawn in flushed packets, the pool held unchanged at every render: tiles built in ($capped_built | length) frames"
    {}
}

# The pool's own fixtures run: the rotation, first sight, the rings
export def pool [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let still_disk = $records."light independence".still_disk
    let spawn_captures = $records."tiles block".spawn_captures
    let pool = (pool-holds $kernel $image $out $set $still_disk $spawn_captures.held.bytes)
    print $"fps: the tile pool: under a tier of one and a ring of four, ($pool.rotation_surfaces) surfaces requesting each built within ($pool.rotation_wait) frames of its first request; first sight settled under the ordinary budget in ($pool.sight_frames) frames on ($pool.sight_slots) slots; the warming frame merged ($pool.rings_merged) keys past tiers of one; ($pool.stale_evicted) tiles evicted on ($POOL_STALE_SLOTS) slots with their entries left, the picture the lit loop's"
    {}
}

# Every builder tile at every level held texel by texel to the host's oracle
export def builder [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let render_1_source = $context.render_1.source
    let game = $context.game
    let builder = (builder-holds $kernel $image $out $set $render_1_source $game)
    print $"fps: the builder: ($builder.tiles) tiles of the fixture's wall at levels 0 to ($builder.levels - 1) about k ($builder.k), its map ($builder.w) by ($builder.h) nodes, every texel the chain's under the bright and within the build's rounding of its centre's light under the gradient and the parity, by level the most a channel lies from it ($builder.by_level | each {|l| $'($l.level): ($l.gradient | math round --precision 2) and ($l.parity | math round --precision 2)' } | str join ', ')"
    {}
}
