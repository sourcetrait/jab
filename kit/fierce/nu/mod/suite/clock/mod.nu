use (path self ../../../../../../nu/mod/build)
use (path self ../../../../../../nu/mod/launch)
use (path self ../../../../../../nu/mod/present)
use (path self ../../console)
use (path self ../../frame)
use (path self ../../map)
use (path self ../../gauge/measure)
use (path self ../../picture)
use (path self ../../pose)
use (path self ../../gauge/stream)
use (path self ../../tree)
use std/assert
use (path self ../../console) [CLOCK_CADENCE CLOCK_SEED CLOCK_SEED_AT GRAIN_DEFAULT RECEIPT_NONCE]
use (path self ../../frame) [WORKERS_STARTED]
use (path self ../../gauge/measure/presentation) [LAUNCHABLE]
use (path self ../../gauge/stream) [CLOCK_SCHEMA]

# The kernel's source of the frame rule's tolerance, FRAME_EPS
const TIMER = path self ../../../../../../kernel/src/timer.S

# The kernel's TICK: the period at the cap of 60 in the guest clock's ticks
const TICK = (10000000 // 60)

# The walk's bound in microseconds on a frame's next start less its parts
const CLOCK_RESIDUAL = 4

# The period at the cap of 60, in microseconds
const CADENCE_PERIOD = (1000000 / 60)

# The S frame's command byte as a console record carries it
const CONSOLE_S = 83

# The first frames a sustained stage sets aside
const CADENCE_SKIP = 5

# The fast stage from 1.5 s: a 4 ms standing stall, a 500 us consume spin
const SCHEDULE_FAST = { at: 1500ms, stall: 4000, spin: 500 }

# The ten trigger reports' times from 1.8 s, 410 ms apart, across the period
const SCHEDULE_TRIGGERS = [1800ms 2210ms 2620ms 3030ms 3440ms 3850ms 4260ms 4670ms 5080ms 5490ms]

# When the frame whose flip is tried before its wait is asked
const SCHEDULE_FORCED = 5900ms

# The one-off stall: at 6.3 s, 38000 us on one frame
const SCHEDULE_ONCE = { at: 6300ms, stall: 38000 }

# The slow stage from 7 s: a 25000 us standing stall
const SCHEDULE_SLOW = { at: 7000ms, stall: 25000 }

# When the schedule's E closes its measurement
const SCHEDULE_END = 9000ms

# The wakes every frame stays under
const SCHEDULE_WAKES = 8

# MotionByTime's placement on the still bay's east side
const MOTION_POSE = { name: "motion", x: 28.0, y: 2.5, z: 1.6, yaw: 90, pitch: 0 }

# When MotionByTime places the eye and starts its standing stall
const MOTION_AT = 1500ms

# MotionByTime's standing stall, in microseconds
const MOTION_STALL = 25000

# When MotionByTime's stick is held forward and when it is released
const MOTION_STICK = { from: 2000ms, to: 5000ms }

# When MotionByTime's E closes its measurement
const MOTION_END = 5500ms

# The body's speed MotionByTime expects, in metres a second
const MOTION_SPEED = 4.0

# The metres from every wall a frame must keep to be measured
const MOTION_CLEAR = 1.0

# The program's cadence held on CadenceSchedule and MotionByTime
export def cadence-holds [kernel: path, image: path, out: path, set: string, game: path]: nothing -> nothing {
    let dir = ($out | path join "cadence")
    mkdir $dir
    let render_1_disk = (tree romfs (build program-shard $game "asset" | path join "render_1") ($dir | path join "render_1.romfs"))
    let still_tree = (tree variant (open ($game | path join "content" "map" "render_0.nuon")) "render_0_still" [android] ($dir | path join "still") $game)
    let still_disk = (tree romfs $still_tree ($dir | path join "still.romfs"))
    let still_read = (map read ($still_tree | path join "map" "render_0_still.jabfps.map"))
    let triggers = ($dir | path join "triggers.nuon")
    $SCHEDULE_TRIGGERS | each {|at| [{ at: $at, type: 1, code: 313, value: 1 } { at: $at, type: 1, code: 313, value: 0 }] } | flatten | to nuon | save --raw -f $triggers
    let stick = ($dir | path join "stick.nuon")
    [{ at: $MOTION_STICK.from, type: 3, code: 1, value: 0 } { at: $MOTION_STICK.to, type: 3, code: 1, value: 127 }] | to nuon | save --raw -f $stick
    let p = $CADENCE_PERIOD
    let eps = (frame-eps)
    for cadence in $LAUNCHABLE {
        let says = $"on the schedule at cadence ($cadence)"
        let sends = ([
            { at: $CLOCK_SEED_AT, bytes: (console seed $CLOCK_SEED) }
            { at: $CLOCK_SEED_AT, bytes: (console cadence $cadence) }
            { at: $SCHEDULE_FAST.at, bytes: (console stall true $SCHEDULE_FAST.stall 0 false $SCHEDULE_FAST.spin) }
            { at: $SCHEDULE_FORCED, bytes: (console stall true $SCHEDULE_FAST.stall 0 true $SCHEDULE_FAST.spin) }
            { at: $SCHEDULE_ONCE.at, bytes: (console stall true $SCHEDULE_FAST.stall $SCHEDULE_ONCE.stall false $SCHEDULE_FAST.spin) }
            { at: $SCHEDULE_SLOW.at, bytes: (console stall true $SCHEDULE_SLOW.stall 0 false $SCHEDULE_FAST.spin) }
            { at: $SCHEDULE_END, bytes: (pose command-frame "E") }
        ] | sort-by at)
        let run = (launch --kernel $kernel --image $image --out ($dir | path join $"schedule_($cadence)") --set $set --sound --api --pad $triggers --disk $render_1_disk --serial "fps" --send $sends --capture ($SCHEDULE_END + 1sec) --seconds 11)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest ($says)"
        let m = (measure $run.api [{ name: "schedule", places: [], pad: [] }] --eps $eps)
        assert ($m.complete and $m.valid and $m.schema == $CLOCK_SCHEMA) $"the window complete and valid at schema ($CLOCK_SCHEMA) ($says): ($m.problems) ($m.invalid)"
        assert equal $m.cadences [$cadence] $"every frame presented at cadence ($cadence) ($says)"
        rule-holds $m $eps $says
        let s = (frame answered $run.api $CONSOLE_S)
        assert equal ($s | length) 4 $"the four S frames answered in the window ($says): ($s)"
        let rows = (submitted $m.rows)
        let row = {|f: int| $rows | where frame == $f | get 0 }
        let fast = ($rows | where {|r| $r.frame >= ($s.0 + $CADENCE_SKIP) and $r.frame < $s.1 })
        let slow = ($rows | where {|r| $r.frame >= ($s.3 + $CADENCE_SKIP) })

        let interval = ($fast | get submit_interval_us | compact | math median)
        assert ((($interval - $p) | math abs) <= 500) $"the fast stage presents every period ($says): ($interval) us"
        let age = ($fast | get submission_age_us | compact | math median)
        assert ($age > 14000) $"the fast stage's submission age near a period ($says): ($age) us"
        let wait = ($fast | get wait_us | math median)
        assert ($wait > 9000) $"the fast stage waits for the tick ($says): ($wait) us"
        let woken = ($fast | where {|r| $r.wakes > 0 })
        let spilled = ($woken | where {|r| $r.pacing_us < ($r.wakes * $SCHEDULE_FAST.spin) or $r.unattributed_us < 0 or $r.unattributed_us > 1000 })
        let spilled_says = $"every frame with wakes holds the consume's spin in its pacing and its critical path ($says): ($spilled | select frame wakes pacing_us wait_us unattributed_us | first 3)"
        assert ($spilled | is-empty) $spilled_says

        let forced = (do $row $s.1)
        let others = ($rows | where {|r| $r.frame != $s.1 and $r.flip_attempts != 1 })
        assert ($others | is-empty) $"every other frame tries its flip once ($says): ($others | select frame flip_attempts refusals | first 3)"
        let tried = ($forced.flip_attempts == 2 and $forced.refusals == 1 and $forced.flip_status == 0)
        assert $tried $"the forced frame tried before its wait, refused once, then presented ($says): ($forced | select frame flip_attempts refusals flip_status)"
        assert ((($forced.submit_interval_us - $p) | math abs) <= 1000) $"the forced frame presents on the tick ($says): ($forced.submit_interval_us) us"

        let once = $SCHEDULE_ONCE.stall
        let stalled = (do $row $s.2)
        assert ($stalled.draw_us >= $once and $stalled.draw_us <= ($once + 1000)) $"the stalled frame's drawing its ($once / 1000) ms stall ($says): ($stalled.draw_us) us"
        let after = (0..2 | each {|k| (do $row ($s.2 + $k)).submit_interval_us })
        let recovered = ($after.0 >= $once and $after.0 <= ($once + 7000) and $after.1 >= ($p - 500) and $after.1 <= ($p + 6000) and ((($after.2 - $p) | math abs) <= 1000))
        assert $recovered $"the stall's intervals ($says): ($after) us"

        let slow_interval = ($slow | get submit_interval_us | compact | math median)
        assert ($slow_interval < 28000) $"the slow stage presents as soon as ready ($says): ($slow_interval) us"
        let waited = ($slow | where {|r| $r.wait_us > 0 })
        assert ($waited | is-empty) $"no frame of the slow stage waits ($says): ($waited | select frame wait_us | first 3)"

        let rounds = (picture records $run.api | where kind == 2 | length)
        assert equal $rounds 10 $"ten rounds from ten trigger reports ($says)"
        let presses = ($rows | get wait_presses | math sum)
        assert ($presses >= 1) $"presses taken in waits ($says): ($presses)"
        let wakes = ($rows | get wakes | math max)
        assert ($wakes < $SCHEDULE_WAKES) $"under ($SCHEDULE_WAKES) wakes in any frame ($says): ($wakes)"
        print $"fps: the schedule at cadence ($cadence): ($m.frames) frames; the fast stage's interval ($interval) us and age ($age) us; the stall's intervals ($after) us; the slow stage's ($slow_interval) us"
    }
    for cadence in $LAUNCHABLE {
        let says = $"walking at cadence ($cadence)"
        let sends = ([
            { at: $CLOCK_SEED_AT, bytes: (console seed $CLOCK_SEED) }
            { at: $CLOCK_SEED_AT, bytes: (console cadence $cadence) }
            { at: $MOTION_AT, bytes: (pose pose-frame $MOTION_POSE) }
            { at: $MOTION_AT, bytes: (console stall true $MOTION_STALL 0 false 0) }
            { at: $MOTION_END, bytes: (pose command-frame "E") }
        ] | sort-by at)
        let run = (launch --kernel $kernel --image $image --out ($dir | path join $"motion_($cadence)") --set $set --sound --api --pad $stick --disk $still_disk --serial "fps" --send $sends --capture ($MOTION_END + 1sec) --seconds 7)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest ($says)"
        let m = (measure $run.api [{ name: "motion", places: [$MOTION_POSE], pad: [] }])
        assert ($m.complete and $m.valid and $m.schema == $CLOCK_SCHEMA) $"the window complete and valid at schema ($CLOCK_SCHEMA) ($says): ($m.problems) ($m.invalid)"
        let moved = ($m.rows | window 2 | where {|w|
            let step = (((($w.1.x - $w.0.x) ** 2) + (($w.1.y - $w.0.y) ** 2)) | math sqrt)
            $step > 0.001 and $step < 0.5
        } | each {|w| $w.1 })
        let clear = ($moved | where {|r| $r.sector >= 0 and (tree wall-clearance $still_read $r.sector $r.x $r.y) >= $MOTION_CLEAR })
        assert (($clear | length) >= 2) $"frames that moved clear of the walls ($says): ($clear | length) of ($moved | length)"
        let first = ($clear | first)
        let last = ($clear | last)
        let seconds = (($last.simulation_us - $first.simulation_us) / 1000000)
        assert ($seconds >= 2.0) $"the walk measured over at least 2 s ($says): ($seconds) s"
        let metres = (((($last.x - $first.x) ** 2) + (($last.y - $first.y) ** 2)) | math sqrt)
        let speed = ($metres / $seconds)
        assert ((($speed - $MOTION_SPEED) | math abs) <= ($MOTION_SPEED * 0.02)) $"the body walks 4 m/s by the clock ($says): ($speed) m/s over ($seconds) s"
        print $"fps: the walk at cadence ($cadence): ($speed) m/s over ($seconds) s, ($clear | length) frames, the completion interval's median ($m.rows | get completion_interval_us | compact | math median) us"
    }
}

# The frame rule's on-time tolerance as timer.S sets it, in ticks
def frame-eps []: nothing -> int {
    open --raw $TIMER | decode | parse --regex '\.set FRAME_EPS, (?P<eps>\d+)' | get 0.eps | into int
}

# The frame rule on a window's receipts, and K at eps over every acceptance
def rule-holds [m: record, eps: int, says: string]: nothing -> nothing {
    let presented = ($m.rows | where {|r| $r.flip_status == 0 })
    let steps = ($presented | window 2 | each {|w|
        let late = ($w.0.receipt_stamp - $w.0.receipt_tick)
        let next = (if $late < $eps { $w.0.receipt_tick + $TICK } else { $w.0.receipt_stamp + $TICK })
        let gap = ($w.1.receipt_tick - $next)
        { frame: $w.1.frame, late: $late, gap: $gap, periods: ($gap // $TICK), off: ($gap mod $TICK) }
    })
    let off = ($steps | where {|x| $x.off != 0 or $x.periods != 0 })
    assert ($off | is-empty) $"each presented flip judged against the rule's tick from the flip before it, exactly, at eps ($eps) ($says): ($off | first 3)"
    assert equal $m.contract.k_violations 0 $"K at eps ($eps) over every acceptance ($says): ($m.contract.k_first | first 3)"
}

# Rows each with the interval since the last presented flip's call start
def submitted [rows: list<any>]: nothing -> list<any> {
    mut previous: any = null
    mut out = []
    for r in $rows {
        let start = (if $r.flip_status == 0 { $r.flip_done_us - $r.flip_us } else { null })
        let interval = (if $start == null or $previous == null { null } else { $start - $previous })
        if $start != null { $previous = $start }
        $out = ($out | append ($r | insert submit_interval_us $interval))
    }
    $out
}

# Receipts on Render One: the load record and its bounds, ordinals in sequence
export def receipts [context: record, records: record]: nothing -> record {
    let render_1_run = $records."render_one launched".render_1_run
    let r1 = (stream $render_1_run.api)
    assert equal ($r1.loads | length) 1 $"render_1_receipts: one load record: ($r1.loads | length)"
    let r1_load = ($r1.loads | first)
    assert equal [$r1_load.arrival_states $r1_load.title_ordinal $r1_load.clear_ordinal $r1_load.nonce] [0 2 3 $RECEIPT_NONCE] $"render_1_receipts: the load record before the first state, ordinals 2 and 3, the I's nonce: ($r1_load)"
    assert equal ($r1.bounds | length) 1 $"render_1_receipts: one bounds record: ($r1.bounds | length)"
    let b = ($r1.bounds | first)
    assert ($b.arrival_states == 0 and $b.arrival_loads == 1 and $b.schema == $CLOCK_SCHEMA) $"render_1_receipts: the bounds record after the load record, before the first state, at schema ($CLOCK_SCHEMA): ($b)"
    let ordered = ($b.origin <= $b.title_start and $b.title_start <= $r1_load.title_stamp and $r1_load.title_stamp <= $b.title_end and $b.title_end < $b.clear_start and $b.clear_start <= $r1_load.clear_stamp and $r1_load.clear_stamp <= $b.clear_end)
    assert $ordered $"render_1_receipts: each load decision inside its call, the calls in order after the origin: ($b), the title's at ($r1_load.title_stamp), the cleared screen's at ($r1_load.clear_stamp)"
    let r1_frames = ($r1.frames | length)
    assert (($r1.receipts | length) == $r1_frames and $r1_frames > 10) $"render_1_receipts: a receipt a frame: ($r1.receipts | length) for ($r1_frames)"
    let r1_rows = ($r1.frames | zip $r1.receipts | each {|p| { frame: $p.0.frame, presented: ($p.0.flip_status == 0), ordinal: $p.1.ordinal, stamp: $p.1.stamp, tick: $p.1.tick, start: $p.1.call_start, end: $p.1.call_end } })
    let r1_broken = (present ordinal-violations 3 ($r1_rows | select presented ordinal))
    assert equal $r1_broken [] $"render_1_receipts: the presented frames' ordinals consecutive from 4: ($r1_broken | first 3)"
    let r1_presented = ($r1_rows | where presented)
    assert ($r1_presented | all {|r| $r.stamp >= $r.tick }) "render_1_receipts: each presented frame's decision at or past its tick"
    let outside = ($r1_presented | where {|r| $r.stamp < $r.start or $r.stamp > $r.end })
    assert ($outside | is-empty) $"render_1_receipts: each presented frame's decision inside its final attempt's recorded call: ($outside | first 3)"
    {}
}

# The walk's clock: seeded, complete, valid at the schema, frames balanced
export def walk [context: record, records: record]: nothing -> record {
    let render_0_walk = $records."render_zero walk".render_0_walk
    let render_0_starts = $records."render_zero walk".render_0_starts
    let walk_clock = (measure $render_0_walk.api [{ name: "walk", places: $render_0_starts, pad: [] }])
    assert $walk_clock.seeded "the walk's seed answered before its first frame"
    assert ($walk_clock.cadence_set and (not $walk_clock.late_cadence)) "the walk's cadence asked before its first frame, once"
    assert $walk_clock.complete $"the walk's measurement complete: ($walk_clock.problems)"
    assert equal $walk_clock.schema $CLOCK_SCHEMA $"the walk's clock records at schema ($CLOCK_SCHEMA)"
    let clock_rows = $walk_clock.rows
    assert ($clock_rows | all {|r| $r.cadence == $CLOCK_CADENCE }) $"every frame of the walk presented at cadence ($CLOCK_CADENCE): ($walk_clock.cadences)"
    let unbalanced = ($clock_rows | where {|r| $r.residual_us < 0 or $r.residual_us > $CLOCK_RESIDUAL })
    assert ($unbalanced | is-empty) $"every frame's start, critical path, wait, and await add up to its next start: ($unbalanced | select frame start_us critical_us wait_us await_us next_start_us residual_us | first 3)"
    let broken = ($clock_rows | window 2 | where {|w| $w.0.next_start_us != $w.1.start_us })
    assert ($broken | is-empty) $"each frame's next start is the next frame's start: ($broken | first 3)"
    let unpresented = ($clock_rows | where {|r| $r.flip_status != 0 or $r.flip_attempts != ($r.refusals + 1) })
    assert ($unpresented | is-empty) $"each frame's final flip presented, its attempts its refusals and one more: ($unpresented | select frame flip_status flip_attempts refusals | first 3)"
    assert $walk_clock.valid $"the walk's measurement valid: ($walk_clock.invalid)"
    assert ($walk_clock.past_window > 0) $"the game went on past the measurement: ($walk_clock.past_window) frames"
    let outside = ($clock_rows | where {|r| $r.unattributed_us < 0 or $r.parts_unattributed_us < 0 })
    assert ($outside | is-empty) $"every phase within its frame and every part within its drawing: ($outside | first 3)"
    assert ($clock_rows | all {|r| $r.tiled_pixels <= $r.lit_pixels }) "the tiled pixels within the lit"
    assert ($clock_rows | all {|r| $r.tile_peak >= $r.tile_bytes }) "the tile pool's peak at or past what it holds"
    assert ($clock_rows | all {|r| $r.slots_used != null and $r.admitted != null }) "every frame of the walk with its tile and storage records"
    assert ($clock_rows | all {|r| $r.aligned }) "each frame record carries its state's drawing and game times"
    let unprepared = ($clock_rows | where {|r| $r.commands == null or $r.commands == 0 or $r.spans == 0 })
    assert ($unprepared | is-empty) $"each frame of the walk prepares commands and spans into its packets: ($unprepared | select frame commands spans | first 3)"
    let undrawn = ($clock_rows | where {|r| $r.workers != $WORKERS_STARTED or $r.grain != $GRAIN_DEFAULT or $r.slowest_us == 0 or $r.busy_us == 0 })
    assert ($undrawn | is-empty) $"every frame of the walk drawn by the ($WORKERS_STARTED) workers started in bands of ($GRAIN_DEFAULT) rows, a slowest worker and busy time recorded:($undrawn | select frame workers grain slowest_us busy_us | first 3)"
    let unmasked = ($clock_rows | where {|r| $r.grant != 6 or $r.started != 6 or $r.active != 6 or $r.reported != 6 })
    assert ($unmasked | is-empty) $"every frame of the walk on its grant, harts 1 and 2, both started and active: ($unmasked | select frame grant started active reported | first 3)"
    print $"fps: the clock over the walk: ($walk_clock.frames) frames to frame ($walk_clock.final) at schema ($walk_clock.schema), the critical path's median ($walk_clock.whole.critical.median) us, unattributed at most ($walk_clock.whole.unattributed.max) us of a frame and ($walk_clock.whole.parts_unattributed.max) us of a drawing, residual at most ($clock_rows | get residual_us | math max) us, ($walk_clock.whole.refusals) flips early; the preparation's median ($walk_clock.whole.preparation.median) us and the raster's ($walk_clock.whole.raster.median) us, ($walk_clock.whole.commands.min) to ($walk_clock.whole.commands.max) commands a frame, ($walk_clock.whole.flushes) flushes, ($walk_clock.whole.packet_bytes_max) packet bytes at most; ($walk_clock.whole.tiles_built) tiles built, ($walk_clock.whole.tile_peak) bytes of tiles at most; ($walk_clock.workers | str join ', ') workers, the slowest's median ($walk_clock.whole.slowest.median) us, dispatch ($walk_clock.whole.dispatch.median) and barrier ($walk_clock.whole.barrier.median)"
    {}
}

# The program's cadence checked on stalls, triggers, and a timed walk
export def cadences [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let game = $context.game
    cadence-holds $kernel $image $out $set $game
    {}
}
