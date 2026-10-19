use (path self ../../../../../../nu/mod/present)
use (path self ../report)
use (path self ../stream)
use (path self ../identity) [SCHEMAS]
use (path self ../report) [CEILING_US]
use (path self ../../picture) [STAMP_BITS]

# The slack on a bound frame's eye position, in metres
const POSE_SLACK_M = 0.001

# The slack on a bound frame's angles, in degrees
const POSE_SLACK_DEGREES = 0.01

# The batch source of the first boundary, which consumes none
const NO_BATCH = 4294967295

# The most raster workers a frame may have through schema 5
const WORKERS_MAX_TO_FIVE = 2

# The ABI's harts, a harts mask's bound
const HARTS_MAX = 8

# The cadence that awaits after its flip
export const CADENCE_AFTER_FLIP = 0

# The cap a frame's period comes from when the identity names none
export const CAP = 60

# The validity bound in microseconds on the residual the conversions drop
const RESIDUAL_US = 4

# The span records a frame holds before its spans go unrecorded
const SPAN_RECORDS = 65536

# A packet command's bytes by schema, the polygon record copied whole
const COMMAND_BYTES = { "3": 312, "4": 312, "5": 232, "6": 232, "7": 232 }

# A span record's bytes in a packet
const SPAN_BYTES = 16

# The microsecond a drawing may run past its preparation and raster
const PACKET_RESIDUAL_US = 1

# The multiple of its leg's median an outlier phase must pass
const OUTLIER_RATIO = 4

# The microseconds over its leg's median an outlier phase must pass
const OUTLIER_US = 2000

# A flip's status when presented
export const FLIP_PRESENTED = 0

# A flip's status when refused before the tick
export const FLIP_EARLY = 1

# The flip statuses a valid measurement holds, presented and early
const FLIP_VALID = [0 1]

# The guest clock's ticks a microsecond, its 10 MHz, a receipt's stamps' unit
const TICKS_PER_US = 10.0

# The android events' names, indexed as the program reports them
const ANDROID_EVENTS = [none roused fired struck destroyed fallen waypoint]

# What a round met, named, indexed as the program reports it
const MET = [nothing geometry android]

# The cadences: 0 awaits after the flip, 1 waits only if early, 2 on the tick
export const CADENCES = [0 1 2]

# The screen's rows, a grain's bound
export const SCREEN_ROWS = 1080

# A capture measured: its window, rows, legs, outliers, outcomes, validity
export def main [api: binary, legs: list<any>, --cap: int = 60]: nothing -> record {
    let s = (stream $api)
    let clocked = (([$s.frames $s.draws $s.presents $s.packets $s.tiles $s.storages $s.configs $s.harts $s.receipts] | any {|k| not ($k | is-empty) }) or $s.end != null)
    let schema = (if $clocked { stream schema-of $s } else { null })
    let final = (if $s.end == null { null } else { $s.end.frame })
    let problems = (if not $clocked { [] } else { window-problems $s $schema })
    let complete = ($clocked and ($problems | is-empty))
    let last = (if not $clocked { ($s.states | length) - 1 } else if $final == null { ($s.frames | length) - 1 } else { $final })
    let framed = (rows-of $s $legs $last $schema)
    let anchor = ($s.loads | get -o 0.clear_ordinal)
    let receipted = (if $complete and ($schema | default 1) >= 7 { receipt-invalidity $framed $anchor } else { [] })
    let invalid = (if $complete { (invalidity $framed $schema) ++ $receipted } else { [] })
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
        acceptance: $acceptance,
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
        rows: $rows,
    }
}

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

