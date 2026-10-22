use (path self ../../../../../../../nu/mod/present)
use (path self ../presentation) [CADENCE_IF_EARLY FLIP_NONE FLIP_PRESENTED FLIP_VALID]

# The guest clock's ticks a microsecond, its 10 MHz, a receipt's stamps' unit
const TICKS_PER_US = 10.0

# The program's US_TICKS, the guest clock's ticks a microsecond as an integer
const US_TICKS = 10

# The guest clock's ticks a second, its 10 MHz, a period's numerator
const HZ = 10000000

# A measurement's presents in order, the load's two and every frame's, each its
# status, ordinal, and call's bounds in ticks: recorded, or derived at schema 7
export def flips [m: record]: nothing -> record<source: oneof<string, nothing>, reason: oneof<string, nothing>, origin: oneof<record<lo: int, hi: int, width: int>, nothing>, flips: list<any>> {
    let at = ($m.schema | default 1)
    if $at < 7 { return { source: null, reason: $"schema ($at) carries no receipt", origin: null, flips: [] } }
    if not $m.acceptance.available { return { source: null, reason: $m.acceptance.reason, origin: null, flips: [] } }
    let load = $m.load
    if $at >= 8 {
        let b = $m.bounds
        let loads = [
            { present: "title", frame: null, status: $FLIP_PRESENTED, ordinal: $load.title_ordinal, lo: $b.title_start, hi: $b.title_end, bound: "recorded" }
            { present: "cleared", frame: null, status: $FLIP_PRESENTED, ordinal: $load.clear_ordinal, lo: $b.clear_start, hi: $b.clear_end, bound: "recorded" }
        ]
        let frames = ($m.rows | each {|r|
            let none = ($r.flip_status == $FLIP_NONE)
            {
                present: "frame", frame: $r.frame, status: $r.flip_status, ordinal: $r.ordinal,
                lo: (if $none { 0 } else { $r.call_start }), hi: (if $none { 0 } else { $r.call_end }),
                bound: (if $none { "none" } else { "recorded" }),
            }
        })
        return { source: "recorded", reason: null, origin: { lo: $b.origin, hi: $b.origin, width: 0 }, flips: ($loads ++ $frames) }
    }
    let slack = ($US_TICKS - 1)
    let title_end = ($load.title_end_us * $US_TICKS)
    let clear_end = ($load.clear_end_us * $US_TICKS)
    let stamped = ($m.rows | where {|r| $r.flip_status in $FLIP_VALID and $r.receipt_stamp > 0 })
    let admits = ([
        { present: "the title", lo: ($load.title_stamp - $title_end - $slack), hi: $load.title_stamp }
        { present: "the cleared screen", lo: ($load.clear_stamp - $clear_end - $slack), hi: ($load.clear_stamp - $title_end) }
    ] ++ ($stamped | each {|r|
        let end = ($r.flip_done_us * $US_TICKS)
        { present: $"frame ($r.frame)", lo: ($r.receipt_stamp - $end - $slack), hi: ($r.receipt_stamp - $end + $r.flip_us * $US_TICKS + $slack) }
    }))
    let floor = ($admits | sort-by lo | last)
    let ceiling = ($admits | sort-by hi | first)
    if $floor.lo > $ceiling.hi {
        let gap = ($floor.lo - $ceiling.hi)
        return { source: null, reason: $"the receipts admit no common origin: ($floor.present)'s least passes ($ceiling.present)'s greatest by ($gap) ticks", origin: null, flips: [] }
    }
    let o = $floor.lo
    let loads = [
        { present: "title", frame: null, status: $FLIP_PRESENTED, ordinal: $load.title_ordinal, lo: $o, hi: ($o + $title_end + $slack), bound: "outer" }
        { present: "cleared", frame: null, status: $FLIP_PRESENTED, ordinal: $load.clear_ordinal, lo: ($o + $title_end), hi: ($o + $clear_end + $slack), bound: "outer" }
    ]
    let frames = ($m.rows | each {|r|
        if $r.flip_status == $FLIP_NONE {
            { present: "frame", frame: $r.frame, status: $r.flip_status, ordinal: $r.ordinal, lo: 0, hi: 0, bound: "none" }
        } else {
            let end = ($o + $r.flip_done_us * $US_TICKS)
            {
                present: "frame", frame: $r.frame, status: $r.flip_status, ordinal: $r.ordinal,
                lo: ($end - $r.flip_us * $US_TICKS - $slack), hi: ($end + $slack),
                bound: (if $r.flip_attempts == 1 { "derived" } else { "outer" }),
            }
        }
    })
    { source: "derived", reason: null, origin: { lo: $floor.lo, hi: $ceiling.hi, width: ($ceiling.hi - $floor.lo) }, flips: ($loads ++ $frames) }
}

