use (path self ../../../../../../nu/mod/target)
use (path self ../identity)

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../../../../..

# The play's ceiling in microseconds, a frame at or over it the tail
export const CEILING_US = 15000

# One line on a run: complete, valid, its median against the ceiling
export def run-line [label: string, n: int, m: record, ran: record]: nothing -> string {
    let name = (if $label == "" { "" } else { $"($label): " })
    let fault = (if ($ran.fault? | default null) == null { "" } else { $"; a program fault: ($ran.fault)" })
    if not $m.clocked {
        return $"gauge: ($name)run ($n): ($m.frames) frames from the state records alone; draw (spread $m.whole.draw), game (spread $m.whole.game)($fault)"
    }
    let state = (if not $m.complete {
        $"incomplete: ($m.problems | str join '; ')"
    } else if not $m.valid {
        $"complete but invalid: ($m.invalid | str join '; ')"
    } else {
        let against = (if $m.under { "under" } else { "at or over" })
        $"complete, valid, median (ms $m.whole.critical.median) ms ($against) the ($CEILING_US // 1000) ms ceiling, a tail of ($m.over) of ($m.frames) frames at or over it"
    })
    let seed = (if $m.seeded and (not $m.late_seed) { "seeded" } else if $m.late_seed { "seeded late, no paired comparison" } else { "unseeded" })
    let cadence = (if ($m.schema | default 1) < 2 {
        ""
    } else if $m.cadence_set and (not $m.late_cadence) {
        $"; cadence ($m.cadences | each {|c| $c | into string } | str join ', ')"
    } else if $m.late_cadence {
        "; cadence asked late, no paired comparison"
    } else {
        "; no cadence asked"
    })
    let workers = (if ($m.schema | default 1) < 4 {
        ""
    } else if ($m.late_workers? | default false) {
        "; workers asked late, no paired comparison"
    } else {
        $"; workers ($m.workers | each {|w| $w | into string } | str join ', ') at grain ($m.grains | each {|g| $g | into string } | str join ', ')"
    })
    $"gauge: ($name)run ($n): ($state); ($m.frames) frames to frame ($m.final) at schema ($m.schema), critical (spread $m.whole.critical) ms; ($seed)($cadence)($workers)($fault)"
}

# One line on what a run played, its window, and its audio driver
export def outcome-line [n: int, m: record, ran: record]: nothing -> string {
    let o = $m.outcomes
    let rounds = (if ($o.rounds | is-empty) { "none" } else { $o.rounds | each {|r| $"($r.met) ($r.count)" } | str join ", " })
    let androids = (if ($o.androids | is-empty) { "none" } else { $o.androids | each {|a| $"($a.event) ($a.count)" } | str join ", " })
    let window = ($ran.window? | default "unknown")
    let audio = ($ran.audio? | default "unknown" | split row "," | first)
    $"gauge:   run ($n) played: rounds ($rounds); androids ($androids); struck ($o.struck); pickups ($o.pickups); window ($window), audio ($audio)"
}

# A spread in milliseconds: least / median / 95th / 99th / greatest
export def spread [s: record]: nothing -> string {
    [$s.min $s.median $s.p95 $s.p99 $s.max] | each {|v| ms $v } | str join " / "
}

# Microseconds as milliseconds to a tenth, a dash for none
export def ms [us: any]: nothing -> string {
    if $us == null { "-" } else { $"(($us / 1000.0) | math round --precision 1)" }
}

# A report's document: label, identity, ceiling, every run, every row
def report-doc [label: string, id: record, runs: list<any>, reread: any]: nothing -> record {
    let doc = {
        label: $label,
        identity: $id,
        ceiling_us: $CEILING_US,
        runs: ($runs | each {|r| {
            run: $r.run, seed: $r.seed, out: $r.out, ran: $r.ran, measured: ($r.measured | reject rows),
            identity: ($r | get -o identity), corrections: ($r | get -o corrections), identity_sha256: ($r | get -o identity_sha256),
            identity_from: ($r | get -o identity_from), binding: ($r | get -o binding), passed: ($r | get -o passed),
            reports: ($r | get -o reports), cpu: ($r | get -o cpu),
        } }),
        rows: ($runs | each {|r| $r.measured.rows | each {|row| $row | insert run $r.run } } | flatten),
    }
    if $reread == null { $doc } else { $doc | insert reread $reread }
}

# Whether a critical path's median lies under CEILING_US
export def under-ceiling [median: number]: nothing -> bool {
    $median < $CEILING_US
}

# The ceiling's words for a median: under, or at or over
export def against-ceiling [median: number]: nothing -> string {
    if (under-ceiling $median) { "under" } else { "at or over" }
}