# What keeps a window from complete, from the records before its marker
def window-problems [s: record, schema: oneof<int, nothing>]: nothing -> list<string> {
    mut problems = []
    if $s.end == null {
        $problems = ($problems | append "no end marker: the measurement never closed")
    }
    if $schema not-in $SCHEMAS {
        $problems = ($problems | append $"the clock records at schema ($schema), this reader's being ($SCHEMAS | str join ', ')")
    }
    let last = (if $s.end == null { ($s.frames | length) - 1 } else { $s.end.frame })
    let at = ($schema | default 1)
    let records = ([[name items]; [frame $s.frames] [draw $s.draws]]
        | append (if $at >= 2 { [[name items]; [presentation $s.presents]] } else { [] })
        | append (if $at >= 3 { [[name items]; [packet $s.packets]] } else { [] })
        | append (if $at >= 5 { [[name items]; [tile $s.tiles] [storage $s.storages]] } else { [] })
        | append (if $at >= 6 { [[name items]; [harts $s.harts]] } else { [] })
        | append (if $at >= 7 { [[name items]; [receipt $s.receipts]] } else { [] }))
    for kind in $records {
        let order = ($kind.items | enumerate | where {|e| $e.item.frame != $e.index } | length)
        if $order > 0 { $problems = ($problems | append $"($order) ($kind.name) records out of order or repeated") }
        if ($kind.items | length) != ($last + 1) { $problems = ($problems | append $"($kind.items | length) ($kind.name) records before the end marker for ($last + 1) frames") }
    }
    if ($s.states | length) != ($last + 1) { $problems = ($problems | append $"($s.states | length) state records before the end marker for ($last + 1) frames") }
    if $at >= 5 {
        let froms = ($s.configs | each {|c| $c.from })
        let first = (if ($froms | is-empty) { null } else { $froms | math min })
        if $first == null or $first > 0 { $problems = ($problems | append $"frames before any configuration of the tile pool: the first from frame ($first | default 'none')") }
        let arriving = ($s.configs | where {|c| $c.arrival_states != $c.from or $c.arrival_frames != $c.from })
        if ($arriving | is-not-empty) {
            let named = ($arriving | each {|c| $"from ($c.from) after ($c.arrival_states) state and ($c.arrival_frames) frame records" } | str join "; ")
            $problems = ($problems | append $"($arriving | length) configurations of the tile pool arriving other than at the first frame they govern: ($named)")
        }
    }
    if $at >= 7 {
        let before = ($s.loads | where arrival_states == 0)
        if ($s.loads | is-empty) { $problems = ($problems | append "no load record: the load's presents and the nonce never came") }
        if ($s.loads | length) > 1 { $problems = ($problems | append $"($s.loads | length) load records, where the program writes one") }
        if ($before | length) != ($s.loads | length) { $problems = ($problems | append "a load record after the first state, where the program writes it before") }
    }
    let marker = (if $s.end == null { [] } else { [$s.end.schema] })
    let others = ($s.frames | append $s.draws | append $s.presents | append $s.packets | append $s.tiles | append $s.storages | append $s.configs | append $s.harts | append $s.receipts | append $s.loads | each {|r| $r.schema } | append $marker | uniq | where {|v| $v != $schema })
    if not ($others | is-empty) { $problems = ($problems | append $"clock records at schemas ($others | str join ', ') in a capture at schema ($schema)") }
    $problems
}

