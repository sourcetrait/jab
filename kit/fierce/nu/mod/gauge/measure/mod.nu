use (path self ../report)
use (path self ../stream)
use (path self ./completeness) [window-problems]
use (path self ./presentation) [EPS_CAP]
use (path self ./receipt) [acceptance-of accepted bracket-invalidity contract-of receipt-invalidity]
use (path self ./rows) [rows-of]
use (path self ./service) [service-of]
use (path self ./summary) [leg-summary outcomes-of outliers]
use (path self ./validity) [invalidity]
export use (path self ./receipt) [contract-of flips wake-delays]
export use (path self ./screen) [screen-frame]
export use (path self ./summary) [stats total]

# A capture measured: its window, rows, legs, outliers, outcomes, and contract
export def main [api: binary, legs: list<any>, --cap: int = 60, --eps: int = 10000]: nothing -> record {
    if $eps <= 0 or $eps > $EPS_CAP { error make { msg: $"--eps is 1 to ($EPS_CAP) ticks, not ($eps)" } }
    let s = (stream $api)
    let clocked = (([$s.frames $s.draws $s.presents $s.packets $s.tiles $s.storages $s.configs $s.harts $s.receipts] | any {|k| not ($k | is-empty) }) or $s.end != null)
    let schema = (if $clocked { stream schema-of $s } else { null })
    let final = (if $s.end == null { null } else { $s.end.frame })
    let problems = (if not $clocked { [] } else { window-problems $s $schema })
    let complete = ($clocked and ($problems | is-empty))
    let last = (if not $clocked { ($s.states | length) - 1 } else if $final == null { ($s.frames | length) - 1 } else { $final })
    let framed = (rows-of $s $legs $last $schema)
    let anchor = ($s.loads | get -o 0.clear_ordinal)
    let sequenced = (if $complete and ($schema | default 1) >= 7 { receipt-invalidity $framed $anchor } else { [] })
    let bracketed = (if $complete and ($schema | default 1) >= 8 { bracket-invalidity $framed ($s.loads | get -o 0) ($s.bounds | get -o 0) } else { [] })
    let receipted = ($sequenced ++ $bracketed)
    let service = (service-of $s $framed $last)
    let served = (if $service == null { [] } else { $service.problems })
    let invalid = (if $complete { (invalidity $framed $schema) ++ $receipted ++ $served } else { [] })
    let valid = ($complete and ($invalid | is-empty))
    let acceptance = (acceptance-of $clocked $schema $complete $receipted)
    let rows = (if $acceptance.available { accepted $framed ($s.loads | get -o 0.clear_stamp) } else { $framed })
    let period_us = (1000000 / $cap)
    let names = ($legs | get name)
    let summaries = ($names | each {|n| leg-summary $n ($rows | where leg == $n) $period_us } | where frames > 0)
    let whole = (leg-summary "whole" $rows $period_us)
    {
        clocked: $clocked,
        schema: $schema,
        complete: $complete,
        final: $final,
        problems: $problems,
        valid: $valid,
        invalid: $invalid,
        seeded: $s.seeded,
        late_seed: $s.late_seed,
        cadence_set: $s.cadence_set,
        late_cadence: $s.late_cadence,
        cadences: ($rows | get -o cadence | compact | uniq | sort),
        workers_set: $s.workers_set,
        late_workers: $s.late_workers,
        nonce_set: $s.nonce_set,
        late_nonce: $s.late_nonce,
        load: ($s.loads | get -o 0),
        bounds: ($s.bounds | get -o 0),
        acceptance: $acceptance,
        contract: (contract-of $rows $acceptance $cap $eps),
        workers: ($rows | get -o workers | compact | uniq | sort),
        grains: ($rows | get -o grain | compact | uniq | sort),
        grants: ($rows | get -o grant | compact | uniq | sort),
        actives: ($rows | get -o active | compact | uniq | sort),
        period_us: $period_us,
        frames: ($rows | length),
        past_window: $s.past,
        under: (if $valid { report under-ceiling $whole.critical.median } else { null }),
        over: (if $clocked { $rows | where {|r| $r.over == true } | length } else { null }),
        whole: $whole,
        legs: $summaries,
        outliers: (if $clocked { outliers $rows $schema } else { [] }),
        outcomes: (outcomes-of $s.events $rows $last),
        rounds: $s.rounds,
        service: $service,
        rows: $rows,
    }
}
