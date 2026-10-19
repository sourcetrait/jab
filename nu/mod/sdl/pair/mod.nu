use (path self ../../present)
use (path self ../../tool)

# The workspace this module ships in, whose tool workspace builds jabpair
const workspace = (path self ../../../..)

# The pairing's limits, printed with every reading
const pair_limits = "the pairing is exact under the run binding, which ties the guest's records to the log, and under the log's assumptions, that it records every upload once and that every flush the device accepted makes one upload. The bracket is a consistency check under a correspondence fitted from the same stream: it cannot in general prove the absence of compensating edits, it cannot uniquely reject every stream shift, and it does not establish that a loss and an addition fall inside one call; a host stamp is read as the closed microsecond after it, admitting the one point no instant logged there holds. A stall is reported, never refused. walk's TIMING-off arm pairs on a frame bracket alone. The fit is a diagnostic, giving intervals and jitter and no absolute guest-to-SDL latency."

# A probed run's presents paired with the host's flip uploads, the bracket on top
export def main [events: list<any>, flips: list<record<status: int, ordinal: int, lo: int, hi: int>>, --period: float = 0.016666666666666666, --drift-ppm: int = 50, --stall-ms: float = 4.2]: nothing -> record<ok: bool, verdict: string, refusals: list<record<refusal: string, count: int>>, bracket: oneof<record, nothing>, shifts: list<any>, stalls: list<any>, pairs: list<any>, fit: oneof<record, nothing>, window: oneof<record, nothing>, limits: string> {
    let host = ($events | each {|e| { ts: (if ($e | get -o ts) != null { $e.ts } else { $e.stamp | into float }), us: (micros $e), name: $e.name, kind: ($e | get -o kind | default $e.name), key: ($e | get -o key | default "") } })
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
    let paired = (if (not $held) or ($presented | length) < 2 { [] } else { $presented | each {|p| let up = ($uploads | get ($p.ordinal - 1)); { ordinal: $p.ordinal, lo: $p.lo, hi: $p.hi, upload: $up.ts, upload_us: $up.us } } })
    let answers = (if ($paired | is-empty) { [] } else { brackets $paired $uploads $drift_ppm })
    let bound = ($answers | where name == "binding" | get -o 0)
    if $bound != null and $bound.status != "feasible" { $refusals = ($refusals | append { refusal: (bracket-refusal $bound), count: 1 }) }
    let shifted = ($answers | where name != "binding" | where status == "feasible")
    let verdict = (if not ($refusals | is-empty) { "refused" } else if not ($shifted | is-empty) { "ambiguous" } else { "admitted" })
    let fit = (fit-of $paired)
    let places = (if $bound == null { [] } else { $bound.places })
    let pairs = ($paired | enumerate | each {|e|
        let place = ($places | get -o $e.index)
        {
            ordinal: $e.item.ordinal,
            upload_us: $e.item.upload_us,
            lo: $e.item.lo,
            hi: $e.item.hi,
            call_ms: (($e.item.hi - $e.item.lo) / 10000.0),
            place: (if $place == null { null } else { { first_ms: ($place.first_ticks / 10000.0), last_ms: ($place.last_ticks / 10000.0) } }),
            residual_ms: ($fit.residuals_ms? | default [] | get -o $e.index),
        }
    })
    let median = (if ($pairs | is-empty) { 0.0 } else { $pairs | get call_ms | math median })
    let ordinal = {|i: int| $paired | get $i | get ordinal }
    {
        ok: ($verdict != "refused"),
        verdict: $verdict,
        refusals: $refusals,
        bracket: (if $bound == null { null } else {
            {
                status: $bound.status,
                reason: $bound.reason,
                drift_ppm: $drift_ppm,
                best: $bound.best,
                feasible: $bound.feasible,
                free: $bound.free,
                binding: (if $bound.binding == null { null } else { { ceiling: ($bound.binding.ceiling | each {|i| do $ordinal $i }), floor: ($bound.binding.floor | each {|i| do $ordinal $i }) } }),
            }
        }),
        shifts: ($answers | where name != "binding" | each {|a| { name: $a.name, status: $a.status } }),
        stalls: ($pairs | where {|p| ($p.call_ms - $median) > $stall_ms } | each {|p| { ordinal: $p.ordinal, call_ms: $p.call_ms, median_ms: $median, place: $p.place } }),
        pairs: $pairs,
        fit: (if $fit == null { null } else { { offset_s: ($fit.base + $fit.offset), drift: $fit.drift, max_residual_ms: ($fit.residuals_ms | each {|r| $r | math abs } | math max) } }),
        window: (if ($presented | is-empty) { null } else { { first: ($presented | first | get ordinal), last: $last, presents: ($presented | length), uploads: ($uploads | length) } }),
        limits: $pair_limits,
    }
}

# A host stamp as whole microseconds, from its text where the event keeps it
def micros [event: record]: nothing -> int {
    let stamp = ($event | get -o stamp)
    if $stamp != null {
        let parts = ($stamp | into string | split row ".")
        ($parts.0 | into int) * 1000000 + ($parts.1 | into int)
    } else {
        $event.ts * 1000000.0 | math round | into int
    }
}

# The binding's pairing and the stream shifted an upload each way, bracketed
def brackets [paired: list<any>, uploads: list<any>, drift_ppm: int]: nothing -> list<any> {
    let count = ($uploads | length)
    let shift = {|by: int| $paired | each {|p| let index = ($p.ordinal - 1 + $by); if $index < 0 or $index >= $count { null } else { { h_us: ($uploads | get $index | get us), l: $p.lo, u: $p.hi } } } | compact }
    let request = {
        drift: { lo: [(1000000 - $drift_ppm) 1000000], hi: [(1000000 + $drift_ppm) 1000000] },
        cases: [
            { name: "binding", pairs: (do $shift 0) }
            { name: "earlier", pairs: (do $shift (-1)) }
            { name: "later", pairs: (do $shift 1) }
        ],
    }
    let bin = (tool pair $workspace)
    let ran = ($request | to json --raw | ^$bin | complete)
    if $ran.exit_code != 0 { error make {msg: $"jabpair refused the request: ($ran.stderr)"} }
    $ran.stdout | from json | get cases
}

# The bracket's refusal in words, by what the wide range found
def bracket-refusal [answer: record]: nothing -> string {
    match $answer.status {
        "infeasible" => (if $answer.free.feasible { "the bracket: no drift within the declared bound holds every upload in its call, and one past it does" } else { "the bracket: the clock model holds at no drift, a pause, a real-clock step, or an upload outside its call" }),
        _ => $"the bracket unresolved: ($answer.reason)",
    }
}

# The least-squares fit of the paired uploads on their calls' ends, a diagnostic
def fit-of [paired: list<any>]: nothing -> oneof<record, nothing> {
    if ($paired | is-empty) { return null }
    let base = ($paired | first | get upload)
    let xs = ($paired | each {|p| $p.hi / 1e7 })
    let ys = ($paired | each {|p| $p.upload - $base })
    let mx = ($xs | math avg)
    let my = ($ys | math avg)
    let sxx = ($xs | each {|x| ($x - $mx) * ($x - $mx) } | math sum)
    let sxy = ($xs | zip $ys | each {|p| ($p.0 - $mx) * ($p.1 - $my) } | math sum)
    let drift = (if $sxx == 0.0 { 1.0 } else { $sxy / $sxx })
    let offset = ($my - $drift * $mx)
    { base: $base, offset: $offset, drift: $drift, residuals_ms: ($xs | zip $ys | each {|p| ($p.1 - ($offset + $drift * $p.0)) * 1000.0 }) }
}