# What makes a complete window invalid, schema by schema
def invalidity [rows: list<any>, schema: oneof<int, nothing>]: nothing -> list<string> {
    let unshown = ($rows | where {|r| $r.flip_status not-in $FLIP_VALID })
    let negative = ($rows | where {|r| $r.unattributed_us < 0 or $r.parts_unattributed_us < 0 })
    let misaligned = ($rows | where {|r| not $r.aligned })
    let base = [
        (if ($unshown | is-empty) { null } else { $"($unshown | length) flips at status ($unshown | get flip_status | uniq | each {|v| $v | into string } | str join ', '), never shown" }),
        (if ($negative | is-empty) { null } else { $"($negative | length) frames whose phases or parts sum past their whole" }),
        (if ($misaligned | is-empty) { null } else { $"($misaligned | length) frames whose clock record differs from their state's" }),
    ]
    let at = ($schema | default 1)
    if $at < 2 { return ($base | compact) }
    let every = $rows
    let unrecorded = ($every | where {|r| $r.cadence == null })
    let rows = ($every | where {|r| $r.cadence != null })
    let outside = ($rows | where {|r| $r.cadence not-in $CADENCES })
    let after = ($rows | where {|r| $r.cadence == $CADENCE_AFTER_FLIP })
    let waited = ($after | where {|r| $r.wait_us != 0 or $r.pacing_us != 0 })
    let retried = ($after | where {|r| $r.flip_attempts != 1 })
    let unpresented = ($rows | where {|r| $r.cadence in [1 2] and $r.flip_status != $FLIP_PRESENTED })
    let counted = ($rows | where {|r| $r.flip_attempts != ($r.refusals + (if $r.flip_status == $FLIP_EARLY { 0 } else { 1 })) })
    let unbalanced = ($rows | where {|r| $r.residual_us < 0 or $r.residual_us > $RESIDUAL_US })
    let disordered = ($rows | where {|r| not ($r.start_us <= $r.simulation_us and $r.simulation_us <= $r.flip_done_us and $r.flip_done_us <= $r.next_start_us) })
    let broken = ($rows | window 2 | where {|w| $w.0.next_start_us != $w.1.start_us })
    let presented = [
        (if ($unrecorded | is-empty) { null } else { $"($unrecorded | length) frames without a presentation record" }),
        (if ($outside | is-empty) { null } else { $"($outside | length) frames at a cadence outside 0 to 2" }),
        (if ($waited | is-empty) { null } else { $"($waited | length) frames under cadence 0 with a wait or a pacing" }),
        (if ($retried | is-empty) { null } else { $"($retried | length) frames under cadence 0 whose flip was attempted other than once" }),
        (if ($unpresented | is-empty) { null } else { $"($unpresented | length) frames under cadence 1 or 2 whose final flip was not presented" }),
        (if ($counted | is-empty) { null } else { $"($counted | length) frames whose attempts are not their refusals and their final attempt" }),
        (if ($unbalanced | is-empty) { null } else { $"($unbalanced | length) frames whose next start less their start is not their critical path, wait, and await" }),
        (if ($disordered | is-empty) { null } else { $"($disordered | length) frames whose start, simulation, flip end, and next start are out of order" }),
        (if ($broken | is-empty) { null } else { $"($broken | length) frames whose next start is not the next frame's start" }),
    ]
    if $at < 3 { return ($base | append $presented | compact) }
    let unpacked = ($every | where {|r| $r.raster_us == null })
    let packed = ($every | where {|r| $r.raster_us != null })
    let unsplit = ($packed | where {|r| $r.packet_residual_us < 0 or $r.packet_residual_us > $PACKET_RESIDUAL_US })
    let command_bytes = ($COMMAND_BYTES | get ($at | into string))
    let unsized = ($packed | where {|r| $r.packet_bytes != ($r.commands * $command_bytes + $r.spans * $SPAN_BYTES) })
    let stale = ($packed | where {|r| $r.snapshot != $r.frame })
    let packets = [
        (if ($unpacked | is-empty) { null } else { $"($unpacked | length) frames without a packet record" }),
        (if ($unsplit | is-empty) { null } else { $"($unsplit | length) frames whose drawing is not their preparation and their raster" }),
        (if ($unsized | is-empty) { null } else { $"($unsized | length) frames whose packets' bytes are not their commands' and their span records'" }),
        (if ($stale | is-empty) { null } else { $"($stale | length) frames whose packets were prepared from another frame's simulation" }),
    ]
    if $at < 4 { return ($base | append $presented | append $packets | compact) }
    let crowded = (if $at >= 6 { [] } else { $packed | where {|r| ($r.workers | default 0) > $WORKERS_MAX_TO_FIVE } })
    let coarse = ($packed | where {|r| ($r.grain | default 0) > $SCREEN_ROWS })
    let serial_timed = ($packed | where {|r| $r.workers == 0 and ([$r.slowest_us $r.busy_us $r.dispatch_us $r.barrier_us] | any {|t| ($t | default 0) != 0 }) })
    let overtimed = ($packed | where {|r| ($r.workers | default 0) > 0 and ([$r.slowest_us $r.dispatch_us $r.barrier_us] | any {|t| ($t | default 0) > $r.raster_us }) })
    let short_busy = ($packed | where {|r| ($r.workers | default 0) > 0 and ($r.busy_us | default 0) < ($r.slowest_us | default 0) })
    let long_busy = ($packed | where {|r| let w = ($r.workers | default 0); $w > 0 and ($r.busy_us | default 0) > ($w * ($r.slowest_us | default 0) + $w - 1) })
    let workers = [
        (if ($crowded | is-empty) { null } else { $"($crowded | length) frames drawn by more than ($WORKERS_MAX_TO_FIVE) workers" }),
        (if ($coarse | is-empty) { null } else { $"($coarse | length) frames at a grain past the screen's ($SCREEN_ROWS) rows" }),
        (if ($serial_timed | is-empty) { null } else { $"($serial_timed | length) frames of the serial backend carrying a round's time" }),
        (if ($overtimed | is-empty) { null } else { $"($overtimed | length) frames whose slowest worker, dispatch, or barrier is past their raster" }),
        (if ($short_busy | is-empty) { null } else { $"($short_busy | length) frames whose workers' busy time is less than their slowest's" }),
        (if ($long_busy | is-empty) { null } else { $"($long_busy | length) frames whose workers' busy time is past W times their slowest's" }),
    ]
    if $at < 5 { return ($base | append $presented | append $packets | append $workers | compact) }
    if $at < 6 { return ($base | append $presented | append $packets | append $workers | append (pool-invalidity $every) | compact) }
    $base | append $presented | append $packets | append $workers | append (pool-invalidity $every) | append (harts-invalidity $every) | compact
}

