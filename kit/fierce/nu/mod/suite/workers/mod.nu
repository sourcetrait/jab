use (path self ../../../../../../nu/mod/launch)
use (path self ../../console)
use (path self ../../frame)
use (path self ../../gauge/measure)
use (path self ../../picture)
use (path self ../../pose)
use (path self ../../gauge/measure/screen)
use (path self ../../gauge/stream)
use std/assert
use (path self ../../console) [CONSOLE_P GRAIN_DEFAULT SPAWN_POSE]
use (path self ../../frame) [FRAME GFX_SLOTS WORKERS_STARTED]
use (path self ../../gauge/measure/validity) [SCREEN_ROWS]
use (path self ../../gauge/stream) [CLOCK_SCHEMA]

# The H frame's command byte as a console record carries it
const CONSOLE_H = 72

# The J frame's command byte as a console record carries it
const CONSOLE_J = 74

# The most workers the default draws with, render.inc's GFX_GUIDELINE
const GFX_GUIDELINE = 3

# When the picture contract's stamp goes on
const STAMP_AT = 200ms

# When the cancel cases' screen is taken
const JOB_SCREEN_AT = 3000ms

# The rows a band for the banded worker cases
const WORKER_GRAIN = 16

# The worker modes drawn against the default: workers and grain
const WORKER_MODES = [
    { workers: 0, grain: 0 }
    { workers: 1, grain: 0 }
    { workers: 2, grain: 0 }
    { workers: 2, grain: $WORKER_GRAIN }
]

# The frame line's counts every worker mode must share with the default
const WORKER_COUNTS = [spans pixels lit_spans lit_pixels rejected samples tiled commands flushes]

# When construction freezes, the view settled
const WORKER_FREEZE_AT = 2100ms

# The J frame's cases: a worker held, rounds cancelled, by grain
const JOB_CASES = [
    { name: "hart 2's worker held at a band a worker", grain: 0, delayed: 2, delay_us: 150000, cancel: false }
    { name: "hart 2's worker held at 16 rows", grain: 16, delayed: 2, delay_us: 150000, cancel: false }
    { name: "every round cancelled, hart 2's worker held, at a band a worker", grain: 0, delayed: 2, delay_us: 50000, cancel: true }
    { name: "every round cancelled at 16 rows", grain: 16, delayed: 0, delay_us: 0, cancel: true }
]

# The most of a core an idle worker's thread may use
const IDLE_RATE = 0.05

# When the idle worker's held span starts
const IDLE_AT = 2500ms

# The times the idle launches' thread readings are asked at
const IDLE_READINGS = [3sec 4sec 60sec]

# The idle cases: harts, workers asked, and the harts that must sleep
const IDLE_CASES = [
    { harts: 3, workers: 0, asleep: [1 2] }
    { harts: 3, workers: 1, asleep: [2] }
    { harts: 8, workers: 2, asleep: [3 4 5 6 7] }
    { harts: 8, workers: null, asleep: [4 5 6 7] }
]

# When the H frame takes the grant's highest hart
const TAKE_AT = 2500ms

# When a placement is read while the hart is taken
const TAKEN_AT = 2900ms

# When the H frame gives the hart back
const GIVE_AT = 3300ms

# When a placement is read after the give-back
const GIVEN_AT = 3700ms

# When the give-back runs' screen is taken
const TAKE_CAPTURE_AT = 4500ms

# The harts the take and give-back run on
const TAKE_HARTS = 4

# The program's lines for a take: worker stopped, then hart claimed
const TAKE_LINES = ["fps: workers stopped on harts 3" "fps: harts claimed 2, harts 3"]

# The program's lines for a give-back: claim released, worker started
const GIVE_LINES = ["fps: harts released 2, harts 3" "fps: workers started on harts 3"]

# The program's line refusing a take under the floor
const FLOOR_LINE = "fps: harts take refused under the floor: 1 of grant 1 2, floor 2"

# The prefixes of the program's lines on worker and hart moves
const MOVE_PREFIXES = ["fps: workers stopped" "fps: workers started" "fps: worker refused" "fps: harts claim" "fps: harts release" "fps: harts take" "fps: harts give"]

# The mask of harts 1, 2, and 3
const HARTS_THREE = 14

# The mask of harts 1 and 2
const HARTS_TWO = 6

# The mask of hart 3 alone
const HART_THREE = 8

