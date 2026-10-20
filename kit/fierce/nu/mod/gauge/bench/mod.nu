use (path self ../../../../../../nu/mod/target)
use (path self ../audio)
use (path self ../compare)
use (path self ../identity)
use (path self ../measure)
use (path self ../report)
use (path self ../measure) [CAP FLIP_EARLY FLIP_PRESENTED]
use (path self ../report) [CEILING_US]

# The workspace's root, resolved from this file's own path
const WORKSPACE = path self ../../../../../..

# Clocked frames with their presenting call's interval, unknown if retried
def presented-calls [rows: list<any>, period: number]: nothing -> list<any> {
    mut previous: any = null
    mut known = false
    mut seen = false
    mut late = false
    mut out = []
    for r in ($rows | where {|x| ($x | get -o critical_us) != null }) {
        let presented = (($r | get -o flip_status) == $FLIP_PRESENTED)
        let single = (($r | get -o flip_attempts | default 1) <= 1)
        let done = ($r | get -o flip_done_us)
        let flip = ($r | get -o flip_us)
        let start = (if $presented and $single and $done != null and $flip != null { $done - $flip } else { null })
        let interval = (if $start != null and $known { $start - $previous } else { null })
        let unknown = ($presented and $seen and $interval == null)
        $out = ($out | append ($r | insert call_interval_us $interval | insert call_unknown $unknown | insert after_late $late))
        if $presented {
            $seen = true
            $known = ($start != null)
            $previous = $start
        }
        $late = ($r.critical_us >= $period)
    }
    $out
}

# Frames pooled for a bench: intervals, tick grid, flips, tail, catch-up
def bench-frames [rows: list<any>, period: number]: nothing -> record {
    if ($rows | is-empty) { return { frames: 0 } }
    let calls = (column-of $rows "call_interval_us" | compact)
    let multiples = ($calls | each {|c|
        let k = (($c / $period) | math round)
        if $k >= 1 and ((($c - $k * $period) | math abs) <= 1000) { $k } else { null }
    } | compact)
    let critical = {|r| $r | get -o critical_us }
    {
        frames: ($rows | length),
        presented: ($rows | where {|r| ($r | get -o flip_status) == $FLIP_PRESENTED } | length),
        acceptance: (measure stats (column-of $rows "acceptance_interval_us")),
        completion: (measure stats (completion-of $rows)),
        call_interval: (measure stats $calls),
        grid: ($multiples | uniq --count | sort-by value | each {|c| { periods: $c.value, intervals: $c.count } }),
        off_grid: (($calls | length) - ($multiples | length)),
        unknown_calls: ($rows | where {|r| ($r | get -o call_unknown) == true } | length),
        submission_age: (measure stats (column-of $rows "submission_age_us")),
        critical: (measure stats (column-of $rows "critical_us")),
        draw: (measure stats (column-of $rows "draw_us")),
        wait: (measure stats (column-of $rows "wait_us")),
        pacing: (measure stats (column-of $rows "pacing_us")),
        await: (measure stats (column-of $rows "await_us")),
        wakes: (measure total (column-of $rows "wakes")),
        attempts: (measure total (column-of $rows "flip_attempts")),
        refusals: (measure total (column-of $rows "refusals")),
        flips_early: ($rows | where {|r| ($r | get -o flip_status) == $FLIP_EARLY } | length),
        flips_failed: ($rows | where {|r| ($r | get -o flip_status | default $FLIP_PRESENTED) > $FLIP_EARLY } | length),
        over: ($rows | where {|r| (do $critical $r | default 0) >= $CEILING_US } | length),
        fast: ($rows | where {|r| let c = (do $critical $r); $c != null and $c < $period } | length),
        fast_waited: ($rows | where {|r| let c = (do $critical $r); $c != null and $c < $period and ($r | get -o wait_us | default 0) > 0 } | length),
        catch_up: ($rows | where {|r| let i = ($r | get -o call_interval_us); ($r | get -o after_late) == true and $i != null and $i < ($period / 2) } | length),
    }
}

# A column of rows, null in a row that lacks it
def column-of [rows: list<any>, name: string]: nothing -> list<any> {
    $rows | each {|r| $r | get -o $name }
}

# Each row's completion interval; a report written before AcceptanceInterval
# names the same flip-end-to-flip-end interval flip_interval_us
def completion-of [rows: list<any>]: nothing -> list<any> {
    $rows | each {|r| $r | get -o completion_interval_us | default ($r | get -o flip_interval_us) }
}