# What makes a schema 7 window invalid in its receipts
def receipt-invalidity [rows: list<any>, anchor: oneof<int, nothing>]: nothing -> list<string> {
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

# Whether a measurement's acceptance intervals stand, and why not where not
def acceptance-of [clocked: bool, schema: any, complete: bool, receipted: list<string>]: nothing -> record<available: bool, reason: any> {
    if not $clocked or ($schema | default 1) < 7 { return { available: false, reason: $"schema ($schema | default 1) carries no receipt" } }
    if not $complete { return { available: false, reason: "the capture is not complete, so its present sequence is not whole" } }
    if not ($receipted | is-empty) { return { available: false, reason: "its receipt sequence is invalid" } }
    { available: true, reason: null }
}

# Each presented frame's acceptance interval from the present before it, the
# first from the load's cleared screen; a frame that presented nothing keeps
# null and breaks no adjacency
def accepted [rows: list<any>, anchor: int]: nothing -> list<any> {
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

# The count of harts a mask holds
def popcount [mask: int]: nothing -> int {
    0..<$HARTS_MAX | where {|h| (($mask bit-shr $h) bit-and 1) == 1 } | length
}

# What makes a schema 6 window invalid in its harts' masks
def harts-invalidity [rows: list<any>]: nothing -> list<any> {
    let unharted = ($rows | where {|r| $r.online == null })
    let masked = ($rows | where {|r| $r.online != null })
    let unhoused = ($masked | where {|r| ($r.active bit-and $r.started) != $r.active })
    let ungranted = ($masked | where {|r| ($r.started bit-and $r.grant) != $r.started })
    let miscounted = ($masked | where {|r| $r.workers != null and $r.workers != (popcount $r.active) })
    let misreported = ($masked | where {|r| $r.reported != $r.active })
    let doubled = ($masked | where {|r| ($r.claimed bit-and $r.grant) != 0 })
    let offline = ($masked | where {|r| ($r.grant bit-and $r.online) != $r.grant or ($r.claimed bit-and $r.online) != $r.claimed })
    let impossible = ($masked | where {|r| ($r.online bit-and 1) != 0 or $r.online >= (1 bit-shl $HARTS_MAX) })
    let underfloor = ($masked | where {|r| (popcount $r.grant) < $r.floor })
    [
        (if ($unharted | is-empty) { null } else { $"($unharted | length) frames without a harts record" }),
        (if ($unhoused | is-empty) { null } else { $"($unhoused | length) frames dispatched to a hart holding no raster worker" }),
        (if ($ungranted | is-empty) { null } else { $"($ungranted | length) frames with a raster worker on a hart outside the grant" }),
        (if ($miscounted | is-empty) { null } else { $"($miscounted | length) frames whose packet record's workers are not their active harts' count" }),
        (if ($misreported | is-empty) { null } else { $"($misreported | length) frames whose reporting harts are not their active" }),
        (if ($doubled | is-empty) { null } else { $"($doubled | length) frames with a claimed hart inside the grant" }),
        (if ($offline | is-empty) { null } else { $"($offline | length) frames whose grant or claimed harts lie outside the online secondaries" }),
        (if ($impossible | is-empty) { null } else { $"($impossible | length) frames whose online mask holds hart 0 or a hart past the ABI's bound" }),
        (if ($underfloor | is-empty) { null } else { $"($underfloor | length) frames whose grant holds fewer harts than its floor" }),
    ]
}

# What makes a schema 5 window invalid in its tile pool
def pool-invalidity [rows: list<any>]: nothing -> list<any> {
    let untiled = ($rows | where {|r| $r.admitted == null })
    let unstored = ($rows | where {|r| $r.slots_used == null })
    let unconfigured = ($rows | where {|r| $r.tile_memory == null })
    let pooled = ($rows | where {|r| $r.admitted != null and $r.slots_used != null and $r.tile_memory != null })
    let by_frame = ($pooled | reduce --fold {} {|r, acc| $acc | upsert ($r.frame | into string) $r.admitted })
    let overfull = ($pooled | where {|r| $r.slots_used > $r.slots_effective or $r.building > $r.slots_effective })
    let beyond = ($pooled | where {|r| $r.slots_effective > $r.slots })
    let overbuilt = ($pooled | where {|r| $r.tiles_built > $r.slots_effective or $r.evicted > $r.slots_effective })
    let unbuilt = ($pooled | where {|r| $r.building > $r.slots_used })
    let overtime = ($pooled | where {|r| $r.build_us > $r.tiles_us })
    let overmerged = ($pooled | where {|r| $r.merged > $r.batch_admitted })
    let overspent = ($pooled | where {|r| ($r.merged + $r.unprocessed) > $r.batch_admitted })
    let unsourced = ($pooled | where {|r| if $r.frame == 0 { $r.batch_source != $NO_BATCH } else { $r.batch_source != ($r.frame - 1) } })
    let unsentinel = ($pooled | where {|r| $r.frame == 0 and ($r.batch_admitted != 0 or $r.merged != 0 or $r.unprocessed != 0) })
    let overmemory = ($pooled | where {|r| $r.memory > $r.tile_memory or $r.memory > $r.memory_peak or $r.memory_peak > $r.tile_memory })
    let falling = ($pooled | window 2 | where {|w| $w.1.memory_peak < $w.0.memory_peak or $w.1.tile_peak < $w.0.tile_peak })
    let unbatched = ($pooled | where {|r| $r.frame > 0 and ($by_frame | get -o ($r.batch_source | into string)) != null and ($by_frame | get ($r.batch_source | into string)) != $r.batch_admitted })
    let unconfigured_slots = ($pooled | where {|r| $r.slots_effective != $r.config_effective })
    let unsized = ($pooled | where {|r| $r.tile_bytes != ($r.slots_used * $r.tile_size) })
    let unasked = ($pooled | where {|r| $r.missed_blocks != ($r.admitted + $r.dropped + $r.filtered) })
    [
        (if ($untiled | is-empty) { null } else { $"($untiled | length) frames without a tile record" }),
        (if ($unstored | is-empty) { null } else { $"($unstored | length) frames without a storage record" }),
        (if ($unconfigured | is-empty) { null } else { $"($unconfigured | length) frames with no configuration of the tile pool in force" }),
        (if ($overfull | is-empty) { null } else { $"($overfull | length) frames whose slots in use or BUILDING slots pass the effective slots" }),
        (if ($beyond | is-empty) { null } else { $"($beyond | length) frames whose effective slots pass the physical" }),
        (if ($overbuilt | is-empty) { null } else { $"($overbuilt | length) frames that built or evicted past the effective slots" }),
        (if ($unbuilt | is-empty) { null } else { $"($unbuilt | length) frames with more BUILDING slots than slots in use" }),
        (if ($overtime | is-empty) { null } else { $"($overtime | length) frames whose construction passes their boundary's time" }),
        (if ($overmerged | is-empty) { null } else { $"($overmerged | length) frames that merged past their batch's admitted requests" }),
        (if ($overspent | is-empty) { null } else { $"($overspent | length) frames that merged and left unprocessed past their batch's admitted requests" }),
        (if ($unsourced | is-empty) { null } else { $"($unsourced | length) frames whose batch is not the frame before's" }),
        (if ($unsentinel | is-empty) { null } else { $"($unsentinel | length) first boundaries whose sentinel batch holds requests" }),
        (if ($overmemory | is-empty) { null } else { $"($overmemory | length) frames whose memory in use passes TILE_MEMORY or its high-water, or whose high-water passes TILE_MEMORY" }),
        (if ($falling | is-empty) { null } else { $"($falling | length) frames whose memory's or tiles' high-water fell" }),
        (if ($unbatched | is-empty) { null } else { $"($unbatched | length) frames whose batch's admitted requests are not its source frame's admissions" }),
        (if ($unconfigured_slots | is-empty) { null } else { $"($unconfigured_slots | length) frames whose effective slots are not their configuration's" }),
        (if ($unsized | is-empty) { null } else { $"($unsized | length) frames whose tile bytes are not their slots in use's" }),
        (if ($unasked | is-empty) { null } else { $"($unasked | length) frames whose blocks drawn without their tiles are not their requests admitted, dropped, and filtered" }),
    ]
}

# Every frame from 0 to `last` as a row: its leg, state, and records' columns
def rows-of [s: record, legs: list<any>, last: int, schema: oneof<int, nothing>]: nothing -> list<any> {
    let names = ($legs | get name)
    let reach = ($legs | enumerate | each {|e| $legs | first ($e.index + 1) | each {|l| $l.places | length } | math sum })
    let phases = (stream phases-of $schema)
    let parts = (stream parts-of $schema)
    let at = ($schema | default 1)
    mut rows = []
    mut previous_flip: any = null
    for e in ($s.states | first ($last + 1) | enumerate) {
        let st = $e.item
        let leg_at = ($reach | enumerate | where {|r| $r.item >= $st.placed } | get -o 0.index | default (($names | length) - 1))
        let entry = (if $e.index == 0 { true } else { ($s.states | get ($e.index - 1) | get placed) != $st.placed })
        let f = ($s.frames | get -o $st.frame)
        let d = ($s.draws | get -o $st.frame)
        let p = (if $at >= 2 { $s.presents | get -o $st.frame } else { null })
        let k = (if $at >= 3 { $s.packets | get -o $st.frame } else { null })
        let t = (if $at >= 5 { $s.tiles | get -o $st.frame } else { null })
        let o = (if $at >= 5 { $s.storages | get -o $st.frame } else { null })
        let governing = (if $at >= 5 { $s.configs | where {|x| $x.from <= $st.frame } } else { [] })
        let pool = ((if $t == null { tileless } else { $t | reject frame schema })
            | merge (if $o == null { storageless } else { $o | reject frame schema })
            | merge (if ($governing | is-empty) { configless } else { $governing | last | reject schema arrival_states arrival_frames }))
        let h = (if $at >= 6 { $s.harts | get -o $st.frame } else { null })
        let masks = (if $h == null { hartsless } else { $h | reject frame schema })
        let rc = (if $at >= 7 { $s.receipts | get -o $st.frame } else { null })
        let receipt = (if $rc == null { receiptless } else { { receipt_stamp: $rc.stamp, receipt_tick: $rc.tick, ordinal: $rc.ordinal, first_ordinal: $rc.first_ordinal } })
        let base = {
            frame: $st.frame, leg: ($names | get $leg_at), entry: $entry, sector: $st.sector,
            x: $st.x, y: $st.y, z: $st.z, yaw: $st.yaw, pitch: $st.pitch, roll: $st.roll,
            draw_us: $st.draw_us, game_us: $st.game_us,
        }
        if $f == null or $d == null {
            $rows = ($rows | append ($base | merge (clockless) | merge $pool | merge $masks | merge $receipt))
        } else {
            let presented = ($f.flip_status == $FLIP_PRESENTED)
            let interval = (if $presented and $previous_flip != null { $f.flip_done_us - $previous_flip } else { null })
            if $presented { $previous_flip = $f.flip_done_us }
            let shown = (if $p == null { presentationless } else { {
                cadence: $p.cadence, simulation_us: $p.simulation_us, next_start_us: $p.next_start_us,
                wait_us: $p.wait_us, pacing_us: $p.pacing_us, wakes: $p.wakes, wait_presses: $p.wait_presses,
                flip_attempts: $p.flip_attempts, refusals: $p.refusals,
                submission_age_us: (if $presented { $f.flip_done_us - $p.simulation_us } else { null }),
                residual_us: ($p.next_start_us - $f.start_us - ($f.critical_us + $p.wait_us + $f.await_us)),
            } })
            let timed = ($f | upsert pacing_us ($shown.pacing_us | default 0))
            let packed = (if $k == null { packetless } else { {
                preparation_us: $k.preparation_us, raster_us: $k.raster_us, commands: $k.commands, flushes: $k.flushes,
                invalidated: $k.invalidated, packet_bytes: $k.packet_bytes, snapshot: $k.snapshot,
                packet_residual_us: ($f.draw_us - $k.preparation_us - $k.raster_us),
                workers: $k.workers, grain: $k.grain, slowest_us: $k.slowest_us, busy_us: $k.busy_us,
                dispatch_us: $k.dispatch_us, barrier_us: $k.barrier_us,
            } })
            let drawn = ($d | upsert raster_us ($packed.raster_us | default 0))
            $rows = ($rows | append ($base | merge {
                start_us: $f.start_us, critical_us: $f.critical_us, hud_us: $f.hud_us, mix_us: $f.mix_us,
                flip_us: $f.flip_us, report_us: $f.report_us, await_us: $f.await_us, flip_done_us: $f.flip_done_us,
                flip_status: $f.flip_status, completion_interval_us: $interval, acceptance_interval_us: null,
                latency_us: ($f.flip_done_us - $f.start_us),
                unattributed_us: ($f.critical_us - ($phases | each {|ph| $timed | get $ph } | math sum)),
                clear_us: $d.clear_us, portals_us: $d.portals_us, planes_us: $d.planes_us, walls_us: $d.walls_us,
                sprites_us: $d.sprites_us, tiles_us: $d.tiles_us,
                parts_unattributed_us: ($f.draw_us - ($parts | each {|pt| $drawn | get $pt } | math sum)),
                tiles_built: $d.tiles_built, tile_resets: $d.tile_resets, tiled_pixels: $d.tiled_pixels,
                lit_pixels: $d.lit_pixels, fallback_pixels: ($d.lit_pixels - $d.tiled_pixels),
                tile_bytes: $d.tile_bytes, tile_peak: $d.tile_peak, spans: $d.spans, spans_over: ($d.spans > $SPAN_RECORDS),
                over: ($f.critical_us >= $CEILING_US),
                aligned: ($f.draw_us == $st.draw_us and $f.game_us == $st.game_us),
            } | merge $shown | merge $packed | merge $pool | merge $masks | merge $receipt))
        }
    }
    $rows
}

# A row's receipt columns, all null, below schema 7 or without its record
def receiptless []: nothing -> record {
    [receipt_stamp receipt_tick ordinal first_ordinal]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's harts masks, all null, below schema 6 or without its record
def hartsless []: nothing -> record {
    [online floor grant claimed started active reported]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's clock columns, all null, presentation's and packets' among them
def clockless []: nothing -> record {
    [start_us critical_us hud_us mix_us flip_us report_us await_us flip_done_us flip_status completion_interval_us acceptance_interval_us latency_us unattributed_us clear_us portals_us planes_us walls_us sprites_us tiles_us parts_unattributed_us tiles_built tile_resets tiled_pixels lit_pixels fallback_pixels tile_bytes tile_peak spans spans_over over aligned]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
    | merge (presentationless)
    | merge (packetless)
}

# A row's presentation columns, all null, below schema 2
def presentationless []: nothing -> record {
    [cadence simulation_us next_start_us wait_us pacing_us wakes wait_presses flip_attempts refusals submission_age_us residual_us]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's packet columns, workers' among them, all null, below schema 3
def packetless []: nothing -> record {
    [preparation_us raster_us commands flushes invalidated packet_bytes snapshot packet_residual_us workers grain slowest_us busy_us dispatch_us barrier_us]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's tile record columns, all null, below schema 5 or without one
def tileless []: nothing -> record {
    [admitted dropped filtered batch_source batch_admitted merged unprocessed evicted build_us overrun_us hit_blocks straddling_blocks missed_blocks]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's storage record columns, all null, below schema 5 or without one
def storageless []: nothing -> record {
    [slots_used slots_effective building ring_fill requesting merge_entries memory memory_peak]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A row's configuration columns, all null, below schema 5 or none in force
def configless []: nothing -> record {
    [merge_us from tile_shift tile_size slots config_effective quota allowance_us config_flags guarantee ring recent directory_bytes tile_memory]
    | reduce --fold {} {|column, acc| $acc | insert $column null }
}

# A list's count, least, median, 95th, 99th, and greatest by nearest rank
export def stats [values: list<any>]: nothing -> record {
    let v = ($values | compact)
    let n = ($v | length)
    if $n == 0 { return { count: 0, min: null, median: null, p95: null, p99: null, max: null } }
    let s = ($v | sort)
    let rank = {|q: float| $s | get ((($q * $n) | math ceil) - 1) }
    { count: $n, min: ($s | first), median: (do $rank 0.5), p95: (if $n >= 20 { do $rank 0.95 } else { null }), p99: (if $n >= 100 { do $rank 0.99 } else { null }), max: ($s | last) }
}

# A list's sum with nulls dropped, 0 for no values
export def total [values: list<any>]: nothing -> int {
    let v = ($values | compact)
    if ($v | is-empty) { 0 } else { $v | math sum }
}

# A leg's frames summed up: counts, phases, flips, parts, pool, workers
def leg-summary [name: string, rows: list<any>, period_us: number]: nothing -> record {
    let clocked = ($rows | where {|r| $r.critical_us != null })
    let base = { leg: $name, frames: ($rows | length), entries: ($rows | where entry | length), draw: (stats ($rows | get draw_us)), game: (stats ($rows | get game_us)) }
    if ($clocked | is-empty) { return $base }
    let fast = ($clocked | where {|r| $r.critical_us < $period_us })
    let held = ($clocked | get packet_bytes | compact)
    $base | merge {
        over: ($clocked | where {|r| $r.over } | length),
        fast: ($fast | length),
        fast_waited: ($fast | where {|r| ($r.wait_us | default 0) > 0 } | length),
        wait: (stats ($clocked | get wait_us)),
        pacing: (stats ($clocked | get pacing_us)),
        submission_age: (stats ($clocked | get submission_age_us)),
        wakes: (total ($clocked | get wakes)),
        wait_presses: (total ($clocked | get wait_presses)),
        attempts: (total ($clocked | get flip_attempts)),
        refusals: (total ($clocked | get refusals)),
        critical: (stats ($clocked | get critical_us)),
        hud: (stats ($clocked | get hud_us)),
        mix: (stats ($clocked | get mix_us)),
        flip: (stats ($clocked | get flip_us)),
        report: (stats ($clocked | get report_us)),
        await: (stats ($clocked | get await_us)),
        flips_early: ($clocked | where {|r| $r.flip_status == $FLIP_EARLY } | length),
        flips_failed: ($clocked | where {|r| $r.flip_status > $FLIP_EARLY } | length),
        completion_interval: (stats ($clocked | get completion_interval_us)),
        acceptance_interval: (stats ($clocked | get acceptance_interval_us)),
        latency: (stats ($clocked | get latency_us)),
        unattributed: (stats ($clocked | get unattributed_us)),
        parts_unattributed: (stats ($clocked | get parts_unattributed_us)),
        clear: (stats ($clocked | get clear_us)),
        portals: (stats ($clocked | get portals_us)),
        planes: (stats ($clocked | get planes_us)),
        walls: (stats ($clocked | get walls_us)),
        sprites: (stats ($clocked | get sprites_us)),
        tiles: (stats ($clocked | get tiles_us)),
        tiles_built: (total ($clocked | get tiles_built)),
        building_frames: ($clocked | where {|r| $r.tiles_built > 0 } | length),
        tiled_pixels: (total ($clocked | get tiled_pixels)),
        fallback_pixels: (total ($clocked | get fallback_pixels)),
        tile_bytes_max: ($clocked | get tile_bytes | math max),
        tile_peak: ($clocked | get tile_peak | math max),
        tile_resets: ($clocked | get tile_resets | math max),
        spans_max: ($clocked | get spans | math max),
        spans_over: ($clocked | where {|r| $r.spans_over } | length),
        misaligned: ($clocked | where {|r| not $r.aligned } | length),
        preparation: (stats ($clocked | get preparation_us)),
        raster: (stats ($clocked | get raster_us)),
        commands: (stats ($clocked | get commands)),
        flushes: (total ($clocked | get flushes)),
        invalidated: (total ($clocked | get invalidated)),
        packet_bytes_max: (if ($held | is-empty) { null } else { $held | math max }),
        workers: ($clocked | get workers | compact | uniq | sort),
        grains: ($clocked | get grain | compact | uniq | sort),
        grants: ($clocked | get grant | compact | uniq | sort),
        actives: ($clocked | get active | compact | uniq | sort),
        slowest: (stats ($clocked | get slowest_us)),
        busy: (stats ($clocked | get busy_us)),
        dispatch: (stats ($clocked | get dispatch_us)),
        barrier: (stats ($clocked | get barrier_us)),
        admitted: (total ($clocked | get admitted)),
        dropped: (total ($clocked | get dropped)),
        filtered: (total ($clocked | get filtered)),
        merged: (total ($clocked | get merged)),
        unprocessed: (total ($clocked | get unprocessed)),
        evicted: (total ($clocked | get evicted)),
        build: (stats ($clocked | get build_us)),
        overrun: (stats ($clocked | get overrun_us)),
        hit_blocks: (total ($clocked | get hit_blocks)),
        straddling_blocks: (total ($clocked | get straddling_blocks)),
        missed_blocks: (total ($clocked | get missed_blocks)),
        slots_used_max: (greatest ($clocked | get slots_used)),
        ring_fill_max: (greatest ($clocked | get ring_fill)),
        memory_peak: (greatest ($clocked | get memory_peak)),
    }
}

# A list's greatest value with nulls dropped, null for none
def greatest [values: list<any>]: nothing -> any {
    let v = ($values | compact)
    if ($v | is-empty) { null } else { $v | math max }
}

# The unexplained phase outliers in frames no placement opened
def outliers [rows: list<any>, schema: oneof<int, nothing>]: nothing -> list<any> {
    let clocked = ($rows | where {|r| $r.critical_us != null })
    let watched = (stream phases-of $schema)
    $clocked | get leg | uniq | each {|leg|
        let these = ($clocked | where leg == $leg)
        let medians = ($watched | append "tiles_us" | reduce --fold {} {|p, acc| $acc | insert $p ((stats ($these | get $p)).median | default 0) })
        $these | where {|r| not $r.entry } | each {|r|
            let phases = ($watched | where {|p| let v = ($r | get $p | default 0); let m = ($medians | get $p); $v > ($OUTLIER_RATIO * $m) and ($v - $m) > $OUTLIER_US })
            let tiles_held = ($r.tiles_us <= (2 * ([($medians | get tiles_us) 100] | math max)))
            if ($phases | is-empty) or (not $tiles_held) { null } else {
                { frame: $r.frame, leg: $leg, phases: ($phases | each {|p| { phase: $p, us: ($r | get $p), median: ($medians | get $p) } }), critical_us: $r.critical_us }
            }
        } | compact
    } | flatten
}

# The play's outcomes in the window: rounds, android events, strikes, pickups
def outcomes-of [events: list<any>, rows: list<any>, last: int]: nothing -> record {
    let inside = ($events | where {|e| $e.frame <= $last })
    let rounds = ($inside | where kind == 2 | each {|e| $MET | get -o ($e.fields | get 0) | default "unknown" } | uniq --count | each {|c| { met: $c.value, count: $c.count } })
    let androids = ($inside | where kind == 3 | each {|e| $ANDROID_EVENTS | get -o ($e.fields | get 0) | default "unknown" } | uniq --count | each {|c| { event: $c.value, count: $c.count } })
    {
        rounds: $rounds,
        androids: $androids,
        struck: ($inside | where kind == 4 | length),
        pickups: ($inside | where kind == 5 | length),
        sectors: ($rows | get leg | uniq | each {|leg| { leg: $leg, sectors: ($rows | where leg == $leg | get sector | uniq) } }),
    }
}