# What makes a schema 7 window invalid in its receipts
export def receipt-invalidity [rows: list<any>, anchor: oneof<int, nothing>]: nothing -> list<string> {
    if $anchor == null { return ["the present sequence unanchored: no load record's cleared screen to start it"] }
    let unreceipted = ($rows | where {|r| $r.ordinal == null })
    let receipted = ($rows | where {|r| $r.ordinal != null })
    let violations = (present ordinal-violations $anchor ($receipted | each {|r| { presented: ($r.flip_status == $FLIP_PRESENTED), ordinal: $r.ordinal } }))
    let lasts = ([$anchor] ++ ($receipted | get ordinal | drop 1))
    let firsts = ($receipted | zip $lasts | where {|p| $p.0.flip_status == $FLIP_PRESENTED and $p.0.first_ordinal != (if $p.0.flip_attempts == 1 { $p.0.ordinal } else { $p.1 }) })
    let early = ($receipted | where {|r| $r.flip_status == $FLIP_PRESENTED and $r.receipt_stamp < $r.receipt_tick })
    [
        (if ($unreceipted | is-empty) { null } else { $"($unreceipted | length) frames without a receipt record" }),
        (if ($violations | is-empty) { null } else { $"($violations | length) frames whose present ordinal breaks the sequence: ($violations | first 4 | each {|v| $'frame ($v.index) ($v.rule), ($v.ordinal) where ($v.wanted)' } | str join '; ')" }),
        (if ($firsts | is-empty) { null } else { $"($firsts | length) presented frames whose first attempt's ordinal is neither their own presented at once nor the last before a refusal" }),
        (if ($early | is-empty) { null } else { $"($early | length) presented frames whose decision's stamp comes before their eligibility tick" }),
    ] | compact
}

# What makes a schema 8 window invalid in its recorded calls' bounds, at the
# receipt stage: the origin, the load's two calls, and every attempted frame's
export def bracket-invalidity [rows: list<any>, load: any, bounds: any]: nothing -> list<string> {
    if $load == null or $bounds == null { return ["the load's calls unbounded: no load record or no bounds record to read"] }
    let b = $bounds
    let receipted = ($rows | where {|r| $r.receipt_stamp != null })
    let attempted = ($receipted | where {|r| $r.flip_status != $FLIP_NONE })
    let idle = ($receipted | where {|r| $r.flip_status == $FLIP_NONE and ($r.call_start != 0 or $r.call_end != 0) })
    let outside = ($attempted | where {|r| $r.call_start > $r.receipt_stamp or $r.receipt_stamp > $r.call_end })
    let starts = ([$b.title_start $b.clear_start] ++ ($attempted | get call_start))
    [
        (if ($starts | any {|t| $t < $b.origin }) { "the bounds' origin after a stamp the run records" }),
        (if not ($b.title_start <= $b.title_end and $b.title_end < $b.clear_start and $b.clear_start <= $b.clear_end) { $"the load's calls out of order: the title's ($b.title_start) to ($b.title_end), the cleared screen's ($b.clear_start) to ($b.clear_end)" }),
        (if $load.title_stamp < $b.title_start or $load.title_stamp > $b.title_end { $"the title's decision ($load.title_stamp) outside its call, ($b.title_start) to ($b.title_end)" }),
        (if $load.clear_stamp < $b.clear_start or $load.clear_stamp > $b.clear_end { $"the cleared screen's decision ($load.clear_stamp) outside its call, ($b.clear_start) to ($b.clear_end)" }),
        (if ($outside | is-empty) { null } else { $"($outside | length) frames whose decision lies outside their final attempt's call: ($outside | first 3 | each {|r| $'frame ($r.frame) at ($r.receipt_stamp) in ($r.call_start) to ($r.call_end)' } | str join '; ')" }),
        (if ($idle | is-empty) { null } else { $"($idle | length) frames that made no attempt carrying a call's bounds" }),
    ] | compact
}