# A bench step's runs, each as its own identity asks, its standing and frames
def bench-step [dir: path, label: string, state: any]: nothing -> record {
    let file = ($dir | path join $label "gauge.nuon")
    if not ($file | path exists) { return { label: $label, state: $state, file: null, runs: [] } }
    let g = (open $file)
    let all_rows = ($g.rows? | default [])
    let runs = ($g.runs | each {|r|
        let m = ($r | get -o measured)
        let rows = ($all_rows | where run == $r.run)
        let request = (identity request $file $r ($g | get -o identity))
        let asked = { workers: $request.workers, grain: $request.grain }
        let standing = (compare standing-of $m $rows "critical_us" $request.cadence $asked $request.machine ($request.identity | get -o overrides))
        let ran = ($r | get -o ran | default {})
        let wall = ($ran | get -o wall_seconds)
        let cpu = ($ran | get -o cpu_seconds)
        let why = (cpu-why $ran $wall $cpu)
        let period = (1000000 / ($request.cap | default $CAP))
        {
            label: $label, run: $r.run, seed: ($r | get -o seed),
            kind: (match $request.pad { "host" => "play", "table" => "audio", _ => "route" }), cadence: $request.cadence, period_us: $period,
            selection: $request.selection, workers: $request.workers, grain: $request.grain,
            machine: $request.machine, qemu: $request.qemu,
            standing: $standing.standing,
            reasons: $standing.reasons,
            cpu_over_wall: (if $why == null { $cpu / $wall } else { null }),
            cpu_why: $why,
            outcomes: ($m | get -o outcomes),
            service: ($m | get -o service),
            audio: ($r | get -o audio),
            rows: (presented-calls $rows $period),
        }
    })
    { label: $label, state: $state, file: $file, runs: $runs }
}

# A run's service in a bench report's words: its windows' accounting, or its refusal
def service-text [label: string, run: int, sv: record]: nothing -> string {
    let state = (if ($sv.problems | is-empty) { "held" } else { $"broken: ($sv.problems | str join '; ')" })
    if not $sv.started {
        let why = (if ($sv.refusals | is-empty) { "never started" } else { $"refused, status ($sv.refusals | each {|v| $v | into string } | str join ', ')" })
        return $"  ($label) run ($run): ($why), ($sv.frames) frames none running; ($state)"
    }
    let windows = ($sv.windows | each {|w|
        let rate = (if $w.per_frame == null { "" } else { $", ($w.per_frame | math round --precision 2) a frame" })
        $"offered ($w.offered)($rate), applied ($w.applied), dropped ($w.dropped), rejected ($w.rejected), discarded ($w.discarded), quotas skipped ($w.skipped), (if $w.valid { 'a valid handoff' } else { 'forced' }), apply ($w.apply.median) us median and ($w.apply.max) us most"
    } | str join "; ")
    let reduced = (if $sv.reduced { ", a reduced load" } else { "" })
    $"  ($label) run ($run): ($windows)($reduced); ($state)"
}

# Why a run's CPU over wall cannot be taken, null when it can
def cpu-why [ran: record, wall: any, cpu: any]: nothing -> oneof<string, nothing> {
    if "wall_seconds" not-in ($ran | columns) { return "a record older than its wall time" }
    if $wall == null { return $"no wall time, its launch's receipt absent: ($ran | get -o incomplete | default 'no receipt')" }
    if $wall <= 0 { return $"a wall time of ($wall) s" }
    if $cpu == null { return "no CPU seconds" }
    null
}

# A bench group at one cadence: valid runs pooled, every other kept apart
def bench-cadence [runs: list<any>]: nothing -> record {
    let cadence = ($runs | first | get cadence)
    let period = ($runs | first | get period_us)
    let pooled = ($runs | where standing == "valid")
    let apart = ($runs | where standing != "valid")
    {
        cadence: $cadence,
        period_us: $period,
        steps: ($runs | get label | uniq),
        runs: ($runs | length),
        valid: ($pooled | length),
        standings: ($runs | each {|r| { label: $r.label, run: $r.run, standing: $r.standing, reasons: $r.reasons } }),
        cpu_over_wall: ($pooled | each {|r| $r.cpu_over_wall }),
        cpu_left: ($pooled | where {|r| $r.cpu_over_wall == null } | each {|r| { label: $r.label, run: $r.run, why: $r.cpu_why } }),
        outcomes: ($runs | each {|r| { label: $r.label, run: $r.run, outcomes: $r.outcomes } }),
        frames: (bench-frames ($pooled | each {|r| $r.rows } | flatten) $period),
        apart: ($apart | each {|r| { label: $r.label, run: $r.run, standing: $r.standing, reasons: $r.reasons, cpu_over_wall: $r.cpu_over_wall, frames: (bench-frames $r.rows $period) } }),
    }
}

