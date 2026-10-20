use (path self ../../../../../../nu/mod/capture)
use (path self ../../../../../../nu/mod/launch)
use (path self ../../console)
use (path self ../../frame)
use (path self ../../gauge/stream)
use (path self ../../pose)
use (path self ../../tree)
use std/assert

# The peak a window must reach to be heard, sound's own
const SOUND_HEARD = 64

# The play's reports a second, the reference pad's rate
const REPORT_HZ = 125

# The play's reports, ten seconds at the reference pad's rate
const REPORTS = 1250

# The first report's time, the pad opened by the first frame's look by then
const PLAY_FROM = 2000ms

# The Z frame's time, a second past the last report so every event is taken
const END_AT = 13000ms

# The run's bound, past the exit's flush of the sound
const SECONDS = 20

# The recording's window, a coarse gap's length
const WINDOW_SECONDS = 0.05

# The windows read from the ambient's first, to the play's end less a second
const HEARD_TO = 11.0

# The axes each report moves: the left stick's two and the right stick's Z
const AXES = [0 1 2]

# The QEMU trace event of a report virtio-input dropped for want of buffers
const QUEUE_FULL = "virtio_input_queue_full"

# The pad's table: three axes a report, sweeping, REPORT_HZ reports a second
def play-table []: nothing -> table<at: duration, type: int, code: int, value: int> {
    0..<$REPORTS | each {|i|
        let at = ($PLAY_FROM + ($i * (1sec / $REPORT_HZ)))
        let t = ($i | into float)
        let x = (127 + 60 * (2 * 3.141592653589793 * $t / 250 | math sin) | math round | into int)
        let y = (87 + 30 * (2 * 3.141592653589793 * $t / 625 | math cos) | math round | into int)
        let z = (127 + 40 * (2 * 3.141592653589793 * $t / 375 | math sin) | math round | into int)
        [[at type code value]; [$at 3 ($AXES | get 0) $x] [$at 3 ($AXES | get 1) $y] [$at 3 ($AXES | get 2) $z]]
    } | flatten
}

# The frames apart a window's picks sit, a coarse read of each window
const PICK_FRAMES = 16