# A leg's line under a run, as the report prints it
def leg-text [run: int, schema: any, l: record]: nothing -> string {
    let built = (if ($schema | default 1) >= 5 { "tiles" } else { "cells" })
    if ($l.critical? | default null) == null {
        $"gauge:   run ($run) ($l.leg): ($l.frames) frames; draw (spread $l.draw), game (spread $l.game)"
    } else {
        $"gauge:   run ($run) ($l.leg): median (ms $l.critical.median) ms (against-ceiling $l.critical.median) the ceiling, a tail of ($l.over) of ($l.frames); ($l.fast) fast and ($l.fast_waited) of them waited; critical (spread $l.critical); draw (ms $l.draw.median), preparation (ms $l.preparation.median), raster (ms $l.raster.median), slowest worker (ms $l.slowest.median), dispatch (ms $l.dispatch.median), barrier (ms $l.barrier.median), game (ms $l.game.median), flip (ms $l.flip.median), report (ms $l.report.median), await (ms $l.await.median), wait (ms $l.wait.median), pacing (ms $l.pacing.median), tiles (ms $l.tiles.median) median; ($l.tiles_built) ($built) built over ($l.building_frames) frames, ($l.tiled_pixels) tiled and ($l.fallback_pixels) fallback lit pixels; flips early ($l.flips_early), refusals ($l.refusals); unattributed (ms $l.unattributed.max) at most"
    }
}

# The report saved as gauge.nuon in `out`, the old one retired, legs printed
export def write [label: string, id: record, runs: list<any>, out: path, --reread: record]: nothing -> nothing {
    let file = ($out | path join "gauge.nuon")
    target retire $file (target root $WORKSPACE)
    report-doc $label $id $runs $reread | to nuon | save --raw $file
    for r in $runs {
        for l in $r.measured.legs {
            print (leg-text $r.run ($r.measured | get -o schema) $l)
        }
        let o = $r.measured.outliers
        if not ($o | is-empty) { print $"gauge:   run ($r.run): ($o | length) unexplained phase outliers, the first at frame ($o | first | get frame)" }
    }
    print $"gauge: ($file)"
}

# The legs a capture's frames fall in, from the route held to its SHA-256
export def legs-for [dir: path, id: record, route: string]: nothing -> record<legs: list<any>, route: oneof<string, nothing>, checked: bool> {
    let recorded = ($id | get -o route.sha256)
    let kept = ($dir | path join "route.nuon")
    let named = (identity moved ($id | get -o route.file | default ""))
    let file = (if $route != "" { $route | path expand } else if ($kept | path exists) { $kept } else { $named })
    if $file == "" { return { legs: [{ name: "play", places: [], pad: [] }], route: null, checked: false } }
    if not ($file | path exists) { error make { msg: $"the route ($file) is not there" } }
    let bytes = (open --raw $file | into binary)
    let sha = ($bytes | hash sha256)
    if $recorded != null and $sha != $recorded {
        error make { msg: $"the route ($file) has SHA-256 ($sha) where the capture's identity recorded ($recorded): its legs are not the ones that played" }
    }
    { legs: ($bytes | decode utf-8 | from nuon | get legs), route: $file, checked: ($recorded != null) }
}

# A compared run's route held to its recorded SHA-256: its legs or problem
export def route-of [report: path, run: record, effective: record]: nothing -> record<sha256: any, file: any, legs: any, problem: any> {
    let recorded = ($effective.identity | get -o route.sha256)
    if $recorded == null { return { sha256: null, file: null, legs: null, problem: null } }
    let recorded_file = ($effective.identity | get -o route.file)
    let named = (if $recorded_file == null { null } else { identity moved $recorded_file })
    let bound = (if $effective.file == null { [] } else { [($effective.file | path dirname)] })
    let kept = ($bound | append (identity dirs $report $run) | uniq | each {|d| $d | path join "route.nuon" } | where {|f| $f | path exists })
    let file = (if not ($kept | is-empty) { $kept | first } else { $named })
    if $file == null or (not ($file | path exists)) {
        return { sha256: $recorded, file: $file, legs: null, problem: $"its identity records the route ($recorded_file | default 'unnamed') of SHA-256 ($recorded), and none is beside its run or at that file" }
    }
    let bytes = (open --raw $file | into binary)
    let sha = ($bytes | hash sha256)
    if $sha != $recorded {
        return { sha256: $recorded, file: $file, legs: null, problem: $"the route ($file) has SHA-256 ($sha) where its identity recorded ($recorded): its legs are not the ones that played" }
    }
    let legs = (try { $bytes | decode utf-8 | from nuon | get legs | get name } catch { [] })
    if ($legs | is-empty) { return { sha256: $recorded, file: $file, legs: null, problem: $"the route ($file) names no legs" } }
    { sha256: $recorded, file: $file, legs: $legs, problem: null }
}

# A compared route in words: its SHA-256 and file, or none recorded
export def route-text [t: record]: nothing -> string {
    if $t.sha256 == null { return "no route recorded" }
    $"the route of SHA-256 ($t.sha256), ($t.file | default 'not found')"
}

# A machine as a run's identity records it, in words
export def machine-text [m: any]: nothing -> string {
    if $m == null { return "unrecorded" }
    let spec = ($m | get -o spec)
    let custom = ($m | get -o diagnostic)
    let kind = (if (($spec | describe) | str starts-with "record") {
        $", ($spec.name), ($spec.ram_gib) GiB"
    } else if (($custom | describe) | str starts-with "record") {
        $", custom, ($custom.ram_gib) GiB, diagnostic"
    } else if $custom == true { ", legacy, diagnostic" } else { ", legacy" })
    $"($m | get -o harts) harts($kind), -machine ($m | get -o machine), -cpu ($m | get -o cpu), -accel ($m | get -o accel)"
}
