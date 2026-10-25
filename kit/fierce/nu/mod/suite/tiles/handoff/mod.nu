use (path self ../../../../../../../nu/mod/launch)
use (path self ../../../console)
use (path self ../../../map)
use (path self ../../../gauge/measure)
use (path self ../../../picture)
use (path self ../../../pose)
use (path self ../../../tree)
use std/assert
use (path self ../builder) [TILE_SHIFT]
use (path self ../../../console) [PLACE_AT SETTLE_AT]
use (path self ../../../frame) [CRACKS FRAME]
use (path self ../../../gauge/stream) [CLOCK_SCHEMA]
use (path self ../../../picture) [FIXTURE_CROSSHAIR FIXTURE_INSET STAMP_BITS STAMP_CELL]
use (path self ../pool) [POOL_LIFTED POOL_ONCE]
use (path self ../../../tree) [EYE_HEIGHT FIXTURE_MAP HANDOFF_FIXTURE]

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
export const HANDOFF_EARLY = 50ms

# The oblique pose: metres along the wall and off it, degrees turned
const HANDOFF_OBLIQUE = { along: 1.98, off: 2.5, turn: 45 }

# The slots an oblique partial residency run builds once
const HANDOFF_OBLIQUE_SLOTS = 3

# The oblique pose's levels, from 0 to this less one
const HANDOFF_OBLIQUE_LEVELS = 3

# A COUNT build's count line form, the reported frame's own counts
const COUNT_LINE = "fps: count {divides} divides, {avoided} avoided; blocks {shifted} shifted, {short} short; negative steps off sixteen {nu} in u, {nv} in v; flat spans {flat}; mismatches {mismatches}; re-entries {two} in two blocks, {four} in four, {cut} cut short"

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

# A count line's counts, else refused
def count-of [line: string]: nothing -> record {
    let parsed = ($line | parse $COUNT_LINE)
    assert equal ($parsed | length) 1 $"a count line of COUNT_LINE's form: ($line)"
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
    let tiles = ($game | path join "nu" "bin" "nuance" "tiles.nu")
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
