use ../../../../../../nu/mod/launch
use ../../console
use ../../picture
use ../../tree
use std/assert
use ../../frame [CRACKS FRAME]
use ../../picture [FIXTURE_CROSSHAIR]
use ../../tree [FIXTURE_POSES]

# Under room light, the most a channel may differ tiled against lit, of 255
const REAL_LIGHT_BOUND = 10

# The most a lit-loop pixel may step from its neighbour on a row, of 255
const CENTRE_STEP = 4

# The bay's floor points read for the light's view independence
const VIEW_POINTS = [[26.0, 6.0], [15.0, 6.0], [18.0, 4.0], [22.0, 8.0], [20.0, 12.0], [24.0, 16.0]]

# The spawn's eye the floor points are read from
const VIEW_EYE = { x: 29.0, y: 2.5, z: 1.6 }

# The two yaws the floor points are read at
export const VIEW_YAWS = [170, 130]

# The levels of 256 the light alone may differ by across the yaws
const VIEW_SLACK = 4

# The light's view independence: floor points read alike from two yaws
export def independence [context: record, records: record]: nothing -> record {
    let render_0_source = $records."render_zero poses".render_0_source
    let out = $context.out
    let game = $context.game
    let kernel = $context.kernel
    let image = $context.image
    let set = $context.set
    let view_still = (tree variant $render_0_source "render_0_still" [android] ($out | path join "still") $game)
    mut view_readings = []
    for yaw in $VIEW_YAWS {
        let view_pose = { name: $"view($yaw)", x: $VIEW_EYE.x, y: $VIEW_EYE.y, z: $VIEW_EYE.z, yaw: $yaw, pitch: 0 }
        mut captures = {}
        for v in [{ name: "still", bright: false }, { name: "bright", bright: true }] {
            let view_sends = ([{ at: 1400ms, bytes: (console level $v.bright false) }] | append (console settled $view_pose))
            let run = (launch --kernel $kernel --image $image --out ($out | path join $"view_($v.name)_($yaw)") --set $set --sound --api --disk (tree romfs $view_still ($out | path join $"($v.name).romfs")) --serial "fps" --send $view_sends --capture 3000ms --seconds 5)
            assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on the ($v.name) view at yaw ($yaw)"
            let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
            assert equal ($frames | length) 3 $"the first frame and the pose's two placements reported on the ($v.name) view at yaw ($yaw): ($run.serial)"
            let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
            assert ($frame.uncovered < $CRACKS) $"the ($v.name) view at yaw ($yaw) has no pixel uncovered: ($frame)"
            assert ($run.screen != "") $"a screen was taken on the ($v.name) view at yaw ($yaw)"
            $captures = ($captures | insert $v.name { bytes: (open --raw $run.screen | into binary), frame: $frame })
        }
        assert ($captures.bright.frame.tiled > 0) $"the bright copy reads its tiles: ($captures.bright.frame)"
        assert ($captures.still.frame.tiled > 0) $"the lit copy reads its tiles: ($captures.still.frame)"
        for p in $VIEW_POINTS {
            let at = (picture project $VIEW_EYE $yaw [$p.0, $p.1, 0.0])
            if $at == null { continue }
            let lit = (picture block-sum $captures.still.bytes $at)
            let bright = (picture block-sum $captures.bright.bytes $at)
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
    let still_disk = ($out | path join "still.romfs")
    {view_spread: $view_spread, still_disk: $still_disk}
}

# The tiled and lit pictures identical over the opening at every level
export def openings [context: record, records: record]: nothing -> record {
    let fixture_runs = $records."alpha fixture".fixture_runs
    let fixture_read = $records."alpha fixture".fixture_read
    let fixture_wall = $records."alpha fixture".fixture_wall
    mut openings = []
    for fp in $FIXTURE_POSES {
        let tiled = ($fixture_runs | get $"($fp.name)_tiled")
        let lit = ($fixture_runs | get $"($fp.name)_lit")
        let opening = (picture fixture-opening $fixture_read $fixture_wall $tiled.eye)
        let differing = (picture rows-differ $tiled.bytes $lit.bytes $opening)
        assert ($differing | is-empty) $"the tiled and the lit pictures agree over the opening ($opening) at level ($fp.level): rows ($differing | first 5) differ, ($differing | length) in all"
        $openings = ($openings | append [$opening])
    }
    let level_pairs = ($fixture_runs.near_tiled.read | zip $fixture_runs.mid_tiled.read | where {|p| $p.0.uniform })
    assert (($level_pairs | where {|p| $p.0.shows != $p.1.shows } | length) > 0) "a uniform patch's pass differs at level 1 from level 0, so the scale is exercised"
    {openings: $openings}
}

# Alpha poses under the room's light: tiled against lit within REAL_LIGHT_BOUND
export def room [context: record, records: record]: nothing -> record {
    let fixture_runs = $records."alpha fixture".fixture_runs
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let fixture_disk = $records."alpha fixture".fixture_disk
    let fixture_read = $records."alpha fixture".fixture_read
    let fixture_wall = $records."alpha fixture".fixture_wall
    mut light_report = []
    for fp in $FIXTURE_POSES {
        let eye = ($fixture_runs | get $"($fp.name)_tiled" | get eye)
        let placed = { name: $"alpha_($fp.name)", x: $eye.x, y: $eye.y, z: $eye.z, yaw: 0, pitch: 0 }
        mut lit_captures = {}
        for mode in [tiled lit] {
            let sends = ([{ at: 1400ms, bytes: (console level false ($mode == "lit")) }] | append (console settled $placed))
            let run = (launch --kernel $kernel --image $image --out ($out | path join $"alpha_light_($fp.name)_($mode)") --set $set --sound --api --disk $fixture_disk --serial "fps" --send $sends --capture 3500ms --seconds 5)
            let label = $"the ($fp.name) pose under the room's light with the tiles ($mode)"
            assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($label)"
            let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
            assert equal ($frames | length) 3 $"the first frame and the pose's two placements reported on ($label): ($run.serial)"
            let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
            assert ($frame.uncovered < $CRACKS) $"no pixel uncovered on ($label): ($frame)"
            if $mode == "tiled" {
                assert ($frame.tiles_built == 0 and $frame.tiled > 0) $"the view settled on its tiles on ($label): ($frame)"
            } else {
                assert ($frame.tiles_built == 0 and $frame.tiled == 0) $"no tile built or read with the tiles held off on ($label): ($frame)"
            }
            assert ($run.screen != "") $"a screen was taken on ($label)"
            $lit_captures = ($lit_captures | insert $mode (open --raw $run.screen | into binary))
        }
        let opening = (picture fixture-opening $fixture_read $fixture_wall $eye)
        let delta = (picture region-delta $lit_captures.tiled $lit_captures.lit $opening)
        $light_report = ($light_report | append ($delta | insert pose $fp.name | insert level $fp.level))
    }
    print $"fps: the alpha poses under the room's light, tiled against lit over the opening: ($light_report | each {|r| $'($r.pose) at level ($r.level), ($r.differing) of ($r.pixels) pixels differ, by ($r.largest) at most' } | str join '; ')"
    for r in $light_report {
        assert ($r.largest <= $REAL_LIGHT_BOUND) $"the ($r.pose) pose under the room's light, tiled against lit over the opening, within ($REAL_LIGHT_BOUND) of 255 a channel: ($r.differing) of ($r.pixels) pixels differ, by ($r.largest) at most"
    }
    {}
}

# The lit loop continuous along the opening's rows, within CENTRE_STEP
export def steps [context: record, records: record]: nothing -> record {
    let out = $context.out
    let game = $context.game
    let centre_screens = $records."alpha centre".centre_screens
    let centre_opening = $records."alpha centre".centre_opening
    let centre_tiled = $records."alpha centre".centre_tiled
    let centre_samples = $records."alpha centre".centre_samples
    let telling = $records."alpha centre".telling
    let varied = $records."alpha centre".varied
    let steps_out = ($out | path join "centre_steps.nuon")
    let steps = (^nu ($game | path join "test" "tiles.nu") lit-steps $centre_screens.held ($centre_opening | to nuon) $FIXTURE_CROSSHAIR $steps_out | complete)
    assert equal $steps.exit_code 0 $"the lit loop's steps read from the held-off capture: ($steps.stderr)"
    let centre_steps = (open $steps_out)
    assert ($centre_steps.most <= $CENTRE_STEP) $"the lit loop's picture continuous along the opening's rows, every pixel within ($CENTRE_STEP) of the one beside it: ($centre_steps.most) at ($centre_steps.x), ($centre_steps.y)"
    print $"fps: the texel-centre rule, ($centre_tiled | length) texels beside ($centre_samples | get node | uniq | length) nodes read from their tiles within ($centre_tiled | get off | math max | math round --precision 2) of their centres' light, ($telling | length) where the corner's lies past twice the slack; the lit loop's pixels varied over ($varied), stepping by ($centre_steps.most) at most along ($centre_steps.rows) rows"
    {}
}