# Whether a measurement's acceptance intervals stand, and why not where not
export def acceptance-of [clocked: bool, schema: any, complete: bool, receipted: list<string>]: nothing -> record<available: bool, reason: any> {
    if not $clocked or ($schema | default 1) < 7 { return { available: false, reason: $"schema ($schema | default 1) carries no receipt" } }
    if not $complete { return { available: false, reason: "the capture is not complete, so its present sequence is not whole" } }
    if not ($receipted | is-empty) { return { available: false, reason: "its receipt sequence is invalid" } }
    { available: true, reason: null }
}

# Each presented frame's acceptance interval from the present before it, the
# first from the load's cleared screen; a frame that presented nothing keeps
# null and breaks no adjacency
export def accepted [rows: list<any>, anchor: int]: nothing -> list<any> {
    mut last = $anchor
    mut out = []
    for r in $rows {
        if $r.flip_status == $FLIP_PRESENTED {
            $out = ($out | append ($r | upsert acceptance_interval_us ((($r.receipt_stamp - $last) / $TICKS_PER_US) | math round --precision 1)))
            $last = $r.receipt_stamp
        } else {
            $out = ($out | append $r)
        }
    }
    $out
}

# The presentation contract read on a measurement's receipts at eps, where its
# receipt stage passed: K's violations over the presented acceptances, the
# first eight named, the late wakes, and the catch-ups; else none, its reason
export def contract-of [rows: list<any>, acceptance: record, cap: int, eps: int]: nothing -> record {
    let period = ($HZ // $cap)
    let read = { eps: $eps, period: $period, available: $acceptance.available, reason: $acceptance.reason }
    if not $acceptance.available { return ($read | merge { k_violations: null, k_first: [], late_wakes: null, catch_ups: null }) }
    let presented = ($rows | where {|r| $r.flip_status == $FLIP_PRESENTED })
    let k = (present k-violations ($presented | each {|r| $r.receipt_stamp }) $period $eps)
    let half_us = ($period / $TICKS_PER_US / 2)
    let named = ($k | first 8 | each {|v| $v | insert frame ($presented | get $v.index | get frame) | insert witness_frame ($presented | get $v.witness | get frame) })
    $read | merge {
        k_violations: ($k | length),
        k_first: $named,
        late_wakes: (wake-delays $rows | where {|d| $d >= $eps } | length),
        catch_ups: ($presented | where {|r| $r.acceptance_interval_us < $half_us } | length),
    }
}

# A measurement's wake delays, s less T in ticks: its frames at the cadence
# that waits only while early which waited and presented, each its receipt's
# acceptance less the tick it was judged against
export def wake-delays [rows: list<any>]: nothing -> list<int> {
    $rows
    | where {|r| $r.cadence == $CADENCE_IF_EARLY and ($r.wait_us | default 0) > 0 and $r.flip_status == $FLIP_PRESENTED and $r.receipt_stamp != null and $r.receipt_tick != null }
    | each {|r| $r.receipt_stamp - $r.receipt_tick }
}