# A cadence's lines in a bench report, the pool's median leading
def bench-cadence-text [c: record]: nothing -> list<string> {
    let f = $c.frames
    let cpu = ($c.cpu_over_wall | compact)
    let core = (if ($cpu | is-empty) { "-" } else if (($cpu | math max) - ($cpu | math min)) < 0.005 { $"($cpu | first | math round --precision 2)" } else { $"($cpu | math min | math round --precision 2) to ($cpu | math max | math round --precision 2)" })
    let left = ($c | get -o cpu_left | default [])
    let covered = $"over ($cpu | length) of ($c.valid) pooled runs"
    let named = (if ($left | is-empty) { "" } else { $"; left out of it: ($left | each {|l| $'($l.label) run ($l.run), ($l.why)' } | str join '; ')" })
    let head = $"  cadence ($c.cadence | default 'none asked') at a period of (report ms $c.period_us) ms, ($c.steps | str join ' '): ($c.runs) runs, ($c.valid) valid and pooled; the process at ($core) of a core ($covered)($named)"
    let apart = ($c.apart | each {|a|
        let seen = (if $a.frames.frames == 0 { "no frames" } else { $"($a.frames.frames) frames, accepted every (report ms $a.frames.acceptance.median) and completed every (report ms $a.frames.completion.median) ms at the median" })
        $"    left out of the pool, a diagnostic: ($a.label) run ($a.run), ($a.standing): ($a.reasons | str join '; '); ($seen)"
    })
    if $f.frames == 0 { return ([$head "    no valid run to pool"] ++ $apart) }
    let grid = (if ($f.grid | is-empty) { "none" } else { $f.grid | each {|g| $"($g.intervals) at ($g.periods)P" } | str join ", " })
    [
        $head
        $"    median (report ms $f.critical.median) ms (report against-ceiling $f.critical.median) the ($CEILING_US // 1000) ms ceiling, a tail of ($f.over) of ($f.frames) frames at or over it"
        $"    ($f.frames) frames, ($f.presented) presented, accepted every (report spread $f.acceptance)"
        $"    completed every (report spread $f.completion)"
        $"    submission age (report spread $f.submission_age)"
        $"    critical path (report spread $f.critical); drawing (report spread $f.draw)"
        $"    wait (report spread $f.wait); pacing (report ms $f.pacing.median) and await (report ms $f.await.median) at the median"
        $"    presenting calls on the tick grid: ($grid); ($f.off_grid) off it; ($f.unknown_calls) unknown after a retried flip; ($f.catch_up) catch-up"
        $"    ($f.fast) fast, ($f.fast_waited) of them waited; flips early ($f.flips_early), failed ($f.flips_failed); wakes ($f.wakes), refusals ($f.refusals)"
    ] ++ $apart
}

# A bench's report as text: steps, machines, cadences, then comparisons
def bench-text [doc: record]: nothing -> string {
    let named = (if $doc.bench == null { "" } else { $"($doc.bench) " })
    let placed = ($doc.runs | each {|r| { machine: $r.machine, qemu: $r.qemu, run: $"($r.label) run ($r.run)" } })
    let machines = ($placed | each {|p| { machine: $p.machine, qemu: $p.qemu } } | uniq | each {|m|
        let runs = ($placed | where {|p| $p.machine == $m.machine and $p.qemu == $m.qemu } | get run)
        $"machine: (report machine-text $m.machine); ($m.qemu | default 'QEMU unrecorded'): ($runs | str join ', ')"
    })
    let head = [
        $"bench ($named)run ($doc.stamp | default '-') in ($doc.dir)"
        $"steps: ($doc.steps | each {|s| $'($s.label) (if $s.file == null { 'no capture' } else { $s.state | default 'read' })' } | str join ', ')"
    ] ++ $machines
    let kinds = ($doc.groups | each {|g|
        let title = (if $g.kind == "play" { "your play" } else { "the route" })
        [$"($title), per cadence, ms as least / median / 95th / 99th / greatest:"] ++ ($g.cadences | each {|c| bench-cadence-text $c } | flatten)
    } | flatten)
    let compared = ($doc.compared | each {|c|
        if ($c | get -o error) != null { [$"the route at 50 cm on ($c.field): refused even as a diagnostic, ($c.error | lines | first)"] } else {
            let title = (if $c.diagnostic {
                [$"the route at 50 cm, ($c.field) by leg, a diagnostic admitting the runs a comparison refuses: ($c.refused | lines | first)"]
            } else {
                [$"the route at 50 cm, ($c.field) by leg, ms with the half spread:"]
            })
            $title ++ ($c.table | get build | uniq | each {|b|
                let rows = ($c.table | where build == $b)
                let legs = ($rows | each {|t| if $t.value_us == null { $"($t.leg) -" } else { $"($t.leg) (report ms $t.value_us) \((report ms $t.half_spread_us)\)" } })
                let marks = ($rows | get standings | flatten | uniq | where {|s| $s != "valid" })
                let marked = (if ($marks | is-empty) { "" } else { $"; admits ($marks | str join ', ')" })
                $"  ($b): ($legs | str join ', ')($marked)"
            })
        }
    } | flatten)
    let served = (if ($doc.services | is-empty) { [] } else {
        ["the synthetic service, each run's window:"] ++ ($doc.services | each {|s| service-text $s.label $s.run $s.service })
    })
    let heard = (if ($doc.audio | is-empty) { [] } else {
        ["the audio's debug runs, a diagnostic:"] ++ ($doc.audio | each {|a| $"  ($a.label) run ($a.run), ($a.standing): (if $a.reading == null { 'no reading' } else { audio line $a.reading | str replace 'gauge:   audio ' '' })" })
    })
    $head ++ $kinds ++ $compared ++ $served ++ $heard | str join "\n"
}

