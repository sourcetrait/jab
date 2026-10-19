use ../../present

# The pairing's limits, printed with every reading
const pair_limits = "the pairing assumes the run binding, which ties the guest's records to the log, and that the log records every upload once and that every flush the device accepted makes one upload; under those assumptions it is exact, and the oracle's flush trace rechecks them run by run on the box. The residual is a consistency check: it proves no absence of a loss and an addition that compensate inside the window, and it catches a uniform shift only where the paired intervals are irregular past half a period. The fit gives intervals and jitter, and no absolute guest-to-SDL latency."

# A probed run's presents paired with the host's flip uploads, and their fit
export def main [events: list<any>, flips: list<record<status: int, ordinal: int, end_us: number>>, --period: float = 0.016666666666666666]: nothing -> record<ok: bool, refusals: list<record<refusal: string, count: int>>, pairs: list<any>, fit: oneof<record, nothing>, window: oneof<record, nothing>, limits: string> {
    let host = ($events | each {|e| { ts: (if ($e | get -o ts) != null { $e.ts } else { $e.stamp | into float }), name: $e.name, kind: ($e | get -o kind | default $e.name), key: ($e | get -o key | default "") } })
    let presented = ($flips | where status == 0)
    let uploads = ($host | where kind == "upload")
    mut refusals = []
    let gaps = (if ($presented | is-empty) { [] } else { present ordinal-violations (($presented | first | get ordinal) - 1) ($presented | each {|p| { presented: true, ordinal: $p.ordinal } }) })
    if not ($gaps | is-empty) { $refusals = ($refusals | append { refusal: "an ordinal gap in the guest's presents", count: ($gaps | length) }) }
    let last = (if ($presented | is-empty) { 0 } else { $presented | last | get ordinal })
    let short = ($last - ($uploads | length))
    if $short > 0 { $refusals = ($refusals | append { refusal: "the log short of an ordinal", count: $short }) }
    let duplicated = ($host | window 2 | where {|w| $w.0 == $w.1 } | length)
    if $duplicated > 0 { $refusals = ($refusals | append { refusal: "a duplicated event", count: $duplicated }) }
    let backwards = ($host | window 2 | where {|w| $w.1.ts < $w.0.ts } | length)
    if $backwards > 0 { $refusals = ($refusals | append { refusal: "a stamp going backwards", count: $backwards }) }
    let errors = ($flips | where status == 3 | length)
    if $errors > 0 { $refusals = ($refusals | append { refusal: "a device error in the window", count: $errors }) }
    if ($presented | length) < 2 { $refusals = ($refusals | append { refusal: "fewer than two presents to fit", count: ($presented | length) }) }
    let held = ($short <= 0 and $last >= 1)
    if $held {
        let after = (($host | last | get ts) - ($uploads | get ($last - 1) | get ts))
        if $after < 1.0 { $refusals = ($refusals | append { refusal: "the log ending under 1 s past the window's last upload", count: 1 }) }
    }
    let paired = (if (not $held) or ($presented | length) < 2 { [] } else { $presented | each {|p| { ordinal: $p.ordinal, end_us: $p.end_us, upload: ($uploads | get ($p.ordinal - 1) | get ts) } } })
    let fit = (if ($paired | is-empty) { null } else {
        let base = ($paired | first | get upload)
        let xs = ($paired | each {|p| $p.end_us / 1e6 })
        let ys = ($paired | each {|p| $p.upload - $base })
        let mx = ($xs | math avg)
        let my = ($ys | math avg)
        let sxx = ($xs | each {|x| ($x - $mx) * ($x - $mx) } | math sum)
        let sxy = ($xs | zip $ys | each {|p| ($p.0 - $mx) * ($p.1 - $my) } | math sum)
        let drift = (if $sxx == 0.0 { 1.0 } else { $sxy / $sxx })
        let offset = ($my - $drift * $mx)
        let residuals = ($xs | zip $ys | each {|p| ($p.1 - ($offset + $drift * $p.0)) * 1000.0 })
        { base: $base, offset: $offset, drift: $drift, residuals_ms: $residuals }
    })
    let pairs = (if $fit == null { [] } else { $paired | zip $fit.residuals_ms | each {|p| $p.0 | insert residual_ms $p.1 } })
    let past = ($pairs | where {|p| ($p.residual_ms | math abs) >= ($period * 500.0) } | length)
    if $past > 0 { $refusals = ($refusals | append { refusal: "a residual past half the period", count: $past }) }
    {
        ok: ($refusals | is-empty),
        refusals: $refusals,
        pairs: $pairs,
        fit: (if $fit == null { null } else { { offset_s: ($fit.base + $fit.offset), drift: $fit.drift, max_residual_ms: ($fit.residuals_ms | each {|r| $r | math abs } | math max) } }),
        window: (if ($presented | is-empty) { null } else { { first: ($presented | first | get ordinal), last: $last, presents: ($presented | length), uploads: ($uploads | length) } }),
        limits: $pair_limits,
    }
}