# A recording's 50 ms windows' peaks from its first frame, left channel, sampled
def window-peaks [wav: path]: nothing -> list<int> {
    let w = (capture wave $wav)
    let frame_bytes = ($w.channels * ($w.bits // 8))
    let per = (($w.rate * $WINDOW_SECONDS) | math round | into int)
    let windows = ($w.frames // $per)
    0..<$windows | each {|i|
        seq ($i * $per) $PICK_FRAMES (($i + 1) * $per - 1) | each {|f|
            $w.samples | bytes at ($f * $frame_bytes)..<($f * $frame_bytes + 2) | into int --endian little --signed | math abs
        } | math max
    }
}

# The pad and the sound under the default workers through ten seconds of play
export def regression [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = ($context.out | path join "service")
    let set = $context.set
    let render_0_disk = $records."render_zero launched".render_0_disk
    mkdir $out
    let table = (play-table)
    let table_file = ($out | path join "table.nuon")
    $table | to nuon --indent 2 | save --raw -f $table_file
    let sent = ($table | length)
    let end = (pose command-frame "Z")
    let run = (launch --kernel $kernel --image $image --out ($out | path join "run") --set $set --sound --api --pad $table_file --disk $render_0_disk --serial "fps" --send [{ at: $END_AT, bytes: $end }] --seconds $SECONDS --qemu ["-trace" $QUEUE_FULL])
    let events = (^$run.qemu_binary -trace help | complete | get stdout | lines | each {|l| $l | str trim })
    assert ($QUEUE_FULL in $events) $"($run.qemu_binary) lists the trace event ($QUEUE_FULL), the device's dropped reports' count"
    let qemu_text = (open --raw $run.qemu_log | decode)
    let full = ($qemu_text | lines | where {|l| $l | str contains $QUEUE_FULL } | length)
    assert equal $full 0 $"QEMU dropped no pad report for want of buffers: ($full) times"
    assert equal ($qemu_text | lines | where {|l| not ($l | str contains $QUEUE_FULL) }) [] $"QEMU has no complaint about the guest: ($qemu_text)"
    assert equal $run.status 0 $"the Z frame ended the run with 0, the kernel's exit lines written: status ($run.status), ($run.serial)"
    assert (not ($run.serial | lines | any {|l| ($l starts-with "jab: ") and ($l =~ "fault") })) $"no fault: ($run.serial)"
    let debug = ($run.debug | lines)
    let pads = ($debug | where {|l| $l starts-with "jab: pad accepted " } | each {|l| $l | parse "jab: pad accepted {accepted} taken {taken} dropped {dropped}" | get 0 | update cells {|c| $c | into int } })
    assert equal ($pads | length) 1 $"the exit's pad counts once: ($debug | where {|l| $l starts-with 'jab: pad' })"
    let pad = ($pads | get 0)
    assert equal $pad.dropped 0 $"the pad's ring lost nothing: ($pad)"
    assert equal $pad.accepted $sent $"every event the table sent into the ring: ($pad.accepted) of ($sent)"
    assert equal $pad.taken $pad.accepted $"the program took every event the ring held: ($pad)"
    let sounds = ($debug | where {|l| $l starts-with "jab: sound submitted " } | each {|l| $l | parse "jab: sound submitted {submitted} returned {returned} failed {failed} exhausted {exhausted}" | get 0 | update cells {|c| $c | into int } })
    assert equal ($sounds | length) 1 $"the exit's sound counts once: ($debug | where {|l| $l starts-with 'jab: sound' })"
    let sound = ($sounds | get 0)
    assert equal $sound.exhausted 0 $"no service found the sound's queue empty after its drain: ($sound)"
    assert equal $sound.failed 0 $"no period failed: ($sound)"
    assert ($run.sound != "") "the run recorded its sound"
    let peaks = (window-peaks $run.sound)
    let first = ($peaks | enumerate | where {|w| $w.item >= $SOUND_HEARD } | get -o 0.index)
    assert ($first != null) $"the ambient heard: ($peaks | first 40)"
    let last = (($HEARD_TO / $WINDOW_SECONDS) | math floor | into int)
    assert ($last < ($peaks | length)) $"the recording reaches ($HEARD_TO) s: ($peaks | length) windows"
    let quiet = ($peaks | enumerate | where {|w| $w.index >= $first and $w.index < $last and $w.item < $SOUND_HEARD } | get index)
    assert equal $quiet [] $"every 50 ms window heard from the ambient's first at ($first * $WINDOW_SECONDS) s to ($HEARD_TO) s"
    { service: { sent: $sent, pad: $pad, sound: $sound, queue_full: $full, heard_from: ($first * $WINDOW_SECONDS), windows: ($last - $first) } }
}

# The V frame's command byte as a console record carries it
const CONSOLE_V = 86

# When a V starts the service, the load past and the frames running
const SERVICE_AT = 2000ms

# The machine the service runs on: hart 3 its io hart beside the two graphics harts
const SERVICE_HARTS = 4

# Hart 3's mask, the service's hart on four
const IO_HART = 8

# Harts 1 and 2's mask: the graphics left on four, the grant on three
const GFX_TWO = 6

# Harts 1, 2, and 3's mask, the grant on four
const GFX_THREE = 14

# A boundary's most consumed slots, render.inc's MSG_APPLY_MAX
const APPLY_MAX = 32

# The ring's slots, render.inc's MSG_SLOTS
const SLOTS = 256

# A service record's flags: running, torn, lockstep, started, stopped
const SVC_RUNNING = 1
const SVC_TORN = 2
const SVC_LOCKSTEP = 4
const SVC_STARTED = 8
const SVC_STOPPED = 16

# The stop's answer for a forced producer, render.inc's SERVICE_FORCED
const STOPPED_FORCED = 1

# The take's refusal under the floor, render.inc's GFX_FLOOR
const GFX_FLOOR = -1

# The take refused on three harts, workers.S's line
const FLOOR_LINE = "fps: harts take refused under the floor: 1 of grant 1 2, floor 2"

# The LOCKSTEP loads: messages over quota frames, the stop's time, the plan's acceptance and drops
const LOCKSTEP_LOADS = [
    { name: "steady", total: 120, frames: 60, stop_at: 5000ms, accepted: 120, dropped: 0 }
    { name: "burst", total: 1000, frames: 6, stop_at: 4000ms, accepted: 416, dropped: 584 }
    { name: "overload", total: 18000, frames: 60, stop_at: 7000ms, accepted: 2144, dropped: 15856 }
]

# The corruption case: two quotas of 32 under LOCKSTEP, the second's sequence 40 corrupted
const CORRUPT_LOAD = { name: "corrupt", total: 64, frames: 2, corrupt: 40, stop_at: 4000ms }

# A stop mid-quota: one quota too long to finish, 200 us before each message
const CANCEL_LOAD = { name: "cancel", total: 100000, frames: 0, delay_us: 200, stop_at: 3500ms }

# A forced stop: half a second spun before each message, past WORK_STOP_TICKS
const FORCED_LOAD = { name: "forced", total: 2, frames: 0, delay_us: 500000, stop_at: 2300ms }

# The steady load's offering time bound: two messages offered, the producer woken
const STEADY_OFFERING_US = 1000

# The instructions an index's fence may stand apart from it by: address and value work
const ORDER_BETWEEN = [la li addi mv slli add andi]

# The ring's index stores and loads in service.S, each placed on purpose
const ORDER_COUNTS = [5 4]

# The service's fixtures, a SERVICE build's set alone: order, loads, corruption, stops, refusal
export def holds [context: record, records: record]: nothing -> record {
    let out = ($context.out | path join "service")
    mkdir $out
    let disk = (tree romfs ($context.trees | path join "render_0") ($out | path join "render_0.romfs"))
    let order = (order-holds $context.game)
    mut loads = {}
    for load in $LOCKSTEP_LOADS {
        $loads = ($loads | insert $load.name (lockstep-holds $context $disk $load))
    }
    { order: $order, loads: $loads, corrupt: (corrupt-holds $context $disk), cancel: (cancel-holds $context $disk), forced: (forced-holds $context $disk), refusal: (refusal-holds $context $disk) }
}

# The ring's indexes' fences read from the source: each store after fence rw, w, each load before fence r, rw
def order-holds [game: path]: nothing -> record<stores: int, loads: int> {
    let lines = (open --raw ($game | path join "src" "service.S") | decode | lines | each {|l| $l | split row "#" | first | str trim })
    let count = ($lines | length)
    let between = {|l: string| ($l == "") or ($ORDER_BETWEEN | any {|m| $l starts-with $"($m) " }) }
    mut stores = 0
    mut loads = 0
    for e in ($lines | enumerate) {
        if ($e.item starts-with "sd ") and ($e.item | str contains "LINE_INDEX(") {
            mut i = $e.index - 1
            while $i >= 0 and (do $between ($lines | get $i)) { $i -= 1 }
            let fence = (if $i >= 0 { $lines | get $i } else { "" })
            assert equal $fence "fence rw, w" $"service.S line ($e.index + 1), an index store, follows fence rw, w with only address and value work between"
            $stores += 1
        }
        if ($e.item starts-with "ld ") and ($e.item | str contains "LINE_INDEX(") {
            mut i = $e.index + 1
            while $i < $count and (do $between ($lines | get $i)) { $i += 1 }
            let fence = (if $i < $count { $lines | get $i } else { "" })
            assert equal $fence "fence r, rw" $"service.S line ($e.index + 1), an index load, precedes fence r, rw with only address and value work between"
            $loads += 1
        }
    }
    assert equal [$stores $loads] $ORDER_COUNTS "the ring's index stores and loads, each placed on purpose"
    { stores: $stores, loads: $loads }
}

# The LOCKSTEP model: each boundary's quota offered, accepted, dropped, the slots applied, the depth after
def lockstep-model [total: int, frames: int]: nothing -> list<record> {
    mut depth = 0
    mut rows = []
    mut b = 1
    loop {
        let k = $b - 2
        let q = (if $k >= 0 and $k < $frames { ($total // $frames) + (if $k < ($total mod $frames) { 1 } else { 0 }) } else { 0 })
        let accepted = ([$q ($SLOTS - $depth)] | math min)
        let held = $depth + $accepted
        let applied = ([$held $APPLY_MAX] | math min)
        $depth = $held - $applied
        $rows = ($rows | append { boundary: $b, offered: $q, accepted: $accepted, dropped: ($q - $accepted), applied: $applied, depth: $depth })
        if $k >= ($frames - 1) and $depth == 0 { break }
        $b += 1
    }
    $rows
}

# A launch with its V frames on a machine of the harts given, its records read
def service-run [context: record, disk: path, name: string, sends: list<any>, stop_at: duration, harts: int]: nothing -> record {
    let seconds = (($stop_at / 1sec | math ceil) + 3 | into int)
    let run = (launch --kernel $context.kernel --image $context.image --out ($context.out | path join "service" $name) --set $context.set --sound --api --disk $disk --serial "fps" --send ($sends | sort-by at) --seconds $seconds --harts $harts)
    assert equal (open --raw $run.qemu_log | decode) "" $"QEMU has no complaint about the guest on the service's ($name)"
    assert (not ($run.serial | lines | any {|l| ($l starts-with "jab: ") and ($l =~ "fault") })) $"no fault on the service's ($name): ($run.serial)"
    { run: $run, s: (stream $run.api), answered: (frame answered $run.api $CONSOLE_V) }
}

# Every record's packet word its boundary's, no torn read, no boundary past its 32
def witness-holds [label: string, services: list<any>]: nothing -> nothing {
    let torn = ($services | where {|v| (($v.flags // $SVC_TORN) mod 2) == 1 or $v.word != $v.last })
    assert ($torn | is-empty) $"($label): every frame's packet carried the word its boundary left, no worker reading another: ($torn | first 3)"
    let over = ($services | where {|v| ($v.applied + $v.rejected) > $APPLY_MAX })
    assert ($over | is-empty) $"($label): no boundary consumed past ($APPLY_MAX) slots: ($over | first 3)"
}

# The window's flags frame by frame: idle before the start, running to the stop, idle after
def flags-hold [label: string, services: list<any>, started: int, stopped: int, lockstep: bool]: nothing -> nothing {
    let wrong = ($services | where {|v|
        let running = (($v.flags mod 2) == 1)
        let marked_start = ((($v.flags // $SVC_STARTED) mod 2) == 1)
        let marked_stop = ((($v.flags // $SVC_STOPPED) mod 2) == 1)
        let stepped = ((($v.flags // $SVC_LOCKSTEP) mod 2) == 1)
        let inside = ($v.frame >= $started and $v.frame < $stopped)
        ($running != $inside) or ($marked_start != ($v.frame == $started)) or ($marked_stop != ($v.frame == $stopped)) or ($inside and $stepped != $lockstep)
    })
    assert ($wrong | is-empty) $"($label): idle before frame ($started), running from it to frame ($stopped), marked started and stopped at those two: ($wrong | first 3 | select frame flags)"
}

# The harts frame by frame: hart 3 claimed from the start's frame to the stop's, the three drawing otherwise
def harts-hold [label: string, s: record, started: int, stopped: int]: nothing -> nothing {
    let wrong = ($s.harts | where {|h|
        let held = ($h.frame >= $started and $h.frame < $stopped)
        [$h.grant $h.claimed $h.started] != (if $held { [$GFX_TWO $IO_HART $GFX_TWO] } else { [$GFX_THREE 0 $GFX_THREE] })
    })
    assert ($wrong | is-empty) $"($label): hart 3 under the claim from frame ($started) to ($stopped), the grant and the started harts 1 2 then, 1 2 3 otherwise: ($wrong | first 3 | select frame grant claimed started)"
}

# A closed window held: conservation, the chains, the gaps, and its counts
def window-holds [label: string, end: record, evidence: record, expected: record]: nothing -> nothing {
    assert ($end.valid and not $end.forced) $"($label): a valid handoff: ($end)"
    assert equal ($end | select offered dropped applied rejected discarded) $expected $"($label): the window's counts"
    assert equal $end.offered ($end.applied + $end.dropped + $end.rejected + $end.discarded) $"($label): offered conserved as applied, dropped, rejected, and discarded: ($end)"
    assert equal $end.last ($end.offered - 1) $"($label): the last sequence offered the count's: ($end)"
    assert equal $evidence.applied $end.expected $"($label): the applied chain the producer's expected one"
    assert equal $evidence.gaps ($end.dropped + $end.rejected + $end.discarded) $"($label): the sequences' gaps, leading, between, and trailing, the dropped, rejected, and discarded: ($evidence.gaps)"
}

# A LOCKSTEP load on four harts: every boundary's counts the model's, the window exact
def lockstep-holds [context: record, disk: path, load: record]: nothing -> record {
    let label = $"the service's ($load.name) load under LOCKSTEP"
    let model = (lockstep-model $load.total $load.frames)
    assert equal [($model | get accepted | math sum) ($model | get dropped | math sum)] [$load.accepted $load.dropped] $"($label): the model's acceptance and drops, the plan's"
    let sends = [
        { at: $SERVICE_AT, bytes: (console service true --total $load.total --frames $load.frames --lockstep) }
        { at: $load.stop_at, bytes: (console service false) }
    ]
    let r = (service-run $context $disk $load.name $sends $load.stop_at $SERVICE_HARTS)
    assert equal ($r.answered | length) 2 $"($label): the start and the stop each answered once: ($r.answered)"
    let started = ($r.answered | get 0)
    let stopped = ($r.answered | get 1)
    let start = ($r.s.service_answers | get 0)
    assert equal ($start | select status harts) { status: 0, harts: $IO_HART } $"($label): started on hart 3: ($start)"
    assert equal ($r.s.service_answers | get 1 | get status) 0 $"($label): stopped with a valid handoff"
    for row in $model {
        let v = ($r.s.services | where frame == ($started + $row.boundary) | get -o 0)
        assert ($v != null) $"($label): a service record for boundary ($row.boundary), frame ($started + $row.boundary)"
        let offered = ($model | where boundary <= $row.boundary | get offered | math sum)
        let dropped = ($model | where boundary <= $row.boundary | get dropped | math sum)
        assert equal [$v.applied $v.rejected $v.depth $v.offered $v.dropped $v.skipped] [$row.applied 0 $row.depth $offered $dropped 0] $"($label): boundary ($row.boundary), frame ($v.frame): applied, rejected, the depth after, offered, dropped, and skipped so far, the model's"
        assert equal $v.generation $start.generation $"($label): frame ($v.frame) of the window's generation"
    }
    let drained = ($started + ($model | length))
    assert ($drained < $stopped) $"($label): the model's boundaries, to frame ($drained), all before the stop's, frame ($stopped)"
    let after = ($r.s.services | where {|v| $v.frame > $drained and $v.frame < $stopped and ($v.applied != 0 or $v.depth != 0) })
    assert ($after | is-empty) $"($label): nothing left once drained: ($after | first 3)"
    witness-holds $label $r.s.services
    flags-hold $label $r.s.services $started $stopped true
    harts-hold $label $r.s $started $stopped
    assert equal ($r.s.service_ends | length) 1 $"($label): one window closed"
    let end = ($r.s.service_ends | get 0)
    let evidence = ($r.s.service_evidence | get 0)
    window-holds $label $end $evidence { offered: $load.total, dropped: $load.dropped, applied: $load.accepted, rejected: 0, discarded: 0 }
    assert equal [$end.skipped $end.corrupted $evidence.corrupted] [0 0 -1] $"($label): no quota skipped, nothing corrupted"
    assert equal $end.published $end.expected $"($label): every message published untouched"
    assert equal $r.s.service_rejects [] $"($label): nothing rejected"
    if $load.name == "steady" {
        let late = ($model | where applied > 0 | each {|row|
            let g = ($started + $row.boundary)
            let v = ($r.s.services | where frame == $g | get 0)
            let f = ($r.s.frames | where frame == $g | get 0)
            let period = ($f.start_us - ($r.s.frames | where frame == ($g - 1) | get 0.start_us))
            { frame: $g, age_us: $v.age_us, bound_us: ($period + $f.report_us + $STEADY_OFFERING_US) }
        } | where {|a| $a.age_us >= $a.bound_us })
        assert ($late | is-empty) $"($label): every message applied at the boundary after its offer, its age under the frame's period, the boundary's place in its frame, and the quota's offering: ($late | first 3)"
    }
    { started: $started, stopped: $stopped, boundaries: ($model | length), end: $end }
}

# The corruption case: its message rejected in its frame's 32, the lists equal, the window conserved
def corrupt-holds [context: record, disk: path]: nothing -> record {
    let load = $CORRUPT_LOAD
    let label = "the service's corruption case under LOCKSTEP"
    let sends = [
        { at: $SERVICE_AT, bytes: (console service true --total $load.total --frames $load.frames --lockstep --corrupt $load.corrupt) }
        { at: $load.stop_at, bytes: (console service false) }
    ]
    let r = (service-run $context $disk $load.name $sends $load.stop_at $SERVICE_HARTS)
    let started = ($r.answered | get 0)
    let stopped = ($r.answered | get 1)
    let start = ($r.s.service_answers | get 0)
    assert equal ($r.s.service_rejects | select sequence generation) [{ sequence: $load.corrupt, generation: $start.generation }] $"($label): one message rejected, the corrupted sequence: ($r.s.service_rejects)"
    let reject_frame = ($r.s.service_rejects | get 0.frame)
    let v = ($r.s.services | where frame == $reject_frame | get 0)
    assert equal [$v.applied $v.rejected] [($APPLY_MAX - 1) 1] $"($label): the rejected message counted among its frame's ($APPLY_MAX): ($v)"
    assert equal $reject_frame ($started + 3) $"($label): rejected at the second quota's boundary"
    let end = ($r.s.service_ends | get 0)
    let evidence = ($r.s.service_evidence | get 0)
    window-holds $label $end $evidence { offered: $load.total, dropped: 0, applied: ($load.total - 1), rejected: 1, discarded: 0 }
    assert equal [$end.corrupted $evidence.corrupted] [1 $load.corrupt] $"($label): the producer's corrupted list its one sequence, the rejected one"
    assert ($end.published != $end.expected) $"($label): the corrupted message in the published chain alone"
    witness-holds $label $r.s.services
    flags-hold $label $r.s.services $started $stopped true
    { rejected: $load.corrupt, frame: $reject_frame }
}

# A stop mid-quota: the cancel taken at the next message, the evidence handed over whole
def cancel-holds [context: record, disk: path]: nothing -> record {
    let load = $CANCEL_LOAD
    let label = "the service stopped mid-quota"
    let sends = [
        { at: $SERVICE_AT, bytes: (console service true --total $load.total --frames $load.frames --delay-us $load.delay_us) }
        { at: $load.stop_at, bytes: (console service false) }
    ]
    let r = (service-run $context $disk $load.name $sends $load.stop_at $SERVICE_HARTS)
    let started = ($r.answered | get 0)
    let stopped = ($r.answered | get 1)
    assert equal ($r.s.service_answers | get status) [0 0] $"($label): started, then stopped with a valid handoff"
    let end = ($r.s.service_ends | get 0)
    let evidence = ($r.s.service_evidence | get 0)
    assert ($end.valid and not $end.forced) $"($label): a valid handoff: ($end)"
    assert ($end.offered > 0 and $end.offered < $load.total) $"($label): the one quota cut short by the cancel: ($end.offered) of ($load.total) offered"
    assert equal $end.offered ($end.applied + $end.dropped + $end.rejected + $end.discarded) $"($label): offered conserved: ($end)"
    assert equal $end.discarded 0 $"($label): nothing discarded"
    assert equal $evidence.applied $end.expected $"($label): the applied chain the expected one"
    assert equal $evidence.gaps ($end.dropped + $end.rejected) $"($label): the gaps the dropped and rejected"
    assert ($end.skipped > 0) $"($label): the quotas past the first skipped while it ran, a reduced load: ($end.skipped)"
    witness-holds $label $r.s.services
    flags-hold $label $r.s.services $started $stopped false
    harts-hold $label $r.s $started $stopped
    { offered: $end.offered, applied: $end.applied, dropped: $end.dropped, skipped: $end.skipped }
}

# A forced stop: the producer interrupted, its evidence absent, the window incomplete, the hart back
def forced-holds [context: record, disk: path]: nothing -> record {
    let load = $FORCED_LOAD
    let label = "the service's forced stop"
    let sends = [
        { at: $SERVICE_AT, bytes: (console service true --total $load.total --frames $load.frames --delay-us $load.delay_us) }
        { at: $load.stop_at, bytes: (console service false) }
    ]
    let r = (service-run $context $disk $load.name $sends $load.stop_at $SERVICE_HARTS)
    let started = ($r.answered | get 0)
    let stopped = ($r.answered | get 1)
    assert equal ($r.s.service_answers | get status) [0 $STOPPED_FORCED] $"($label): started, then stopped forced"
    let end = ($r.s.service_ends | get 0)
    assert ($end.forced and not $end.valid) $"($label): forced, its accounting incomplete: ($end)"
    assert equal [$end.last $end.published $end.expected] [-1 0 0] $"($label): the last sequence and the chains unknown"
    assert equal $end.discarded ($end.offered - $end.dropped - $end.applied - $end.rejected) $"($label): what the ring held discarded: ($end)"
    flags-hold $label $r.s.services $started $stopped false
    harts-hold $label $r.s $started $stopped
    { offered: $end.offered, discarded: $end.discarded }
}

# The service refused on three harts: the take under the floor, everything held as it stood
def refusal-holds [context: record, disk: path]: nothing -> record {
    let label = "the service on three harts"
    let sends = [{ at: $SERVICE_AT, bytes: (console service true --total 2 --frames 0) }]
    let r = (service-run $context $disk "refusal" $sends $SERVICE_AT 3)
    assert equal ($r.s.service_answers | select status harts) [{ status: $GFX_FLOOR, harts: 0 }] $"($label): refused under the floor, no hart its"
    assert ($r.serial | lines | any {|l| $l == $FLOOR_LINE }) $"($label): the take's refusal on the UART: ($r.serial | lines | where {|l| $l starts-with 'fps: harts' })"
    let running = ($r.s.services | where {|v| ($v.flags mod 2) == 1 })
    assert ($running | is-empty) $"($label): no frame with the service running: ($running | first 3)"
    assert equal $r.s.service_ends [] $"($label): no window opened"
    let moved = ($r.s.harts | where {|h| [$h.grant $h.claimed $h.started] != [$GFX_TWO 0 $GFX_TWO] })
    assert ($moved | is-empty) $"($label): every frame on harts 1 2, nothing claimed: ($moved | first 3)"
    assert (($r.s.states | length) > ($r.answered | get 0) + 30) $"($label): the game playing on past the refusal: ($r.s.states | length) frames"
    { frames: ($r.s.states | length) }
}
