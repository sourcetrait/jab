use ../classify

# The report on a shim log: how the flips reached the window, or a refusal
export def main [log: path]: nothing -> record {
    let classified = (classify $log)
    let events = $classified.events
    let executable = ($classified.objects | where index == 0 | get -o 0)
    let kinds = ($events | select ts kind callers)
    let t0 = ($events | first | get ts)
    let uploads = ($kinds | where kind == "upload")
    let others = ($kinds | where kind == "console")
    let switches = ($kinds | where kind == "switch")
    let renders = ($kinds | where kind == "render" | get ts)
    let polls = ($kinds | where kind == "poll" | get ts)
    mut flips: list<record<start: float, end: float, size: int, gaps: list<float>>> = []
    for u in $uploads {
        if (($flips | length) > 0) and (($u.ts - ($flips | last | get end)) < 0.005) {
            let f = ($flips | last)
            $flips = (($flips | drop 1) ++ [{ start: $f.start, end: $u.ts, size: ($f.size + 1), gaps: ($f.gaps ++ [(($u.ts - $f.end) * 1000.0)]) }])
        } else {
            $flips = ($flips ++ [{ start: $u.ts, end: $u.ts, size: 1, gaps: [] }])
        }
    }
    let done = $flips
    mut last_upload = -1.0
    mut befores: list<float> = []
    for e in $kinds {
        if $e.kind == "upload" { $last_upload = $e.ts } else if $e.kind == "render" { $befores = ($befores ++ [(if $last_upload < 0.0 { 1.0 } else { $e.ts - $last_upload })]) }
    }
    mut next_upload = -1.0
    mut afters: list<float> = []
    for e in ($kinds | reverse) {
        if $e.kind == "upload" { $next_upload = $e.ts } else if $e.kind == "render" { $afters = ($afters ++ [(if $next_upload < 0.0 { 1.0 } else { $next_upload - $e.ts })]) }
    }
    let afters_in_order = ($afters | reverse)
    let befores_in_order = $befores
    let inside = ($renders | enumerate | each {|r|
        let before = (($befores_in_order | get $r.index) * 1000.0)
        let after = (($afters_in_order | get $r.index) * 1000.0)
        if $before < 3.0 and $after < 3.0 { { at: (($r.item - $t0) | math round -p 3), upload_before_ms: ($before | math round -p 2), upload_after_ms: ($after | math round -p 2) } } else { null }
    } | compact)
    let spans = ($done | where size > 1 | each {|f| ($f.end - $f.start) * 1000.0 })
    let gaps = ($done | get gaps | flatten)
    let cadence = ($done | window 2 | each {|w| ($w.1.start - $w.0.start) * 1000.0 })
    let intervals = ($renders | window 2 | each {|w| ($w.1 - $w.0) * 1000.0 })
    let hist = {|values: list<float>| $values | each {|v| $v | math round -p 0 } | uniq --count | sort-by count --reverse | first 6 | each {|c| { ms: $c.value, count: $c.count } } }
    let stat = {|values: list<float>| if ($values | is-empty) { { median: 0.0, max: 0.0 } } else { { median: ($values | math median | math round -p 2), max: ($values | math max | math round -p 2) } } }
    let range = {|values: list<float>| if ($values | is-empty) { { median: 0.0, min: 0.0, max: 0.0 } } else { { median: ($values | math median | math round -p 0), min: ($values | math min | math round -p 0), max: ($values | math max | math round -p 0) } } }
    let top = {|rows: list| $rows | get callers | uniq --count | sort-by count --reverse | first 2 | each {|c| { callers: $c.value, count: $c.count } } }
    # which guest frame each render showed: the flips whose last upload
    # landed since the render before it; none is the frame before shown
    # again, one is that flip shown, more is every one but the last
    # skipped, so a beat between the guest's cadence and the window's
    # timer reads as skips or repeats at a steady interval and a stall
    # as a burst of them
    let flip_count = ($done | length)
    mut next_flip = 0
    mut showings: list<record<at: float, flips: int>> = []
    for r in $renders {
        mut n = 0
        while ($next_flip < $flip_count) and (($done | get $next_flip | get end) <= $r) {
            $n += 1
            $next_flip += 1
        }
        $showings = ($showings ++ [{ at: ($r - $t0), flips: $n }])
    }
    let showed = $showings
    let repeats = ($showed | where flips == 0)
    let skips = ($showed | where flips > 1)
    let skipped = (if ($skips | is-empty) { 0 } else { $skips | each {|s| $s.flips - 1 } | math sum })
    let skip_times = ($skips | get at)
    let repeat_times = ($repeats | get at)
    let between = {|times: list<float>| $times | window 2 | each {|w| ($w.1 - $w.0) * 1000.0 } }
    {
        run: { binary: (if $executable == null { "" } else { $executable.path }) },
        virtio_gpu_in: $classified.virtio_gpu_in,
        seconds_logged: ((($events | last | get ts) - $t0) | math round -p 1),
        flips: ($done | length),
        uploads_per_flip: ($done | get size | uniq --count | sort-by count --reverse | first 6 | each {|c| { uploads: $c.value, count: $c.count } }),
        flip_span_ms: (do $stat $spans),
        upload_gap_ms: (do $stat $gaps),
        flip_cadence_ms: (do $hist $cadence),
        renders: ($renders | length),
        render_interval_ms: (do $hist $intervals),
        frames_shown: { shown: ($showed | where flips == 1 | length), repeated: ($repeats | length), skipped: $skipped, unshown_at_end: ($flip_count - $next_flip) },
        skip_times_s: ($skip_times | first 24 | each {|t| $t | math round -p 3 }),
        skip_interval_ms: (do $range (do $between $skip_times)),
        repeat_times_s: ($repeat_times | first 24 | each {|t| $t | math round -p 3 }),
        repeat_interval_ms: (do $range (do $between $repeat_times)),
        renders_inside_flip: ($inside | length),
        inside_cases: ($inside | first 8),
        polls: ($polls | length),
        switches: ($switches | length),
        other_uploads: ($others | length),
        upload_callers: (do $top $uploads),
        other_upload_callers: (do $top $others),
        switch_callers: (do $top $switches),
        render_callers: (do $top ($kinds | where kind == "render")),
    }
}
