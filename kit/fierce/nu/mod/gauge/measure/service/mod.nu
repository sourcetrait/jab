use (path self ../summary) [greatest stats]

# A service record's flags: running, a torn word, and the start's frame
const SVC_RUNNING = 1
const SVC_TORN = 2
const SVC_STARTED = 8

# A SERVICE build's service read from its capture, null without its records
export def service-of [s: record, rows: list<any>, last: int]: nothing -> any {
    if ($s.services | is-empty) and ($s.service_answers | is-empty) { return null }
    let framed = ($s.services | where {|x| $x.frame <= $last })
    let starts = ($s.service_answers | where start)
    let windows = ($s.service_ends | each {|e|
        let ev = ($s.service_evidence | where generation == $e.generation | get -o 0)
        service-window $e $ev ($framed | where generation == $e.generation) ($s.service_rejects | where generation == $e.generation) $rows
    })
    let closed = ($windows | each {|w| $w.generation })
    let unclosed = ($starts | where status == 0 | each {|a| $a.generation } | where {|g| $g not-in $closed })
    let torn = ($framed | where {|x| ($x.flags bit-and $SVC_TORN) != 0 } | length)
    let unwitnessed = ($framed | where {|x| $x.word != $x.last } | length)
    let problems = ([
        (if ($unclosed | is-empty) { null } else { $"($unclosed | length) windows started and never closed, generation ($unclosed | each {|g| $g | into string } | str join ', ')" })
        (if $torn == 0 { null } else { $"($torn) frames whose packet's service word a raster worker read torn" })
        (if $unwitnessed == 0 { null } else { $"($unwitnessed) frames whose packet's service word is not their boundary's last applied sequence" })
    ] | compact) ++ ($windows | each {|w| $w.problems | each {|p| $"window ($w.generation): ($p)" } } | flatten)
    {
        frames: ($framed | length),
        running: ($framed | where {|x| ($x.flags bit-and $SVC_RUNNING) != 0 } | length),
        answers: $s.service_answers,
        started: ($starts | any {|a| $a.status == 0 }),
        refusals: ($starts | where status != 0 | each {|a| $a.status }),
        windows: $windows,
        skipped: ($windows | each {|w| $w.skipped } | append 0 | math sum),
        reduced: ($windows | any {|w| $w.skipped > 0 }),
        apply: (stats ($framed | each {|x| $x.service_us })),
        problems: $problems,
    }
}

# A closed window held to its accounting, a forced stop leaving it incomplete
def service-window [e: record, ev: any, framed: list<any>, rejects: list<any>, rows: list<any>]: nothing -> record {
    let lost = ($e.dropped + $e.rejected + $e.discarded)
    let started = ($framed | where {|x| ($x.flags bit-and $SVC_STARTED) != 0 } | get -o 0.frame)
    let boundaries = ($framed | where {|x| $started != null and $x.frame > $started and $x.frame <= $e.frame })
    let at = {|f: any| if $f == null { null } else { $rows | where frame == $f | get -o 0.start_us } }
    let from = (do $at $started)
    let to = (do $at $e.frame)
    let seconds = (if $from == null or $to == null or $to <= $from { null } else { ($to - $from) / 1000000.0 })
    let frames = ($boundaries | length)
    let problems = [
        (if $e.forced or (not $e.valid) { "its stop was forced: the producer's last sequence and chains unknown, the window incomplete" })
        (if $e.offered != ($e.applied + $lost) { $"offered ($e.offered) is not applied ($e.applied), dropped ($e.dropped), rejected ($e.rejected), and discarded ($e.discarded)" })
        (if $e.valid and $ev == null { "no evidence record beside its end" })
        (if $e.valid and $ev != null and $ev.applied != $e.expected { $"hart 0's applied chain ($ev.applied) is not the producer's expected chain ($e.expected)" })
        (if $e.valid and $ev != null and $ev.gaps != $lost { $"the sequences' gaps sum to ($ev.gaps), not the ($lost) dropped, rejected, and discarded" })
        (if $e.valid and ($e.last + 1) != $e.offered { $"its last sequence offered is ($e.last), where ($e.offered) were offered" })
        (if ($rejects | length) != $e.rejected { $"($rejects | length) rejection records for ($e.rejected) rejected" })
        (if $started == null { "no frame marked its start" })
    ] | compact
    {
        generation: $e.generation, started: $started, stopped: $e.frame, valid: $e.valid, forced: $e.forced,
        offered: $e.offered, applied: $e.applied, dropped: $e.dropped, rejected: $e.rejected, discarded: $e.discarded,
        skipped: $e.skipped, corrupted: $e.corrupted, last: $e.last, published: $e.published, expected: $e.expected,
        applied_chain: ($ev | get -o applied), gaps: ($ev | get -o gaps),
        frames: $frames, seconds: $seconds,
        per_frame: (if $frames == 0 { null } else { $e.offered / $frames }),
        per_second: (if $seconds == null { null } else { $e.offered / $seconds }),
        apply: (stats ($boundaries | each {|x| $x.service_us })),
        age: (stats ($boundaries | where applied > 0 | each {|x| $x.age_us })),
        depth_max: (greatest ($boundaries | each {|x| $x.depth })),
        problems: $problems,
    }
}
