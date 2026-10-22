use (path self ../../../picture) [STAMP_BITS]

# The slack on a bound frame's eye position, in metres
const POSE_SLACK_M = 0.001

# The slack on a bound frame's angles, in degrees
const POSE_SLACK_DEGREES = 0.01

# The frame a screen's stamp names, held to the picture contract, or why not
export def screen-frame [m: record, stamp: any, from: int, expect: record]: nothing -> record<frame: any, problems: list<string>> {
    if not ($m.complete and $m.valid) {
        return { frame: null, problems: [$"the capture is not complete and valid: ($m.problems | append $m.invalid | str join '; ')"] }
    }
    let length = ($m.final - $from)
    let bound = (1 bit-shl $STAMP_BITS)
    if $length >= $bound {
        return { frame: null, problems: [$"the window from frame ($from) to the final frame ($m.final) holds ($length) frames; it must be shorter than ($bound | into string --group-digits) frames"] }
    }
    if $stamp == null { return { frame: null, problems: ["the screen carries no stamp"] } }
    let named = ($m.rows | where {|r| ($r.frame mod (1 bit-shl $STAMP_BITS)) == $stamp } | get frame)
    let inside = ($named | where {|f| $f >= $from and $f < $m.final })
    if ($inside | is-empty) {
        let before = ($named | where {|f| $f < $from })
        let why = (if not ($before | is-empty) {
            $"the stamp ($stamp) names frame ($before | last), before the window's opening frame ($from)"
        } else {
            $"the stamp ($stamp) names the final frame ($m.final) or none of the window"
        })
        return { frame: null, problems: [$why] }
    }
    let n = ($inside | first)
    let r = ($m.rows | where frame == $n | first)
    mut problems = []
    let unsettled = ([missed_blocks building admitted dropped filtered tiles_built] | where {|f| ($r | get $f) != 0 })
    if not ($unsettled | is-empty) {
        $problems = ($problems | append $"frame ($n) unsettled: ($unsettled | each {|f| $'($f) ($r | get $f)' } | str join ', ')")
    }
    let p = $expect.pose
    let turn = {|a: number, b: number| let d = ((($a - $b) mod 360) + 360) mod 360; [$d (360 - $d)] | math min }
    let off = ([
        (if (($r.x - $p.x) | math abs) > $POSE_SLACK_M { "x" })
        (if (($r.y - $p.y) | math abs) > $POSE_SLACK_M { "y" })
        (if (($r.z - $p.z) | math abs) > $POSE_SLACK_M { "z" })
        (if (do $turn $r.yaw $p.yaw) > $POSE_SLACK_DEGREES { "yaw" })
        (if (($r.pitch - $p.pitch) | math abs) > $POSE_SLACK_DEGREES { "pitch" })
        (if (($r.roll - $p.roll) | math abs) > $POSE_SLACK_DEGREES { "roll" })
    ] | compact)
    if not ($off | is-empty) {
        $problems = ($problems | append $"frame ($n)'s pose differs in ($off | str join ', '): ($off | each {|f| $'($f) ($r | get $f) where ($p | get $f) was expected' } | str join ', ')")
    }
    if $r.workers != $expect.workers or $r.grain != $expect.grain {
        $problems = ($problems | append $"frame ($n) drawn by ($r.workers) workers at grain ($r.grain) where ($expect.workers) at ($expect.grain) was expected")
    }
    let masks = ($expect | get -o masks)
    if $masks != null {
        let differ = ($masks | columns | where {|k| ($r | get $k) != ($masks | get $k) })
        if not ($differ | is-empty) {
            $problems = ($problems | append $"frame ($n)'s harts record: ($differ | each {|k| $'($k) ($r | get $k) where ($masks | get $k) was expected' } | str join ', ')")
        }
    }
    let mode = ($expect | get -o witness)
    if $mode != null {
        let ws = ($m.rounds | where frame == $n)
        let w = (if ($ws | length) == 1 { $ws | first } else { null })
        if ($ws | is-empty) {
            $problems = ($problems | append $"no witness for frame ($n)")
        } else if $w == null {
            let counts = ($ws | each {|x| $"rounds ($x.rounds) cancelled ($x.cancelled)" } | str join "; ")
            let detail = (if (($ws | uniq | length) == 1) { "alike" } else { $"conflicting: ($counts)" })
            $problems = ($problems | append $"($ws | length) witnesses for frame ($n), ($detail)")
        } else if $mode == "serial" {
            if $w.rounds != 0 or $w.cancelled != 0 {
                $problems = ($problems | append $"the serial backend's witness for frame ($n) reads rounds ($w.rounds), cancelled ($w.cancelled)")
            }
        } else if $w.rounds == 0 {
            $problems = ($problems | append $"a worker mode's witness for frame ($n) reads no rounds")
        } else if $w.cancelled != $w.rounds {
            $problems = ($problems | append $"a worker mode's witness for frame ($n) reads cancelled ($w.cancelled) of rounds ($w.rounds)")
        }
    }
    { frame: $n, problems: $problems }
}