# The machines the workers are held on: harts, boot words, grant
const WORKER_MACHINES = [
    { harts: 3, bootargs: "", started: 2, harts_of: "1 2" }
    { harts: 4, bootargs: "", started: 3, harts_of: "1 2 3" }
    { harts: 8, bootargs: "", started: 7, harts_of: "1 2 3 4 5 6 7" }
    { harts: 4, bootargs: "jab.late=2", started: 2, harts_of: "1 3" }
]

# The machines short of the reservation, each with its refusal line
const SHORT_MACHINES = [
    { harts: 2, line: "fps: harts short: 1 secondaries online for the 2 reserved" }
    { harts: 1, line: "fps: harts short: 0 secondaries online for the 2 reserved" }
]

# The exit status of a program short of its reservation
const SHORT_EXIT = 17

# The debug kernel's boot word letting a short machine reach the program
const SHORT_KNOB = "jab.nominimum=1"

# The kernel's line refusing a machine short of the program's demand
const KERNEL_SHORT = "jab: harts short of the program's demand: 2 for 3"

# The O frame's frozen mode bit: construction frozen
const POOL_FROZEN = 2

# Harts taken and given back through the H frame on four, refused on three
def take-holds [kernel: path, image: path, out: path, set: string, disk: path, default_frame: record]: nothing -> record<default_taken: int, asked_taken: int> {
    let base = ([{ at: $STAMP_AT, bytes: (console raise 0 --stamp) }, { at: 1400ms, bytes: (console level true false) }] | append (console settled $SPAWN_POSE))
    let launch = {|name: string, harts: int, sends: list<any>, screen: duration|
        let ended = [{ at: $screen, bytes: (pose command-frame "E") }]
        let run = (launch --kernel $kernel --image $image --out ($out | path join $"take_($name)") --set $set --sound --api --disk $disk --serial "fps" --send ($base | append $sends | append $ended | sort-by at) --screen $screen --seconds 7 --harts $harts)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on the take's ($name)"
        let outside = ($run.serial | lines | where {|l| $l starts-with "fps: dispatch outside the grant" })
        assert ($outside | is-empty) $"the take's ($name) dispatches to started harts inside the grant alone: ($outside)"
        assert ($run.screen != "") $"a screen was taken on the take's ($name)"
        $run
    }
    let moves = {|run: record| $run.serial | lines | where {|l| $MOVE_PREFIXES | any {|p| $l starts-with $p } } }
    let frames = {|run: record| $run.serial | lines | where {|l| $l starts-with "fps: frame in" } | each {|l| $l | parse $FRAME | get 0 | update cells {|c| $c | into int } } }
    let counted = {|f: record, label: string|
        let differ = ($WORKER_COUNTS | where {|c| ($f | get $c) != ($default_frame | get $c) })
        assert ($differ | is-empty) $"($label) counts as the default's: ($differ | each {|c| $'($c) ($f | get $c) against ($default_frame | get $c)' } | str join ', ')"
    }
    let pose = ($SPAWN_POSE | select x y z yaw pitch | insert roll 0.0)
    let three = { grant: $HARTS_THREE, claimed: 0, started: $HARTS_THREE, active: $HARTS_THREE }
    let placed_legs = {|n: int| [{ name: "start", places: [], pad: [] }, { name: "placed", places: (1..$n | each { $SPAWN_POSE }), pad: [] }] }
    let bound = {|run: record, legs: list<any>, from: int, expect: record, label: string|
        let m = (measure $run.api $legs)
        let bytes = (open --raw $run.screen | into binary)
        let stamp = (picture stamp $bytes)
        let b = (screen screen-frame $m $stamp $from $expect)
        assert ($b.problems | is-empty) $"($label): its screen bound to a settled frame of its window, at the spawn pose, by its workers at its grain on its harts: ($b.problems | str join '; ')"
        { m: $m, stamp: $stamp, frame: $b.frame, bytes: $bytes }
    }

    let reference_run = (do $launch "reference" $TAKE_HARTS [{ at: $TAKEN_AT, bytes: (pose pose-frame $SPAWN_POSE) }] $GIVE_AT)
    let reference_expect = { pose: $pose, workers: 3, grain: $GRAIN_DEFAULT, masks: $three, witness: null }
    let reference = (do $bound $reference_run (do $placed_legs 3) (frame answered $reference_run.api $CONSOLE_P | get 1) $reference_expect "the take's stamped reference on four harts")
    let pictured = {|b: record, label: string|
        let rows = (picture unstamped-differ $b.bytes $reference.bytes)
        assert ($rows | is-empty) $"($label) the reference's picture, the stamp's cells skipped: rows ($rows | first 5) differ, ($rows | length) in all"
    }

    let taken = (do $launch "taken" $TAKE_HARTS [{ at: $TAKE_AT, bytes: (console harts 1) }, { at: $TAKEN_AT, bytes: (pose pose-frame $SPAWN_POSE) }] $GIVE_AT)
    assert equal (do $moves $taken) $TAKE_LINES "the take on four harts stops hart 3's worker, then claims the hart"
    let taken_frames = (do $frames $taken)
    assert equal ($taken_frames | length) 4 $"the first frame and the three placements reported on the take's taken: ($taken.serial | lines | last 3)"
    let held = ($taken_frames | last)
    assert ($held.workers == 2 and $held.grain == $GRAIN_DEFAULT and $held.bands3 == 0) $"the frame read while hart 3 is taken drawn by the two started, no band on hart 3: ($held)"
    assert equal (frame band-sum $held) ($held.rounds * (($SCREEN_ROWS + $GRAIN_DEFAULT - 1) // $GRAIN_DEFAULT)) $"every band of every round rendered once while hart 3 is taken: ($held)"
    do $counted $held "the frame read while hart 3 is taken"
    let taken_expect = { pose: $pose, workers: 2, grain: $GRAIN_DEFAULT, masks: { grant: $HARTS_TWO, claimed: $HART_THREE, started: $HARTS_TWO, active: $HARTS_TWO }, witness: null }
    let taken_bound = (do $bound $taken (do $placed_legs 3) (frame answered $taken.api $CONSOLE_H | first) $taken_expect "the frame read while hart 3 is taken")
    do $pictured $taken_bound "the frame read while hart 3 is taken"
    for s in [{ name: "taken", b: $taken_bound, expect: $taken_expect } { name: "reference", b: $reference, expect: $reference_expect }] {
        let stale = (screen screen-frame $s.b.m $s.b.stamp ($s.b.frame + 1) $s.expect)
        assert ($stale.problems | any {|p| $p =~ "before the window's opening frame" }) $"the ($s.name)'s screen bound against a window opening past its frame, ($s.b.frame + 1), refused for its stamp: ($stale.problems)"
    }

    mut drawn = {}
    for asked in [{ name: "default", workers: null }, { name: "asked", workers: 3 }] {
        let label = $"the take and give-back on four harts by the ($asked.name)"
        let ask = (if $asked.workers == null { [] } else { [{ at: 1300ms, bytes: (console workers $asked.workers 0) }] })
        let run = (do $launch $"given_($asked.name)" $TAKE_HARTS ($ask | append [
            { at: $TAKE_AT, bytes: (console harts 1) }
            { at: $TAKEN_AT, bytes: (pose pose-frame $SPAWN_POSE) }
            { at: $GIVE_AT, bytes: (console harts 0) }
            { at: $GIVEN_AT, bytes: (pose pose-frame $SPAWN_POSE) }
        ]) $TAKE_CAPTURE_AT)
        assert equal (do $moves $run) ($TAKE_LINES | append $GIVE_LINES) $"($label): hart 3's worker stopped and the hart claimed, then the claim released and the hart's worker started"
        let m = (measure $run.api [{ name: "start", places: [], pad: [] }, { name: "placed", places: [$SPAWN_POSE $SPAWN_POSE $SPAWN_POSE $SPAWN_POSE], pad: [] }])
        assert ($m.complete and $m.valid and $m.schema == $CLOCK_SCHEMA) $"($label) complete and valid at schema ($CLOCK_SCHEMA): ($m.problems | str join '; ') ($m.invalid | str join '; ')"
        let answered = (frame answered $run.api $CONSOLE_H)
        assert equal ($answered | length) 2 $"($label): the take and the give-back each answered once: ($answered)"
        let take_at = ($answered | get 0)
        let give_at = ($answered | get 1)
        assert ($give_at > $take_at) $"($label): frames drawn while taken, from ($take_at) to ($give_at)"
        let three_row = [$HARTS_THREE 0 $HARTS_THREE $HARTS_THREE $HARTS_THREE 3]
        let two_row = [$HARTS_TWO $HART_THREE $HARTS_TWO $HARTS_TWO $HARTS_TWO 2]
        let wrong = ($m.rows | where {|r| [$r.grant $r.claimed $r.started $r.active $r.reported $r.workers] != (if $r.frame < $take_at or $r.frame >= $give_at { $three_row } else { $two_row }) })
        assert ($wrong | is-empty) $"($label): the masks the three harts' before frame ($take_at), the grant harts 1 2 with 3 claimed and two drawing from it to frame ($give_at), the three's again from it: ($wrong | length) frames otherwise, first ($wrong | first 3 | select frame grant claimed started active reported workers)"
        let read = (do $frames $run)
        assert equal ($read | length) 5 $"the first frame and the four placements reported on ($label): ($run.serial | lines | last 3)"
        let grain = (if $asked.workers == null { $GRAIN_DEFAULT } else { 0 })
        let while_taken = ($read | get 3)
        let after = ($read | get 4)
        assert ($while_taken.workers == 2 and $while_taken.grain == $grain and $while_taken.bands3 == 0) $"($label): the frame read while taken drawn by two, no band on hart 3: ($while_taken)"
        assert ($after.workers == 3 and $after.grain == $grain) $"($label): the frame read after the give-back drawn by three: ($after)"
        if $asked.workers != null {
            assert ($after.bands1 == $after.rounds and $after.bands2 == $after.rounds and $after.bands3 == $after.rounds) $"($label): a band a worker after the give-back, hart 3's among them: ($after)"
        }
        do $counted $while_taken $"($label), the frame read while taken,"
        do $counted $after $"($label), the frame read after the give-back,"
        let given_bound = (do $bound $run (do $placed_legs 4) $give_at { pose: $pose, workers: 3, grain: $grain, masks: $three, witness: null } $"($label), after the give-back,")
        do $pictured $given_bound $"($label), after the give-back,"
        $drawn = ($drawn | insert $asked.name ($give_at - $take_at))
    }

    let floor = (do $launch "floor" 3 [{ at: $TAKE_AT, bytes: (console harts 1) }, { at: $TAKEN_AT, bytes: (pose pose-frame $SPAWN_POSE) }] $GIVEN_AT)
    assert equal (do $moves $floor) [$FLOOR_LINE] "the take on three harts refused under the floor, nothing stopped or claimed"
    let fm = (measure $floor.api [{ name: "start", places: [], pad: [] }, { name: "placed", places: [$SPAWN_POSE $SPAWN_POSE $SPAWN_POSE], pad: [] }])
    assert ($fm.complete and $fm.valid and $fm.schema == $CLOCK_SCHEMA) $"the take refused on three harts complete and valid at schema ($CLOCK_SCHEMA): ($fm.problems | str join '; ') ($fm.invalid | str join '; ')"
    let moved = ($fm.rows | where {|r| [$r.grant $r.claimed $r.started $r.active $r.reported $r.workers] != [$HARTS_TWO 0 $HARTS_TWO $HARTS_TWO $HARTS_TWO 2] })
    assert ($moved | is-empty) $"the take refused on three harts: every frame on harts 1 2, nothing claimed: ($moved | length) frames otherwise, first ($moved | first 3 | select frame grant claimed started active reported workers)"
    { default_taken: $drawn.default, asked_taken: $drawn.asked }
}

# Start on three harts: the grant harts 1 and 2, a raster worker on each
export def started [context: record, records: record]: nothing -> record {
    let plain_run = $records."render_one plain".plain_run
    let plain_lines = ($plain_run.serial | lines)
    assert ("fps: harts reserved 2, grant 1 2" in $plain_lines) $"the plain run names its grant, harts 1 and 2: ($plain_lines | where {|l| $l starts-with 'fps: harts' })"
    assert ("fps: workers 2 on harts 1 2" in $plain_lines) $"the plain run names its workers, a raster worker on each hart of its grant: ($plain_lines | where {|l| $l starts-with 'fps: worker' })"
    {}
}

# Serial, one, two, and banded workers each drawing the default's picture
export def raster [context: record, records: record]: nothing -> record {
    let spawn_captures = $records."tiles block".spawn_captures
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let still_disk = $records."light independence".still_disk
    let default_frame = $spawn_captures.tiled.frame
    let default_bands = (($SCREEN_ROWS + $GRAIN_DEFAULT - 1) // $GRAIN_DEFAULT)
    assert ($default_frame.workers == $WORKERS_STARTED and $default_frame.grain == $GRAIN_DEFAULT) $"the default draws with every worker started in bands of ($GRAIN_DEFAULT) rows: ($default_frame)"
    assert ($default_frame.rounds == 1 and (frame band-sum $default_frame) == $default_bands and $default_frame.clear == 0) $"the default's one round, its ($default_bands) bands each rendered once, the clear theirs: ($default_frame)"
    for m in $WORKER_MODES {
        let label = $"the spawn view by ($m.workers) workers in bands of ($m.grain) rows"
        let sends = ([{ at: 1300ms, bytes: (console workers $m.workers $m.grain) }, { at: 1400ms, bytes: (console level true false) }, { at: $WORKER_FREEZE_AT, bytes: (console pool --modes $POOL_FROZEN) }] | append (console settled $SPAWN_POSE) | sort-by at)
        let run = (launch --kernel $kernel --image $image --out ($out | path join $"spawn_w($m.workers)_g($m.grain)") --set $set --sound --api --disk $still_disk --serial "fps" --send $sends --capture 3000ms --seconds 5)
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($label)"
        let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
        assert equal ($frames | length) 3 $"the first frame and the pose's two placements reported on ($label): ($run.serial)"
        let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
        assert ($frame.workers == $m.workers and $frame.grain == $m.grain) $"($label) drawn as the W frame chose: ($frame)"
        assert ($frame.tiles_built == 0 and $frame.slots == $default_frame.slots) $"($label) drawn from the pool held as the default's settled view left it, ($default_frame.slots) slots: ($frame)"
        let bands = (if $m.workers == 0 { 0 } else if $m.grain == 0 { $m.workers } else { ($SCREEN_ROWS + $m.grain - 1) // $m.grain })
        assert equal (frame band-sum $frame) ($frame.rounds * $bands) $"every band of every round rendered once on ($label): ($frame)"
        if $m.workers == 0 {
            assert ($frame.rounds == 0 and $frame.clear > 0) $"the serial backend takes no round and clears on hart 0: ($frame)"
        } else {
            assert ($frame.rounds == 1 and $frame.clear == 0) $"($label) one round, the clear the bands': ($frame)"
        }
        if $m.workers == 1 { assert equal $frame.bands1 (frame band-sum $frame) $"one worker, hart 1's, renders every band: ($frame)" }
        let differ = ($WORKER_COUNTS | where {|c| ($frame | get $c) != ($default_frame | get $c) })
        assert ($differ | is-empty) $"($label) counts as the default's: ($differ | each {|c| $'($c) ($frame | get $c) against ($default_frame | get $c)' } | str join ', ')"
        assert ($run.screen != "") $"a screen was taken on ($label)"
        let rows = (picture rows-differ (open --raw $run.screen | into binary) $spawn_captures.tiled.bytes [0 0 1920 1080])
        assert ($rows | is-empty) $"($label) the default's picture: rows ($rows | first 5) differ, ($rows | length) in all"
    }
    {default_frame: $default_frame}
}

# Workers on each machine, a grant of every secondary; short ones refused
export def machines [context: record, records: record]: nothing -> record {
    let out = $context.out
    let kernel = $context.kernel
    let image = $context.image
    let set = $context.set
    let still_disk = $records."light independence".still_disk
    let default_frame = $records."workers raster".default_frame
    let spawn_captures = $records."tiles block".spawn_captures
    for h in $WORKER_MACHINES {
        for grain in [0 $GRAIN_DEFAULT] {
            let label = $"the spawn view on ($h.harts) harts(if $h.bootargs == '' { '' } else { $', ($h.bootargs),' }) ($GFX_SLOTS) workers asked in bands of ($grain) rows"
            let sends = ([{ at: 1300ms, bytes: (console workers $GFX_SLOTS $grain) }, { at: 1400ms, bytes: (console level true false) }] | append (console settled $SPAWN_POSE))
            let dir = ($out | path join $"spawn_harts_($h.harts)(if $h.bootargs == '' { '' } else { '_late' })_g($grain)")
            let run = (launch --kernel $kernel --image $image --out $dir --set $set --sound --api --disk $still_disk --serial "fps" --send $sends --capture 3000ms --seconds 6 --harts $h.harts --bootargs $h.bootargs)
            assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($label)"
            let lines = ($run.serial | lines)
            let reserved = $"fps: harts reserved 2, grant ($h.harts_of)"
            assert ($reserved in $lines) $"($label) names its grant, ($reserved): ($lines | where {|l| $l starts-with 'fps: harts' })"
            let workers = $"fps: workers ($h.started) on harts ($h.harts_of)"
            assert ($workers in $lines) $"($label) names its workers, ($workers): ($lines | where {|l| $l starts-with 'fps: worker' })"
            let frames = ($lines | where {|l| $l starts-with "fps: frame in" })
            assert equal ($frames | length) 3 $"the first frame and the pose's two placements reported on ($label): ($run.serial)"
            let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
            assert equal [$frame.workers $frame.grain] [$h.started $grain] $"($label) drawn by the ($h.started) workers started: ($frame)"
            let bands = (if $grain == 0 { $h.started } else { ($SCREEN_ROWS + $grain - 1) // $grain })
            assert equal (frame band-sum $frame) ($frame.rounds * $bands) $"every band of every round rendered once on ($label): ($frame)"
            let banded = (1..$GFX_SLOTS | where {|s| ($frame | get $"bands($s)") > 0 } | each {|s| $s | into string } | str join " ")
            if $grain == 0 { assert equal $banded $h.harts_of $"($label) a band a worker, on the harts started: ($frame)" }
            let differ = ($WORKER_COUNTS | where {|c| ($frame | get $c) != ($default_frame | get $c) })
            assert ($differ | is-empty) $"($label) counts as the default's: ($differ | each {|c| $'($c) ($frame | get $c) against ($default_frame | get $c)' } | str join ', ')"
            assert ($run.screen != "") $"a screen was taken on ($label)"
            let rows = (picture rows-differ (open --raw $run.screen | into binary) $spawn_captures.tiled.bytes [0 0 1920 1080])
            assert ($rows | is-empty) $"($label) the default's picture: rows ($rows | first 5) differ, ($rows | length) in all"
        }
    }
    for h in $SHORT_MACHINES {
        let run = (launch --kernel $kernel --image $image --out ($out | path join $"spawn_short_($h.harts)") --set $set --sound --api --disk $still_disk --serial "fps" --seconds 6 --harts $h.harts --bootargs $SHORT_KNOB)
        assert ($h.line in ($run.serial | lines)) $"($h.harts) harts hold fewer secondaries than the reservation, refused with its line, ($h.line): ($run.serial | lines | last 3)"
        assert equal $run.status $SHORT_EXIT $"a machine short of the reservation ends the run with ($SHORT_EXIT) on ($h.harts) harts: ($run.serial | lines | last 3)"
        assert ($run.machine | get -o below_minimum | default false) $"the run past the kernel's minimum is recorded below it on ($h.harts) harts: ($run.machine)"
    }
    let kernel_short = (launch --kernel $kernel --image $image --out ($out | path join "spawn_short_kernel") --set $set --sound --api --disk $still_disk --serial "fps" --seconds 6 --harts 2)
    assert equal [$kernel_short.status ($kernel_short.serial | lines)] [1 [$KERNEL_SHORT]] $"two harts without the knob refused by the kernel before the program starts: ($kernel_short.serial | lines | last 3)"
    {}
}

# The grant moved by the H frame: a hart taken and given back, the floor
export def grant [context: record, records: record]: nothing -> record {
    let kernel = $context.kernel
    let image = $context.image
    let out = $context.out
    let set = $context.set
    let still_disk = $records."light independence".still_disk
    let default_frame = $records."workers raster".default_frame
    let take = (take-holds $kernel $image $out $set $still_disk $default_frame)
    {take: $take}
}

# The jobs: a held worker, the cancel, the fault, and idle workers asleep
export def jobs [context: record, records: record]: nothing -> record {
    let out = $context.out
    let kernel = $context.kernel
    let image = $context.image
    let set = $context.set
    let still_disk = $records."light independence".still_disk
    let default_frame = $records."workers raster".default_frame
    let spawn_captures = $records."tiles block".spawn_captures
    let take = $records."workers grant".take
    for j in $JOB_CASES {
        let label = $"the spawn view with ($j.name)"
        let sends = ([
            { at: 1300ms, bytes: (console workers 2 $j.grain) }
            { at: 1300ms, bytes: (console jobs $j.delayed $j.delay_us $j.cancel 0) }
            { at: 1400ms, bytes: (console level true false) }
        ] | append (console settled $SPAWN_POSE))
        let jobs_out = ($out | path join $"spawn_jobs_($j.grain)_($j.delayed)_($j.cancel)")
        let run = (if $j.cancel {
            let contract = ($sends | append [{ at: $STAMP_AT, bytes: (console raise 0 --stamp) }, { at: $JOB_SCREEN_AT, bytes: (pose command-frame "E") }] | sort-by at)
            launch --kernel $kernel --image $image --out $jobs_out --set $set --sound --api --disk $still_disk --serial "fps" --send $contract --screen $JOB_SCREEN_AT --seconds 5
        } else {
            launch --kernel $kernel --image $image --out $jobs_out --set $set --sound --api --disk $still_disk --serial "fps" --send $sends --capture 3000ms --seconds 5
        })
        assert equal (open --raw $run.qemu_log) "" $"QEMU has no complaint about the guest on ($label)"
        let frames = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" })
        assert equal ($frames | length) 3 $"the first frame and the pose's two placements reported on ($label): ($run.serial)"
        let frame = ($frames | last | parse $FRAME | get 0 | update cells {|c| $c | into int })
        let bands = (if $j.grain == 0 { 2 } else { ($SCREEN_ROWS + $j.grain - 1) // $j.grain })
        if $j.cancel {
            assert equal $frame.cancelled $frame.rounds $"($label) cancels its every round: ($frame)"
            assert ((frame band-sum $frame) <= ($frame.rounds * $bands)) $"($label) no band rendered twice: ($frame)"
            if $j.delayed > 0 { assert equal $frame.bands2 0 $"($label) hart 2's worker reads the cancel after its hold, its band hart 0's: ($frame)" }
            let built = ((stream $run.api).draws | where {|d| $d.tiles_built > 0 } | length)
            assert ($built > 0) $"($label) built tiles at the boundaries of frames whose every round was cancelled, the pool held unchanged through round_finish: ($built) frames"
            let m = (measure $run.api [{ name: "start", places: [], pad: [] }, { name: "placed", places: [$SPAWN_POSE $SPAWN_POSE], pad: [] }])
            assert ($m.complete and $m.valid and $m.schema == $CLOCK_SCHEMA) $"($label) complete and valid at schema ($CLOCK_SCHEMA): ($m.problems | str join '; ') ($m.invalid | str join '; ')"
            let cancelled_from = (frame answered $run.api $CONSOLE_J | first)
            let unwitnessed = ($cancelled_from..$m.final | each {|f|
                let ws = ($m.rounds | where frame == $f)
                if ($ws | length) != 1 {
                    $"frame ($f): ($ws | length) witnesses"
                } else if ($ws | first).rounds == 0 or ($ws | first).cancelled != ($ws | first).rounds {
                    $"frame ($f): rounds ($ws | first | get rounds), cancelled ($ws | first | get cancelled)"
                }
            } | compact)
            assert ($unwitnessed | is-empty) $"($label): exactly one witness for every measured frame from the J's answer, frame ($cancelled_from), through the final, frame ($m.final), rounds above 0 and cancelled equal to rounds: ($unwitnessed | first 3 | str join '; '), ($unwitnessed | length) in all"
            let placements = (frame answered $run.api $CONSOLE_P)
            let stamp = (picture stamp (open --raw $run.screen | into binary))
            let pose = ($SPAWN_POSE | select x y z yaw pitch | insert roll 0.0)
            let bound = (screen screen-frame $m $stamp ($placements | get 1) { pose: $pose, workers: 2, grain: $j.grain, masks: { grant: $HARTS_TWO, claimed: 0, started: $HARTS_TWO, active: $HARTS_TWO }, witness: "worker" })
            assert ($bound.problems | is-empty) $"($label): its screen bound to a settled frame of its window, drawn by its two workers under the cancel with its witness: ($bound.problems | str join '; ')"
        } else {
            assert ($frame.cancelled == 0 and (frame band-sum $frame) == ($frame.rounds * $bands)) $"($label) every band rendered once by the workers: ($frame)"
            assert ($frame.slowest >= $j.delay_us) $"($label) the slowest worker held ($j.delay_us) us: ($frame)"
            if $j.grain == 0 {
                assert ($frame.bands1 == $frame.rounds and $frame.bands2 == $frame.rounds) $"($label) each worker its own band: ($frame)"
            } else {
                assert ($frame.bands1 > $frame.bands2) $"($label) hart 1's worker takes the held worker's bands: ($frame)"
            }
        }
        let differ = ($WORKER_COUNTS | where {|c| ($frame | get $c) != ($default_frame | get $c) })
        assert ($differ | is-empty) $"($label) counts as the default's: ($differ | each {|c| $'($c) ($frame | get $c) against ($default_frame | get $c)' } | str join ', ')"
        assert ($run.screen != "") $"a screen was taken on ($label)"
        let shot = (open --raw $run.screen | into binary)
        let rows = (if $j.cancel { picture unstamped-differ $shot $spawn_captures.tiled.bytes } else { picture rows-differ $shot $spawn_captures.tiled.bytes [0 0 1920 1080] })
        assert ($rows | is-empty) $"($label) the default's picture, no HUD or flip before the join: rows ($rows | first 5) differ, ($rows | length) in all"
    }
    let fault_sends = [{ at: 1300ms, bytes: (console jobs 0 0 false 1) }, { at: 1500ms, bytes: (pose pose-frame $SPAWN_POSE) }]
    let fault_run = (launch --kernel $kernel --image $image --out ($out | path join "spawn_jobs_fault") --set $set --sound --api --disk $still_disk --serial "fps" --send $fault_sends --capture 3000ms --seconds 5)
    let fault_lines = ($fault_run.serial | lines | where {|l| $l starts-with "jab: worker fault: " })
    assert (($fault_lines | length) == 1 and ($fault_lines | get 0 | str starts-with "jab: worker fault: hart=1 argument=")) $"hart 1's worker faults on its round with its line: ($fault_run.serial | lines | last 3)"
    assert equal $fault_run.status 1 $"a worker's fault ends the run with status 1: ($fault_run.serial | lines | last 3)"
    if $nu.os-info.name == "linux" {
        for i in $IDLE_CASES {
            let sends = (if $i.workers == null { [] } else { [{ at: 1300ms, bytes: (console workers $i.workers 0) }] })
            let drawing = ($i.workers | default $GFX_GUIDELINE)
            let run = (launch --kernel $kernel --image $image --out ($out | path join $"spawn_idle_($i.harts)_($i.workers | default 'default')") --set $set --sound --api --disk $still_disk --serial "fps" --send $sends --seconds 6 --threads $IDLE_AT --threads-at $IDLE_READINGS --harts $i.harts)
            if $i.workers == null {
                let first = ($run.serial | lines | where {|l| $l starts-with "fps: frame in" } | first | parse $FRAME | get 0 | update cells {|c| $c | into int })
                assert equal $first.workers $GFX_GUIDELINE $"the default on ($i.harts) harts draws with GFX_GUIDELINE's ($GFX_GUIDELINE) of its ($i.harts - 1) started workers: ($first)"
            }
            assert (not ($run.threads | is-empty)) $"the threads read over the held span with ($drawing) workers drawing on ($i.harts) harts: ($run.threads)"
            let readings = $run.thread_readings
            let taken = ($readings | where {|r| $r.at != null })
            let taken_held = (($readings | length) == 3 and ($taken | length) == 2 and ($taken | all {|r| $r.at >= $r.requested and ($r.threads | any {|t| $t.name == "CPU 1/TCG" }) }))
            assert $taken_held $"the readings asked at 3 and 4 s taken at or past their requests, every hart's thread in each: ($readings | each {|r| { requested: $r.requested, at: $r.at, threads: ($r.threads | default [] | length) } })"
            assert (($readings | last | get at) == null and ($readings | last | get threads) == null) $"the reading asked past the run's end recorded missing: ($readings | last)"
            for h in $i.asleep {
                let thread = ($run.threads | where name == $"CPU ($h)/TCG" | get -o 0)
                assert ($thread != null) $"hart ($h)'s thread among ($run.threads | get name)"
                assert ($thread.rate <= $IDLE_RATE) $"hart ($h)'s worker, given no job with ($drawing) workers drawing on ($i.harts) harts, asleep: ($thread.rate) of a core over the held ($run.threads_span) s, past ($IDLE_RATE)"
            }
        }
    }
    print $"fps: the spawn view by the serial backend, one worker, and two a band a worker and in bands of ($WORKER_GRAIN) rows; on three, four, and eight harts and on four with hart 2 failed, every grant hart's worker drawing a band a worker and at the default grain; hart 3 taken and given back on four harts, ($take.default_taken) frames drawn by two while taken by the default and ($take.asked_taken) by a W of three, and the take refused by the floor on three; with a worker held and every round cancelled, each the default's picture and counts, the cancelled ones bound with a witness a frame; two and one harts refused short past the kernel's minimum by its knob, and two refused by the kernel without it; a worker's fault ends the run; an idle worker sleeps, on eight harts five past a W of two and four past the default's ($GFX_GUIDELINE)"
    {}
}