# A bench's report over its steps: runs grouped by kind and cadence, compared
export def doc [dir: path]: nothing -> record {
    let dir = ($dir | path expand)
    let listed = ($dir | path join "bench.nuon")
    let bench = (if ($listed | path exists) { open $listed } else { null })
    let labels = (if $bench != null { $bench.steps | get label } else { ls $dir | where type == dir | get name | each {|d| $d | path basename } | where {|d| $d != "watch" } | sort })
    let steps = ($labels | each {|label|
        let state = (if $bench == null { null } else { $bench.steps | where label == $label | get -o 0.state })
        bench-step $dir $label $state
    })
    let runs = ($steps | get runs | flatten | each {|r| $r | insert group { cadence: $r.cadence, period_us: $r.period_us } })
    let groups = (["play" "route"] | each {|kind|
        let these = ($runs | where kind == $kind)
        let keys = ($these | get group | uniq | sort-by cadence)
        { kind: $kind, cadences: ($keys | each {|k| bench-cadence ($these | where {|r| $r.group == $k }) }) }
    } | where {|g| not ($g.cadences | is-empty) })
    let reports = ($steps | where file != null | each {|s| { file: $s.file, kinds: ($s.runs | get kind | uniq | sort) } })
    let mixed = ($reports | where {|x| ($x.kinds | length) > 1 })
    let files = ($reports | where {|x| $x.kinds == ["route"] } | get file)
    let compared = (if not ($mixed | is-empty) {
        let named = ($mixed | each {|x| $"($x.file) holds ($x.kinds | str join ' and ') runs" } | str join "; ")
        ["critical_us" "draw_us"] | each {|field| { field: $field, error: $"the route comparison refuses a report mixing plays and route runs, which compare would read whole: ($named)" } }
    } else if ($files | is-empty) { [] } else {
        ["critical_us" "draw_us"] | each {|field|
            try { { field: $field, diagnostic: false, table: (compare $files $field 50 | get table) } } catch {|refusal|
                try { { field: $field, diagnostic: true, refused: $refusal.msg, table: (compare $files $field 50 --diagnostic | get table) } } catch {|e| { field: $field, error: $e.msg } }
            }
        }
    })
    {
        bench: ($bench | get -o bench),
        stamp: ($bench | get -o stamp),
        dir: $dir,
        steps: ($steps | each {|s| $s | reject runs }),
        runs: ($runs | each {|r| $r | select label run seed kind selection cadence workers grain period_us machine qemu standing reasons }),
        groups: $groups,
        compared: $compared,
        services: ($runs | where {|r| $r.service != null } | each {|r| { label: $r.label, run: $r.run, service: $r.service } }),
        audio: ($runs | where kind == "audio" | each {|r| { label: $r.label, run: $r.run, standing: $r.standing, reading: $r.audio } }),
    }
}

# A bench's report saved as report.nuon and report.txt, the text printed
export def report [dir: path] {
    let dir = ($dir | path expand)
    let doc = (doc $dir)
    let text = (bench-text $doc)
    let nuon_file = ($dir | path join "report.nuon")
    let text_file = ($dir | path join "report.txt")
    target retire $nuon_file (target root $WORKSPACE)
    target retire $text_file (target root $WORKSPACE)
    $doc | to nuon --indent 1 | save --raw $nuon_file
    $text + "\n" | save --raw $text_file
    print $text
    print $"gauge: ($nuon_file)"
}
