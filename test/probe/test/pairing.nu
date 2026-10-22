# The present sequence's cases, each its frames and the violations wanted
export def ordinals []: nothing -> list<any> {
    let p = {|ordinal: int| { presented: true, ordinal: $ordinal } }
    let n = {|ordinal: int| { presented: false, ordinal: $ordinal } }
    let violations = [
        { name: "ordinals_held", frames: [(do $p 4) (do $n 4) (do $p 5) (do $n 5) (do $p 6)], wanted: [] }
        { name: "ordinals_skip", frames: [(do $p 4) (do $p 6) (do $p 7)], wanted: [{ index: 1, rule: "skip", ordinal: 6, wanted: 5 }] }
        { name: "ordinals_repeat", frames: [(do $p 4) (do $p 4)], wanted: [{ index: 1, rule: "repeat", ordinal: 4, wanted: 5 }] }
        { name: "ordinals_backward", frames: [(do $p 4) (do $p 3)], wanted: [{ index: 1, rule: "backward", ordinal: 3, wanted: 5 }] }
        { name: "ordinals_advance", frames: [(do $p 4) (do $n 5)], wanted: [{ index: 1, rule: "advance", ordinal: 5, wanted: 4 }] }
        { name: "ordinals_first", frames: [(do $p 5) (do $p 6)], wanted: [{ index: 0, rule: "skip", ordinal: 5, wanted: 4 }] }
    ]
    $violations
}

# The synthetic runs the pairing reads, the regular run and its makers
export def runs []: nothing -> record {
    let period_ms = (1000.0 / 60.0)
    let base = 1792000000.0
    let starts = ([100.0 1500.0] ++ (0..<120 | each {|i| 1600.0 + $i * $period_ms }))
    let stamped = {|ms: float, name: string, kind: string, key: string| { ts: ($base + ($ms * 1000.0 | math floor) / 1000000.0), name: $name, kind: $kind, key: $key } }
    let upload = {|ms: float| do $stamped $ms "make_current" "upload" "chain:0+10" }
    let render = {|ms: float| do $stamped ($ms + 5.0) "make_current" "render" "chain:?+20" }
    let poll = {|ms: float| do $stamped $ms "poll" "poll" "chain:" }
    let made_at = {|times: list<float>, offsets: list<float>, after: float| [(do $upload 50.0)] ++ ($times | zip $offsets | each {|t| [(do $upload ($t.0 + $t.1)) (do $render $t.0)] } | flatten) ++ [(do $poll (($times | last) + $after))] }
    let made = {|times: list<float>, after: float| do $made_at $times ($times | each { 0.3 }) $after }
    let ticks = {|ms: float| $ms * 10000.0 | math round | into int }
    let flipped_at = {|times: list<float>, lengths: list<float>| $times | zip $lengths | enumerate | each {|e| { status: 0, ordinal: ($e.index + 2), lo: (do $ticks $e.item.0), hi: (do $ticks ($e.item.0 + $e.item.1)) } } }
    let flipped = {|times: list<float>| do $flipped_at $times ($times | each { 1.5 }) }
    let regular = { events: (do $made $starts 1500.0), flips: (do $flipped $starts) }
    { period_ms: $period_ms, base: $base, starts: $starts, stamped: $stamped, upload: $upload, render: $render, poll: $poll, made_at: $made_at, made: $made, ticks: $ticks, flipped_at: $flipped_at, flipped: $flipped, regular: $regular }
}

# The pairing's refused runs, each at its own rule
export def refusals [runs: record]: nothing -> list<any> {
    let starts = $runs.starts
    let period_ms = $runs.period_ms
    let upload = $runs.upload
    let render = $runs.render
    let made = $runs.made
    let poll = $runs.poll
    let regular = $runs.regular
    let late = ($starts | skip 2 | last 10 | each {|ms| $ms + 10 * $period_ms })
    let tail = {|times: list<float>| $times | each {|ms| [(do $upload ($ms + 0.3)) (do $render $ms)] } | flatten }
    let extra = {|at: float, count: int| 1..$count | each {|i| do $upload ($at + 5.0 + $i) } }
    let model = "the bracket: the clock model holds at no drift, a pause, a real-clock step, or an upload outside its call"
    let refusals = [
        { name: "pair_three_uploads", says: $model, events: ((do $made ($starts | take 50) 0.0 | drop 1) ++ (do $extra ($starts | get 49) 2) ++ (do $tail (($starts | skip 50) ++ $late)) ++ [(do $poll (($late | last) + 1500.0))]), flips: $regular.flips }
        { name: "pair_upload_missing", says: $model, events: ((do $made ($starts | take 60) 0.0 | drop 1) ++ (do $tail (($starts | skip 61) ++ $late)) ++ [(do $poll (($late | last) + 1500.0))]), flips: $regular.flips }
        { name: "pair_duplicated", says: "a duplicated event", events: ($regular.events | take 41 | append ($regular.events | get 40) | append ($regular.events | skip 41)), flips: $regular.flips }
        { name: "pair_gap", says: "an ordinal gap in the guest's presents", events: ((do $made ($starts | take 30) 0.0 | drop 1) ++ [(do $upload (($starts | get 29) + 5.5))] ++ (do $tail ($starts | skip 30)) ++ [(do $poll (($starts | last) + 1500.0))]), flips: ($regular.flips | take 30 | append ($regular.flips | skip 30 | each {|f| $f | update ordinal ($f.ordinal + 1) })) }
        { name: "pair_shifted", says: $model, events: ([(do $upload 10.0)] ++ $regular.events), flips: $regular.flips }
        { name: "pair_slip", says: $model, events: ((do $made ($starts | take 62) 0.0 | drop 1) ++ [(do $upload (($starts | get 61) + 8.0))] ++ (do $tail (($starts | skip 62) ++ $late)) ++ [(do $poll (($late | last) + 1500.0))]), flips: $regular.flips }
        { name: "pair_backwards", says: "a stamp going backwards", events: ($regular.events | update 82 {|e| $e | update ts ($e.ts - 0.5) }), flips: $regular.flips }
        { name: "pair_device", says: "a device error in the window", events: $regular.events, flips: ($regular.flips | take 70 | append { status: 3, ordinal: 71, lo: 0, hi: 0 } | append ($regular.flips | skip 70)) }
        { name: "pair_cut", says: "the log ending under 1 s past the window's last upload", events: (do $made $starts 500.0), flips: $regular.flips }
        { name: "pair_short", says: "the log short of an ordinal", events: (do $made ($starts | drop 3) 1500.0), flips: $regular.flips }
    ]
    $refusals
}
